# Integrations

## WordPress perimeter

The Flutter app integrates with WordPress through two approved providers:

- WooCommerce
- MGWS

The app must not integrate directly with ATUM, myCred or other WordPress plugins. If those plugins are used by a shop, MGWS must expose the needed behavior as its own API or gateway.

## MG Warehouse Stock

MGWS is the operational backend for:

- stock levels and locations
- movement ledger
- POS checkout
- loyalty accounts, cards and points
- employees and permissions
- suppliers, purchase orders and receiving
- physical inventory counts
- management reports and custom operational flows

Companion plugin repository: <https://github.com/Vincenzoferrara/mg-warehouse-stock>

## WooCommerce

WooCommerce remains the e-commerce source for:

- products and variants
- orders
- coupons
- customers
- standard e-commerce data exposed by WooCommerce APIs

The cashier flow delegates POS checkout to MGWS; MGWS creates the WooCommerce order and records the operational audit data.

## Authentication

Supported authentication paths include JWT, WooCommerce API credentials and WordPress Admin credentials. The JWT connector checks for known JWT routes before sending username/password; if the routes are absent, login fails without sending credentials to the backend.

`WooConnect` is the owner of authenticated transport. MGWS queries build requests on the same authenticated transport, so MGWS routes use the credentials of the active session.

## User settings sync

`GET/PATCH /wp-json/mgws/v1/me/settings` synchronizes non-secret app preferences for the authenticated WordPress user. Passwords, tokens, secrets and sensitive keys are excluded.

## Reports and dashboards

- `POST /wp-json/mgws/v1/reports/query` answers a question made of a measure, an optional split and filters. MGWS aggregates POS receipts (VAT included, document discount spread over the lines, cancelled receipts excluded, returns negative) and online order lines from the WooCommerce analytics tables, excluding the orders created by the POS. Time buckets follow the shop timezone, DST included.
- `GET /wp-json/mgws/v1/reports/catalog` lists measures, splits, filters and known values (tills, operators, payment methods).
- Both routes need `mgws_reports_read`, `manage_woocommerce` or `manage_options`; answers are cached for 120 seconds.
- `GET /wp-json/mgws/v1/dashboards`, `PUT` and `DELETE /wp-json/mgws/v1/dashboards/{id}` store personal dashboards and dashboards shared with everyone or with managers only.

## Employee credentials

The app can list and revoke employee Application Passwords and WooCommerce keys through MGWS routes. It does not generate those credentials. Credential routes require administrator-level MGWS capability and a 403 must be treated as an authorization limit for that section, not as a full employee-page failure.
