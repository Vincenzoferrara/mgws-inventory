# Troubleshooting

[Documentation index](README.md)

The first half is for shop staff; [Technical notes](#technical-notes) is for
whoever runs the site or develops the app. When you ask for help, attach
the log from `View logs` (it never contains passwords or keys).

## Login fails

- Check the site address, including `https://`.
- Try the other login method: JWT needs a JWT plugin on the site, while
  WordPress Admin and WooCommerce API do not.
- If the site is local (`localhost`, `192.168.x.x`, `10.x.x.x`), tick the
  local development option.
- Check that the site answers in a browser and that WooCommerce is active.

## "MGWS backend not available"

The cashier, the inventory, suppliers, loyalty cards, employees and
templates need the MGWS plugin. If they say it is not available:

- Check that the MGWS plugin is installed and active on the site.
- Log in with **WordPress Admin** or **JWT**. WooCommerce API keys work only
  for WooCommerce: MGWS needs a WordPress user and answers `401` to them.
- Check that your WordPress user has the MGWS capabilities for that section
  (a `403` in the log means a missing permission).
- If the plugin is active but the sections stay closed, the MGWS tables may
  not be installed: the status routes then answer with the service
  switched off.

## No products

- Check that WooCommerce has published products.
- Clear the filters (`Clear all`) and show out-of-stock items.
- Check the connection: the first page appears as soon as it arrives.

## Cashier

- **A search finds nothing**: the cashier searches the shop only when you
  scan or type; if nothing matches the list stays empty until you change
  the text.
- **The sale was sent twice**: it is safe. Each receipt has its own key and
  MGWS returns the saved answer instead of creating a second order.
- **You cannot add products**: with `Cash register shift mandatory` on, open
  a shift first.
- **A return is refused**: you cannot return more than what is left on that
  line, counting the returns made on every device.

## Inventory

- **A stock-in is refused**: quantities must be positive, a product must be
  chosen and your user must be allowed to book stock. A supplier, an order,
  an invoice or a delivery note is never required.
- **Errors only on transfers**: transfers use a different permission from
  adjustments; ask for the stock-move capability.
- **A delivery did not change the stock**: a delivery draft changes nothing
  until it is validated, and one waiting for checking needs a manager's
  approval.
- **A physical count did not change the stock**: rows and drafts change
  nothing until the count session is approved.
- **`Cancel movement` is off for a product**: that product changed after the
  movement, so undoing it would also cancel the later operation. The
  reason is shown next to the button.
- **A movement shows only part of the products**: very large operations can
  be split across pages. Narrow the filters by date or product; the panel
  warns you when the list is incomplete.
- **The operator is a number**: it is the WordPress user ID; MGWS does not
  send the name.
- **Movements cannot be edited or deleted**: by design. A wrong movement is
  fixed with `Cancel movement`, which records a new one.

## Loyalty cards

- **Customer or card not found**: the customer has no loyalty account, or
  the card number does not exist.
- **Not enough points**: you cannot remove more points than the balance.
- **Service unavailable**: the MGWS loyalty tables are not ready.

## Images

- Use an image format WordPress accepts.
- The "over the limit" badge is only information; the limits are in
  `Settings > Products`.

## AI help

- **"Provider not configured"**: enter the API key (or the Ollama address)
  in `Settings > AI` and choose the active provider.
- **Nothing happens after the consent dialog**: you pressed `Cancel`; the
  question comes back the next time.

## Technical notes

### MGWS requests never reach the site

If the web server log shows no request to `/wp-json/mgws/*`, the problem is
in the app, not in the plugin or the network. Every MGWS client must take
the site address and credentials from `WooConnect`; a client that creates
its own connector sends requests with credentials that do not match the
session. See [Architecture](architecture.md#login-and-the-mgws-chain).

### MGWS answers 200 but the section stays closed

The status routes answer `200` also when the service is off, with `enabled`
or `ok` set to `false`. Check that the MGWS tables are installed and that
the user can read stock. The app reads the body of the answer, not only
the HTTP status.

### Checkout errors

| Answer | Meaning |
|--------|---------|
| `409 mgws_idempotency_conflict` | Same key, different content. Do not resend changed data with the old key. |
| `409 mgws_idempotency_in_progress` | The same request is still running. Wait and resend the same content. |
| `409` on a return | More than the returnable remainder. |
| `409` without an open shift | The shop requires a shift and none is open on the server. |

When MGWS saved a failure for a key, the same key repeats that failure: it
needs a fix on the site.

Without an `idempotency_key`, MGWS uses the `_id_scontrino_locale` meta of
the receipt; a request with neither is accepted but is not protected from
duplicates.

### Inventory and loyalty answers

| Answer | Meaning |
|--------|---------|
| `404 mgws_product_not_found` | The WooCommerce product does not exist. |
| `404 mgws_loyalty_customer_not_found` | No WordPress/WooCommerce customer, or no loyalty account. |
| `404 mgws_loyalty_card_not_found` | No card to remove: removing a card is not idempotent. |
| `400 mgws_insufficient_points` | More points removed than the balance. |
| `403` | The WordPress user lacks the capability of that route. |
| `503` | MGWS storage or tables not ready. |

`POST /inventory/rfid/scan` only resolves a tag or barcode and never
changes stock. `InventoryGlobal.reconcileInventory(fixDiscrepancies)`
proposes corrections and never applies them by itself.
