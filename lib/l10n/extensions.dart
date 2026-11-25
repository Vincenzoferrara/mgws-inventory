import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

// Importing this file also exposes AppLocalizations.
export 'generated/app_localizations.dart';

/// Quick access to application translations.
///
/// Use it as `context.l10n.checkoutTotal`. It is the recommended way to read
/// a visible string: it makes it clear to source readers that the text depends
/// on the active language and must be translated in both ARB files.
extension TranslationContext on BuildContext {
  /// The current translations for the given context.
  ///
  /// With `nullable-getter: false` in `l10n.yaml`, this value is never null:
  /// a null value would mean that the widget has no `MaterialApp` ancestor,
  /// which means localizations are missing from the widget tree.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
