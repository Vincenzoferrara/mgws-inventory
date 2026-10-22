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
these are `Cashier`, `MGWS Inventory`, `Suppliers`, `Loyalty Cards`,
`Employees` and `Templates and print`.

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
- When the answer has no `sequential_number`, the app falls back to a local
  counter that resumes from the local maximum, so a sale is never lost and
  the sequence never goes back.
- `mg_pos_receipt_lines` stores the lines once per document, so a replayed
  checkout cannot count twice.
- MGWS computes the returnable remainder of each line from every recorded
  return, on every device. The app asks for it before a return; when the
  server is unreachable it uses the same check on `StoricoCassaStore`. The
  server figure is the one that counts.
- `StoricoCassaStore` keeps on the device the presentation data: closing
  totals, shifts and pending receipts.
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
- `print_template_catalog.dart`: the ready-made templates and categories,
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
- The dashboard filters are period, comparison and order statuses, plus a
  text filter and a limit per widget. Brands, variants and attributes are
  not offered as controls until the data layer aggregates them.

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
