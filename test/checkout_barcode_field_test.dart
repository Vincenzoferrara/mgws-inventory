import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/checkout/checkout_barcode_field.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/theme/theme.dart';

void main() {
  testWidgets('till barcode field: letters, Enter after Enter, keeps focus', (
    tester,
  ) async {
    final letti = <String>[];
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
          body: CassaBarcodeField(
            onCodice: (codice) async {
              letti.add(codice);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    for (final codice in <String>['MGWS-T-1', '8001234567890']) {
      tester.testTextInput.enterText(codice);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    expect(letti, <String>['MGWS-T-1', '8001234567890']);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.keyboardType, TextInputType.text);
    expect(editable.controller.text, isEmpty);
  });
}
