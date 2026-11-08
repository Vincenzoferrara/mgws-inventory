import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_add_products.code.dart';
import 'package:mgws_inventory/inventory/inventory_add_products.gui.dart';
import 'package:mgws_inventory/inventory/inventory_move.code.dart';
import 'package:mgws_inventory/inventory/inventory_quick_load.code.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';

void main() {
  const line = InventoryQuickLoadLineDraft(
    productId: 11761,
    variationId: 0,
    label: 'MGWS test P1',
    quantity: 1,
    idempotencyKey: 'k1',
  );

  Future<void> openDialog(
    WidgetTester tester,
    InventoryAddProductsPlan plan,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showInventoryAddProductsConfirmDialog(
              context: context,
              plan: plan,
              places: const InventoryLocationDirectory(
                warehouses: <InventoryPlace>[
                  InventoryPlace(id: 206, name: 'sottopiedi', siteId: 205),
                ],
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the load confirmation says where the pieces go, also when automatic',
    (tester) async {
      await openDialog(
        tester,
        const InventoryAddProductsPlan(
          mode: InventoryAddMode.simple,
          lines: <InventoryQuickLoadLineDraft>[line],
          siteIdText: '205',
          documentNumberText: '',
        ),
      );
      final destination = tester.widget<Text>(
        find.byKey(const ValueKey('inventory-add-confirm-destination')),
      );
      expect(destination.data, contains('Automatico'));
      expect(find.text('1 riga · 1 pezzo'), findsOneWidget);
      expect(find.textContaining('MGWS riceve'), findsNothing);
    },
  );

  testWidgets('a chosen warehouse is named in the confirmation', (
    tester,
  ) async {
    await openDialog(
      tester,
      const InventoryAddProductsPlan(
        mode: InventoryAddMode.simple,
        lines: <InventoryQuickLoadLineDraft>[line, line],
        siteIdText: '205',
        documentNumberText: '',
        warehouseId: 206,
      ),
    );
    final destination = tester.widget<Text>(
      find.byKey(const ValueKey('inventory-add-confirm-destination')),
    );
    expect(destination.data, contains('sottopiedi'));
    expect(find.text('2 righe · 2 pezzi'), findsOneWidget);
  });
}
