import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/gui/login.gui.dart';
import 'package:mgws_inventory/login/gui/login_local_dev.code.dart';
import 'package:mgws_inventory/theme/theme.dart';

void main() {
  test('local addresses are recognised, with or without scheme', () {
    expect(loginIsLocalSiteUrl('http://localhost:8080'), isTrue);
    expect(loginIsLocalSiteUrl('192.168.1.20:8080'), isTrue);
    expect(loginIsLocalSiteUrl('http://10.0.0.5/shop'), isTrue);
    expect(loginIsLocalSiteUrl('https://negozio.example.com'), isFalse);
    expect(loginIsLocalSiteUrl(''), isFalse);
  });

  test('the checkbox is saved only for a local site', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await loginSaveAllowLocalDev(
      prefs,
      siteUrl: 'http://localhost:8080',
      allowed: true,
    );
    expect(prefs.getBool(loginPrefKeyAllowLocalDev), isTrue);

    // Same checkbox, public site: nothing is kept.
    await loginSaveAllowLocalDev(
      prefs,
      siteUrl: 'https://negozio.example.com',
      allowed: true,
    );
    expect(prefs.containsKey(loginPrefKeyAllowLocalDev), isFalse);
  });

  test('a saved checkbox does not come back on a public URL', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      loginPrefKeyAllowLocalDev: true,
    });
    final prefs = await SharedPreferences.getInstance();
    expect(
      loginLoadAllowLocalDev(prefs, siteUrl: 'http://localhost:8080'),
      isTrue,
    );
    expect(
      loginLoadAllowLocalDev(prefs, siteUrl: 'https://negozio.example.com'),
      isFalse,
    );
  });

  Future<bool> checkboxAfterOpening(
    WidgetTester tester,
    Map<String, Object> saved,
  ) async {
    SharedPreferences.setMockInitialValues(saved);
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
    return tester.widget<Checkbox>(find.byType(Checkbox).first).value!;
  }

  testWidgets('the login page ticks the checkbox again for a local site', (
    tester,
  ) async {
    expect(
      await checkboxAfterOpening(tester, <String, Object>{
        'login_site_url': 'http://localhost:8080',
        loginPrefKeyAllowLocalDev: true,
      }),
      isTrue,
    );
  });

  testWidgets('the login page leaves it off for a public site', (tester) async {
    expect(
      await checkboxAfterOpening(tester, <String, Object>{
        'login_site_url': 'https://negozio.example.com',
        loginPrefKeyAllowLocalDev: true,
      }),
      isFalse,
    );
  });
}
