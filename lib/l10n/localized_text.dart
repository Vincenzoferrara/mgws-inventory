import 'generated/app_localizations.dart';
import 'known_messages.dart';

/// Text prepared by code without `BuildContext`, then translated by the GUI.
///
/// Module code (`*.code.dart`, queries) does not know the current language:
/// it returns a function that selects an ARB key and parameters, and the GUI
/// calls it with `context.l10n` when displaying the message. This keeps text
/// aligned with the active locale even when it changes after the message is created.
typedef LocalizedText = String Function(AppLocalizations l10n);

/// Text that is already complete, such as a message returned by the server.
///
/// Fixed texts in [AppMessages] are always translated.
LocalizedText literalText(String text) =>
    (l10n) => knownMessageText(l10n, text);

/// Complete texts, such as server-returned errors.
List<LocalizedText> literalTexts(Iterable<String> texts) =>
    texts.map(literalText).toList(growable: false);
