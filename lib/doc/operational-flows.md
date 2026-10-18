# Operational Flows

## Login

1. Open the login action from the top bar.
2. Enter the WordPress site URL.
3. Select JWT, WooCommerce API or WordPress Admin login.
4. Enable local development only for trusted local backends.
5. Confirm login and wait for the online user state.

## POS sale

1. Open `Cashier`.
2. Open or continue the local cash shift.
3. Scan a barcode or add products manually.
4. Review quantities, discounts, customer, loyalty card and coupon.
5. Confirm checkout.
6. MGWS creates the WooCommerce order and records movements/audit data.
7. The app stores local POS receipt history separately from WooCommerce orders.

## POS return

1. Open POS history.
2. Select the original receipt and sold line.
3. Choose the return operation.
4. Confirm the return reason and outcome.
5. MGWS records the linked return movement.

## Product management

1. Open `Products`.
2. Use filters, search, hidden-out-of-stock toggle and column chooser.
3. Select a product row to open details.
4. Use quick edit for categories, tags, status, price or stock-related operations.
5. Use the product editor for full product, image and variant changes.
6. Optional MGWS stock reconciliation runs only after the product has a valid product ID.

## MGWS stock add

1. Open `MGWS Inventory`.
2. Select `Add`.
3. Add products through barcode or product picker.
4. Enter quantities and optional details.
5. Confirm. Successful rows remain recorded; failed rows stay available for retry.

## MGWS stock reconcile

1. Select `Reconcile`.
2. Add products.
3. Choose increment/decrement quick mode or enter absolute counted values.
4. Provide a required reason.
5. Review the `before -> after` preview.
6. Confirm one row at a time.

## MGWS stock move

1. Select `Move`.
2. Add products.
3. Choose the source warehouse/location from real availability.
4. Choose the destination warehouse/location.
5. Provide a required reason.
6. Confirm. Product total quantity does not change.

## Movement ledger

1. Select `Movements`.
2. Review operations grouped by movement instead of by product.
3. Open a movement detail to inspect stock before/after.
4. Reopen supported operations or create an undo movement when allowed.
5. The original ledger record is never deleted.

## Employee offboarding

1. Open `Employees`.
2. Select the employee.
3. Disable the employee record through MGWS.
4. If you are an administrator, revoke active Application Passwords and WooCommerce keys from the credentials section.
5. Verify role/capability links only for employees with a linked `wp_user_id`.

## Desktop update

1. Open `Updates`.
2. Check for updates.
3. Install the update.
4. Let the app close and restart through Velopack.
5. Read the release notes shown after restart.

## Templates and print

1. Open `Templates and print` (MGWS required).
2. In the `Print` tab tap a template in its group.
3. Set copies, positions already used and paper format while looking at the preview.
4. Press `Print` or `Save PDF`.

## Print labels from products

1. In `Products` select the products.
2. Press `Print labels` in the toolbar or in the right-click menu.
3. In the `Print` tab choose the label template.
4. Check the labels of each variant (one per piece in stock), remove with `Delete` the lines not to print and add more products with `Add label`.
5. Press `Print`.

## New template

1. In the `Template` tab press `New template` (shop managers only).
2. Choose name, type, category and paper format.
3. Draw in the designer by dragging the fields onto the label.
4. Press `Use these changes`: the template is saved on MGWS.
