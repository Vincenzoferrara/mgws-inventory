import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/products/sku_barcode_generator.dart';

void main() {
  test('skuFromPattern substitutes seq and date', () {
    final now = DateTime.utc(2026, 3, 15);
    final sku = SkuBarcodeGenerator.skuFromPattern(
      '{seq:3}-{date}',
      seq: 7,
      now: now,
    );
    expect(sku, '007-20260315');
  });

  test('skuFromPattern substitutes vars', () {
    final now = DateTime.utc(2026, 3, 15);
    final sku = SkuBarcodeGenerator.skuFromPattern(
      '{brand}-{category}-{seq}',
      seq: 1,
      vars: const {'brand': 'ACME', 'category': 'SHOES'},
      now: now,
    );
    expect(sku, 'ACME-SHOES-0001');
  });

  test('ean13 produces 13 digits with valid check digit', () {
    final code = SkuBarcodeGenerator.ean13(seq: 42);
    expect(code.length, 13);
    expect(SkuBarcodeGenerator.isValidEan13(code), isTrue);
  });

  test('upcA produces 12 digits with valid check digit', () {
    final code = SkuBarcodeGenerator.upcA(seq: 7);
    expect(code.length, 12);
    expect(SkuBarcodeGenerator.isValidUpcA(code), isTrue);
  });

  test('isValidEan13 rejects bad check digit', () {
    expect(SkuBarcodeGenerator.isValidEan13('0000000000001'), isFalse);
  });
}
