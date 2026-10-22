import '../login/jwt_api/error_list.dart';
import 'generated/app_localizations.dart';
import 'known_messages.dart';

/// Testo di un errore da mostrare all'operatore.
///
/// Le eccezioni dell'app ([AppException]) portano un testo tradotto; le altre
/// mostrano la propria descrizione, che di solito arriva da librerie o server.
String localizedErrorText(AppLocalizations l10n, Object error) {
  if (error is AppException) return error.localizedMessage(l10n);
  final text = error.toString();
  const prefix = 'Exception: ';
  return knownMessageText(
    l10n,
    text.startsWith(prefix) ? text.substring(prefix.length) : text,
  );
}
