# User guide

[Documentation index](README.md)

MGWS Inventory runs the daily work of a clothing store on top of your own
WordPress and WooCommerce site: point of sale, products, stock, labels,
orders, customers, loyalty cards, employees and reports.

## Contents

- [Before you start](#before-you-start)
- [Logging in](#logging-in)
- [The home screen](#the-home-screen)
- [Cashier](#cashier)
- [Products](#products)
- [MGWS Inventory](#mgws-inventory)
- [Suppliers](#suppliers)
- [Templates and print](#templates-and-print)
- [Customers and employees](#customers-and-employees)
- [Loyalty cards](#loyalty-cards)
- [Dashboard](#dashboard)
- [Settings](#settings)
- [Updates](#updates)
- [View logs](#view-logs)
- [Questions](#questions)

## Before you start

For now the app works with a **WordPress + WooCommerce** shop; other
e-commerce platforms, such as Shopify, are planned.

What you can do comes in two tiers:

| With the app only | With the MGWS plugin installed |
|-------------------|--------------------------------|
| Products, variants, images, barcodes and WooCommerce stock | Point of sale: sales, returns, exchanges, cash shifts |
| Orders, customers and coupons | Inventory: stock in, adjustments, transfers, movement ledger |
| Dashboard with sales, products and orders figures | Suppliers |
| Barcode and QR scanner | Loyalty cards |
| CalDAV calendars and contacts | Employees, permissions and credentials |
| Optional AI help for product texts | Templates and print (labels, signs, reports) |
| | Custom sales reports and shared dashboards |
| | Settings synced across devices |

The **MGWS plugin** is free and installs on your WordPress site:
<https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>. Without it, the sections in the right column show a notice instead
of opening; the [home screen table](#the-home-screen) lists which sections
need it.

See [Installation](installation.md) for downloads and requirements.

## Logging in

1. Press `Log in` in the top bar.
2. Enter the address of your WordPress site.
3. Choose how to log in:
   - **WordPress Admin**: your WordPress user and password. The app creates
     an Application Password for this device by itself.
   - **JWT**: your WordPress user and password, when the site has a JWT
     plugin. If the site has none, the app stops before sending the
     password.
   - **WooCommerce API**: a Consumer Key and Secret created in WooCommerce.
     They work only for the WooCommerce sections: MGWS needs a WordPress
     user, so use one of the other two methods for the shop functions.
   - **Smart card**: an NFC or USB card prepared for an employee.
4. If the site is on your computer or local network (`localhost`,
   `192.168.x.x`, `10.x.x.x`), tick the local development option. Use it
   only for sites you trust.

On phones the login opens as a full page; on large screens it opens as a
dialog. When you are logged in, the top bar shows your WordPress avatar and
name with `Online`, and its menu has `Log out`. Logging out deletes the
credentials stored on the device.

After login, if MGWS is available, the app loads your preferences from the
site (only the ones that are not secret) and applies them. If the site has
none yet, it saves the preferences of this device there.

## The home screen

On a computer the home screen is a desktop of tabs that you can move, split
and resize. Some sections open once and come back to the same tab; others
can be opened more times, and the tabs get a `#2`, `#3` suffix. On phones
the app shows one screen at a time.

| Section | What it does | Needs MGWS |
|---------|--------------|:----------:|
| `Cashier` | Sales, returns, exchanges, cash shifts and the checkout history | yes |
| `Products` | Catalogue, variants, images, barcodes and stock | no |
| `MGWS Inventory` | Stock in, adjustments, moves and the movement ledger | yes |
| `New Product` | Create a product | no |
| `Coupon` | WooCommerce discounts | no |
| `Orders` | WooCommerce orders | no |
| `Customers` | WooCommerce customers | no |
| `Suppliers` | Supplier registry | yes |
| `Loyalty Cards` | Cards, points and history | yes |
| `Templates and print` | Labels, shop signs and reports | yes |
| `Dashboard` | Sales and stock figures, reports and exports | no¹ |
| `Settings` | App and module preferences | no |
| `Updates` | Check for new versions | no |
| `CalDAV` | Calendars and contacts on your CalDAV server | no |
| `Employees` | Staff registry and permissions | yes |

¹ Custom reports and shared dashboards need MGWS.

## Cashier

### Selling

1. Open `Cashier`. The operator is the user you logged in with: every
   receipt records that username.
2. If `Settings > Checkout > Cash register shift mandatory` is on, press
   `Open shift` and enter the `Initial float`. The app opens the shift on the server
   first and then on the device; until a shift is open you cannot add
   products or take payment. With the option off, shifts are optional.
3. Add products with the barcode field, the camera scanner or
   `Add manually`. A barcode adds the product or variant straight to the
   cart; unknown codes show an error and items with no stock are blocked.
4. Check the cart: change quantities, remove lines or add line discounts.
5. Add the customer, the loyalty card and coupons if needed.
6. Press `Pay` and choose the payment method.

MGWS confirms the sale, creates the WooCommerce order and records the stock
movement. If the network drops and the same sale is sent again, MGWS
recognises it and does not create a second order. The receipt is saved in
the `Checkout history` on the device, with lines, payment method, operator,
till, shift, totals and the number of the WooCommerce order.

On a computer the right side holds operation type, customer, loyalty card,
coupons, parked receipts, totals and payment. On a phone the cart fills the
screen, `Pay` stays at the bottom and the options button opens the rest.

The till does not load the whole catalogue when it opens: it searches the
shop when you scan or type, so it opens fast even with a large catalogue.

### Returns and exchanges

1. Open `Cashier > Checkout history` and find the receipt (by customer, number,
   order, till, payment method or returns only).
2. Open it and choose the sold line.
3. For a **return**, the app shows how many pieces were sold, already
   returned and still returnable, at the price really paid. A reason is
   required and you cannot return more than what is left.
4. For an **exchange**, choose `Exchange`: the cart gets the linked return
   line and stays open for the replacement product.
5. Confirm. MGWS checks again what is still returnable, counting the
   returns made on every device.

A closed receipt accepts only append-only corrections or a cancellation
with a reason. Cancelled receipts leave the totals and cannot be returned.

### Closing the shift

Use `Close shift` in the cashier or `Closing` in the `Checkout history`. Enter the
counted cash and card totals, a reason and notes. MGWS works out the
expected totals from the shift's sales and shows the differences. The shift
closes on the device only when the server has closed it; a recorded closing
cannot be changed, only annotated.

## Products

`Products` is the catalogue workstation.

- The filter panel searches and filters by field, operator and value,
  hides out-of-stock items and sorts the list. `Article code / SKU`,
  `Product name` and `Barcode` are separate filters; `Barcode` finds both
  the internal and the manufacturer barcode, on products and variants.
  Closed, the panel takes one line.
- `Choose columns` picks the visible columns. Active filters show as chips;
  `Clear all` removes them.
- The first page appears at once; the next pages load in the background.
- Tick rows (or the header box for the whole page) for bulk actions. The
  count shows as `Sel:` in the pagination bar.
- For variable products the price column shows the single price, or a
  note that the prices vary when variants differ.
- Selecting a product opens its details: images, data, quick edit and
  variants. On a computer list and details sit side by side.
- `Print labels`, in the toolbar or the right-click menu, opens
  `Templates and print` with the selected products.

### Variants

Every variant in the details has a box. Ticking one or more shows a bar with
`Clear selection`, `Print labels` (ticked variants only, one label per
piece), `Bulk edit` (price, sale price and quantity; empty fields stay as
they are) and `Delete`. Deleting first brings the MGWS stock of the variant
to 0 on every site, with an adjustment movement, and only then deletes it
from WooCommerce; if MGWS does not answer, nothing is deleted.

### Creating and editing products

`New Product` (or `Edit` in the details) opens a step editor: basic info,
prices and stock, images, details and variants.

- Choose the product type first; the other fields unlock after it.
- `Images` keeps the original files, lets you pick the cover and order the
  gallery. Photos over the size limits in `Settings > Products` get an
  information badge but are not blocked.
- Variants can have their own image, barcode, price, sale price and
  quantity.
- The automatic barcode button creates a numeric Code 128 code that is not
  already in the form.
- Before saving changes, a summary shows the new values and the missing
  fields; required errors block the save.
- With `MGWS inventory` ticked in prices and stock, enter the counted total
  stock and a reason: after the product is saved, the app sets that stock
  in MGWS with an adjustment.
- The AI buttons write descriptions and suggest categories and tags. The
  first time you use a cloud provider the app asks for your consent; see
  [AI help](configuration.md#ai).

## MGWS Inventory

MGWS holds the real stock of the shop; WooCommerce shows a synchronised
copy. Choose the module at the top:

| Module | Use it to |
|--------|-----------|
| `Add` | Book goods in |
| `Adjustment` | Correct the stock to what you counted |
| `Transfer` | Move pieces between warehouses without changing the total |
| `Movements` | Read the ledger, reopen or undo an operation |

The three working modules share the barcode field, the product search and
the list of rows. The page's `Details` field travels with the movement.

### Add

1. Choose **Simple** to book goods in, or **Linked to an order** to also
   create a draft order for a supplier with the same rows.
2. Add products with `Add existing product` or the barcode. With quick mode
   ticked every scan adds one piece; without it the app asks the quantity.
3. Optionally choose warehouse, room, shelf and level. Empty values are not
   sent and MGWS uses the first allowed warehouse.
4. Confirm. Each row is sent on its own: the rows that succeed are booked
   at once and the failed ones stay in the list to retry.

### Adjustment

1. Choose `Increase` or `Decrease` next to the quick-mode box: it decides
   what a scan does.
2. Add products. Each row shows the current MGWS stock and the
   `before -> after` preview.
3. Set the pieces with the counter, or untick quick mode and type the
   absolute counted quantity.
4. Enter the reason (required).
5. Confirm. The app does not stop at the first error and reports which rows
   passed and which did not.

### Transfer

1. Add products and choose, for each row, the warehouse the pieces come
   from (only the ones that really have the product are listed).
2. Choose the destination site; warehouse, room, shelf and level are
   optional.
3. Set the pieces (not more than available) and the reason.
4. Confirm. The total of the product does not change.

### Movements

1. Filter by product, variant, date, source, operator or reason. There is
   one row per operation, not per product.
2. Double-click a row, or `Open the movement`, to see the stock of each product
   before and after (for a move: the pieces and the route `from -> to`).
3. `Edit` reopens the operation in its module. It works for `Adjustment` and
   `Transfer`; a stock-in cannot be reopened. When it is not possible, the
   button explains why.
4. `Cancel movement` brings each product back to the stock it had before. It
   writes a **new** movement and never deletes the old one, so the history
   shows both. If a product changed in the meantime, its row is blocked
   and named. A move is undone with a move in the opposite direction, and
   only if the pieces are still in the destination warehouse.

The ledger cannot be edited or deleted: it is the record of what happened
in the warehouse. The operator column shows the WordPress user number.

## Suppliers

`Suppliers` lists the supplier registry kept by MGWS. `Add supplier` opens
the form: the name is required, the email is optional. Suppliers are not
WordPress users or WooCommerce customers and do not appear in `Customers`.
They belong to the whole shop, not to one site.

Booking goods in, with or without a supplier order, always needs a site. A
received delivery waiting for checking changes the stock only when a
manager approves it.

## Templates and print

`Templates and print` prints product labels, shop signs and reports. It
needs MGWS: templates, categories and paper formats are stored on the site
and shared by every device of the shop. `Reload` reads them again.

The first time a shop manager opens it, the app adds the ready-made
templates, the categories (`Labels`, `Sales and discounts`, `Shop signs`,
`Reports`) and the paper formats. This happens once; afterwards they are
normal items that can be changed or deleted.

### Print tab

Templates are grouped by category. Tapping one opens its options and the
preview, which always matches the printed sheet: on the right on large
screens, at the top on phones.

- `How many`: number of copies, or `Whole sheet` to fill an adhesive sheet.
- `Positions already used on each sheet` (sheets only, not rolls): for
  `Sheet 1`, `Sheet 2`… enter how many labels are already missing at the
  start; printing begins right after them. The preview shows them in grey.
- `Paper format`: applies to this print only.
- `One` / `Whole sheet` switch the preview between one label and the sheet.
- `Print` opens the system print dialog; `Save PDF` saves or shares the
  file. The arrow next to the name goes back to the list.

**Labels from products.** `Print labels` in `Products` opens this tab with
the selected products: only label templates are listed, and every variant
with stock gets one label per piece. Variants without stock are left out.
`Delete` removes a line; `Add label` adds more products with the same rule.
Labels use the real name, colour, size, price, old price and discount,
code and barcode of each variant.

### Templates tab

Only shop managers (`manage_options` or `manage_woocommerce`) can change
templates; other users see the list with a notice.

- `New template`: name, category and paper format, then the designer opens.
- Each template's menu has `Edit template`, `Rename`, `Duplicate`,
  `Move to category` and `Delete`.
- `New category`; each category menu has `Rename`, `Move up`, `Move down`
  and `Delete`. Deleting a category keeps its templates under
  `No category`.
- `Paper formats` lists sheets and rolls; `New paper format` creates one
  with name, type (sheet or roll), label size and, for sheets, sheet size,
  columns, rows, margins and gaps. A format whose labels do not fit is
  refused. Deleting a format used by templates warns you first.

### Designer

The designer has millimetre rulers. On the left are the elements (text,
data field, barcode, QR, shapes, table) and the data fields to drag; on the
right are the properties of the selected element.

- The bar above the canvas picks the paper format and, for labels and
  signs, the separator printed between colour and size (`-`, `/`, `·`, `|`,
  `,`, space or your own text).
- A line is as tall as its thickness and stretches only horizontally.
- In print every text fits its box: the font size set is the largest, and
  longer texts shrink.
- `Use these changes` saves the template on the site. Closing with unsaved
  changes asks for confirmation.

The data fields of labels and signs are the product fields (`nome`, `sku`,
`global_unique_id`, `marca`…) plus `taglia`, `colore`, `coloreTaglia`
(for example `Navy blue - M`), `prezzoTesto`, `prezzoPrecedenteTesto` and
`scontoTesto`. Previews use an example product; reports still use example
figures and say so.

## Customers and employees

`Customers` shows and edits WooCommerce customers. It has no staff roles.

`Employees` is the staff registry kept by MGWS.

1. Add or edit name, surname, email, role and salary. The salary accepts
   local formats such as `1500,00` or `1.500,00` and is never turned into
   zero silently.
2. If the person has a WordPress account, enter the `WordPress user ID`
   (optional).
   Clearing the field unlinks the employee.
3. For linked employees, `Access and Permissions` manages roles and the
   MGWS capabilities allowed by the app.
4. `Active Credentials` revokes the employee's Application Passwords and
   WooCommerce keys. It works only when you are logged in as a WordPress
   administrator; with other roles it shows a notice and the rest of the
   card keeps working.
5. Deleting an employee disables the record. It does **not** revoke the
   credentials: revoke them from `Active Credentials` when someone leaves.

## Loyalty cards

1. Open `Loyalty Cards` and find the customer by ID, card or email. The
   camera scanner reads the card.
2. Add or remove points, with a reference and a note if useful. You cannot
   remove more points than the balance.
3. The history lists every change, newest first.
4. Removing a card deletes only the card number: the account and its
   history stay.

## Dashboard

The dashboard is a grid of widgets that each user builds.

- The name at the top lists your dashboards (`Only me`), the ones shared
  with `Everyone` and, for shop managers, the ones for `Admins only`.
  `New dashboard` is in the same list.
- The filter bar applies to every widget: period, `Compare with previous
  period` and order statuses.
- `Customize dashboard` lets you `Add widget`, move, resize, `Edit widget`,
  `Remove widget` and `Restore standard`.
  Changes apply after `Save`; `Cancel` discards them. The filters active
  when you save become the dashboard's defaults.
- `Edit widget` picks the data (numbers, trends, rankings, breakdowns), the
  display (number, gauge, columns, bars, line, area, pie, donut, table),
  the title and the size.
- `Custom report (MGWS)` answers sales questions: choose what to measure
  (revenue, pieces sold, average ticket, new customers, till differences…),
  how to split it (hour, day, product, category, brand, customer, channel,
  till, operator, payment method…) and the filters. `Ready-made questions`
  fill it in one tap. Reports count store receipts and online orders
  together, include VAT, count returns as negative and leave out cancelled
  receipts. They need the `mgws_reports_read` capability.
- `Name and visibility` sets who sees a dashboard. Only shop managers can
  share or change shared dashboards; other users can `Duplicate dashboard`.
- Without MGWS, personal dashboards stay on the device and cannot be
  shared.
- `More options > Export report` creates `Dashboard CSV`, `Dashboard PDF`,
  `Sales CSV` or `Sales PDF` for the filtered period.

## Settings

Settings are grouped in tabs; see [Configuration](configuration.md) for
every option. The `About` tab shows the version, the license, the source
code, the open source licenses of the libraries and how to support the
project.

## Updates

- **Windows and Linux**: at start-up the app checks in the background for a
  new version and tells you once per release. `Updates` installs it: the
  app closes, the installer runs and the app starts again. The release
  notes are shown once after the update.
- **Android**: the app only tells you that a new version exists. F-Droid,
  Obtainium or the store you installed it from does the update. Builds
  from F-Droid and the stores do not check.

## View logs

`View logs`, in the top bar, shows the app's diagnostic messages. They stay
in memory and are not saved in your folders.

- `Record temporary log` writes them to a temporary file inside the app,
  useful while you reproduce a problem; `Stop temporary log` stops it.
- `Share and clear` shares the filtered messages and then deletes them.
- `Delete log` deletes them without sharing.
- `Filter by level` shows all messages, or only debug, warnings or errors;
  `Filter by tag` narrows them to one part of the app.
- When a temporary file exists, the source menu switches between it and the
  `Temporary memory buffer`.

Passwords, tokens and keys are removed from the messages before they are
shown or shared.

## Questions

**Does the app work without Google services?** Yes. It has no Google
dependency, no tracking and no ads. The barcode scanner works offline.

**Do I need a server or a database for the app?** No. The app uses your
WordPress site as its only backend. There is nothing else to install, run
or pay for.

**Does the developer see my data?** No. The app has no analytics,
telemetry or automatic crash reports. Your data goes only to your
WordPress site and, if you enable them, to the AI services you choose. See
the [privacy policy](../../PRIVACY.md).

**How do I report a bug or ask for a feature?** Open an issue on
[GitHub](https://github.com/Vincenzoferrara/mgws-inventory/issues). Issues
are public, so leave out your shop address, names, emails and passwords.
Security problems go through the private channel described in
[SECURITY.md](../../SECURITY.md).

**Does the app talk to ATUM, myCred or other plugins?** No. It talks only
to WooCommerce and MGWS; any other plugin must be reached through MGWS.

**Where are the downloads?** In the [project README](../../README.md#download).

**Something does not work.** See [Troubleshooting](troubleshooting.md).
