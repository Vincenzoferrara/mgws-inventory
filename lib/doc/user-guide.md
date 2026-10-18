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
- `Templates and print` - printing product labels, shop signs and reports, and managing the templates, categories and paper formats stored on MGWS
- `Dashboard` - sales, products, orders, stock and PDF/CSV reports
- `Settings` - app and module preferences
- `Updates` - desktop update checks and installation
- `Employees` - staff registry, WordPress user link and MGWS permissions

## Templates and print

The `Templates and print` section opens only when MGWS works: templates, categories and paper formats are stored on the server and shared by every device of the shop; nothing stays on the device. `Reload` reads everything again from the server.

The first time a shop manager opens the section on a site, the app loads the default templates, categories (`Labels`, `Sales and discounts`, `Shop signs`, `Reports`) and paper formats on the server. This happens once: from then on they are ordinary items that can be changed or deleted, and they are never loaded again.

### Print tab

Every template is on one screen, grouped by category: each group has its title and a dividing line; templates without a category close the list. Tapping a template opens the preview (identical to the printed sheet) and the options. The preview is always visible: on the right on wide screens, fixed on top on phones while the options scroll below; it updates on every change. On multi-label sheets it opens on `Whole sheet`, with every sheet, the real labels and the skipped positions in grey; `One` enlarges a single label.

- `How many` (labels and signs): number of copies and `Whole sheet` to fill an adhesive sheet.
- `Positions already used on each sheet` (multi-label sheets only, not rolls): for every sheet to print (`Sheet 1`, `Sheet 2`, ...) enter how many labels are missing at the start; printing on that sheet begins right after them and labels continue on the next sheet. The number of sheets is recalculated and the whole-sheet preview shows skipped positions in grey.
- `Paper format`: applies to this print only and does not change the template. When the cell differs from the layout size, the layout is stretched to the cell.
- `Print` opens the system print dialog with the template page format; `Save PDF` saves or shares the file.
- The arrow next to the name goes back to the list (`Change template`).

From `Products`, the `Print labels` button in the toolbar (or the right-click menu item) opens this tab on the selected products: only label templates are listed, and every variant (or simple product) has a line with its labels: always one per piece in stock, a number that cannot be changed. Variants without pieces are not listed; when no selected product has pieces, the app warns and does not open printing. The `Delete` button of a line removes it from the labels to print. `Add label` opens the same product picker used by the till and the MGWS inventory: the chosen products and variants are added with the same rule (one label per piece, no zero-stock variants, no duplicates). The same button appears when printing a label template without products: adding products switches from example labels to real ones. Labels use the real data: name, colour and size of the variant, price, old price and discount when the variant is on sale, variant code and barcode. `Cancel` in the top box goes back to normal printing.

### Template tab

Shows the same groups as the Print tab, plus empty categories. Only shop managers (`manage_options` or `manage_woocommerce`) can change anything; other users see the list with a notice.

- `New template`: name, type (`Product labels`, `Shop signs`, `Printable reports`), category and paper format, then the designer opens on an empty canvas the size of one cell.
- Tapping a template, or `Edit template` in its menu, opens the designer. The menu also has `Rename`, `Duplicate`, `Move to category` and `Delete`.
- `New category`; each category menu has `Rename`, `Move up`, `Move down` and `Delete`. Deleting a category keeps its templates under `No category`.
- `Paper formats` opens the formats grouped by type: every format can be added, changed or deleted, defaults included. A format has a name (empty shows the measures), a type, `Sheet` or `Roll`, the size of each label and, for sheets, the sheet size, columns, rows, margins and gaps; the app refuses a format whose labels do not fit on the sheet. Deleting a format used by templates warns that those templates print on another format of the same type until one is chosen.

### Designer

The drag-and-drop designer has millimetre rulers: elements (text, data field, barcode, QR, shapes, table) and the data fields to drag onto the label on the left, the properties of the selected element on the right. The bar above the canvas chooses the `Paper format` (the canvas takes the size of one cell, elements keep their position) and, for labels and signs, what is printed between colour and size in the `coloreTaglia` field: `-` (default), `/`, `·`, `|`, `,`, `space` or a typed text. `Use these changes` (or `Save` inside the designer) saves the template on the server; closing with unapplied changes asks for confirmation. A line is as tall as its thickness (`Spessore (mm)` property, 0.3 mm for a new line): it has handles only at its two ends and stretches horizontally only. In print and preview every text always fits its box: the font size set is the largest one, and a text that is too long shrinks (on one line to the box width; when more lines are allowed it wraps and shrinks to the box height). Report table cells behave the same way. The designer shows the text at the size set.

