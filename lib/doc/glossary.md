# Glossary

[Documentation index](README.md)

- **Application Password** – a WordPress password created for one device or
  app; WordPress Admin login creates one for the device.
- **Adjustment** – inventory operation that sets the stock of a product to
  the counted value (`stock/reconcile`).
- **Capability** – a WordPress permission, such as `manage_woocommerce` or
  the MGWS ones (`mgws_reports_read`, `mgws_manage_credentials`,
  `mgws_purchase_approve`…).
- **Cash shift** – a working session of a till, opened with a starting
  float and closed with the counted totals; mandatory only when the shop
  requires it.
- **Checkout history** – the receipts of this till, kept on the device and
  checked against MGWS; separate from WooCommerce orders.
- **DataGridView** – the shared table used by the operational lists.
- **Fiscal register** – a device that issues legal receipts; without one,
  the till works in simulation mode.
- **Idempotency key** – a unique key sent with each sale or stock request,
  so a request sent twice is executed once.
- **Loyalty card** – a card linked to a customer's MGWS loyalty account and
  its points ledger.
- **MGWS** – the optional WordPress plugin that unlocks stock, point of
  sale, loyalty, employees, suppliers, print templates and reports in the
  app (Warehouse Stock Manager for WooCommerce): <https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>.
- **Movement** – one inventory operation, made of one row per product.
- **Movement ledger** – the append-only MGWS history of stock movements;
  rows are never changed or deleted.
- **Paper format** – the sheet or roll a template is printed on, with label
  size, columns, rows, margins and gaps.
- **POS identifier** – the code that identifies a till, used in Italy to
  pair it with a fiscal register in the tax agency portal.
- **Site** – a shop location in MGWS; stock is kept per site, warehouse and
  location.
- **Stock-in** – inventory operation that adds pieces (`quick-load`).
- **Supplier** – an MGWS record used by purchasing; not a WordPress user or
  WooCommerce customer.
- **Template** – a label, shop sign or report layout, stored on the site.
- **Transfer** – inventory operation that moves pieces between locations
  without changing the total (`stock/move`).
- **Velopack** – the installer and update system of the Windows and Linux
  builds.
- **WooCommerce** – the e-commerce plugin that holds products, orders,
  coupons and customers.
