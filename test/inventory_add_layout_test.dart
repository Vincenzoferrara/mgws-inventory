import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mgws_inventory/inventory/inventory_add_products.gui.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/settings/inventory_quick_load_settings.dart';
import 'package:mgws_inventory/theme/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpPanel(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('it'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InventoryAddProductsPanel(
            settings: InventoryQuickLoadSettings(),
            warehouseLoader: ({int? siteId}) async =>
                MgwsRestockResult.success(const <MgwsInventoryWarehouse>[
                  MgwsInventoryWarehouse(
                    id: 206,
                    siteId: 205,
                    name: 'sottopiedi',
                    active: true,
                  ),
                  MgwsInventoryWarehouse(
                    id: 207,
                    siteId: 205,
                    name: 'WH2',
                    active: true,
                  ),
                ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  testWidgets('at 1024 px mode and warehouse share one row', (tester) async {
    await pumpPanel(tester, 1024);

    expect(
      find.byKey(const ValueKey('inventory-add-setup-row')),
      findsOneWidget,
    );
    final mode = find.byKey(const ValueKey('inventory-add-mode-simple'));
    final warehouse = find.byKey(
      const ValueKey('inventory-add-warehouse-field'),
    );
    expect(top(tester, mode), top(tester, warehouse));
    // The warehouse choice and the meaning of "Automatico" are still there.
    expect(find.text('Automatico'), findsOneWidget);
    expect(
      find.text(
        'Dove il prodotto è già, altrimenti nel predefinito della sede.',
      ),
      findsOneWidget,
    );
    expect(find.text('2. Posizione'), findsOneWidget);
    expect(find.text('3. Prodotti e quantità'), findsOneWidget);
    // The barcode field is in the upper part of a 768 px high window.
    expect(top(tester, find.byType(TextField).first), lessThan(420));
  });

  testWidgets('on a phone the steps stay one under the other', (tester) async {
    await pumpPanel(tester, 400);

    expect(find.byKey(const ValueKey('inventory-add-setup-row')), findsNothing);
    final mode = find.byKey(const ValueKey('inventory-add-mode-simple'));
    final warehouse = find.byKey(
      const ValueKey('inventory-add-warehouse-field'),
    );
    expect(top(tester, warehouse), greaterThan(top(tester, mode)));
  });
}
