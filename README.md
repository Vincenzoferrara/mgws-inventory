# MGWS Inventory

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/Vincenzoferrara/mgws-inventory)](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support-ff5e5b?logo=kofi&logoColor=white)](https://ko-fi.com/vinc0101)

A free and open source app to run a clothing store on top of your own
online shop: point of sale, products, stock, labels, orders, customers and
loyalty cards.

**Platforms:** for now the app works with **WordPress + WooCommerce**.
Support for other e-commerce platforms, such as Shopify, is planned.

Your data stays on your server. No account, no ads, no tracking. English
and Italian.

## Features

The features come in two tiers: what the app does on its own with your
WooCommerce shop, and what it unlocks when you also install the free
**MGWS plugin** on your WordPress site:
<https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>.

### With the app only (WooCommerce)

- **Products**: create and edit products and variants, images, barcodes,
  prices and WooCommerce stock.
- **Barcode and QR scanner** with the camera.
- **Orders, customers and coupons.**
- **Dashboard** with sales, products and orders figures, PDF and CSV
  exports.
- **Calendars and contacts** on your CalDAV server.
- **Optional AI help** for product descriptions, categories and tags,
  with your own API key (OpenAI, Anthropic, Google, Mistral) or a local
  Ollama server.
- **Login** with WordPress credentials, WooCommerce API keys, JWT or
  application passwords.

### With the MGWS plugin installed

- **Point of sale**: sales, returns and exchanges, receipts, cash shifts
  and closings, with sales that are never recorded twice.
- **Inventory**: stock in (with or without a supplier order), adjustments
  and transfers between warehouses, with a movement ledger whose
  operations can be undone.
- **Labels, signs and reports**: drag-and-drop designer, adhesive A4
  sheets and label rolls, PDF printing, built on
  [report_flutter](https://github.com/Vincenzoferrara/report_flutter);
  templates are shared by every device of the shop.
- **Loyalty cards** with points and history.
- **Employees and suppliers**, with permissions and credential
  revocation.
- **Custom sales reports** and dashboards shared with the team.
- **Settings synced** across your devices.

Like most plugins, MGWS adds its own tables to the WordPress database.

## Download

| Platform | Download |
|----------|----------|
| Windows | [Installer](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest/download/mgws_inventory-win-Setup.exe) · [Portable](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest/download/mgws_inventory-win-Portable.zip) |
| Linux | [AppImage](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest/download/mgws_inventory.AppImage) |
| Android | [APK](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest/download/mgws_inventory.apk) · [Obtainium](https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/Vincenzoferrara/mgws-inventory) · F-Droid and Google Play coming soon |

All releases: <https://github.com/Vincenzoferrara/mgws-inventory/releases>.
The desktop versions update themselves.

## Documentation

The guides are in [`lib/doc`](lib/doc/README.md):
[user guide](lib/doc/user-guide.md) ·
[installation](lib/doc/installation.md) ·
[configuration](lib/doc/configuration.md) ·
[troubleshooting](lib/doc/troubleshooting.md) ·
[developer guide](lib/doc/developer-guide.md).

## Privacy

The developer receives no data from the app. See the
[privacy policy](PRIVACY.md) for what is stored on the device, on your
site and, only if you enable them, sent to AI services.

## Contributing

Bug reports, translations and pull requests are welcome: see
[CONTRIBUTING.md](CONTRIBUTING.md). Report security problems privately, as
described in [SECURITY.md](SECURITY.md).

## Support the project

MGWS Inventory is free. If it helps your shop, you can support its
development on [Ko-fi](https://ko-fi.com/vinc0101).

## License

Copyright © 2025-2026 Vincenzo Ferrara.

MGWS Inventory is free software: you can redistribute it and/or modify it
under the terms of the [GNU General Public License v3.0](LICENSE). It comes
with no warranty. The licenses of the libraries it uses are listed in the
app, under Settings → About → Open source licenses.
