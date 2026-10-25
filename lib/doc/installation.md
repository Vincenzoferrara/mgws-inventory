# Installation

[Documentation index](README.md)

## What you need

For now the app works with **WordPress + WooCommerce**; other e-commerce
platforms, such as Shopify, are planned.

- **Required**: a WordPress site with **WooCommerce**, reachable from the
  device. This is enough for products, orders, coupons, customers and the
  dashboard.
- **Optional, to unlock the shop features**: the free **MGWS plugin**
  (<https://github.com/Vincenzoferrara/mgws-inventory-wordpress-plugin>), for the point of sale, inventory, suppliers, loyalty cards,
  employees, print templates, custom reports and synced settings. Like most
  plugins, it adds its own tables to the database. See
  [Before you start](user-guide.md#before-you-start) for the full split.
- A WordPress user with the WooCommerce and MGWS permissions needed for the
  work you do (for example reading and moving stock, or managing the
  shop).

Nothing else. Your WordPress site is the only backend: there is no
separate server, database or cloud account to set up for the app.

## Download

| Platform | Where |
|----------|-------|
| Windows | Installer or portable zip from the [latest release](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest) |
| Linux | AppImage from the [latest release](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest) |
| Android | APK from the [latest release](https://github.com/Vincenzoferrara/mgws-inventory/releases/latest), or [Obtainium](https://github.com/ImranR98/Obtainium) with the address `https://github.com/Vincenzoferrara/mgws-inventory`. F-Droid and Google Play are coming. |
| macOS, iOS | Build from source for now. |

The direct links are in the [project README](../../README.md#download).

Release versions are `major.minor.build`, for example `1.0.58`. On Android
the last number is also the technical version code used to recognise
updates.

## First login

1. Open the app and press `Log in`.
2. Enter the site address.
3. Choose the login method: WordPress Admin, JWT, WooCommerce API or smart
   card. See [Logging in](user-guide.md#logging-in) for the differences.
4. If the site is on your computer or local network (`localhost`,
   `192.168.x.x`, `10.x.x.x`), tick the local development option. It also
   allows WordPress Admin login over plain HTTP. Use it only for sites you
   trust.

## Platform notes

- **Android**: allow network, camera and NFC when the app asks, to use the
  barcode scanner and the smart card login.
- **iOS**: the app asks for the camera (barcode scanner), NFC (staff login
  cards), photos (product images) and local network (a WordPress site on
  your network).
- **Smart cards**: check that the device has NFC, or use a USB reader.
- **RFID**: USB and Wi-Fi readers are supported. Bluetooth is not available
  while the RFID module is in alpha.

## Updates

On Windows and Linux the app updates itself from `Updates`. On Android it
only tells you that a new version exists: the update comes from F-Droid,
Obtainium or the store. See [Updates](user-guide.md#updates).

## Build from source

You need Flutter `>=3.44.0` with Dart `>=3.12.0 <4.0.0`, and the SDK of the
platform you build for.

```bash
git clone https://github.com/Vincenzoferrara/mgws-inventory.git
cd mgws-inventory
flutter pub get
flutter run
```

The [developer guide](developer-guide.md) explains the local backend, the
build options for the stores and how releases are made.
