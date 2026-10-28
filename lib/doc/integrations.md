# Integrations

[Documentation index](README.md)

## Overview

| Service | Used for | When |
|---------|----------|------|
| WooCommerce REST API | Products, variants, orders, coupons, customers, taxes | Always |
| MGWS REST API (`/wp-json/mgws/v1`) | Stock, POS, loyalty, employees, suppliers, print templates, reports, dashboards, user settings | When the plugin is installed |
| AI providers | Product descriptions, categories, tags | Only if configured; cloud ones after consent |
| GitHub API | Update check | Desktop and Android builds from GitHub only |
| Smart card (NFC/USB), RFID | Staff login cards, tag and barcode reading | Only if used |

The app never talks directly to other WordPress plugins such as ATUM or
myCred: if a shop uses them, MGWS exposes what is needed.

## Authentication

| Method | How |
|--------|-----|
| WordPress Admin | Username and password; the app provisions an Application Password for the device and uses Basic Auth. |
| JWT | Username and password exchanged for a token. Before sending them, the connector checks that a known JWT route exists; if none does, it fails without sending the credentials. |
| WooCommerce API | Consumer Key and Secret. They authenticate only the `wc/` routes, so MGWS (which needs a WordPress user) answers `401`. Independent of the JWT plugin. |
| Smart card | NFC (NDEF) or USB card prepared for an employee. |

