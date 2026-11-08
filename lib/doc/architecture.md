# Architecture

[Documentation index](README.md)

## Principles

- The app talks directly only to **WooCommerce** and **MGWS** inside the
  WordPress perimeter. Any other plugin (ATUM, myCred…) is reached through
  MGWS, never directly.
- WooCommerce owns the e-commerce domain: products, variants, orders,
  coupons, customers. MGWS owns the shop operations: stock, movement
  ledger, point of sale, loyalty, employees, suppliers, print templates,
  reports.
- The stock **total** belongs to whoever owns the movement: WooCommerce for
  orders, the point of sale, returns, cancellations and order acceptance;
  MGWS for loads, receipts, counts, transfers and admin adjustments. MGWS
  owns the **distribution** (which shelf holds the pieces) and the product
  **cost**, and applies its own movements to WooCommerce as a delta, never
  as an absolute total. A difference between the two totals is recorded as
  a movement, not overwritten: surplus goes to the per-site *Unassigned*
  warehouse, shortage leaves real shelves in a deterministic order.
- Data that is persistent and shared by users or devices lives on
  WordPress/MGWS. Temporary or UI-only state stays in Flutter.
- UI, screen logic, domain services and backend connectors stay separate.
- Privacy first: no Google dependency in the base architecture, no hidden
  tracking, telemetry or ads, no unnecessary data collection. A feature
  that can work without Google must work without it; an optional one that
  uses an external service says so and asks first.

## Stack

