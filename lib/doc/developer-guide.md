# Developer guide

[Documentation index](README.md)

Read [Architecture](architecture.md) first. Contribution rules and the
license of contributions are in [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Contents

- [Setup](#setup)
- [Local backend and Android emulator](#local-backend-and-android-emulator)
- [Code rules](#code-rules)
- [Logging](#logging)
- [Localization](#localization)
- [Theme](#theme)
- [Tables and pagination](#tables-and-pagination)
- [Dependencies](#dependencies)
- [Build options](#build-options)
- [Versions and releases](#versions-and-releases)
- [Stores and F-Droid](#stores-and-f-droid)
- [Verification](#verification)
- [Documentation](#documentation)
- [Commits](#commits)

## Setup

- Flutter `>=3.44.0`, Dart `>=3.12.0 <4.0.0`. CI uses the version set in
  `.github/workflows/flutter-build.yml`.
- `flutter pub get`, then `flutter run -d <device>`.
- `script/run_debug.sh -d <device>` increments the git-ignored counter
  `.debug_build_nr` and passes it as `--dart-define=DEBUG_BUILD_NR`. Debug
  builds then show `Version X (debug #N)`; release builds never do.

## Local backend and Android emulator

You need a reachable WordPress with WooCommerce and the MGWS plugin. Log in
with the local development option for `localhost` and LAN addresses.

`script/start_android_emulator.sh` starts the local AVD and forwards host
ports `8080` and `8081` with ADB, so `http://localhost:8080` and
`http://localhost:8081` inside the emulator reach the services on your
computer (the emulator uses NAT and has no LAN address). In VS Code the
launch configuration `4. Flutter Android Virtual (locale)` runs the script,
waits for ADB and starts the debugger on `emulator-5554`.

## Code rules

- Large modules split `*.gui.dart` (widgets, layout, input) from
  `*.code.dart` (state, orchestration, screen logic).
- Components used by more than one screen go in `lib/reuse_class/`. Do not
  copy scanner, pagination, table or shared dialog behaviour into a module.
- E-commerce behaviour talks to WooCommerce; stock, POS, loyalty, audit and
  every rule WooCommerce does not have go through MGWS. Never integrate
  another WordPress plugin directly.
- Never create a connector outside `WooConnect`. MGWS clients use its
  authenticated Dio and site URL.
- Read the MGWS state through `MgwsConnection.instance.ensureConnected()`.
  Do not call `verify()` from a module, do not keep a local copy of the
  flag, and use `PlatformManager.refreshCanUseMgws()` before an action that
  must not run on a stale state. A home section that needs MGWS declares
  `requiresMgws: true`. Details in
  [Architecture](architecture.md#the-mgws-connection-state).
- Inventory controllers never call Dio directly; they use the typed MGWS
  gateway.
- Module settings get their own settings view; `AppSettings` is only for
  global settings. Secrets go in secure storage.
- Login is security-critical: review every change to it for security
  first. No insecure fallback, no temporary shortcut.
- Optional external services (AI, Google…) must stay optional, be declared
  and ask before sending data.

## Logging

- Log through `log.*` (`lib/log_viewer/app_logger.dart`), never `print` or
  `debugPrint`, so messages can be filtered and pass the central
  sanitisation.
- Format: `HH:mm:ss.SSS [LEVEL] [tag] message`, with the stack trace as an
  indented block.
- Files are written only when the user records a temporary log, in the
  app's temporary folder `mgws_inventory_logs`. `clearAllLogs()` empties
  buffer and files; `getAllLogFiles()` lists the temporary files.
- In debug builds only, loading a variant in the editor or the selected
  product in `Products` logs the full REST JSON with the `PCREA_` and
  `PGEST_` prefixes, to diagnose missing colour or size groups.

## Localization

Every visible string goes through `context.l10n.<key>` and the ARB files in
`lib/l10n/`.

- `app_en.arb` is the template; `app_it.arb` is Italian. To add a language,
  add `app_<code>.arb`.
- Keys are English, `camelCase`, valid Dart getter names, prefixed by the
  module (`cassaTotal`, `productsAdd`, `settingsLanguage`).
- Never translate user data, protocol fields, persistence keys or backend
  payload names.
- After changing strings run `flutter gen-l10n` and
  `dart run lib/l10n/check_translations.dart`. Untranslated keys are
  listed in `lib/l10n/untranslated.json` (generated, not committed).
- Read translations in `build`, never once into a field: see
  [Language changes](architecture.md#language-changes).
- The screens of `report_flutter` use its own `ReportLocalizations`.

## Theme

All graphics refer to the theme: no hand-written colour, radius, spacing or
font size in `.gui.dart` files. The source is `lib/theme/theme.dart`
(`AppTheme`, `AppColorExtension`, `AppShapeExtension`,
`AppSpacingExtension`). Use the accessors, not
`Theme.of(context).extension<T>()!`:

```dart
context.colors   // AppColorExtension
context.shapes   // AppShapeExtension
context.spacing  // AppSpacingExtension
context.text     // TextTheme
context.theme    // ThemeData
```

Without a `BuildContext`, pass the `ThemeData` in and use
`theme.extension<AppColorExtension>()!`.

| Hard-coded | Use |
|------------|-----|
| `Colors.red` (error, delete, failed status) | `context.colors.errorColorStatus` |
| `Colors.green` (ok, valid) | `context.colors.successColor` |
| `Colors.orange`, `Colors.amber` (warning, pending) | `context.colors.warningColor` |
| `Colors.blue` (information) | `context.colors.infoColor` |
| `Colors.grey…` (secondary text) | `context.colors.subtitleColor` |
| `Colors.grey.shade900` (empty panel) | `context.colors.surfaceVariantColor` |
| `Colors.black87`, `Colors.white70` on a surface | `context.text.bodyLarge?.color` |

Keep as they are: white or black text and icons on a gradient or a solid
coloured chip (they keep the contrast), brand colours (Meta blue, TikTok
black, Google red, the gold/silver/bronze loyalty stars), fixed decorative
icons inside a coloured badge, and `Colors.transparent`.

| Radius | Accessor | | Padding | Accessor |
|--------|----------|-|---------|----------|
| 4 | `.xs` | | 4 | `.xs` |
| 8–10 | `.s` | | 8 | `.iS` / `.hS` / `.vS` |
| 12 | `.m` | | 12 | `.iM` / `.hM` / `.vM` |
| 14–16 | `.l` | | 16 | `.iL` / `.hL` / `.vL` |
| 18–20 | `.xl` | | 20–24 | `.iXL` |
| 999 | `.full` | | 32 | `.iXXL` |

| Font size | Text style |
|-----------|------------|
| 28–32 | `headlineLarge` |
| 24 | `headlineMedium` |
| 20 | `headlineSmall` |
| 18 | `titleLarge` |
| 16 | `titleMedium` |
| 14 | `titleSmall` |
| 12 | `bodyMedium` |
| 10–11 | `bodySmall` |

Use `context.text.<style>?.copyWith(...)`. `elevation: 4` is already the
`cardTheme` default: remove it instead of repeating it; keep `elevation: 0`.

## Tables and pagination

- Operational lists use `DataGridView` (`lib/reuse_class/datagridview/`);
  do not build bespoke tables.
- `DataGridView.framed` (default `true`) draws the grid's frame. Set it to
  `false` inside a container that already has a border: one frame per
  region.
- `DataGridViewColumn.flexible` marks the column that takes the remaining
  width, so the table reaches the right edge.
- The context menu belongs to the grid: callers pass
  `DataGridViewContextAction`s and `showDataGridViewContextMenu` builds it.
  A right click selects the row and opens the menu.
- `GlobalPaginationBar` stays on one line. Navigation buttons are outside
  every flexible widget; only the page indicator yields space. The `Rows`
  field has an explicit width (the `DropdownMenu` floor is 112 px) and
  explicit `contentPadding` and `suffixIconConstraints`. The controller
  exposes `progressCaption` and `progressValue` separately;
  `GlobalPaginationOptions.infiniteLabel` is the internal value and
  `infiniteDisplayLabel` the symbol shown. The widths in the file are
  computed on Roboto glyphs: adding a control means recomputing them.

## Dependencies

- `report_flutter` is pinned to a commit of
  <https://github.com/Vincenzoferrara/report_flutter> in `pubspec.yaml`, and
  will move to the pub.dev release once published. To work on the library
  next to the app, create a `pubspec_overrides.yaml` (ignored by git):

  ```yaml
  dependency_overrides:
    report_flutter:
      path: ../../report
  ```

  Commit `pubspec.lock` as resolved **without** the override: delete or
  move the file, run `flutter pub get`, commit, then put it back.
- `woocommerce_flutter_api` stays on the latest compatible release.
- To upgrade: `flutter pub upgrade --major-versions`, `flutter pub get`,
  `flutter analyze`. If `report_flutter` conflicts, update the library first.
- Before adding a dependency, check its license (GPL-3.0 compatible), that
  it has no Google Play Services or proprietary blobs (F-Droid), and that
  it is needed.

## Build options

Pass them with `--dart-define=NAME=value`:

| Name | Default | Effect |
|------|---------|--------|
| `DONATIONS` | `true` | `false` hides the Ko-fi donation button in `Settings > About`. It is always hidden on iOS. |
| `UPDATE_CHECK` | `true` | `false` turns off the "new version" notice on Android. |
| `DEBUG_BUILD_NR` | none | Debug build counter, set by `script/run_debug.sh`. |

Recommended values:

| Build | `DONATIONS` | `UPDATE_CHECK` |
|-------|-------------|----------------|
| GitHub releases, Obtainium, desktop | `true` | `true` |
| F-Droid | `true` | `false` |
| Google Play | `false` | `false` |
| App Store | `false` (hidden anyway) | (Android only) |

## Versions and releases

- `Flutter Build` (`flutter-build.yml`) builds Linux, Windows and macOS
  artifacts on every push and pull request.
- `Velopack Release` (`velopack-release.yml`) publishes the GitHub release:
  Windows installer and portable zip, Linux AppImage, Android APK and AAB.
  It runs:
  - on every push to `main` or `master`: version `major.minor.<run number>`,
    with `major.minor` taken from `pubspec.yaml`;
  - on a `v*` tag: the version is the tag (`v1.0.58` → `1.0.58`, build 58);
  - by hand, with a version and an optional build number.
- `Manual Prerelease` publishes a prerelease from an existing tag and never
  marks it as latest.
- `check translations` checks the ARB files.
- The Android version code is the last number of the version.
- **For releases that go to F-Droid, use a tag and write the same version in
  `pubspec.yaml` first** (for example `version: 1.0.58+58` and tag
  `v1.0.58`). F-Droid builds the tag and reads the version from
  `pubspec.yaml`, so the two must match.
- Desktop release notes come from the GitHub release and are shown once
  after the update.

## Stores and F-Droid

- Store texts, icon and changelogs are in `fastlane/metadata/android/`
  (`en-US`, `it-IT`). The changelog file is named after the version code:
  `changelogs/58.txt` for `1.0.58+58`. Short description: 80 characters at
  most.
- F-Droid declares the **NonFreeNet** anti-feature, because the optional AI
  providers are proprietary services. The scanner is ZXing and there are no
  Google libraries.
- Privacy policy for the stores:
  <https://github.com/Vincenzoferrara/mgws-inventory/blob/main/PRIVACY.md>.
- iOS: `Info.plist` declares camera, NFC, photo library and local network
  usage; `Runner.entitlements` declares the NFC tag formats (`NDEF`,
  `TAG`), which needs the NFC capability on the App ID. The export
  compliance answer (`ITSAppUsesNonExemptEncryption`) is the maintainer's
  decision and is not set.
- macOS: the sandbox entitlements allow network client, user-selected files
  and printing.
- Reviewers need a demo WordPress site with test credentials, because the
  app shows nothing without a backend.

## Verification

- Code changes: `dart format lib` and `flutter analyze` (must report no
  issues).
- String changes: also the localization checks above.
- Documentation changes: check the links and search for stale names.
- There is no automated test suite: verify changes with `flutter analyze` and
  by running the app.

## Documentation

`lib/doc` describes current behaviour for contributors. It holds no backlog
and no before/after history. Update the matching guide whenever a screen,
setting, flow or integration changes.

## Commits

Commit messages are in English:

```text
Short title

- short detail
- short detail
```
