import '../login/jwt_api/error_list.dart';
import 'generated/app_localizations.dart';
import 'known_messages.dart';

/// Error text to display to the operator.
///
/// Application exceptions ([AppException]) carry translated text; all other
/// exceptions expose their own description, usually received from a library or server.
String localizedErrorText(AppLocalizations l10n, Object error) {
  if (error is AppException) return error.localizedMessage(l10n);
  final text = error.toString();
  const prefix = 'Exception: ';
  return knownMessageText(
    l10n,
    text.startsWith(prefix) ? text.substring(prefix.length) : text,
  );
}
