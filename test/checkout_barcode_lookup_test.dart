import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/products/class_products.dart';
import 'package:mgws_inventory/products/product_barcode_lookup.dart';

void main() {
  group('codiciUguali', () {
    test('same code, any case and spaces', () {
      expect(codiciUguali(' mgws-t-1 ', 'MGWS-T-1'), isTrue);
    });

    test('a piece of a code is not the code', () {
      expect(codiciUguali('1', 'MGWS-T-1'), isFalse);
      expect(codiciUguali('123', '8001234567890'), isFalse);
    });

    test('UPC-A read as EAN-13 (leading zero)', () {
      expect(codiciUguali('0012345678905', '012345678905'), isTrue);
    });

    test('empty never matches', () {
      expect(codiciUguali('', ''), isFalse);
    });
  });

  test('a scanned "1" does not pick the variant MGWS-T-1', () {
    final variante = VarianteProductGlobal(
      id: 7,
      codiceProdotto: 'MGWS-T-1',
      barcodeInterno: '8001234567890',
    );
    expect(codiceInVariante(variante, '1'), isFalse);
    expect(codiceInVariante(variante, '800123'), isFalse);
    expect(codiceInVariante(variante, '8001234567890'), isTrue);
    expect(codiceInVariante(variante, 'mgws-t-1'), isTrue);
  });

  test('simple product matches by article code or barcode only', () {
    final prodotto = ProdottoGlobal(
      id: 11761,
      nome: 'MGWS test P1',
      codiceProdotto: 'MGWS-T-1',
      metadatiCustom: const {'supplier_sku': 'FORN-9'},
    );
    expect(codiceInProdotto(prodotto, 'MGWS-T-1'), isTrue);
    expect(codiceInProdotto(prodotto, 'forn-9'), isTrue);
    expect(codiceInProdotto(prodotto, '1'), isFalse);
    expect(codiceInProdotto(prodotto, 'MGWS'), isFalse);
  });
}
