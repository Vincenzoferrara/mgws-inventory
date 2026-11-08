import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_quick_load_catalog.code.dart';
import 'package:mgws_inventory/products/class_products.dart';
import 'package:mgws_inventory/products/product_list/product_list.code.dart';

/// Catalogo fisso, senza rete.
class _FixedProducts extends ProdottiGestioneController {
  _FixedProducts(this.items);

  final List<ProdottoGlobal> items;

  @override
  List<ProdottoGlobal> get prodotti => items;
}

void main() {
  final semplice = ProdottoGlobal(
    id: 1,
    nome: 'Maglia',
    codiceProdotto: 'MGWS-T-1',
    barcodeInterno: '8000000000011',
  );
  final variabile = ProdottoGlobal(
    id: 2,
    nome: 'Pantalone',
    codiceProdotto: 'PANT',
    varianti: <VarianteProductGlobal>[
      VarianteProductGlobal(
        id: 21,
        codiceProdotto: 'PANT-44',
        barcodeInterno: '8000000000028',
      ),
    ],
  );
  // Un barcode uguale al codice di un altro prodotto deve vincere.
  final conflitto = ProdottoGlobal(
    id: 3,
    nome: 'Calza',
    barcodeInterno: 'PANT-44',
  );

  final catalog = InventoryQuickLoadCatalogController(
    productsController: _FixedProducts(<ProdottoGlobal>[
      semplice,
      variabile,
      conflitto,
    ]),
  );

  test('the article code finds a simple product, any case', () {
    expect(catalog.findByBarcode('mgws-t-1')?.product.id, 1);
    expect(catalog.findByBarcode('8000000000011')?.product.id, 1);
  });

  test('a variation is found by its own code, the variable parent is not', () {
    expect(catalog.findByBarcode('PANT'), isNull);
    final byBarcode = catalog.findByBarcode('8000000000028');
    expect(byBarcode?.variation?.id, 21);
  });

  test('barcodes win over article codes', () {
    expect(catalog.findByBarcode('PANT-44')?.product.id, 3);
  });
}
