import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview.code.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview.gui.dart';

/// Regressione per il datagrid vuoto su Android.
///
/// `DataTable2` sottrae dal `minWidth` un blocco
/// `3 * horizontalMargin + Checkbox.width` (colonna checkbox inclusa) prima
/// del suo assert "combined width of columns of fixed width is greater than
/// availble parent width". Se il `minWidth` calcolato da [DataGridView] non
/// contempla anche quella colonna, su schermo stretto con poche colonne
/// l'assert scatta durante `performLayout` e la griglia rende un box vuoto.
///
/// Casi coperti:
/// 1. smartphone 320dp con le 2 colonne di default mobile + checkbox
///    (390 < 368 senza il fix);
/// 2. colonna singola a larghezza fissa più larga del viewport
///    (`240 < 240` senza il fix, off-by-one del margine di sicurezza).
Widget _grid({
  required List<DataGridViewColumn> columns,
  required List<DataGridViewRowData<String>> rows,
  bool showCheckboxes = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DataGridView<String>(
        columns: columns,
        rows: rows,
        showCheckboxes: showCheckboxes,
        onRowChecked: showCheckboxes ? (_, _) {} : null,
      ),
    ),
  );
}

const _twoFixedColumns = [
  DataGridViewColumn(id: 'nome', label: 'Nome', width: 240),
  DataGridViewColumn(id: 'sku', label: 'SKU', width: 150),
];

const _twoRows = [
  DataGridViewRowData<String>(
    id: 'a',
    value: 'Riga A',
    cells: {'nome': Text('Riga A'), 'sku': Text('SKU-A')},
  ),
  DataGridViewRowData<String>(
    id: 'b',
    value: 'Riga B',
    cells: {'nome': Text('Riga B'), 'sku': Text('SKU-B')},
  ),
];

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'due colonne fissa + checkbox su schermo 320dp non fanno esplodere '
    'l\'assert di DataTable2',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 640),
        _grid(columns: _twoFixedColumns, rows: _twoRows, showCheckboxes: true),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Riga A'), findsOneWidget);
      expect(find.text('Riga B'), findsOneWidget);
      expect(find.text('SKU-A'), findsOneWidget);
    },
  );

  testWidgets(
    'una sola colonna fissa più larga del viewport soddisfa l\'assert',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(200, 640),
        _grid(
          columns: const [
            DataGridViewColumn(id: 'nome', label: 'Nome', width: 240),
          ],
          rows: const [
            DataGridViewRowData<String>(
              id: 'a',
              value: 'Riga A',
              cells: {'nome': Text('Riga A')},
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Riga A'), findsOneWidget);
    },
  );

  testWidgets(
    'la griglia resta utilizzabile: tap su una riga seleziona senza errori',
    (tester) async {
      await _pumpAtSize(
        tester,
        const Size(320, 640),
        _grid(columns: _twoFixedColumns, rows: _twoRows, showCheckboxes: true),
      );

      await tester.tap(find.text('Riga A'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
