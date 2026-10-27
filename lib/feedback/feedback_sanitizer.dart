import '../log_viewer/app_logger.dart';

/// Toglie dal testo del feedback tutto cio' che identifica il negozio.
///
/// Le issue del repository sono pubbliche e indicizzate: oltre ai segreti
/// gia' oscurati dal logger vanno tolti dominio del sito, nomi e email
/// dell'utente, indirizzi IP, telefoni e IBAN. Si applica sia al testo
/// scritto dall'utente sia alle righe di log allegate.
class FeedbackSanitizer {
  FeedbackSanitizer({String? siteUrl, Iterable<String?> knownNames = const []})
    : _siteHosts = _hostsOf(siteUrl),
      _knownNames =
          knownNames
              .whereType<String>()
              .map((name) => name.trim())
              // Nomi di una o due lettere colpirebbero parole qualsiasi.
              .where((name) => name.length >= 3)
              .toSet()
              .toList()
            // I nomi lunghi prima: "Mario Rossi" va sostituito prima di "Mario".
            ..sort((a, b) => b.length.compareTo(a.length));

  static const siteMarker = '<sito>';
  static const userMarker = '<utente>';
  static const emailMarker = '<email>';
  static const urlMarker = '<url>';
  static const hostMarker = '<dominio>';
  static const ipMarker = '<ip>';
  static const phoneMarker = '<telefono>';
  static const ibanMarker = '<iban>';
  static const cardMarker = '<carta>';

  final List<String> _siteHosts;
  final List<String> _knownNames;

  static final _email = RegExp(
    r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}',
    caseSensitive: false,
  );
  static final _url = RegExp(
    r'\b(?:https?|wss?)://[^\s<>"]+',
    caseSensitive: false,
  );

  /// Hostname con un TLD comune. L'elenco chiuso evita di colpire i nomi dei
  /// file Dart nelle stack trace (`home.gui.dart`).
  static final _host = RegExp(
    r'\b(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+'
    r'(?:com|net|org|it|eu|de|fr|es|ch|at|uk|nl|be|pt|io|co|me|biz|info|'
    r'shop|store|online|site|app|cloud|xyz|local|lan|home)\b',
    caseSensitive: false,
  );
  static final _ipv4 = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');

  /// Almeno quattro gruppi: gli orari dei log (`12:30:45`) ne hanno tre.
  static final _ipv6 = RegExp(
    r'\b(?:[0-9a-f]{1,4}:){3,7}[0-9a-f]{1,4}\b',
    caseSensitive: false,
  );
  static final _phone = RegExp(r'\+\d[\d\s./-]{7,15}\d');
  static final _iban = RegExp(r'\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]){11,30}\b');

  /// Da 15 a 19 cifre: i barcode EAN-13 dei prodotti non sono dati personali.
  static final _cardCandidate = RegExp(r'\b\d(?:[ -]?\d){14,18}\b');

  String sanitize(String text) {
    var result = AppLogger.redactSecrets(text);

    // Prima le sostituzioni esatte: conoscere il dominio e il nome reale e'
    // piu' affidabile di qualunque regex generica.
    for (final host in _siteHosts) {
      result = result.replaceAll(
        RegExp(
          r'(?:https?://)?' + RegExp.escape(host) + r'(?:/[^\s<>"]*)?',
          caseSensitive: false,
        ),
        siteMarker,
      );
    }
    result = result.replaceAll(_email, emailMarker);
    for (final name in _knownNames) {
      result = result.replaceAll(
        RegExp(r'\b' + RegExp.escape(name) + r'\b', caseSensitive: false),
        userMarker,
      );
    }

    result = result.replaceAll(_url, urlMarker);
    result = result.replaceAll(_host, hostMarker);
    result = result.replaceAll(_ipv4, ipMarker);
    result = result.replaceAll(_ipv6, ipMarker);
    result = result.replaceAll(_iban, ibanMarker);
    result = result.replaceAllMapped(
      _cardCandidate,
      (match) => _passesLuhn(match.group(0)!) ? cardMarker : match.group(0)!,
    );
    result = result.replaceAll(_phone, phoneMarker);
    return result;
  }

  /// Host del sito con e senza `www.`, per riconoscerlo in qualunque forma.
  static List<String> _hostsOf(String? siteUrl) {
    final raw = siteUrl?.trim();
    if (raw == null || raw.isEmpty) return const [];
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    final host = uri?.host.toLowerCase();
    if (host == null || host.isEmpty) return const [];
    final bare = host.startsWith('www.') ? host.substring(4) : host;
    return {host, bare, 'www.$bare'}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  static bool _passesLuhn(String candidate) {
    final digits = candidate.replaceAll(RegExp(r'\D'), '');
    var sum = 0;
    var doubleIt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var digit = digits.codeUnitAt(i) - 48;
      if (doubleIt) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
  }
}
