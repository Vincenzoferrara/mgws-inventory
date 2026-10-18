# Modules Map

## Home

The home screen uses a dockable layout on desktop and a simpler single-view flow on small screens. The top bar exposes the log button and login status. When authenticated, it shows the WordPress user avatar/name, `Online` state and account menu; otherwise it shows the login action.

## Available modules

- `Cashier` - POS workflow with explicit cash shift, barcode/manual product entry, cart lines, MGWS idempotent checkout, WooCommerce order creation and POS history
- `Products` - product catalog, filters, shared DataGridView, multi-selection, details panel, variants, images and MGWS stock readings
- `MGWS Inventory` - operational stock station with Add, Reconcile, Move and Movements modules
- `New Product` - product creation with original image selection and optional MGWS stock reconciliation after save
- `Coupons` - WooCommerce discounts and promotions
- `Orders` - order list and order details
- `Customers` - WooCommerce customer management
- `Suppliers` - MGWS supplier records when exposed by the active flow
- `Loyalty Cards` - MGWS points, card lookup, customer account and loyalty history
- `Templates and print` - prints product labels, shop signs and A4 reports and manages templates, categories and paper formats stored on MGWS (`/print` routes); MGWS-only
- `Dashboard` - customizable widget dashboards (personal, shared with everyone or admins only) with period and order status filters, chart types and PDF/CSV exports
- `Settings` - backend, products, theme, AI, RFID, shortcuts and module settings
- `Updates` - desktop updates through Velopack and post-restart release notes
- `CalDAV` - calendars and contacts
- `Employees` - staff registry, optional WordPress user link and MGWS permissions for linked employees
- `DataGridView` - technical test page for the shared table component

## Navigation notes

- Some modules are singletons and reopen the same tab
- Some modules can have multiple instances
- On mobile, the app shows one view at a time

## MGWS boundaries

- The home sections `Cashier`, `MGWS Inventory`, `Suppliers`, `Loyalty Cards` and `Employees` need the MGWS backend and are not opened without it. The card shows a notice explaining the cause
- `Cashier` is MGWS-only because the cashier shift and the checkout are confirmed by the MGWS server, which also creates the WooCommerce order
- `Suppliers` is MGWS-only because the whole supplier registry, purchase orders and receipts live in MGWS routes
- POS history is local JSON/SharedPreferences data and remains separate from WooCommerce orders
- `Products` reads catalog and availability from WooCommerce, and can trigger MGWS stock reconciliation during create/edit flows; it opens without MGWS and the reconciliation reports the backend as unavailable
- `MGWS Inventory` owns stock add, reconcile, move and movement-ledger reads
- `Loyalty Cards` uses MGWS for accounts, cards, points and history
- `Customers` remains a WooCommerce customer module; WordPress roles and capabilities are not managed there
- `Employees` uses MGWS employee records as the operational identity source
- `Orders`, `Coupons`, `Dashboard`, `Settings`, `Updates` and `CalDAV` read from WooCommerce or local storage and stay open when MGWS is down
