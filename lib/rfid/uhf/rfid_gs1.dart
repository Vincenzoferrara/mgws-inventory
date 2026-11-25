// lib/rfid/uhf/rfid_gs1.dart
//
// Decodifica locale di un EPC SGTIN-96. La decodifica non dipende da MGWS:
// GTIN e seriale sono mostrati appena il tag e' riconosciuto, anche quando
// l'associazione al prodotto non esiste ancora.

class RfidGs1Value {
  const RfidGs1Value({required this.gtin, required this.serial});

  /// GTIN-14, zero-padded, check digit incluso.
  final String gtin;

  /// Seriale numerico contenuto nei 38 bit bassi dell'EPC.
  final String serial;
}

class RfidGs1Decoder {
  RfidGs1Decoder._();

  // SGTIN-96: 8 bit di header, 3 di filter, 3 di partition, poi 44 bit
  // compresi tra company prefix e item reference, e 38 bit di seriale.
  // Le coppie qui sotto sono (bit company, bit item, cifre company, cifre
  // item) secondo la tabella di partizione GS1 per SGTIN-96.
  static const List<_SgtinPartition> _partitions = [
    _SgtinPartition(40, 4, 12, 1),
    _SgtinPartition(37, 7, 11, 2),
    _SgtinPartition(34, 10, 10, 3),
    _SgtinPartition(30, 14, 9, 4),
    _SgtinPartition(27, 17, 8, 5),
    _SgtinPartition(24, 20, 7, 6),
    _SgtinPartition(20, 24, 6, 7),
  ];

  static const int _headerBits = 8;
  static const int _filterBits = 3;
  static const int _partitionBits = 3;
  static const int _serialBits = 38;
  static const int _totalBits = 96;
  static const int _headerSgtin96 = 0x30;

  static const List<String> _urnPrefixes = [
    'URN:EPC:TAG:SGTIN-96:',
    'URN:EPC:RAW:',
  ];

  /// Restituisce null per qualunque cosa non sia un SGTIN-96 valido:
  /// prefisso diverso, lunghezza sbagliata, header diverso da 0x30,
  /// partizione fuori tabella o seriale non numerico.
  static RfidGs1Value? decodeSgtin96(String epc) {
    final hex = _normalize(epc);
    if (hex.length != 24) return null;
    if (RegExp(r'[^0-9A-F]').hasMatch(hex)) return null;

    final value = BigInt.parse(hex, radix: 16);
    final bits = value.toRadixString(2).padLeft(_totalBits, '0');
    if (bits.length != _totalBits) return null;

    final header = int.parse(bits.substring(0, _headerBits), radix: 2);
    if (header != _headerSgtin96) return null;

    final partitionStart = _headerBits + _filterBits;
    final partition = int.parse(
      bits.substring(partitionStart, partitionStart + _partitionBits),
      radix: 2,
    );
    if (partition < 0 || partition >= _partitions.length) return null;

    final spec = _partitions[partition];
    var cursor = partitionStart + _partitionBits;
    final companyBits = bits.substring(cursor, cursor + spec.companyBits);
    cursor += spec.companyBits;
    final itemBits = bits.substring(cursor, cursor + spec.itemBits);
    final serialBits = bits.substring(_totalBits - _serialBits);

    final company = int.parse(companyBits, radix: 2);
    final item = int.parse(itemBits, radix: 2);
    final serial = int.parse(serialBits, radix: 2);

    final serialText = serial.toString();
    if (serialText.isEmpty || int.tryParse(serialText) != serial) return null;

    // L'item reference dell'EPC comprende la cifra indicatore: il GTIN da
    // 14 cifre e' company prefix + item reference + check digit calcolato.
    final base =
        company.toString().padLeft(spec.companyDigits, '0') +
        item.toString().padLeft(spec.itemDigits, '0');
    if (base.length != 13 || int.tryParse(base) == null) return null;

    final gtin = '$base${_checkDigit(base)}';
    if (gtin.length != 14 || int.tryParse(gtin) == null) return null;

    return RfidGs1Value(gtin: gtin, serial: serialText);
  }

  static String _normalize(String value) {
    var result = value.trim().toUpperCase();
    for (final prefix in _urnPrefixes) {
      if (result.startsWith(prefix)) {
        result = result.substring(prefix.length);
        break;
      }
    }
    return result.replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Check digit GS1: pesi 3,1 da destra verso sinistra sul GTIN senza check.
  static int _checkDigit(String base) {
    var sum = 0;
    for (var i = 0; i < base.length; i++) {
      final digit = int.parse(base[base.length - 1 - i]);
      sum += digit * (i.isEven ? 3 : 1);
    }
    return (10 - sum % 10) % 10;
  }
}

class _SgtinPartition {
  const _SgtinPartition(
    this.companyBits,
    this.itemBits,
    this.companyDigits,
    this.itemDigits,
  );

  final int companyBits;
  final int itemBits;
  final int companyDigits;
  final int itemDigits;
}
