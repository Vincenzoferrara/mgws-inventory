# Installation

## Public builds

Use the [global README](../../README.md#download) for current Android, Windows and Linux downloads.

Android can be installed from GitHub Releases or through Obtainium using the repository URL:

```text
https://github.com/Vincenzoferrara/mgws-inventory
```

Google Play and F-Droid pages are planned but are not public yet.

## Requirements

For normal usage you need:

- a WordPress site
- WooCommerce
- the MG Warehouse Stock plugin
- credentials with the required WooCommerce/MGWS permissions

For local development you need:

- Flutter `>=3.41.2`
- Dart `>=3.11.0 <4.0.0`
- Android SDK for Android builds
- a reachable WordPress/WooCommerce/MGWS backend

## First run

1. Open the app.
2. Open login.
3. Enter the WordPress site URL.
4. Choose the login method.
5. Use JWT, WooCommerce API credentials or WordPress Admin credentials.
6. If the backend is local (`localhost`, `192.168.x.x`, `10.x.x.x`), enable the local development option.

The local development option also applies to WordPress Admin login over HTTP.

## Build from source

```bash
flutter pub get
flutter run
```

Use the Android emulator helper when working against local WordPress from an emulator:

```bash
script/start_android_emulator.sh
```

The helper starts the configured AVD and forwards host ports `8080` and `8081` into the emulator.
