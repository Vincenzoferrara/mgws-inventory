import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/count_schedules.gui.dart';
import 'package:mgws_inventory/inventory/documents.gui.dart';
import 'package:mgws_inventory/inventory/kits.gui.dart';
import 'package:mgws_inventory/inventory/payments.gui.dart';
import 'package:mgws_inventory/inventory/product_barcodes.gui.dart';
import 'package:mgws_inventory/inventory/reservations.gui.dart';
import 'package:mgws_inventory/inventory/shipments.gui.dart';
import 'package:mgws_inventory/inventory/stock_reset.gui.dart';
import 'package:mgws_inventory/inventory/supplier_prices.gui.dart';
import 'package:mgws_inventory/inventory/transfers.gui.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/returns/returns.gui.dart';

void main() {
  Future<void> pumpAndSettleInit(WidgetTester tester, Widget child) async {
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
        home: child,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('SupplierPricesScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const SupplierPricesScreen());
    expect(find.text('Storico prezzi fornitori'), findsOneWidget);
  });

  testWidgets('CountSchedulesScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const CountSchedulesScreen());
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('ShipmentsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const ShipmentsScreen());
    expect(find.text('Spedizioni'), findsOneWidget);
  });

  testWidgets('ReservationsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const ReservationsScreen());
    expect(find.text('Prenotazioni'), findsOneWidget);
  });

  testWidgets('PaymentsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const PaymentsScreen());
    expect(find.text('Pagamenti'), findsOneWidget);
  });

  testWidgets('DocumentsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const DocumentsScreen());
    expect(find.text('Documenti'), findsOneWidget);
  });

  testWidgets('ProductBarcodesScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const ProductBarcodesScreen());
    expect(find.text('Barcode prodotti'), findsOneWidget);
    expect(find.text('Cerca'), findsOneWidget);
  });

  testWidgets('StockResetScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const StockResetScreen());
    expect(find.text('Reset massivo stock'), findsOneWidget);
  });

  testWidgets('KitsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const KitsScreen());
    expect(find.text('Kit'), findsOneWidget);
  });

  testWidgets('TransfersScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const TransfersScreen());
    expect(find.text('Trasferimenti con spedizione'), findsOneWidget);
    expect(find.byKey(const ValueKey('transfers-intro')), findsOneWidget);
  });

  testWidgets('ReturnsScreen renders', (tester) async {
    await pumpAndSettleInit(tester, const ReturnsScreen());
    expect(find.text('Resi'), findsOneWidget);
  });
}
