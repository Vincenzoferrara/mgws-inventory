import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_movements_detail.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory_models.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview_image_preview.dart';
import 'package:mgws_inventory/theme/theme.dart';

InventoryMovementGroup _group() {
  final movement = MgwsMovement(
    id: 2,
    movementId: 2,
    occurredAtGmt: '2026-11-24T10:00:00Z',
    type: 'adjust',
    stockEffect: 'adjust',
    productId: 49,
    variationId: 77,
    quantityDelta: -1,
    stockBefore: 12,
    stockAfter: 11,
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
    reasonCode: 'reconcile',
    note: '',
    sourceType: '',
    sourceId: 0,
    sourceLineId: 0,
    sourceLinks: const {},
  );
  final product = InventoryMovementProduct(
    productId: 49,
    variationId: 77,
    quantityDelta: -1,
    quantity: 1,
    stockBefore: 12,
    stockAfter: 11,
    warehouseFrom: 0,
    warehouseTo: 0,
    siteFrom: 1,
    siteTo: 1,
    roomTo: '',
    movements: [movement],
  );
  return InventoryMovementGroup(
    key: '2',
    kind: InventoryMovementKind.rettifica,
    rawType: 'adjust',
    sourceType: '',
    sourceId: 0,
    movementId: 2,
    occurredAtGmt: '2026-11-24T10:00:00Z',
    lastModifiedGmt: '2026-11-24T10:00:00Z',
    operatorUserId: 1,
    reason: 'reconcile',
    note: '',
    movements: [movement],
    products: [product],
  );
}

void main() {
  testWidgets('the movement detail shows the product photo in its grid', (
    tester,
  ) async {
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
            group: _group(),
            imageUrls: const {'49:77': 'variant.png'},
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DataGridViewImagePreview &&
            widget.imageUrl == 'variant.png',
      ),
      findsOneWidget,
    );
  });
}
