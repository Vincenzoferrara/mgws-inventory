import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mgws_inventory/inventory/inventory_module.code.dart';
import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_movements_detail.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory_models.dart';
import 'package:mgws_inventory/theme/theme.dart';

InventoryMovementGroup _loadGroup() {
  final movement = MgwsMovement(
    id: 6,
    movementId: 3,
    occurredAtGmt: '2026-11-24T10:00:00Z',
    type: 'load',
    stockEffect: 'load',
    productId: 43,
    variationId: 0,
    quantityDelta: 1,
    stockBefore: 2,
    stockAfter: 3,
    location: const MgwsLocation(
      siteId: 1,
      warehouseId: 1,
      room: 'A',
      rack: '1',
      shelf: '1',
    ),
    warehouseFrom: 0,
    warehouseTo: 0,
    operatorUserId: 1,
    reasonCode: 'quick_load',
    note: '',
    sourceType: 'quick_load',
    sourceId: 0,
    sourceLineId: 0,
    sourceLinks: const {},
  );
  final product = InventoryMovementProduct(
    productId: 43,
    variationId: 0,
    quantityDelta: 1,
    quantity: 1,
    stockBefore: 2,
    stockAfter: 3,
    warehouseFrom: 0,
    warehouseTo: 0,
    siteFrom: 1,
    siteTo: 1,
    roomTo: '',
    movements: [movement],
  );
  return InventoryMovementGroup(
    key: 'movimento#3',
    kind: InventoryMovementKind.carico,
    rawType: 'load / quick_load',
    sourceType: 'quick_load',
    sourceId: 0,
    movementId: 3,
    occurredAtGmt: '2026-11-24T10:00:00Z',
    lastModifiedGmt: '2026-11-24T10:00:00Z',
    operatorUserId: 1,
    reason: 'quick_load',
    note: '',
    movements: [movement],
    products: [product],
  );
}

InventoryPanelSeed _seed({required int quantity}) {
  final group = _loadGroup();
  final product = group.products.single;
  return InventoryPanelSeed(
    module: InventoryModule.add,
    movements: group.movements,
    products: [
      InventoryMovementProduct(
        productId: product.productId,
        variationId: product.variationId,
        quantityDelta: quantity,
        quantity: quantity,
        stockBefore: product.stockBefore,
        stockAfter: product.stockAfter,
        warehouseFrom: product.warehouseFrom,
        warehouseTo: product.warehouseTo,
        siteFrom: product.siteFrom,
        siteTo: product.siteTo,
        roomTo: product.roomTo,
        movements: product.movements,
      ),
    ],
    reason: group.reason,
    details: group.note,
  );
}

void main() {
  test('a stock-in movement can be reopened in the Add panel', () {
    final group = _loadGroup();

    expect(group.resumeModule, InventoryModule.add);
    expect(group.canResume, isTrue);
  });

  test('the seed stamp changes when a product quantity changes', () {
    final original = _seed(quantity: 3);
    final edited = _seed(quantity: 0);

    expect(edited.stamp, isNot(original.stamp));
  });

  test('a stock-in cannot be reopened when a newer movement exists', () {
    final group = _loadGroup();

    expect(group.canResumeNow(isLatestMovement: true), isTrue);
    expect(group.canResumeNow(isLatestMovement: false), isFalse);
  });

  testWidgets('the Edit button follows the latest-movement gate', (tester) async {
    Future<void> pumpDialog({required bool isLatestMovement}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('it'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InventoryMovementDialog(
              group: _loadGroup(),
              imageUrls: const {},
              isLatestMovement: isLatestMovement,
            ),
          ),
        ),
      );
    }

    final edit = find.byKey(const ValueKey('inventory-movement-reopen'));

    await pumpDialog(isLatestMovement: false);
    expect(tester.widget<FilledButton>(edit).onPressed, isNull);

    await pumpDialog(isLatestMovement: true);
    expect(tester.widget<FilledButton>(edit).onPressed, isNotNull);
  });
}
