import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/prodotti/class_prodotti.dart';
import 'package:mgws_inventory/prodotti/prodotti_crea/variant_combinations.dart';

void main() {
  test('la chiave è indipendente da maiuscole e ordine degli attributi', () {
    final first = VariantCombinations.key([
      AttributoVariante(nome: 'Colore', opzione: 'Rosso'),
      AttributoVariante(nome: 'Taglia', opzione: 'M'),
    ]);
    final second = VariantCombinations.key([
      AttributoVariante(nome: ' taglia ', opzione: 'm'),
      AttributoVariante(nome: 'colore', opzione: 'ROSSO'),
    ]);

    expect(first, second);
  });

  test('genera il prodotto cartesiano di attributi e valori', () {
    final combinations = VariantCombinations.generate([
      AttributoVariante(nome: 'Colore', opzione: 'Rosso'),
      AttributoVariante(nome: 'Colore', opzione: 'Blu'),
      AttributoVariante(nome: 'Taglia', opzione: 'S'),
      AttributoVariante(nome: 'Taglia', opzione: 'M'),
    ]);

    expect(combinations, hasLength(4));
    expect(
      combinations.map(VariantCombinations.key),
      containsAll(<String>[
        'colore=blu|taglia=m',
        'colore=blu|taglia=s',
        'colore=rosso|taglia=m',
        'colore=rosso|taglia=s',
      ]),
    );
  });
}
