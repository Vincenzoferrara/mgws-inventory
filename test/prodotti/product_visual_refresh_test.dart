import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/prodotti/prodotti_gestisci/prodotti_gestisci.gui.dart';
import 'package:mgws_inventory/prodotti/prodotti_gestisci/prodotti_gestisci_view.gui.dart';
import 'package:mgws_inventory/prodotti/prodotto_filters.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview_cache.dart';
import 'package:mgws_inventory/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_visual_fixtures.dart';

Future<void> pumpCatalog(
  WidgetTester tester, {
  required Size size,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  DataGridViewCache.writeProducts(productVisualFixtures());
  addTearDown(DataGridViewCache.clearAll);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: const ProdottiGestisciPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [375.0, 768.0, 1280.0, 1600.0]) {
    for (final dark in [false, true]) {
      testWidgets('catalog $width dark=$dark preserves search and tools', (
        tester,
      ) async {
        await pumpCatalog(tester, size: Size(width, 900), dark: dark);
        expect(tester.takeException(), isNull);
        expect(find.text('mgws_inventory'), findsOneWidget);
        for (final tooltip in [
          'Scegli colonne',
          'Aggiorna cache e lista',
          'Crea Nuovo Prodotto',
        ]) {
          expect(find.byTooltip(tooltip), findsOneWidget);
        }
        expect(find.byTooltip('Importa da CSV'), findsNothing);
        expect(find.byTooltip('Esporta in CSV'), findsNothing);
        await tester.tap(find.byType(DropdownButton<CampoFiltroProdotto>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ricerca rapida').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Camicia Oxford');
        await tester.pumpAndSettle();
        expect(find.text('Camicia Oxford in cotone'), findsOneWidget);
        expect(find.text('Pantalone sartoriale'), findsNothing);
        await tester.tap(find.byTooltip('Cancella ricerca'));
        await tester.pumpAndSettle();
        expect(find.text('24 prodotti'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'Pantalone');
        await tester.pumpAndSettle();
        expect(find.text('Pantalone sartoriale'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('selection and column picker remain interactive', (tester) async {
    await pumpCatalog(tester, size: const Size(1280, 900));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('20 prodotti selezionati'), findsOneWidget);
    await tester.tap(find.text('Deseleziona'));
    await tester.pumpAndSettle();
    expect(find.text('20 prodotti selezionati'), findsNothing);
    await tester.tap(find.byTooltip('Scegli colonne'));
    await tester.pumpAndSettle();
    expect(find.text('Colonne visibili'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Colonne visibili'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow detail supports quick edit without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ProdottoDettagliView(prodotto: productVisualFixtures().first),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final edit = find.widgetWithText(FilledButton, 'Modifica rapida');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Salva tutto'), findsOneWidget);
    await tester.ensureVisible(find.text('Varianti Disponibili'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Prezzo'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'Quantita'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
