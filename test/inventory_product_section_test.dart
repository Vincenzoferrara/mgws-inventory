import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_product_section.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/theme/theme.dart';

void main() {
  testWidgets('the barcode field stays focused after each scan', (
    tester,
  ) async {
    final scanned = <String>[];
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
          body: SingleChildScrollView(
            child: InventoryProductSection(
              title: 'Prodotti',
              lines: const <InventoryProductSectionLine>[],
              autoAdd: true,
              onAutoAddChanged: (_) {},
              onBarcodeEntered: (code) async {
                scanned.add(code);
                return true;
              },
              onPickExisting: () async {},
              onRemoveLine: (_) {},
            ),
          ),
        ),
      ),
    );
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await tester.pump();

    // A scanner: code, Enter, code, Enter, with no tap in between.
    for (final code in <String>['MGWS-T-1', 'MGWS-T-2']) {
      tester.testTextInput.enterText(code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    expect(scanned, <String>['MGWS-T-1', 'MGWS-T-2']);
    final editable = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.keyboardType, TextInputType.text);
  });
}
