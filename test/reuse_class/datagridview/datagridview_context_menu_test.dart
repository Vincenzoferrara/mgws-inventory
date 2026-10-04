import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview.code.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview.gui.dart';

Widget buildGrid({
  required List<DataGridViewContextAction<String>> actions,
  List<DataGridViewRowData<String>>? rows,
}) {
  return MaterialApp(
    home: Scaffold(
      body: DataGridView<String>(
        columns: const [
          DataGridViewColumn(id: 'name', label: 'Nome', width: 240),
        ],
        rows:
            rows ??
            const [
              DataGridViewRowData<String>(
                id: 'a',
                value: 'Riga A',
                cells: {'name': Text('Riga A')},
              ),
              DataGridViewRowData<String>(
                id: 'b',
                value: 'Riga B',
                cells: {'name': Text('Riga B')},
              ),
            ],
        contextActions: actions,
      ),
    ),
  );
}

void main() {
  testWidgets('right-click shows the context menu with all actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGrid(
        actions: const [
          DataGridViewContextAction<String>(
            label: 'Modifica',
            icon: Icons.edit_outlined,
            onSelected: _noop,
          ),
          DataGridViewContextAction<String>(
            label: 'Elimina',
            icon: Icons.delete_outline,
            onSelected: _noop,
          ),
          DataGridViewContextAction<String>(
            label: 'Crea',
            icon: Icons.add_circle_outline,
            onSelected: _noop,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riga A'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Modifica'), findsOneWidget);
    expect(find.text('Elimina'), findsOneWidget);
    expect(find.text('Crea'), findsOneWidget);

    // Dismiss the menu tapping outside.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Modifica'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting an action dispatches the callback with the row value',
    (tester) async {
      final dispatched = <String>[];
      await tester.pumpWidget(
        buildGrid(
          actions: [
            DataGridViewContextAction<String>(
              label: 'Modifica',
              icon: Icons.edit_outlined,
              onSelected: (value) async => dispatched.add('edit:$value'),
            ),
            DataGridViewContextAction<String>(
              label: 'Elimina',
              icon: Icons.delete_outline,
              onSelected: (value) async => dispatched.add('delete:$value'),
            ),
            DataGridViewContextAction<String>(
              label: 'Crea',
              icon: Icons.add_circle_outline,
              onSelected: (value) async => dispatched.add('create:$value'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Riga B'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      expect(dispatched, ['delete:Riga B']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('without actions the grid does not show a menu on right-click', (
    tester,
  ) async {
    await tester.pumpWidget(buildGrid(actions: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riga A'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Modifica'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _noop(String value) async {}
