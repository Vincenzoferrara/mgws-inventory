import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/employees/employee_hr.gui.dart';
import 'package:mgws_inventory/employees/employees.code.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_employees.dart';

/// Server finto: una settimana con un turno e il riepilogo del plugin.
class _FakeApi extends QueryMgwsEmployees {
  final List<String> calls = <String>[];

  @override
  Future<Map<String, dynamic>> shifts(
    int employeeId,
    String from,
    String to,
  ) async {
    calls.add('shifts $from $to');
    return <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'shift_date': from,
          'start_time': '09:00',
          'end_time': '13:00',
          'break_minutes': 0,
          'minutes': 240,
          'note': 'apertura',
        },
      ],
      'summary': <String, dynamic>{
        'planned_minutes': 240,
        'contract_minutes': 2400,
        'difference_minutes': -2160,
      },
    };
  }
}

void main() {
  testWidgets('shifts screen shows the week against the contract', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeApi();
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
        home: DipendenteTurniScreen(
          dipendente: Dipendente(
            id: 5,
            nome: 'Anna',
            cognome: 'Bianchi',
            email: '',
            ruolo: 'Commessa',
            stipendio: 0,
          ),
          service: DipendenteHrService(api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final monday = lunediDi(DateTime.now());
    expect(
      api.calls.single,
      'shifts ${dataMgws(monday)} ${dataMgws(monday.add(const Duration(days: 6)))}',
    );
    expect(find.text('09:00–13:00'), findsOneWidget);
    expect(find.text('apertura'), findsOneWidget);
    expect(find.text('-36:00'), findsOneWidget);
    expect(find.text('Nessun turno'), findsNWidgets(6));

    // Without a usual week there is nothing to copy: the app says so instead of calling the server.
    await tester.tap(find.byTooltip('Copia settimana tipo'));
    await tester.pump();
    expect(
      find.text(
        'Il dipendente non ha una settimana tipo: impostala nella scheda.',
      ),
      findsOneWidget,
    );
    expect(api.calls.length, 1);

    await tester.tap(find.byTooltip('Settimana successiva'));
    await tester.pumpAndSettle();
    expect(
      api.calls.last,
      startsWith('shifts ${dataMgws(monday.add(const Duration(days: 7)))}'),
    );
  });
}
