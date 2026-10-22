# Configuration

[Documentation index](README.md)

Open `Settings` from the home screen. Every tab configures one area of the
app.

## General

- **Language**: the first entry, the system language, shows in brackets the
  language it resolves to; below are the supported languages with their
  own name (`English`, `Italiano`). The change applies at once, without a
  restart, to every screen, the menu and the titles of open tabs. With the
  system language, the app follows the device and falls back to English.
- **Location in use (optional)**: the shop location used by the cashier and
  the inventory. When empty, receipts in the checkout history carry no
  location.
- **Notifications**: what the bell in the top bar reports (available
  update, orders to process, unpaid orders, low stock, cash register).
  Low stock counts only products with their own threshold in WooCommerce.

## Inventory

The locations offered by the `Add` module: warehouses, rooms, shelves and
levels, each with an optional default. Warehouse and room are shared by the
whole operation; shelf and level belong to each row. Leave a list empty to
hide that level: it is then never sent to MGWS.

## Products

- Image size limits: photos over the width or height set here get an
  information badge in the media library. They are never blocked or
  changed.
- Deletion rules and saved filters of the products page.
- Text mode for attribute parameters.

Other preferences of the products page are kept as you use it: page size,
visible columns, keyboard shortcuts. The width of the list/details split is
kept only on this computer.

## Checkout

- **Register name or number**: optional. When empty, the checkout history
  uses a neutral name.
- **POS identifier**: a code such as `POS-7KQ2MX`, created on first start
  with letters and digits that cannot be confused when typed by hand. In
  Italy you use it to pair this till with a cash register in the "Fatture
  e Corrispettivi" portal of the tax agency; the pairing is done in the
  portal, not in the app. You can type your own code (letters, digits and
  hyphens, up to 32 characters). `Regenerate` creates a new one, which must
  be paired again. The tab shows whether the code was generated or typed
  and lets you copy it.
- **Cash register shift mandatory**: when on, the cashier shows open and
  close shift and needs an open shift to add products and take payment.
  When off, shifts are not used. The setting is shared by the whole shop
  (it is stored in MGWS) and needs a user who manages the shop.
- **Fiscal register mode**: how this till issues receipts. **Simulation**
  means no fiscal device is attached: the app records the receipts and no
  device issues them. It is a normal way of working, not an error. Each
  register brand has its own protocol, so a register is added as a separate
  driver when one is chosen, and it then appears in this selector.

## Theme

- Light, dark or system mode, and the primary colour. The colour also drives
  gradients, buttons, chips and the selection of tables.
- Whether the home screen shows the report.
- **Background follows light/dark theme**: on by default. On, decorative
  backgrounds follow the light or dark theme; off, they use the selected
  colour. A value you saved is kept.

## AI

AI help is optional: the shop works fully without it. It writes product
descriptions and suggests categories and tags.

- **Active provider**: Ollama (local), OpenAI, Anthropic (Claude), Google AI
  (Gemini) or Mistral AI.
- For each provider, your own API key (or the Ollama server address) and
  the model. Keys are kept in the secure storage of the device.

**Privacy.** OpenAI, Anthropic, Google and Mistral are external services:
when you use them, the app sends the product name, category, price,
internal barcode and description to them, with your key. The first time
you use each of them the app asks for your consent and remembers the
answer. No customer data is sent. Ollama runs on your own computer or
server and sends nothing outside. See the [privacy policy](../../PRIVACY.md).

## RFID

Reader connection (USB or Wi-Fi) and scanning parameters. Bluetooth is not
available while the module is in alpha.

## Shortcuts

Custom keyboard shortcuts, for example in the products page: start quick
edit, save, select the visible rows, delete, cancel or exit.

## About

The app version and build, the copyright, the GPL-3.0 license and the
no-warranty notice, and links to the source code, the license text, the
WordPress plugin and the issue tracker. `Open source licenses` lists every
library used by the app with its license. On builds where donations are
allowed, the tab also has a button to support the project on Ko-fi.

## Preferences synced with the site

When MGWS is available, the preferences that are not secret are saved on
the site for your WordPress user, so they follow you on every device.
Passwords, tokens, API keys and other secrets are never synced: they stay
in the secure storage of each device. Without MGWS the preferences stay on
the device.
