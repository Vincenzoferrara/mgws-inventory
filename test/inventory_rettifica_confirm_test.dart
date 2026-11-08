import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_adjustment.code.dart';
import 'package:mgws_inventory/inventory/inventory_adjustment.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'the adjustment confirmation has a readable title and the site name',
    (tester) async {
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
              onPressed: () => showInventoryRettificaConfirmDialog(
                context: context,
                siteName: 'fabbrica',
                plan: const InventoryRettificaPlan(
                  siteIdText: '205',
                  lines: <InventoryRettificaLine>[
                    InventoryRettificaLine(
                      productId: 11761,
                      label: 'MGWS test P1',
                      direction: InventoryRettificaDirection.decrease,
                      delta: 2,
                      siteId: 205,
                    ),
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
      expect(find.text('Conferma rettifica di 1 prodotto'), findsOneWidget);
      expect(find.text('Sede: fabbrica'), findsOneWidget);
      expect(find.textContaining('Closure'), findsNothing);
    },
  );
}
