import 'generated/app_localizations.dart';
import 'known_messages.dart';

/// Testo che il codice senza `BuildContext` prepara e la GUI traduce.
///
/// Il codice di modulo (`*.code.dart`, query) non conosce la lingua corrente:
/// restituisce una funzione che sceglie la chiave ARB e i parametri, e la GUI
/// la chiama con `context.l10n` quando mostra il messaggio. Cosi il testo
/// segue la lingua attiva anche se cambia dopo che il messaggio e nato.
typedef LocalizedText = String Function(AppLocalizations l10n);

/// Testo gia pronto, ad esempio un messaggio restituito dal server.
///
/// I testi fissi di [AppMessages] vengono comunque tradotti.
LocalizedText literalText(String text) =>
    (l10n) => knownMessageText(l10n, text);

/// Elenco di testi gia pronti, ad esempio gli errori restituiti dal server.
List<LocalizedText> literalTexts(Iterable<String> texts) =>
    texts.map(literalText).toList(growable: false);