Flutter and Dart; `provider` for state; `docking` for the desktop layout;
`shared_preferences` and `flutter_secure_storage` for persistence; `dio`
and `http` for the APIs; `woocommerce_flutter_api` for WooCommerce;
[`report_flutter`](https://github.com/Vincenzoferrara/report_flutter) for
printing; `flutter_zxing` (ZXing C++) for barcodes, so scanning works
without Google ML Kit; Velopack for desktop updates.

## Folders

Each main page or module has its own folder under `lib/`. When a module is
large enough, UI and logic are split into sibling files:

- `name.gui.dart`: widgets, layout, input and rendering;
- `name.code.dart`: state, orchestration and screen logic.

| Folder | Content |
|--------|---------|
| `main.dart` | Starts logger, theme, localization, runtime services and `MaterialApp` |
| `home/` | Navigation, desktop docking, mobile flow, login gate, version |
| `login/` | Authentication and authenticated connectors |
| `login/jwt_api/` | Integration layer for WordPress and WooCommerce (`WooConnect`, connectors, WooCommerce queries, `PlatformManager`) |
| `login/mgws/connection/` | The MGWS connection state (`MgwsConnection`) |
| `login/mgws/query/` | The MGWS API clients (`QueryMgws*`) |
| `checkout/` | Point of sale, checkout history, fiscal register |
| `products/` | Products list, details and editor |
| `inventory/` | MGWS stock operations and the movement ledger |
| `report/` | The shop side of `Templates and print` |
| `dashboard/` | Widgets, reports and exports |
| `ai/` | AI service and the consent dialog |
| `settings/` | Settings page and one view per module |
| `log_viewer/` | Logger and the `View logs` screen |
| `updater/` | Update check and Velopack install |
| `l10n/` | ARB files and generated localizations |
| `theme/` | `AppTheme` and the theme extensions |
| `reuse_class/` | Components used by more than one screen |
| `doc/` | These guides |

Shared components in `reuse_class/`:

- `barcode/`: the full-screen scanner (`showBarcodeScanner(context)` returns
  `String?`) and `BarcodeGenerator.generaCode128`, which builds a 30-digit
  Code 128 value (13 random digits, date and time `DDMMYYYYHHMMSS`,
  milliseconds), skips excluded values and accepts injected `random` and
  `now` for tests.
- `datagridview/`: the shared table used by every operational list.
- `device_utils/`: `DeviceUtils.isSmartphone`, `isTablet` and `isDesktop`
  classify the screen by its shorter side; `isMobilePlatform` and
  `isDesktopPlatform` read the platform.
- `gui/global_pagination_bar.dart`: the pagination bar.

## Settings

`settings.gui.dart` is the container; each module has its own settings
view. `AppSettings` holds only truly global settings or settings used by
global classes. Secrets use secure storage. Preferences that are not secret
are synced with the site through `GET/PATCH /mgws/v1/me/settings`; without
MGWS the local copy is used.

## Login and the MGWS chain

Login is the most sensitive part of the app: every change to it is reviewed
for security first, and no insecure fallback or temporary shortcut is
allowed.

- `login/auth_connector.dart` defines `AuthConnector`, the contract of every
  connector.
- `WooConnect` is the only owner of the connectors. It exposes `siteUrl`
  and `getAuthenticatedDio()` with the credentials of the active session.
  Nothing else creates a connector: a second one would not match the
  session and the MGWS routes would become unreachable.
- `JwtConnect.connect()` checks that a known JWT route exists before sending
  username and password; without the JWT plugin it fails without sending
  them. The check keeps no state and does not affect the WooCommerce API
  login.
- `home.gui.dart` only decides how the login is presented (full page on
  narrow screens, dialog on large ones); it changes nothing in
  authentication.

The chain is the same for JWT, WordPress Basic Auth (Application
Password), WooCommerce keys and auto-connect:

1. Every connection starts with `MgwsConnection.markDisconnected()`, so the
   state of the previous site cannot survive.
2. When the session succeeds, `MgwsConnection.verify()` reads the MGWS
   status routes (`inventory/status`, `loyalty/status`). It reads the body
   of the answer: the routes answer `200` also when the service is off.
   When the session fails, MGWS is not contacted.
3. A failed MGWS check does not fail the login: the WooCommerce sections
   stay usable and the MGWS sections report the backend as unavailable.

With WooCommerce consumer keys MGWS answers `401`, because it needs a
WordPress user; the app treats it as unavailable.

### The MGWS connection state

`MgwsConnection` (`login/mgws/connection/mgws_connection.dart`) is the only
owner of the MGWS state. No module keeps its own copy, and
`login/mgws/connection/` does not import `login/mgws/query/`.

- `ensureConnected()` is the entry point for modules: it reuses the check
  made by the login chain and hits the network only when the state is
  unknown.
- `verify()` always hits the network. It is reserved for the end of the
  login chain and for checks the user asks for. Modules do not call it,
  and nobody calls it before every operation.
- `markDisconnected()` runs on every session change (logout, disconnection,
  failed auto-connect, forced re-authentication).
- `lastFailure` (`MgwsUnavailableReason`) tells a backend that cannot be
  reached, a disabled service and a missing session apart, so the notice
  can say which.
- `PlatformManager.isMgwsAvailable` and `canUseMgws` read the state;
  `PlatformManager.refreshCanUseMgws()` re-checks it before an action that
  must not run on a stale state, such as a checkout.
- When MGWS is unavailable, every MGWS flow stops before the REST call and
  returns the safe value of its contract (`false`, `null`, an empty list or
  a notice).

A home section that cannot work without MGWS declares `requiresMgws: true`
in its `_HomeSection`: the card does not open and shows the notice. Today
these are `Cashier`, `MGWS Inventory`, `Transfers`, `Price lists`, `Approval
rules`, `Returns`, `Suppliers`, `Loyalty Cards` and `CalDAV`.

The home is the launcher of the standalone modules: each module screen has
its own `Scaffold` and is opened from a card. `ProductLotsScreen` is the
exception, because it needs a `productId`: it is a row action ("Lots") on the
products list, next to "Print labels" and "Delete".

## Permissions and roles

Employees are managed in `employees/`. A WordPress user's capabilities
reach the app through `PATCH /users/{id}/permissions`, which carries an
allow-list of eight capabilities (`editable_capability_whitelist`) plus
the user's roles. The app filters the card with the whitelist returned by
the server (`capability_whitelist`), not with a hard-coded list, so a newer
plugin can expose new capabilities without an app update.

Roles on top of WordPress: `mg_permission_sets` is the template table;
each set is applied as an ordinary WordPress role `mgws_{slug}`. The app
lists them through `QueryMgwsPermissionSets` and edits them in
`PermissionSetsScreen`, reachable from the employees list toolbar. A set in
use is immutable and undeletable, and the last administrator cannot be
removed. `QueryMgwsPermissionSets.list()` returns `items`, `catalog` and
`can_manage` in one call.

The catalog is an allow-list of 21 capabilities, each tagged with an area
(`stock`, `orders`, `costs`, `roles`, `lots`, `transfers`, `price_lists`,
`approvals`, `returns`, ...). A capability outside it is refused with `400`,
not ignored; `manage_options` stays out of the catalog, so no set can turn
someone into an administrator. The app has a label for every known key and
falls back to the server label for keys it does not know.

## Approval rules (`approvals/`)

Approval rules (`mg_approval_rules`) store a threshold above which a document
type requires a capability. `QueryMgwsApprovalRules` lists/creates/updates/
deletes rules and runs the stateless check (`check`). The rule only says
"approval required"; the workflow is a separate concern.

## Price lists (`b2b/`)

Price lists (`mg_price_lists` + `mg_price_list_items`) store a named set of
per-item prices, optionally scoped to a customer or a supplier, with a validity
window and a minimum quantity per tier. A price list is not the WooCommerce
retail price (`_price`): it is a separate price consulted by the app and by
internal flows (no external B2B portal exists). `QueryMgwsPriceLists`
lists/creates/updates/deletes lists and upserts/removes items.

## Stock transfers (`inventory/`)

Stateful transfers (`mg_stock_transfers` + `mg_stock_transfer_lines`) track a
transfer as draft → sent → received, or cancelled. `sent` takes the quantity out
of the source warehouse, `received` puts it into the destination, `cancelled`
from `sent` compensates the source. Each transition writes its own movement
rows (`source_type: stock_transfer`). `QueryMgwsTransfers` lists/creates/sends/
receives/cancels. The instant transfer route is untouched.

## Returns (`returns/`)

Returns (RMA) live in `mg_returns` + `mg_return_lines` and follow requested →
approved → received → refunded, or rejected from requested/approved. A return is
a trail, not a stock writer: the stock total of a return/refund belongs to
WooCommerce, so `receive` is stock-neutral (no `mg_stock_moves` row, no level
change) and the existing reconciler mirrors the new WooCommerce total into the
levels. `warehouse_id` records where the goods were physically put back
(`0` = not recorded). The refund itself is not automated: `close` only marks the
return as refunded. `QueryMgwsReturns` lists/creates/adds lines/approves/
receives/rejects/closes. `mgws_returns_manage` gates every write.

## Stock lots (`products/`)

Lots group pieces of the same item by origin and expiry date. `mg_stock_lots`
carries the supplier, the lot code, the expiry and the receipt date;
`mg_stock_lots_levels` tracks how many pieces of that lot sit on each location.
A lot is a label, not a movement: it creates no stock movement, changes no
level quantity and carries no cost (the WAC in `mg_product_costs` stays the
cost authority). `QueryMgwsLots` lists/creates/updates/deletes lots and
upserts their quantity per level.

## Back-office modules

The modules below are server-side records with a thin app surface. Each one is
a table plus a class in the plugin; none of them takes authority over the
WooCommerce total, so none of them writes `mg_stock_levels` or `mg_stock_moves`
unless it says so.

- **Mass stock reset** (`inventory/stock_reset.gui.dart`,
  `QueryMgwsStockReset`). `POST /inventory/stock/reset` sets every level of a
  warehouse — or the chosen `product_ids` only — to `target_qty`, writes one
  `adjust` movement per level and mirrors the net change to WooCommerce through
  `MGWS_Woo_Stock::commit_delta()`. It is the bulk version of a single
  adjustment, so it follows the same authority rule: the ledger is the source,
  WooCommerce receives a delta.
- **SKU patterns and barcodes** (`products/sku_barcode_generator.dart`,
  `products/sku_barcode_screen.gui.dart`). `SkuBarcodeGenerator` builds a SKU
  from a pattern and produces valid EAN-13/UPC-A codes (`isValidEan13`,
  `isValidUpcA`). The plugin side stores one code per item in
  `mg_product_barcodes` (`POST /inventory/product-barcodes`,
  `GET`/`DELETE /inventory/product-barcodes/{product_id}`), so a scanned code
  resolves without a meta lookup.
- **Supplier price history** (`mg_supplier_price_history`). Append-only prices
  paid to a supplier, separate from `_price` and from the WAC: it is a record of
  what was quoted, not a valuation input. `GET/POST /inventory/supplier-prices`.
- **Scheduled cycle counts** (`mg_count_schedules`). A schedule is a warehouse
  plus a frequency. A daily cron at 04:00 (`mgws_run_count_schedules`) opens a
  draft count session for every due schedule and moves `next_run_gmt` forward; a
  failed write leaves the schedule due so the next run retries it. The schedule
  decides *when*, the existing count session decides *what*.
  `GET/POST /inventory/count-schedules`, `PATCH`/`DELETE .../{id}`,
  `POST .../run-due`.
- **Kits** (`mg_kits` + `mg_kit_components`). A kit names a bundle and its
  pieces with quantities. The kit product is what WooCommerce sells and counts;
  the components are separate products whose stock must also move. Deduction is
  never automatic: the caller decides *when* and *from which physical site*.
  - **Site = physical location** (negozio, magazzino centrale, filiale). The
    site is the unit of deduction: POS always deducts from the site linked to
    the cash register; for a WooCommerce order the operator chooses the site
    from the availability list.
  - **Warehouse = virtual grouping** inside a site (es. "Magliette", "Scarpe").
    It is a logical separator, not a deduction unit: availability is summed
    across every warehouse of the chosen site.
  - **Room / rack / shelf = final physical location** of the piece inside the
    warehouse; shown at picking time and recorded on the movement.
  - Availability: `GET /inventory/kits/availability?product_id=&variation_id=&qty=`
    returns one entry per physical site with `available_kits` and an
    `available` flag; sites without enough components are listed as
    `available: false` (non disponibile in questa sede), with no fallback to
    other sites.
  - Deduction: `POST /inventory/kits/deduct` takes `site_id`, `product_id`,
    `variation_id`, `qty`, optional `ref_order_id`; writes `out` movements for
    the components from that site only.
  - Restore: `POST /inventory/kits/restore` gives the components back to the
    same site (used on cancel/refund/RMA).
  - Order acceptance: `POST /inventory/orders/{id}/accept` expands kit lines
    into component deductions from the site chosen by the operator.
  - POS checkout: `/pos/checkout` expands kit components server-side in the
    same transaction. The Flutter POS shows advisory kit/component availability
    warnings (via `GET /inventory/kits/availability`) before checkout; the
    server remains authoritative for deduction.
  `GET/POST /inventory/kits`, `GET`/`DELETE .../{id}`,
  `POST .../{id}/components`, `DELETE .../components/{id}`.
- **Documents** (`mg_documents`). DDT, invoices and credit notes as metadata:
  type, number, reference, status (`draft` → `issued` → `sent`, or `cancelled`),
  issue date and PDF path. The row is the record; rendering and delivery stay
  with the caller. `POST /inventory/purchase-orders/{id}/send` uses this table
  to record a sent purchase order and emails the supplier when an address
  exists.
- **Payments and aging** (`mg_payments`). A payment is an amount against a
  `reference_type`/`reference_id`, not a link to a real invoice (documents are
  metadata). `GET /inventory/payments/aging` buckets the outstanding amounts
  into `0-30`, `31-60`, `61-90` and `90+` days.
- **Shipments** (`mg_shipments`). Generic over `reference_type`/`reference_id`,
  with `pending` → `shipped` → `delivered` and `cancelled`. A shipment is a
  trail, not a movement.
- **Reservations** (`mg_reservations`). `active` → `released`/`consumed`; a
  reservation never changes a level, it records intent. `release`/`consume`
  answer `409` when the reservation is not `active`.

## Point of sale (`checkout/`)

- `QueryMgwsPos` handles the shift, the idempotent checkout and the
  receipts; see [Integrations](integrations.md#point-of-sale).
- The receipt number is allocated by MGWS during checkout. `mg_pos_receipts`
  has one row per document and a unique index on
  `(business_day_id, register_name, sequential_number)`, so two tills
  cannot produce the same number and a reinstall cannot restart the
  sequence. Each register has its own sequence per business day.
- With a fiscal register attached, the device issues the number and the app
  sends it as `receipt_number`; MGWS records it instead of allocating one.
- The device keeps no copy of the history. `StoricoCassaServer`
  (`checkout_history.code.dart`) reads receipts, lines, the open shift and
  the closings from MGWS, so a reinstall or a new device finds everything.
  The only in-memory state is the open shift, reloaded when the till opens.
- `mg_pos_receipt_lines` stores the lines once per document, so a replayed
  checkout cannot count twice. Operation and movement types are stored in
  canonical form (`sale`, `return`, `exchange`) whatever the app sends.
- MGWS computes the returnable remainder of each line from every recorded
  return, on every device, ignoring cancelled documents. The app reads it
  before a return (`validaReso`) and the checkout checks it again; without
  the server no return is prepared.
- The shift totals and the till counters (`CassaMetricheSnapshot`) are
  built from `GET /pos/receipts` for the open shift, or for the register's
  business day when no shift is open.
- `checkout/fiscal_register/` isolates the fiscal register behind a driver
  contract; the POS never speaks a vendor protocol. `FiscalRegisterRepository`
  selects and stores the driver. Simulation is a declared mode, not a
  fallback: it issues nothing and returns no number, and
  `Scontrino.numeroProgressivoDispositivo` holds the number when a device
  issues one. A failing driver never blocks the till: the sale is recorded
  and the failure is logged.
- The operator is the logged-in username, stored as an identifier only.

## Inventory (`inventory/`)

- `QueryMgwsInventory` exposes typed models and injectable gateways; the
  controllers never call Dio directly.
- `InventoryModule` (`inventory_module.code.dart`) lists the modules.
  `writesStock` decides whether the `Details` field makes sense;
  `canResumeFromLedger` says whether the module can reopen a movement. It
  lives outside the page so the panels can name their module without
  importing the page; icons stay in the page.
- `InventoryProductSection` is shared by the three working panels: barcode
  field, search button, quick-mode box and row list, with each module's own
  label and `keyPrefix`. `Details` belongs to the page (`InventoryPage`)
  and the panels read it.
- `InventoryAddProductsController` merges the simple stock-in and the
  supplier-order stock-in: the stock movement is identical in both modes.
- `InventoryQuickLoadController.submitPlan()` sends one request per row,
  keeps each row's idempotency key and returns partial results and rows to
  retry. Empty location values are left out of the payload.
  `InventoryQuickLoadSettings` hides a location level whose list is empty.
- `InventoryQuickLoadCatalogController` adapts the progressive product
  loading of `ProdottiGestioneController`: variable products are groups,
  only concrete variants become rows, and `findByBarcode` searches simple
  products then variants.
- `InventoryRettificaController` prepares `reconcileStock` with a required
  reason and writes only when sent. The direction (`Increase`/`Decrease`)
  belongs to the section, not to the row. `InventoryRettificaPlan` sends
  every row and collects all results in `lastResults` instead of stopping
  at the first error.
- `reconcile` has no note field: `inventoryMovementText` appends the
  details to the reason when they are not already there. `quick-load` and
  `stock/move` have a real note.

### The movement ledger

- A movement is a set of rows: MGWS writes one row per product. Every row
  of one submission carries the same `movement_key`
  (`newInventoryMovementKey()`), and MGWS creates the movement header with
  the first one and reuses it.
- Grouping follows `movementId`; `sourceType#sourceId` is the fallback for
  rows without a header, and `riga#<id>` leaves the rest alone, because one
  row too many is better than two operations merged. `_classify` reads
  `stockEffect`, then `sourceType`, then `type`; an unknown type stays
  `InventoryMovementKind.altro` and shows the raw word.
- A transfer has two rows per product whose deltas cancel out:
  `InventoryMovementGroup.products` merges them and the detail shows
  `movedQuantity` and the route `from -> to`, not `+0`.
- MGWS paginates the ledger and `MgwsMovementFilter` has no document
  filter, so a very large operation can be split: the default page is 100
  rows and the panel warns when the answer is incomplete.
- Reopening (`Edit`) works for `Adjustment` (from the absolute value left by
  the movement) and `Transfer` (from the route written in each row as
  `warehouse_from`/`warehouse_to`, with the sites, because the same
  warehouse number can exist in two sites). A stock-in is never reopened:
  its route can only increase stock. `InventoryPanelSeed` is consumed once
  (`stamp`). Seeded rows use the absolute `stockAfter`, quick mode is
  switched off, and products removed from a reopened adjustment become
  explicit restores (`InventoryRettificaRestoreLine`).
- The ledger has no update or delete route, and must not have one.
  `InventoryMovementRevertController.prepare` undoes a movement by writing
  a new one: a counter-movement with `stock/reconcile` back to
  `stock_before`, allowed only while the current stock still equals
  `stock_after`; for a transfer, a reverse transfer with `stock/move`,
  allowed only while the destination still has the pieces. Both checks
  read the network per product, so the button stays off until the plan is
  ready, and each blocked row is named.
- The only stock-changing actions are confirmed stock-in, adjustment,
  transfer and undo. Suppliers, reorder, purchase orders, delivery drafts
  and counts are stock-neutral.

### Costs and stock value

- MGWS owns the cost: `mg_product_costs` holds the declared cost of a
  product or variation as an append-only history, and a correction is a new
  declaration, never an edit. A variation without its own declaration
  inherits the parent's. A missing cost is `null`, not `0`: a zero margin and
  an unknown margin are different facts and the app must not draw them the
  same way.
- Money crosses the wire as integer minor units (`cost_cents`,
  `value_cents`, `unit_cost_cents`) plus a `minor_unit` factor that the
  server fixes at installation from WooCommerce's price decimals. The app
  never re-derives the scale from its own locale, because the shop's stored
  values keep the scale they were written with.
- `mg_stock_levels.stock_value_cents` is the value of the pieces on one
  shelf. It moves with the quantity at the level's average cost, so a
  movement can change the value without anyone declaring a price. It is
  nullable, and an unknown value stays unknown rather than becoming zero.
  Declaring a cost sets the basis for the pieces that arrive next; it does
  not rewrite the value of the pieces already on the shelf.
- Revaluation is the only path that changes the value without a movement:
  `POST /inventory/costs` with `revalue_stock` sets `stock_value_cents` to
  quantity × cost on the item and, when the declaration is on the parent, on
  the variants that have no declaration of their own. A variant with its own
  withdrawal is excluded: it said it does not know the cost. A withdrawal
  (`cost: null`) never revalues (`revalue_skipped: "cost_missing"`), and the
  declaration is written before the value so the new value always has a
  declaration behind it.
- The declared cost is projected one way to WooCommerce's Cost of Goods Sold
  field when that feature is on. MGWS values stock either way: the
  projection is what makes order margins readable in WooCommerce, not what
  makes the stock value correct.
- `purchase_price` was a dead field in the unified inventory model and is
  gone; the cost of an item is read from the cost route, not inferred from
  the stock payload. The order-line form still sends `0` as its unit cost
  when the load line carries none: a receipt has no cost field of its own,
  so the order line is the only carrier, and `0` there means "not filled",
  which the receipt turns back into an unknown cost rather than a free item.
- There is no separate Costs screen. The cost lives where the work happens:
  a per-row field in the quick load, a card in the product editor (one
  question per product, the parent for a variable product, with the
  revaluation switch), and a "products without cost" card on the dashboard.
  "Without cost" means "without value": an item with quantity and at least
  one level whose `stock_value_cents` is null, not an item without a
  declaration.
- The app normalizes the decimal separator only (comma to dot) and never
  rounds: the plugin converts to minor units with the scale fixed at
  installation. A cost equal to the saved one is not re-declared, so the
  append-only history does not grow a row per save.

## Products (`products/`)

- `product_list/` publishes each WooCommerce page as soon as it loads
  and keeps loading the next ones in the background. Selecting a variable
  product loads every page of its variants and passes the product
  attributes to their conversion. Quick edit uses the WooCommerce statuses
  `publish`, `private`, `draft` and `pending`.
- Variable product prices come from the variants: on `wc/v3` the parent may
  expose only the active price. The price cache of `DataGridViewCache` is
  invalidated on every variant update and reads first the variants attached
  to the product instance, then the shared variant cache.
- Ticked variants (`_checkedVariantIds`) are printed, bulk edited
  (`saveVariantQuickEdits`) or deleted (`ProdottiGestioneController.deleteVariants`):
  the MGWS stock of each variant is first set to 0 on every site with
  `reconcileStock` (one `movement_key` per deletion), and the WooCommerce
  variation is deleted (`force: true`) only when that succeeded. Nothing is
  deleted while MGWS is unavailable. `onVariantsChanged` refreshes the page.
- `product_editor/` is a stepper (basic info, prices and stock, images,
  details, variants). In edit mode it reloads a fresh `ProdottoGlobal` by
  ID, with the product code as fallback. Top-level barcodes are sent only
  for simple products. On update the parent's variation attributes are not
  sent, so the global WooCommerce attributes are not rewritten. After
  saving, the product cache is marked dirty and the product's variant cache
  is removed. Variant images: the first becomes `image`, the next ones
  `gallery_image_ids`, with the `immagini_variante` meta as fallback for
  URLs without a media ID.
- Product codes: `codiceProdotto` is the WooCommerce `sku`; `barcodeInterno`
  is `global_unique_id`; `barcodeProduttore` (product) and
  `barcodeFornitore` (variant) are `barcode_manufacturer`. SKU and barcodes
  are never used as fallbacks for each other.
- The editor's cost card (`_buildCostoProdotto`) declares the cost on the
  parent (`variation_id = 0`) so the variants inherit it, after the MGWS
  stock is written so a revaluation reads the final quantity. An empty field
  is a withdrawal only if the product had a cost; an unreadable cost leaves
  the field empty and declares nothing (`_costoNonDisponibile`), because a
  missing answer is not a missing cost.

## Templates and print (`report/`)

The print system is the [`report_flutter`](https://github.com/Vincenzoferrara/report_flutter)
library: template library (`PrintLibrary`), paper formats, the print center
(`PrintCenter`), the designer, the PDF renderer, the preview and its
translations (`ReportLocalizations`, registered in `main.dart`). The app
keeps what is specific to the shop:

- `print_data.dart`: the global `printLibrary` on `MgwsPrintStore`, with
  the ready-made paper formats and the catalogue templates and categories,
  and `ShopPrintDataProvider`: example data, the example-data notice of
  reports, product rows only on product labels, `openProdottoPicker` for
  `Add label`, and the colour/size separator in the designer bar (template
  setting `variant_separator`).
- `mgws_print_store.dart`: `MgwsPrintStore` on the MGWS `/print` routes
  through `QueryMgwsPrint`. The content travels as the `data_json` string,
  because WordPress decodes JSON bodies into PHP arrays where `{}` would
  become `[]`.
- `print_template_catalog.dart`: the ready-made templates and categories
  (labels, shop signs, reports including invoices/Fattura and quotes/Preventivo),
  built with `PrintDesign`.
- `print_sample_data.dart`: the fields. `ShopTemplateKind` (product label,
  shop sign, report) is an app setting stored as `kind`; templates without
  it are product labels. Product keys reuse `ProdottoGlobal.toMap()` and add
  `taglia`, `colore`, `coloreTaglia`, `prezzoTesto`,
  `prezzoPrecedenteTesto` and `scontoTesto`; variant code, barcode and
  price replace the product ones. `tagliaColore` carries the same value as
  `coloreTaglia` for older templates. These keys are stored in saved
  templates: never rename them.
- `print_job.dart`: `labelJobFromProducts` turns products and variants into
  `PrintRow`s, one per variant with stock and one label per piece;
  `pendingPrintJob` hands the job to the print center and
  `requestHomeSection(printSectionId)` opens the section.
- `report.gui.dart`: `PrintCenterPage`.

## Dashboard (`dashboard/`)

- `dashboard_customization.dart`: the page (picker, filter bar, grid, edit
  mode with drag and drop, widget editor, visibility dialog).
- `dashboard_layout.dart`: dashboards, widgets and filters, serialised in
  lowercase snake_case JSON because MGWS sanitises keys with
  `sanitize_key`. `DashboardLayout.standard` has one widget per
  `DashboardMetric` (an assert keeps it complete). A metric declares its
  shape (single value, time series, categories) and the charts that fit.
- `dashboard_widget_data.dart`: turns the data into a `DashboardDataset`
  (one value or labelled points). `dashboard_widget_view.dart` draws it;
  parts of a whole use the fixed palette and fold items past the seventh
  into "Other".
- `dashboard_layout_store.dart`: stores dashboards through
  `QueryMgwsDashboards`; who can manage shared dashboards is decided by the
  server (`can_manage_shared`). Without MGWS, personal dashboards fall back
  to `SharedPreferences`.
- `dashboard_report.dart` and `dashboard_report_editor.dart`: custom
  reports. A `DashboardReportQuery` (measure, optional `ReportDimension`,
  filters) is sent to MGWS, which aggregates in SQL: the app never
  downloads all orders to build a report. One request per distinct
  question (`dashboardReportKey`). A new measure is added first to the MGWS
  engine (`includes/class-mgws-reports.php`), then to `reportMeasures` and
  `reportMeasureLabel`, with translations.
- A report has one of three sources and never mixes them: `sales` (POS
  receipts and online orders), `closings` (till sessions) and `stock` (the
  levels as they are now, not as they were in the period). The stock
  measures are `qty_on_hand`, `stock_value`, `unvalued_qty`,
  `stock_cost_coverage`, `sold_qty`, `rotation` and `days_without_sale`;
  `cost_coverage` belongs to `sales`. `sold_qty` is null when the rows are
  sites or warehouses, and a null `days_without_sale` means the product
  never sold, so the row is labelled "never sold" instead of showing zero.
- A margin is only as good as the costs behind it. POS receipt lines carry
  the cost snapshot taken when the receipt was issued
  (`cost_total_cents`, `unit_cost_cents`); online orders have no line cost
  yet, so a margin there is mostly uncovered. For this reason, when a widget
  asks for `margin` or `margin_rate` the request also carries
  `cost_coverage`, and the card declares a coverage below 100% next to the
  value instead of showing a full margin. `revenue_share` is the ABC curve:
  the share of the period revenue each group carries.
- `DashboardMetric.stockDivergences` reads
  `GET /inventory/stock/divergences`: one row per item whose WooCommerce
  total differs from the MGWS total, with the difference (`woo - mgws`).
  It is read-only and never corrects. Items WooCommerce does not manage have
  no second number and are skipped, so "0 divergences" means "everything
  with two numbers agrees", not "everything is aligned".
- The dashboard filters are period, comparison and order statuses, plus a
  text filter and a limit per widget. Brands, variants and attributes are
  not offered as controls until the data layer aggregates them.
- `DashboardMetric.productsWithoutCost` and
  `DashboardMetric.stockDivergences` are the two metrics read from MGWS
  instead of WooCommerce: the first counts the items in stock with an
  unvalued level (`GET /inventory/costs/missing`), the second ranks the
  items whose totals disagree (`GET /inventory/stock/divergences`). Both
  ignore the period, and a failure shows as "unavailable", never as zero.
  `DashboardDataBundle` carries them in
  `missingCostItems`/`missingCostFailed` and
  `divergences`/`divergencesFailed`, loaded in `_loadSecondary` next to the
  other heavy sources.

## Logging

`log_viewer/app_logger.dart` exposes the global `log` (`log.v`, `log.d`,
`log.i`, `log.w`, `log.e`, `log.f`). It keeps a ring buffer in memory and
writes files only when the user starts recording, in the app's temporary
folder `mgws_inventory_logs`. Message, error and stack trace are sanitised
at every level. See [Security](security.md#logs).

## Language changes

A language change reaches every visible string without a restart. A widget
that stays mounted reads its translations in `build`: storing them in a
field, or in a list captured by a widget inserted once in the docking
layout, keeps the old language. The home landing page therefore takes a
section builder, not a prebuilt list. Tab titles are the exception: the
docking library reads them from `DockingItem.name`, so
`HomeLogic.aggiornaTitoli` rewrites them during the rebuild, and the
instance suffix (`#2`, `#3`) is stored once in `HomeTabMeta.istanza`.
