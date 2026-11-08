import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/kit_deduction.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('KitDeductionScreen renders without crashing', (tester) async {
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
        home: const KitDeductionScreen(
          productId: 11762,
          productName: 'Test Kit',
        ),
      ),
    );
    // Allow initState's _load (which will fail offline) to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Deduzione kit: Test Kit'), findsOneWidget);
    expect(find.text('Aggiorna'), findsOneWidget);
    expect(find.text('Dedurre componenti dalla sede scelta'), findsOneWidget);
  });
}
