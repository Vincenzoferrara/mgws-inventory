# User Guide

## What the app is for

mgws_inventory manages daily work in a clothing store: POS sales, products, orders, customers, loyalty cards, stock operations, reports and configuration.

## Access

1. Enter the site URL.
2. Choose the login method.
3. Use JWT, WooCommerce API or WordPress Admin credentials.
4. If you work on a local or private network backend, enable local development.

On smartphones and narrow screens the login opens as a full page. On large screens it opens as a dialog over the main area. The top bar shows the log button and login status.

## Main areas

- `Cashier` - POS sales, cash shift and local POS history
- `Products` - catalog, variants, images, barcode and stock information
- `MGWS Inventory` - add, reconcile, move and inspect stock movements
- `New Product` - product creation
- `Coupons` - discounts and promotions
- `Orders` - order management
- `Customers` - WooCommerce customers
- `Loyalty Cards` - loyalty points and cards
- `Reports` - labels, QR codes and printing
- `Dashboard` - sales, products, orders, stock and PDF/CSV reports
- `Settings` - app and module preferences
- `Updates` - desktop update checks and installation
- `Employees` - staff registry, WordPress user link and MGWS permissions

## Customers and employees

`Customers` manages WooCommerce customers. It does not manage operational roles or capabilities.

`Employees` manages internal staff records stored in MGWS. If an employee has a WordPress account, set the `WordPress user ID` in the employee form. Roles and capabilities are available only for employees linked to a WordPress user.

The `Active credentials` section can revoke Application Passwords and WooCommerce keys when the logged-in user is an administrator.

## Barcode and QR scanning

Barcode and QR actions open the shared full-screen scanner on smartphone and tablet. The scanner returns the detected code to the flow that opened it.

In `Cashier`, the left side contains barcode input, scanner button and manual-add button. A scanned code adds the matching product or variant to the cart when stock is available.

## Products

The `Products` screen is the operational catalog workstation.

- The filter panel searches by SKU, product name, barcode and other fields.
- Active filters appear as removable chips.
- The column chooser controls visible table columns.
- The shared DataGridView supports selection, pagination, horizontal scrolling and row context actions.
- Desktop layout shows list and details side by side; small screens open details on a dedicated page.
- Product details show image gallery, product data, quick edit, variants and stock information.
- Product creation/editing supports basic info, categories, tags, descriptions, brand, status, barcodes, images and variants.
- The images tab preserves original images, supports preview, cover selection, gallery order and dimension checks.
- The variant editor groups variants by attributes when available and supports variant-specific image, barcode, price, sale price and quantity.
- The automatic barcode button generates a Code128-compatible numeric code and avoids duplicates already present in the form.
- Optional MGWS stock reconciliation can run after saving when the product has a valid ID.

## MGWS Inventory

`MGWS Inventory` is the stock workstation. MGWS remains the authoritative source for operational stock and movement ledger data.

Available modules:

- `Add` - add stock to the warehouse
- `Reconcile` - set stock to counted final values or apply increment/decrement quick corrections
- `Move` - transfer stock between locations without changing total quantity
- `Movements` - read the MGWS movement ledger grouped by operation

The operational modules share barcode input, product picker and product rows. The `Details` field is shared by operations that write movements and is hidden in the read-only movement ledger.

Movement details can show stock before/after, reopen supported operations or create undo movements. Undo never deletes the original ledger row; it writes a new counter-movement.

## Dashboard

The dashboard shows the active period, sales, orders, products, stock and available analytics. Reports can be exported as PDF or CSV for the currently loaded period.

## Settings

Settings are grouped by responsibility in dedicated tabs.

- The `General` tab sets the interface language and the store location. The `Language` selector is a dropdown: the first entry is `System default` and shows the effective language in brackets, so you can see what the choice resolves to; below it are the supported languages with their native name (`English`, `Italiano`). The change applies immediately without restart, and the home cards, the navigation drawer, the app bar and the titles of already open tabs all update right away, including the `#2` suffix on sections opened more than once. The `Location` field and its save button set the location used by cash and inventory operations.
- The `Theme` tab sets light/dark/system mode, the primary colour, home report visibility and decorative backgrounds. `Background follows light/dark theme` is on by default: when on, backgrounds follow the light or dark theme; when off, they use the selected primary colour. A previously saved value is respected, so an existing choice is kept.

## Quick tips

- Use `Settings` for inventory, images, AI, RFID and shortcut preferences.
- Log in before opening modules that require backend access.
- POS, inventory and loyalty operational data goes through MGWS.
- On Windows and Linux, use `Updates` to check for new desktop versions.
- After a desktop update, release notes are shown once after restart.
