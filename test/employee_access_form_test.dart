import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/employees/employees.code.dart';
import 'package:mgws_inventory/employees/employees.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, {Dipendente? dipendente}) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        home: DipendenteFormScreen(
          isEdit: dipendente != null,
          dipendente: dipendente,
          service: DipendentiService(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a new employee always gets a user, signed in by work email', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('Nessuno'), findsNothing);
    expect(find.text('Nome utente WordPress'), findsNothing);
    expect(find.text('Email personale'), findsOneWidget);
    expect(find.text('Telefono'), findsOneWidget);
    expect(find.text('Ore settimanali da contratto'), findsOneWidget);
    expect(find.text('Settimana tipo'), findsOneWidget);
    expect(
      find.text('Serve l\'email aziendale per creare l\'utente'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('employee-work-email-field')),
      'mario.rossi@negozio.it',
    );
    await tester.pump();
    expect(find.text('Accesso: mario.rossi@negozio.it'), findsOneWidget);
    expect(find.text('Invia email per scegliere la password'), findsOneWidget);
  });

  testWidgets('link existing asks to pick a user, not an ID', (tester) async {
    await pumpForm(tester);
    await tester.tap(find.text('Collega esistente'));
    await tester.pump();
    expect(find.text("Scegli l'utente WordPress da collegare"), findsOneWidget);
    expect(find.text('Scegli utente'), findsOneWidget);
  });

  testWidgets('usual week adds up and is compared with the contract', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('schedule-add-mon')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('schedule-add-mon')));
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-mon-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('schedule-mon-1')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('employee-contract-hours-field')),
      '40',
    );
    await tester.pump();
    final total = tester.widget<Text>(
      find.byKey(const ValueKey('employee-schedule-total')),
    );
    expect(total.data, 'Settimana tipo 8:00 · contratto 40:00');
  });

  testWidgets(
    'a linked employee shows its login and cannot get a second account',
    (tester) async {
      await pumpForm(
        tester,
        dipendente: Dipendente(
          id: 7,
          wpUserId: 42,
          wpUserLogin: 'mrossi',
          nome: 'Mario',
          cognome: 'Rossi',
          email: 'mario@casa.it',
          emailAziendale: 'mario@negozio.it',
          telefono: '333 1234567',
          ruolo: 'Cassa',
          stipendio: 1000,
        ),
      );
      expect(find.text('mrossi'), findsOneWidget);
      expect(find.text('Crea utente'), findsNothing);
      expect(find.text('333 1234567'), findsOneWidget);
    },
  );

  test('the record round-trips the real fields with MGWS', () {
    final dipendente = Dipendente.fromJson(<String, dynamic>{
      'id': 3,
      'first_name': 'Anna',
      'last_name': 'Bianchi',
      'email': 'anna@casa.it',
      'work_email': 'anna@negozio.it',
      'phone': '02 123',
      'role_label': 'Commessa',
      'salary_cents': 150000,
      'weekly_schedule': <String, dynamic>{
        'mon': <Map<String, String>>[
          <String, String>{'start': '09:00', 'end': '13:00'},
        ],
      },
      'contract_type': 'fixed_term',
      'contract_level': '4',
      'contract_start': '2026-11-01',
      'contract_end': '2027-10-31',
      'contract_minutes_week': 1200,
    });
    expect(dipendente.minutiSettimanaTipo, 240);
    expect(dipendente.contratto.tipo, TipoContratto.fixedTerm);
    final payload = dipendente.toMgwsPayload();
    expect(payload['work_email'], 'anna@negozio.it');
    expect(payload['phone'], '02 123');
    expect(payload['contract_type'], 'fixed_term');
    expect(payload['contract_start'], '2026-11-01');
    expect(payload['contract_end'], '2027-10-31');
    expect(payload['contract_minutes_week'], 1200);
    expect((payload['weekly_schedule'] as Map)['mon'], <Map<String, String>>[
      <String, String>{'start': '09:00', 'end': '13:00'},
    ]);
    expect((payload['weekly_schedule'] as Map)['sun'], isEmpty);
  });

  test('contract hours accept 40, 38:30 and 38,5', () {
    expect(parseOreContratto('40'), 2400);
    expect(parseOreContratto('38:30'), 2310);
    expect(parseOreContratto('38,5'), 2310);
    expect(parseOreContratto(''), 0);
    expect(parseOreContratto('abc'), isNull);
    expect(parseOreContratto('200'), isNull);
    expect(formatOre(2310), '38:30');
    expect(formatOre(-45, segno: true), '-0:45');
  });

  testWidgets('monday is copied to the weekdays and times are typed', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('schedule-add-mon')));
    await tester.pump();
    expect(find.byKey(const ValueKey('schedule-copy-monday')), findsOneWidget);

    // "930" in the start field becomes 09:30 when the field is left.
    final start = find.descendant(
      of: find.byKey(const ValueKey('schedule-mon-0')),
      matching: find.byType(TextField),
    );
    await tester.enterText(start.first, '930');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('09:30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-copy-monday')));
    await tester.pump();
    for (final giorno in <String>['tue', 'wed', 'thu', 'fri']) {
      expect(
        find.byKey(ValueKey('schedule-$giorno-0')),
        findsOneWidget,
        reason: giorno,
      );
    }
    expect(find.byKey(const ValueKey('schedule-sat-0')), findsNothing);
    final total = tester.widget<Text>(
      find.byKey(const ValueKey('employee-schedule-total')),
    );
    expect(total.data, 'Settimana tipo 17:30 · contratto 0:00');
  });

  testWidgets('a schedule that differs from the contract is flagged', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('schedule-add-mon')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('employee-schedule-mismatch')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('employee-contract-hours-field')),
      '40',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('employee-schedule-mismatch')),
      findsOneWidget,
    );
    expect(find.text('Non coincide con il contratto (-36:00)'), findsOneWidget);
  });

  testWidgets('contract end shows only for fixed-term contracts', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('Fine contratto'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('employee-contract-type-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tempo determinato').last);
    await tester.pumpAndSettle();
    expect(find.text('Fine contratto'), findsOneWidget);
  });

  test('typed times are normalised', () {
    expect(normalizzaOra('9'), '09:00');
    expect(normalizzaOra('930'), '09:30');
    expect(normalizzaOra('0930'), '09:30');
    expect(normalizzaOra('9:3'), '09:30');
    expect(normalizzaOra('9.45'), '09:45');
    expect(normalizzaOra('19:30'), '19:30');
    expect(normalizzaOra('24:00'), isNull);
    expect(normalizzaOra('9:75'), isNull);
    expect(normalizzaOra('abc'), isNull);
  });

  testWidgets('on a wide screen Tab stays in the left column', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        home: DipendenteFormScreen(isEdit: false, service: DipendentiService()),
      ),
    );
    await tester.pump();
    final nome = find.widgetWithText(TextFormField, 'Nome');
    final cognome = find.widgetWithText(TextFormField, 'Cognome');
    // Side by side with the contract column.
    expect(
      tester.getTopLeft(find.text('Contratto').first).dx,
      greaterThan(tester.getTopLeft(nome).dx + 300),
    );
    await tester.tap(nome);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(of: cognome, matching: find.byWidget(focused.widget)),
      findsOneWidget,
    );
  });
}
