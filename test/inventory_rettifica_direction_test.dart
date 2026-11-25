import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mgws_inventory/inventory/inventory_adjustment.code.dart';
import 'package:mgws_inventory/inventory/inventory_adjustment.gui.dart';
import 'package:mgws_inventory/inventory/inventory_module.code.dart';
import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_restock_feedback.code.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/theme/theme.dart';

class _FakeRettificaController extends InventoryRettificaController {
  @override
  Future<InventoryActionFeedback> loadStock(
    String productIdText, {
    int variationId = 0,
  }) async {
    final id = int.tryParse(productIdText) ?? 0;
    lastSnapshot = InventoryStockSnapshot(
      productId: id,
      variationId: variationId,
      productName: 'Prodotto $id',
      currentStock: 10,
      levels: const [],
    );
    return InventoryActionFeedback(
      success: true,
      message: (l10n) => l10n.inventoryStockOfProduct('Prodotto $id', 10),
    );
  }
}

MgwsMovement _movement(int id, int productId) {
  return MgwsMovement(
    id: id,
    movementId: 1,
    occurredAtGmt: '2026-11-24T10:00:00Z',
    type: 'adjust',
    stockEffect: 'adjust',
    productId: productId,
    variationId: 0,
    quantityDelta: 1,
    stockBefore: 9,
    stockAfter: 10,
    location: const MgwsLocation(
      siteId: 1,
      warehouseId: 0,
      room: '',
      rack: '',
      shelf: '',
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
}

void main() {
  testWidgets(
    'the direction is chosen per product and the header is only a default',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seed = InventoryPanelSeed(
        module: InventoryModule.fix,
        movements: [_movement(1, 43), _movement(2, 44)],
        products: const [],
        reason: 'reconcile',
        details: '',
      );

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
            body: InventoryRettificaPanel(
              controller: _FakeRettificaController(),
              seed: seed,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('inventory-rettifica-auto-checkbox')),
      );
      await tester.pumpAndSettle();

      // Each product has its own direction control, with a distinct key.
      expect(
        find.byKey(const ValueKey(
          'inventory-rettifica-row-direction-increase-43:0',
        )),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(
          'inventory-rettifica-row-direction-decrease-44:0',
        )),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey(
          'inventory-rettifica-amount-plus-43:0',
        )),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-rettifica-preview-43:0')),
          matching: find.textContaining('+1'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey(
          'inventory-rettifica-row-direction-decrease-43:0',
        )),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-rettifica-preview-43:0')),
          matching: find.textContaining('-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-rettifica-preview-44:0')),
          matching: find.textContaining('+1'),
        ),
        findsNothing,
      );

      // Changing the header choice must not rewrite a row already on screen:
      // it only decides the direction of the next barcode scan.
      await tester.tap(
        find.byKey(const ValueKey('inventory-rettifica-direction-decrease')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-rettifica-preview-43:0')),
          matching: find.textContaining('-1'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey(
          'inventory-rettifica-amount-plus-44:0',
        )),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inventory-rettifica-preview-44:0')),
          matching: find.textContaining('+1'),
        ),
        findsOneWidget,
      );
    },
  );
}