`WooConnect` owns the authenticated transport: MGWS requests are built on
the same transport, so they always carry the credentials of the active
session. See [Architecture](architecture.md#login-and-the-mgws-chain).

## WooCommerce

The app uses `woocommerce_flutter_api` v2 (consumer key and secret,
`WooSort`/`WooOrderBy` sorting, `WooPage<T>` paginated results, and
`updateXxx(id, item)` / `deleteXxx(id)` with the ID first).

- Variants are read with `getProductVariations` (all pages through
  `getAllVariations`, one with `getVariationById`) and changed with
  `updateVariation` and `updateVariationStock`; products in bulk with
  `batchUpdateProducts`. Errors are logged and raised, with no alternative
  transport.
- `WooQueryTasse.getTaxRates(country, state)` filters by country and state
  in the app, because the WooCommerce endpoint does not: it reads every tax
  rate, filters, then returns the requested page.
- The POS does not create WooCommerce orders itself: MGWS does it during
  checkout.

## MGWS

Companion plugin: <https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>.

Every route needs an authenticated WordPress user (`401` otherwise) and the
capability of that route (`403` otherwise). Clients handle `400`, `401`,
`403`, `404`, `409` and `503` as normal answers of the contract. Public
errors never contain SQL, tokens, passwords, local paths or other
customers' data.

The clients live in `lib/login/mgws/query/`:

| Client | Routes |
|--------|--------|
| `QueryMgwsPos` | `pos/settings`, `pos/shifts`, `pos/checkout`, `pos/receipts` |
| `QueryMgwsInventory` | `inventory/*` (stock, movements, suppliers, reorder, purchase orders, receipts, counts, sites) |
| `QueryMgwsLoyalty` | `loyalty/*` |
| `QueryMgwsEmployees` | `employees`, `users/{wp_user_id}/…` |
| `QueryMgwsUserSettings` | `me/settings` |
| `QueryMgwsPrint` | `print/*` |
| `QueryMgwsReports` | `reports/query`, `reports/catalog` |
| `QueryMgwsDashboards` | `dashboards` |
| `QueryMgwsSite` | site information |

### Point of sale

- `GET/PUT /pos/settings`: global settings, including `turno_obbligatorio`
  (mandatory shift). Changing them needs a shop manager.
- `POST /pos/shifts` opens a shift with a `shift_key`; the app saves the
  local shift only after the server accepted it.
- `POST /pos/checkout` sends sale lines, return lines, customer, payment
  methods, totals, meta and, when a shift is open, `shift_id` (or the
  `_turno_id` meta). MGWS creates the WooCommerce order, writes the stock
  movements in `mg_stock_moves`, updates `mg_stock_levels` and answers with
  `success`, `order_id` or `woo_order_id`, the order status, totals,
  processed lines and `sequential_number`.
- **Idempotency**: `idempotency_key` in the payload is the key; without it
  MGWS uses the `_id_scontrino_locale` meta. Same key and same payload
  returns the saved answer without a second order or new movements; same
  key and different payload answers `409 mgws_idempotency_conflict`; a
  request still running answers `409 mgws_idempotency_in_progress`. A
  request with no key is accepted but not protected from duplicates.
- With the mandatory shift on, a checkout without an open server-side shift
  is refused with `409`; with it off, the shift reference can be omitted
  and the order gets no `_mgws_shift_id` meta.
- **Returns and exchanges**: return lines send `source_sale_id`,
  `source_line_key`, `return_reason` and `return_outcome`. MGWS checks the
  origin and the returnable remainder and answers `409` beyond it.
- `POST /pos/shifts/{shift_key}/close` sends only the counted cash and card
  totals, reason and notes. MGWS computes `expected_totals` from the
  shift's orders and returns the differences.
- `GET /pos/receipts` lists documents with aggregate totals;
  `GET /pos/receipts/{receipt_key}` returns a document with its lines and
  the `returnable` map.

### Inventory

`mg_stock_levels` is the authoritative stock; WooCommerce stock is a
synchronised projection.

**Reading**: `inventory/status`, `stock/product/{productId}`, `stock/all`,
`statistics`, `low-stock`. Sites, warehouses and locations come from
`/inventory/sites`, `/inventory/warehouses` and `/inventory/locations`.

**Writing**:

- `POST /inventory/quick-load`: stock-in of a product or variant, positive
  quantity, reason, optional note, idempotency key, optional `warehouse_id`,
  `room`, `rack`, `shelf` (left out when empty; MGWS then uses the first
  allowed warehouse). It never requires a supplier, order, invoice or
  delivery note. It creates a `load` movement.
- `PUT /inventory/stock/reconcile`: sets a product to an absolute value
  (`product_id`, `correct_stock`, `reason`, `site_id`). It has no note
  field. `site_id` is never guessed: it can be zero only in a shop with one
  site; with more sites it must be given, or the route answers with an
  error instead of writing everywhere.
- `POST /inventory/stock/sync`: copies WooCommerce stock into
  `mg_stock_levels`, with the same `site_id` rule.
- `POST /inventory/stock/move`: moves pieces between locations without
  changing the total; it has `note` and `to_room`. Used for transfers and
  for undoing them, never for adjustments.
- `POST /inventory/rfid/scan`: resolves a tag or barcode; never changes
  stock.

All three write routes accept an optional `movement_key`: the app sends
one request per product with the same key, and MGWS creates the movement
header (`mg_stock_movements`) with the first and reuses it. Rows written by
the plugin's internal flows have no key and no header.

**Movement ledger**: the movement routes read `mg_stock_moves` with filters
and details. There is no update or delete route: a movement is never
changed or removed. Undoing one records a new movement next to it, with the
original number in the reason (see
[Architecture](architecture.md#the-movement-ledger)).

**Purchasing** (stock-neutral until a delivery is validated):

- Suppliers: list, detail, create, update and deactivate the `mg_fornitori`
  registry (`/inventory/suppliers`). The name is required, the email
  optional. Suppliers are global (no `site_id`) and are not WordPress users
  or WooCommerce customers.
- Reorder: rules and suggestions from low stock, defer/snooze, draft orders.
- Purchase orders: drafts, product and variant lines, status, dates, costs,
  cancellation.
- Receipts: drafts with received, rejected and back-ordered quantities and
  reasons, `pending_verification` and validation. Only validation changes
  `mg_stock_levels`, once and idempotently; a receipt pending verification
  needs `mgws_purchase_approve`. Validation also writes the purchase cost
  in the `_purchase_cost` meta of the product or variant.

The supplier list is reachable from the home screen; the reorder, purchase
order and receipt panels exist in the code but are not offered by the
inventory module selector today.

**Physical counts**: the `count-sessions` routes create, list, read and
update sessions, rows and discrepancies. Rows can resolve a known barcode or
tag but change nothing. Approving a session applies the discrepancies to
`mg_stock_levels` with `adjust` movements linked to session and row, and
makes the session read-only.

### Loyalty

Service status, customer account, lookup by card or email, create or edit
a card, remove a card, add points, remove points, history and statistics.

- Removing a card deletes only the card number; the account and the history
  stay. It answers `404` when there is no card (not idempotent).
- Removing more points than the balance answers
  `400 mgws_insufficient_points`.
- The history is append-only, paginated and newest first.
- `503` means the loyalty storage is not ready.

### Employees

- `GET/POST /employees`, `GET/PATCH/DELETE /employees/{id}`: staff records
  with optional `wp_user_id` and salary as `salary_cents` and
  `salary_currency`. `DELETE` disables the employee; it does not revoke
  credentials.
- `GET/PATCH /users/{wp_user_id}/permissions`: roles and capabilities,
  only for an employee linked to a WordPress user, within the app's
  allow-list. There is no generic user list route.
- `GET /users/{wp_user_id}/app-passwords`, `GET /users/{wp_user_id}/woo-keys`
  and the matching `DELETE` routes list and revoke credentials. The app
  never creates them. They need `mgws_manage_credentials`, which MGWS gives
  only to administrators: a `403` there limits that section, not the whole
  employee card.

### Print templates

The `/print` routes read and write the template library shared by the site:
templates, categories and paper formats. Item content travels as the
`data_json` string. Changes need `manage_options` or `manage_woocommerce`.

### Reports and dashboards

- `POST /reports/query` answers a question made of a measure, an optional
  split and filters. MGWS aggregates in SQL the POS receipts (VAT included,
  document discount spread over the lines, cancelled receipts excluded,
  returns negative) and the online order lines from the WooCommerce
  analytics tables, excluding the orders created by the POS. Time buckets
  follow the shop timezone, daylight saving included.
- `GET /reports/catalog` lists measures, splits, filters and known values
  (tills, operators, payment methods).
- Both need `mgws_reports_read`, `manage_woocommerce` or `manage_options`;
  answers are cached for 120 seconds.
- `GET /dashboards`, `PUT` and `DELETE /dashboards/{id}` store personal
  dashboards (user meta) and dashboards shared with everyone or with
  managers only (site option). The answer says whether the user
  `can_manage_shared`.

### User settings

`GET/PATCH /me/settings` syncs the app preferences that are not secret for
the logged-in WordPress user. Passwords, tokens, secrets and sensitive keys
are excluded. If the remote profile is empty, the app fills it with the
local preferences.

## AI providers

`lib/ai/ai_service.dart` calls the active provider with the user's own key:
OpenAI, Anthropic, Google AI, Mistral (not implemented yet: it reports so)
or a local Ollama server. Before the first call to each cloud provider,
`lib/ai/ai_consent.dart` asks for consent and stores it per provider. AI is
never required for the shop to work.

## CalDAV

The `CalDAV` module (`lib/caldav/`) is not finished and is hidden: the home
shows it only in builds made with `--dart-define=CALDAV=true`. When enabled,
it connects to the server the user enters and keeps the credentials in secure
storage.

## Update check

`updater/updater_service.dart` reads
`https://api.github.com/repos/Vincenzoferrara/mgws-inventory/releases/latest`.
On Windows and Linux, Velopack downloads and installs the release. On
Android the app only notifies. Builds made with
`--dart-define=UPDATE_CHECK=false` (Flathub, Google Play) skip the
check on every platform, and a Flatpak never runs Velopack because Flathub
delivers its updates. See [Developer guide](developer-guide.md#build-options).
