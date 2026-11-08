import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/transfers.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_transfers.dart';
import 'package:mgws_inventory/theme/theme.dart';

/// The Docker site answers with ids as strings, as wpdb returns them.
class _StringIdsTransfers extends QueryMgwsTransfers {
  @override
  Future<Map<String, dynamic>> list({String status = ''}) async =>
      <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '2',
            'status': 'draft',
            'from_warehouse_id': '206',
            'to_warehouse_id': '207',
            'lines': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '5',
                'product_id': '11761',
                'variation_id': '0',
                'qty': '1',
              },
            ],
          },
        ],
      };
}

void main() {
  testWidgets('a transfer with string ids is shown, not a grey box', (
    tester,
  ) async {
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
        home: TransfersScreen(api: _StringIdsTransfers()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Trasferimenti con spedizione'), findsOneWidget);
    expect(find.byKey(const ValueKey('transfers-intro')), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#11761  × 1'), findsOneWidget);
  });
}
