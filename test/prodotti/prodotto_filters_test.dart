import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/prodotti/class_prodotti.dart';
import 'package:mgws_inventory/prodotti/prodotto_filters.dart';

FiltroProdotto _exactFilter(CampoFiltroProdotto campo, String value) {
  return FiltroProdotto(
    campo: campo,
    operatore: OperatoreFiltroProdotto.ugualeEsatto,
    valori: [value],
  );
}

void main() {
  group('ProdottoFilterEngine identifiers', () {
    final simpleProduct = ProdottoGlobal(
      nome: 'Giacca semplice',
      codiceProdotto: 'SKU-100',
      barcodeInterno: 'INT-100',
      barcodeProduttore: 'EXT-100',
    );
    final variableProduct = ProdottoGlobal(
      nome: 'Giacca variabile',
      varianti: [
        VarianteProductGlobal(
          id: 1,
          codiceProdotto: 'SKU-200-M',
          barcodeInterno: 'INT-200-M',
          barcodeFornitore: 'EXT-200-M',
        ),
      ],
    );

    test('keeps SKU and barcode filters separate', () {
      expect(
        ProdottoFilterEngine.matchesSingleFilter(
          simpleProduct,
          _exactFilter(CampoFiltroProdotto.codiceArticolo, 'SKU-100'),
        ),
        isTrue,
      );
      expect(
        ProdottoFilterEngine.matchesSingleFilter(
          simpleProduct,
          _exactFilter(CampoFiltroProdotto.codiceArticolo, 'INT-100'),
        ),
        isFalse,
      );
      expect(
        ProdottoFilterEngine.matchesSingleFilter(
          simpleProduct,
          _exactFilter(CampoFiltroProdotto.barcode, 'SKU-100'),
        ),
        isFalse,
      );
    });

    test('barcode filter finds internal and external values', () {
      for (final barcode in ['INT-100', 'EXT-100']) {
        expect(
          ProdottoFilterEngine.matchesSingleFilter(
            simpleProduct,
            _exactFilter(CampoFiltroProdotto.barcode, barcode),
          ),
          isTrue,
        );
      }
    });

    test('filters identifiers stored on product variations', () {
      expect(
        ProdottoFilterEngine.matchesSingleFilter(
          variableProduct,
          _exactFilter(CampoFiltroProdotto.codiceArticolo, 'SKU-200-M'),
        ),
        isTrue,
      );
      for (final barcode in ['INT-200-M', 'EXT-200-M']) {
        expect(
          ProdottoFilterEngine.matchesSingleFilter(
            variableProduct,
            _exactFilter(CampoFiltroProdotto.barcode, barcode),
          ),
          isTrue,
        );
      }
    });
  });
}
