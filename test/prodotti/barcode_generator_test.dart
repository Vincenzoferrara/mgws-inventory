import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/reuse_class/barcode/barcode_generator.dart';

void main() {
  test('genera 30 cifre numeriche compatibili Code128', () {
    final value = BarcodeGenerator.generaCode128(esclusi: <String>{});
    expect(value, isNotNull);
    expect(value, hasLength(BarcodeGenerator.lunghezza));
    expect(value, matches(RegExp(r'^\d{30}$')));
  });

  test('termina con data/ora e millisecondi (DDMMYYYYHHMMSSSSS)', () {
    final now = DateTime(2001, 4, 25, 10, 10, 10, 123);
    final value = BarcodeGenerator.generaCode128(esclusi: <String>{}, now: now);
    expect(value, isNotNull);
    expect(value!.endsWith('25042001101010123'), isTrue);
  });

  test('completa con zeri le cifre mancanti di data/ora', () {
    final now = DateTime(2001, 1, 2, 3, 4, 5, 6);
    final value = BarcodeGenerator.generaCode128(esclusi: <String>{}, now: now);
    expect(value, isNotNull);
    expect(value!.endsWith('02012001030405006'), isTrue);
  });

  test('la parte casuale mantiene la lunghezza prevista', () {
    final value = BarcodeGenerator.generaCode128(
      esclusi: <String>{},
      random: Random(7),
      now: DateTime(2026, 9, 21, 8, 30, 0),
    );
    expect(value, isNotNull);
    expect(
      value!.substring(0, BarcodeGenerator.lunghezzaParteCasuale),
      matches(RegExp(r'^\d{13}$')),
    );
  });

  test('non restituisce mai un valore gia in uso', () {
    final rng = Random(42);
    final now = DateTime(2001, 4, 25, 10, 10, 10, 123);
    final usati = <String>{};
    for (int i = 0; i < 200; i++) {
      final value = BarcodeGenerator.generaCode128(
        esclusi: usati,
        random: rng,
        now: now,
      );
      expect(value, isNotNull);
      expect(usati, isNot(contains(value)));
      usati.add(value!);
    }
  });

  test('ignora valori vuoti e con soli spazi negli esclusi', () {
    final value = BarcodeGenerator.generaCode128(
      esclusi: <String>{'', '   '},
      random: Random(1),
    );
    expect(value, isNotNull);
  });

  test('restituisce null quando tutti i tentativi cadono sugli esclusi', () {
    // Un random fisso che produce sempre zeri: la parte casuale e sempre
    // identica, quindi con lo stesso istante il candidato non cambia.
    final now = DateTime(2001, 4, 25, 10, 10, 10, 123);
    final candidato =
        '${'0' * BarcodeGenerator.lunghezzaParteCasuale}25042001101010123';
    final value = BarcodeGenerator.generaCode128(
      esclusi: <String>{candidato},
      random: _FixedRandom(0),
      now: now,
    );
    expect(value, isNull);
  });
}

/// Random deterministico che restituisce sempre lo stesso valore.
class _FixedRandom implements Random {
  _FixedRandom(this._value);

  final int _value;

  @override
  int nextInt(int max) => _value % max;

  @override
  double nextDouble() => 0.0;

  @override
  bool nextBool() => false;
}
