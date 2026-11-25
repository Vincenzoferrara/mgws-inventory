import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_movement_images.code.dart';
import 'package:mgws_inventory/products/class_products.dart';

InventoryMovementProduct _item(int productId, int variationId) =>
    InventoryMovementProduct(
      productId: productId,
      variationId: variationId,
      quantityDelta: 0,
      quantity: 1,
      stockBefore: null,
      stockAfter: null,
      warehouseFrom: 0,
      warehouseTo: 0,
      siteFrom: 0,
      siteTo: 0,
      roomTo: '',
      movements: const [],
    );

void main() {
  test('the variant photo wins over the parent photo', () async {
    final result = await loadInventoryMovementImages(
      [_item(49, 77)],
      cachedProducts: {
        49: ProdottoGlobal(id: 49, immagineUrl: 'parent.png'),
      },
      cachedVariants: {
        49: [VarianteProductGlobal(id: 77, immagineUrl: 'variant.png')],
      },
    );

    expect(result['49:77'], 'variant.png');
  });

  test('an empty variant photo falls back to the parent photo', () async {
    final result = await loadInventoryMovementImages(
      [_item(49, 77)],
      cachedProducts: {
        49: ProdottoGlobal(id: 49, immagineUrl: 'parent.png'),
      },
      cachedVariants: {
        49: [VarianteProductGlobal(id: 77, immagineUrl: '   ')],
      },
    );

    expect(result['49:77'], 'parent.png');
  });

  test('a product without any photo returns a null placeholder', () async {
    final result = await loadInventoryMovementImages(
      [_item(49, 0)],
      cachedProducts: {49: ProdottoGlobal(id: 49)},
      cachedVariants: const {},
    );

    expect(result, containsPair('49:0', isNull));
  });

  test('missing products and variants are fetched once', () async {
    final fetchedProducts = <List<int>>[];
    final fetchedVariants = <int>[];

    final result = await loadInventoryMovementImages(
      [_item(49, 77), _item(50, 0)],
      cachedProducts: const {},
      cachedVariants: const {},
      fetchProducts: (ids) async {
        fetchedProducts.add(ids);
        return [
          ProdottoGlobal(id: 49, immagineUrl: 'parent-49.png'),
          ProdottoGlobal(id: 50, immagineUrl: 'parent-50.png'),
        ];
      },
      fetchVariants: (productId) async {
        fetchedVariants.add(productId);
        return [
          VarianteProductGlobal(id: 77, immagineUrl: 'variant-77.png'),
        ];
      },
    );

    expect(fetchedProducts, [
      [49, 50],
    ]);
    expect(fetchedVariants, [49]);
    expect(result, {
      '49:77': 'variant-77.png',
      '50:0': 'parent-50.png',
    });
  });

  test('complete cache skips the catalog entirely', () async {
    var productFetches = 0;
    var variantFetches = 0;

    final result = await loadInventoryMovementImages(
      [_item(49, 77)],
      cachedProducts: {
        49: ProdottoGlobal(id: 49, immagineUrl: 'parent.png'),
      },
      cachedVariants: {
        49: [VarianteProductGlobal(id: 77, immagineUrl: 'variant.png')],
      },
      fetchProducts: (ids) async {
        productFetches++;
        return const [];
      },
      fetchVariants: (productId) async {
        variantFetches++;
        return const [];
      },
    );

    expect(result['49:77'], 'variant.png');
    expect(productFetches, 0);
    expect(variantFetches, 0);
  });

  test('a catalog failure leaves the ledger readable with placeholders',
      () async {
    final result = await loadInventoryMovementImages(
      [_item(49, 77)],
      cachedProducts: const {},
      cachedVariants: const {},
      fetchProducts: (ids) async => throw StateError('catalog offline'),
      fetchVariants: (productId) async => throw StateError('catalog offline'),
    );

    expect(result, containsPair('49:77', isNull));
  });
}
