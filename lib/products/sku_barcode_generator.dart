/// Utility per generazione SKU da pattern e codici a barre (EAN-13, UPC-A).
///
/// Logica pura, nessuna dipendenza da servizi esterni: testabile in isolamento.
class SkuBarcodeGenerator {
  SkuBarcodeGenerator._();

  /// Genera uno SKU da un pattern sostituendo i placeholder.
  ///
  /// Placeholder supportati:
  /// - {seq} / {seq:N}  -> numero sequenziale a N cifre (default 4)
  /// - {brand}           -> brand (passato in [vars])
  /// - {category}        -> categoria
  /// - {date}            -> YYYYMMDD
  /// - {random:N}        -> N caratteri alfanumerici casuali
  static String skuFromPattern(
    String pattern, {
    int seq = 1,
    Map<String, String> vars = const <String, String>{},
    DateTime? now,
  }) {
    final date = (now ?? DateTime.now()).toUtc();
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    String result = pattern;
    result = result.replaceAll('{date}', dateStr);
    result = result.replaceAll('{brand}', vars['brand'] ?? '');
    result = result.replaceAll('{category}', vars['category'] ?? '');

    // {seq} and {seq:N}
    result = result.replaceAllMapped(RegExp(r'\{seq:(\d+)\}'), (m) {
      final n = int.parse(m.group(1)!);
      return seq.toString().padLeft(n, '0');
    });
    result = result.replaceAll('{seq}', seq.toString().padLeft(4, '0'));

    // {random:N}
    result = result.replaceAllMapped(RegExp(r'\{random:(\d+)\}'), (m) {
      final n = int.parse(m.group(1)!);
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final buf = StringBuffer();
      var seed = seq * 31 + date.millisecondsSinceEpoch;
      for (var i = 0; i < n; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        buf.write(chars[seed % chars.length]);
      }
      return buf.toString();
    });

    return result;
  }

  /// Genera un codice EAN-13 valido (con cifra di controllo).
  ///
  /// [prefix] = primi 12 cifre (o meno; il resto viene riempito con zeri
  /// sequenziali). Se [prefix] è vuoto, usa '000000000000'.
  static String ean13({String prefix = '', int seq = 1}) {
    var base = prefix.replaceAll(RegExp(r'\D'), '');
    if (base.length > 12) base = base.substring(0, 12);
    while (base.length < 12) {
      base += '0';
    }
    // incorporate seq into last digits if prefix short
    if (prefix.isEmpty) {
      final s = seq.toString().padLeft(12, '0');
      base = s.substring(0, 12);
    }
    final check = _eanCheckDigit(base);
    return base + check.toString();
  }

  /// Genera un codice UPC-A valido (12 cifre con check digit).
  static String upcA({String prefix = '', int seq = 1}) {
    var base = prefix.replaceAll(RegExp(r'\D'), '');
    if (base.length > 11) base = base.substring(0, 11);
    while (base.length < 11) {
      base += '0';
    }
    if (prefix.isEmpty) {
      final s = seq.toString().padLeft(11, '0');
      base = s.substring(0, 11);
    }
    final check = _upcCheckDigit(base);
    return base + check.toString();
  }

  static int _eanCheckDigit(String base12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(base12[i]);
      sum += (i % 2 == 0) ? d : d * 3;
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }

  static int _upcCheckDigit(String base11) {
    var sum = 0;
    for (var i = 0; i < 11; i++) {
      final d = int.parse(base11[i]);
      sum += (i % 2 == 0) ? d * 3 : d;
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : 10 - mod;
  }

  /// Valida un EAN-13 (check digit).
  static bool isValidEan13(String code) {
    if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
    return _eanCheckDigit(code.substring(0, 12)) == int.parse(code[12]);
  }

  /// Valida un UPC-A.
  static bool isValidUpcA(String code) {
    if (!RegExp(r'^\d{12}$').hasMatch(code)) return false;
    return _upcCheckDigit(code.substring(0, 11)) == int.parse(code[11]);
  }
}