The draggable fields of labels and signs are the product fields (`nome`, `sku`, `global_unique_id`, `marca`, ...) plus `taglia`, `colore`, `coloreTaglia` (colour, separator, size: `Navy blue - M`), `prezzoTesto`, `prezzoPrecedenteTesto` and `scontoTesto`. Template previews and the designer use an example product; reports still use example figures and carry the `Example data` notice.

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
- The shared DataGridView supports selection, pagination, horizontal scrolling and row context actions. `Print labels`, in the right-click menu or as the printer button in the filter bar, opens `Templates and print` on the selected products with all their variants.
- Every variant in the details list has a box: ticking one or more shows the `N variants selected` bar with `Clear selection`, `Print labels` (ticked variants only, one label per piece), `Bulk edit` (price, sale price and quantity of the ticked variants; empty fields stay as they are) and `Delete` (after a confirmation it brings the MGWS stock of the ticked variants to 0 on every site, with one adjustment movement `Variant deleted from Products`, then deletes them from WooCommerce for good; the product and its other variants stay. When MGWS does not answer or refuses the adjustment the variant is not deleted and the message says so). Selecting the product in the grid means taking all its variants.
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

The dashboard is a grid of widgets each user builds. Every widget shows one shop figure in the chosen way.

- On first use the dashboard holds one widget for every available figure: users remove the ones they do not need with `Remove widget`. `Restore standard` brings all widgets back.
- `Custom report (MGWS)` in `Edit widget` answers any sales question: pick `What to measure` (revenue, pieces sold, average ticket, average price per piece, average spend per customer, new customers, days since last purchase, till differences and more), `Split by` (hour, day of the week, day, week, month, quarter, year, product, variation, category, brand, customer, store/online channel, till, operator, payment method) and `Filters` (products, customers, categories, brands, channel, tills, operators, payment methods, searched by name). The period is the dashboard's.
- `Ready-made questions` fill everything in one tap: pieces sold of a product, best customers, average ticket and average price paid by each customer, average spend per customer, new customers, customers not back for longest, sales by hour, by day of the week, by operator, by payment method, store vs online, till differences by day.
- Reports count store receipts and online orders together, amounts include VAT, returns are negative and cancelled receipts are excluded. They need MGWS and the `mgws_reports_read` capability (given to administrators and shop managers, assignable to employees from the permissions card).

- The name at the top lists the available dashboards: your own (`Only me`), those shared with `Everyone` and, for shop managers, those for `Admins only`. `New dashboard` is in the same list.
- The filter bar applies to every widget: period (today, week, month, year, last 7/30/90 days or a custom calendar range), `Compare with previous period` and order statuses. `Reset filters` goes back to the current month.
- `Customize dashboard` opens edit mode: `Add widget`, drag a widget by its handle to move it (or use `Move before`/`Move after` in its menu), width (1/4 to full) and height (compact, medium, tall), `Edit widget`, `Remove widget`, `Restore standard`. Changes apply only after `Save`; `Cancel` discards them.
- The filters active when you press `Save` become the dashboard's default filters.
- `Edit widget` picks the data (numbers, trends over time, rankings and breakdowns), the display (number, gauge, columns, bars, line, area, pie, donut, table), the title, the size and, for rankings, how many items, their order and a text filter on the items. `Low-stock products` has its own threshold. The preview shows the result with current data.
- `Name and visibility` sets who sees the dashboard: `Only me`, `Everyone` or `Admins only`. Only shop managers (WordPress administrators or WooCommerce shop managers) can share, change or delete a shared dashboard; other users see it read-only and can `Duplicate dashboard` to get their own version.
- Without MGWS, personal dashboards are kept on the device only and sharing is not available.
- `More options` also holds `Export report` (`Dashboard CSV`, `Dashboard PDF`, `Sales CSV`, `Sales PDF` for the filtered period) and the detailed reports: top products, performance over time and order analysis.

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
