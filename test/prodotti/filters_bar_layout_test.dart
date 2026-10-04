import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/prodotti/prodotti_gestisci/prodotti_gestisci.gui.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview_cache.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview.gui.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview_image_preview.dart';
import 'package:mgws_inventory/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_visual_fixtures.dart';

Future<void> _pumpCatalog(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  DataGridViewCache.writeProducts(productVisualFixtures());
  addTearDown(DataGridViewCache.clearAll);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: const ProdottiGestisciPage()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('il comando "Scegli colonne" sta accanto a Filtro, non dentro', (
    tester,
  ) async {
    // Schermo stretto: i filtri partono chiusi, quindi il comando deve
    // restare visibile nella riga di testata anche senza espandere il pannello.
    await _pumpCatalog(tester, size: const Size(375, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('Filtro'), findsOneWidget);
    expect(find.byTooltip('Scegli colonne'), findsOneWidget);

    // Espandi i filtri: il comando resta UNO solo (non viene duplicato
    // dentro il pannello) e non sparisce dalla testata.
    await tester.tap(find.byTooltip('Espandi filtri'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Scegli colonne'), findsOneWidget);
  });

  testWidgets('la griglia mobile mostra la colonna anteprima', (tester) async {
    await _pumpCatalog(tester, size: const Size(375, 900));

    expect(tester.takeException(), isNull);

    final grid = tester.widget<DataGridView<dynamic>>(
      find.byWidgetPredicate((w) => w is DataGridView),
    );
    expect(
      grid.columns.map((c) => c.id),
      contains('preview'),
      reason: 'Su schermo stretto deve essere attiva la colonna Anteprima',
    );
    expect(find.byType(DataGridViewImagePreview), findsWidgets);
  });

  // Le checkbox del selettore sono l'unica fonte di verita: quello che
  // risulta spuntato nel dialog deve coincidere con le colonne in tabella.
  for (final width in [375.0, 1280.0]) {
    testWidgets('le checkbox di "Scegli colonne" coincidono con la tabella '
        'a $width px', (tester) async {
      await _pumpCatalog(tester, size: Size(width, 900));

      final grid = tester.widget<DataGridView<dynamic>>(
        find.byWidgetPredicate((w) => w is DataGridView),
      );
      final rendered = grid.columns.map((c) => c.label).toSet();

      await tester.tap(find.byTooltip('Scegli colonne'));
      await tester.pumpAndSettle();
      expect(find.text('Colonne visibili'), findsOneWidget);

      final checked = <String>{};
      for (final tile in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        if (tile.value == true) {
          final title = tile.title;
          if (title is Text) checked.add(title.data ?? '');
        }
      }

      expect(
        checked,
        rendered,
        reason:
            'Il selettore deve mostrare come spuntate esattamente le colonne '
            'rese nella griglia, senza nascondere un set mobile/desktop '
            'diverso da quello salvato nelle checkbox',
      );

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
    });
  }
}
