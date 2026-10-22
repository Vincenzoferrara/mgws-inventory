# Contributing

Thanks for helping MGWS Inventory. Bug reports, translations, documentation
and code are all welcome.

## Reporting a problem

Open an [issue](https://github.com/Vincenzoferrara/mgws-inventory/issues)
with:

- the app version (Settings → About) and the platform;
- the WordPress, WooCommerce and MGWS plugin versions;
- the steps to reproduce the problem and what you expected.

Do not post passwords, API keys or customer data. For security problems see
[SECURITY.md](SECURITY.md).

## Working on the code

1. Install Flutter (the version is in `.github/workflows/flutter-build.yml`).
2. Clone the repository and run `flutter pub get`.
3. Optional: to work on the
   [report_flutter](https://github.com/Vincenzoferrara/report_flutter)
   library at the same time, clone it next to this repository and create a
   `pubspec_overrides.yaml` (it is ignored by git):

   ```yaml
   dependency_overrides:
     report_flutter:
       path: ../../report
   ```

4. Before opening a pull request, run:

   ```bash
   dart format lib
   flutter analyze
   ```

The guides are in [`lib/doc/`](lib/doc/README.md): start from the
[developer guide](lib/doc/developer-guide.md).

## Translations

The texts are in `lib/traduzioni/app_en.arb` (English, the template) and
`lib/traduzioni/app_it.arb` (Italian). To add a language, copy `app_en.arb`
to `app_<code>.arb`, translate the values and open a pull request.

## License of contributions

MGWS Inventory is licensed under the
[GNU General Public License v3.0](LICENSE). By sending a contribution you
agree that:

- it is your own work, or you have the right to send it;
- it is released under the GPL-3.0, like the rest of the project;
- as an additional permission under section 7 of the GPL-3.0, the
  maintainer may distribute it, as part of MGWS Inventory, through app
  stores (such as the Apple App Store and Google Play) whose terms add
  restrictions to the recipients.

The source code stays available to everyone under the GPL-3.0.
