import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/gui/login.gui.dart';
import 'package:mgws_inventory/theme/theme.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('it'));

  Future<void> openLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
        home: const LoginPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the URL error does not move the local development checkbox', (
    tester,
  ) async {
    // The test font draws every letter one em wide: at normal size the error
    // wraps on two lines, while in the browser it takes one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await openLogin(tester);
    final checkbox = find.byType(Checkbox).first;
    final before = tester.getTopLeft(checkbox);

    await tester.enterText(
      find.byType(TextFormField).first,
      'http://127.0.0.1:8080',
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginLocalNeedsDevMode), findsOneWidget);
    expect(tester.getTopLeft(checkbox), before);
  });

  testWidgets('pressing Accedi brings the URL error into view', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openLogin(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'http://127.0.0.1:8080',
    );
    await tester.pumpAndSettle();

    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    final error = find.text(l10n.loginLocalNeedsDevMode);
    expect(tester.getRect(error).top, lessThan(0));

    await tester.tap(button);
    await tester.pumpAndSettle();

    final rect = tester.getRect(error);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(600));
  });
}
