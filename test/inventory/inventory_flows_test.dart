// Test della logica dei flussi del pannello inventario.
//
// Nessuna chiamata di rete: qui si verifica solo come i piani si validano e
// come viene calcolato il delta, che e la parte dove un errore sfugge piu
// facilmente e si traduce in magazzino sbagliato.

import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/inventory/inventory_add_products.code.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/inventory/inventory_quick_load.code.dart';
import 'package:mgws_inventory/inventory/inventory_restock_feedback.code.dart';
import 'package:mgws_inventory/inventory/inventory_rettifica.code.dart';
import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_suppliers.code.dart';

InventoryQuickLoadLineDraft _line({
  int productId = 10,
  int variationId = 0,
  int quantity = 1,
}) {
  return InventoryQuickLoadLineDraft(
    productId: productId,
    variationId: variationId,
    label: 'Prodotto $productId',
    quantity: quantity,
    idempotencyKey: 'key-$productId-$variationId',
  );
}

MgwsSupplier _supplier({int id = 4}) {
  return MgwsSupplier(
    id: id,
    name: 'Fornitore Uno',
    taxId: '',
    email: '',
    phone: '',
    active: true,
    notes: '',
    paymentTermsDays: 0,
    iban: '',
    leadTimeDays: 0,
    createdAtGmt: '',
    updatedAtGmt: '',
  );
}

InventoryAddProductsPlan _plan({
  InventoryAddMode mode = InventoryAddMode.simple,
  MgwsSupplier? supplier,
  bool validated = false,
  String siteIdText = '1',
  String documentNumberText = 'AGG-1',
  List<InventoryQuickLoadLineDraft>? lines,
}) {
  return InventoryAddProductsPlan(
    mode: mode,
    supplier: supplier,
    validated: validated,
    siteIdText: siteIdText,
    documentNumberText: documentNumberText,
    lines: lines ?? [_line(quantity: 3)],
  );
}

void main() {
  group('Aggiungi prodotto: conteggi', () {
    test('somma i pezzi di tutte le righe', () {
      final plan = _plan(
        lines: [
          _line(productId: 1, quantity: 2),
          _line(productId: 2, quantity: 5),
          _line(productId: 3, variationId: 7, quantity: 1),
        ],
      );
      expect(plan.lineCount, 3);
      expect(plan.enteredQuantity, 8);
    });

    test('senza convalida i pezzi convalidati sono zero', () {
      final plan = _plan(validated: false);
      expect(plan.enteredQuantity, 3);
      expect(plan.validatedQuantity, 0);
      expect(plan.difference, 3);
    });

    test('con convalida i pezzi convalidati coprono tutto', () {
      final plan = _plan(validated: true);
      expect(plan.validatedQuantity, 3);
      expect(plan.difference, 0);
    });
  });

  group('Aggiungi prodotto: validazione piano', () {
    test('modalita semplice non chiede fornitore ne documento', () {
      final parsed = _plan().parse();
      expect(parsed, isA<InventoryFormValid<InventoryAddProductsCommand>>());
      final command =
          (parsed as InventoryFormValid<InventoryAddProductsCommand>).value;
      expect(command.supplierId, isNull);
    });

    test('modalita ordine senza fornitore e non valida', () {
      final parsed = _plan(mode: InventoryAddMode.order).parse();
      expect(parsed, isA<InventoryFormInvalid>());
      expect((parsed as InventoryFormInvalid).message, contains('fornitore'));
    });

    test('modalita ordine senza numero documento non e valida', () {
      final parsed = _plan(
        mode: InventoryAddMode.order,
        supplier: _supplier(),
        documentNumberText: '  ',
      ).parse();
      expect(parsed, isA<InventoryFormInvalid>());
      expect((parsed as InventoryFormInvalid).message, contains('documento'));
    });

    test('modalita ordine completa passa e porta il id fornitore', () {
      final parsed = _plan(
        mode: InventoryAddMode.order,
        supplier: _supplier(id: 9),
        validated: true,
      ).parse();
      expect(parsed, isA<InventoryFormValid<InventoryAddProductsCommand>>());
      final command =
          (parsed as InventoryFormValid<InventoryAddProductsCommand>).value;
      expect(command.supplierId, 9);
      expect(command.validated, isTrue);
    });

    test('senza righe non e valida in nessuna modalita', () {
      expect(_plan(lines: const []).parse(), isA<InventoryFormInvalid>());
      expect(
        _plan(
          mode: InventoryAddMode.order,
          supplier: _supplier(),
          lines: const [],
        ).parse(),
        isA<InventoryFormInvalid>(),
      );
    });

    test('il motivo del carico e fisso e non si sceglie', () {
      final parsed = _plan().parse();
      expect(parsed, isA<InventoryFormValid<InventoryAddProductsCommand>>());
      final command =
          (parsed as InventoryFormValid<InventoryAddProductsCommand>).value;
      final requests = command.quickLoadPlan.parse();
      expect(requests, isA<InventoryFormValid<List<MgwsQuickLoadRequest>>>());
      final values =
          (requests as InventoryFormValid<List<MgwsQuickLoadRequest>>).value;
      expect(values.first.reason, kInventoryCaricoReason);
    });

    test('quantita non positiva non e valida', () {
      final parsed = _plan(lines: [_line(quantity: 0)]).parse();
      expect(parsed, isA<InventoryFormInvalid>());
    });

    test("l'etichetta fornitore e' il nome del fornitore", () {
      expect(_plan(supplier: _supplier()).supplierLabel, 'Fornitore Uno');
    });
  });

  group('Rettifica: lettura stock', () {
    test('estrae quantita e ubicazioni dalla risposta MGWS', () {
      final snapshot = InventoryStockSnapshot.fromRecord({
        'product_id': 7,
        'variation_id': 0,
        'product_name': '  Camicia  ',
        'current_stock': 12,
        'locations': [
          {
            'site_id': 1,
            'warehouse_id': 2,
            'qty': 8,
            'room': 'Retro',
            'rack': 'A1',
            'shelf': '3',
          },
          {'site_id': 1, 'warehouse_id': 2, 'qty': 4},
        ],
      });

      expect(snapshot, isNotNull);
      expect(snapshot!.productId, 7);
      expect(snapshot.currentStock, 12);
      expect(snapshot.label, 'Camicia');
      expect(snapshot.levels, hasLength(2));
      expect(
        snapshot.levels.first.locationLabel,
        'Stanza Retro · Scaffale A1 · Ripiano 3',
      );
      expect(snapshot.levels.last.locationLabel, 'Nessuna ubicazione');
    });

    test('risposta vuota non produce snapshot', () {
      expect(InventoryStockSnapshot.fromRecord(null), isNull);
      expect(InventoryStockSnapshot.fromRecord(const {}), isNull);
    });

    test('stock mancante vale zero invece di far fallire la lettura', () {
      final snapshot = InventoryStockSnapshot.fromRecord({'product_id': 3});
      expect(snapshot, isNotNull);
      expect(snapshot!.currentStock, 0);
      expect(snapshot.label, 'Prodotto #3');
    });
  });

  group('Rettifica: piano', () {
    InventoryStockSnapshot snapshot(int stock) => InventoryStockSnapshot(
      productId: 7,
      productName: 'Camicia',
      currentStock: stock,
      levels: const [],
    );

    // La sede e' dichiarata in ogni piano di questa gruppo: senza, `parse`
    // rifiuta il piano e i test che devono fallire per un altro motivo
    // passerebbero per quello sbagliato. Il numero e' arbitrario perche' nessuna
    // riga ha livelli: `stockAtSite` vale zero e la riga torna al totale del
    // prodotto, che e' il comportamento atteso finche' la sede non ha merce.
    InventoryRettificaPlan planWith(
      InventoryRettificaLine line, {
      String reason = 'Contea fisica',
      String documentNumberText = '',
      String siteIdText = '3',
    }) => InventoryRettificaPlan(
      lines: [line],
      details: reason,
      documentNumberText: documentNumberText,
      siteIdText: siteIdText,
    );

    InventoryRettificaLine increase(int stock, int delta) =>
        InventoryRettificaLine(
          productId: 7,
          label: 'Camicia',
          direction: InventoryRettificaDirection.increase,
          snapshot: snapshot(stock),
          delta: delta,
        );

    test('incremento: il target sale della delta', () {
      final line = increase(10, 3);
      expect(line.previousStock, 10);
      expect(line.targetStock, 13);
      expect(line.effectiveDelta, 3);
      expect(line.isIncrease, isTrue);
    });

    test('decremento: il target scende e resta non negativo', () {
      final line = InventoryRettificaLine(
        productId: 7,
        label: 'Camicia',
        direction: InventoryRettificaDirection.decrease,
        snapshot: snapshot(10),
        delta: 4,
      );
      expect(line.targetStock, 6);
      expect(line.effectiveDelta, -4);
      expect(line.isIncrease, isFalse);

      final floor = InventoryRettificaLine(
        productId: 7,
        label: 'Camicia',
        direction: InventoryRettificaDirection.decrease,
        snapshot: snapshot(2),
        delta: 9,
      );
      expect(floor.targetStock, 0);
    });

    test('il valore contato vince sulla delta', () {
      final line = InventoryRettificaLine(
        productId: 7,
        label: 'Camicia',
        direction: InventoryRettificaDirection.increase,
        snapshot: snapshot(10),
        delta: 3,
        correctStock: 5,
      );
      expect(line.targetStock, 5);
      expect(line.effectiveDelta, -5);
    });

    test('delta nulla non e valida quando lo stock e noto', () {
      expect(planWith(increase(10, 0)).parse(), isA<InventoryFormInvalid>());
    });

    test('senza stock caricato e senza valore contato non e valida', () {
      final plan = planWith(
        InventoryRettificaLine(
          productId: 7,
          label: 'Camicia',
          direction: InventoryRettificaDirection.increase,
          delta: 2,
        ),
      );
      expect(plan.parse(), isA<InventoryFormInvalid>());
    });

    test('dettaglio vuoto resta valido perche il dettaglio e facoltativo', () {
      final plan = planWith(increase(10, 2), reason: '   ');
      expect(plan.parse(), isA<InventoryFormValid<List<InventoryRettificaCommand>>>());
    });

    test('product id non valido non e valido', () {
      final plan = planWith(
        InventoryRettificaLine(
          productId: 0,
          label: 'Senza id',
          direction: InventoryRettificaDirection.increase,
          snapshot: snapshot(10),
          delta: 2,
        ),
      );
      expect(plan.parse(), isA<InventoryFormInvalid>());
    });

    test('nessun prodotto non e valido', () {
      final plan = InventoryRettificaPlan(lines: const [], details: 'Contea');
      expect(plan.parse(), isA<InventoryFormInvalid>());
      expect(plan.canSubmit, isFalse);
    });

    test(
      'i comandi portano il valore assoluto e la motivazione arricchita',
      () {
        final parsed = planWith(increase(10, 3)).parse();
        expect(
          parsed,
          isA<InventoryFormValid<List<InventoryRettificaCommand>>>(),
        );
        final commands =
            (parsed as InventoryFormValid<List<InventoryRettificaCommand>>)
                .value;
        expect(commands, hasLength(1));
        final command = commands.first;
        expect(command.productId, 7);
        expect(command.correctStock, 13);
        expect(command.reason, contains('10 -> 13'));
        expect(command.reason, contains('+3'));
        expect(command.reason, contains('Contea fisica'));
      },
    );

    test('ogni prodotto della lista riceve il suo comando', () {
      final plan = InventoryRettificaPlan(
        details: 'Contea fisica',
        siteIdText: '3',
        lines: [
          increase(10, 3),
          InventoryRettificaLine(
            productId: 9,
            label: 'Pantaloni',
            direction: InventoryRettificaDirection.decrease,
            snapshot: InventoryStockSnapshot(
              productId: 9,
              productName: 'Pantaloni',
              currentStock: 4,
              levels: const [],
            ),
            delta: 1,
          ),
        ],
      );
      expect(plan.canSubmit, isTrue);
      expect(plan.lineCount, 2);
      final parsed = plan.parse();
      expect(
        parsed,
        isA<InventoryFormValid<List<InventoryRettificaCommand>>>(),
      );
      final commands =
          (parsed as InventoryFormValid<List<InventoryRettificaCommand>>).value;
      expect(commands, hasLength(2));
      expect(commands[0].correctStock, 13);
      expect(commands[1].correctStock, 3);
      expect(commands[1].reason, contains('4 -> 3'));
    });

    test('una riga senza correzione blocca tutta la rettifica', () {
      final plan = InventoryRettificaPlan(
        details: 'Contea fisica',
        siteIdText: '3',
        lines: [
          increase(10, 3),
          InventoryRettificaLine(
            productId: 11,
            label: 'Scarpa',
            direction: InventoryRettificaDirection.increase,
            snapshot: snapshot(5),
            delta: 0,
          ),
        ],
      );
      expect(plan.canSubmit, isFalse);
      expect(plan.unchangedCount, 1);
      expect(plan.parse(), isA<InventoryFormInvalid>());
    });

    test('la motivazione registra anche il documento di riferimento', () {
      final plan = planWith(
        InventoryRettificaLine(
          productId: 7,
          label: 'Camicia',
          direction: InventoryRettificaDirection.decrease,
          snapshot: snapshot(10),
          delta: 2,
        ),
        reason: 'Danno',
        documentNumberText: 'INV-42',
      );
      final line = plan.lines.single;
      expect(plan.reasonTextFor(line), contains('diminuzione'));
      expect(plan.reasonTextFor(line), contains('10 -> 8'));
      expect(plan.reasonTextFor(line), contains('[INV-42]'));
    });
  });

  group('Lettura delle righe di libro', () {
    // Il punto e' il segno. MGWS scrive in `quantity_delta` la quantita' cosi'
    // come e' stata movimentata, che e' positiva, e lascia il verso implicito
    // nel `type` della riga. Senza la correzione lo spostamento si legge come
    // se avesse cambiato il totale e i pezzi spostati risultano il doppio: due
    // numeri sbagliati insieme, e il secondo finisce anche nella quantita' con
    // cui il pannello riporterebbe i pezzi indietro.
    Map<String, Object?> row({
      required int id,
      required String type,
      required int warehouseId,
      int stockAfter = 5,
    }) {
      return {
        'id': id,
        'movement_id': 77,
        'occurred_at_gmt': '2026-09-27 10:00:00',
        'type': type,
        'stock_effect': 'move',
        'product_id': 42,
        'variation_id': 0,
        'quantity_delta': 5,
        'stock_before': 10,
        'stock_after': stockAfter,
        'location': {
          'site_id': 1,
          'warehouse_id': warehouseId,
          'room': 'A',
          'rack': '1',
          'shelf': '1',
        },
        'warehouse_from': 3,
        'warehouse_to': 5,
        'operator_user_id': 1,
        'reason_code': 'move',
        'note': 'spostamento',
        'source': {'type': 'move', 'id': 0, 'line_id': 0, 'links': {}},
      };
    }

    test('il verso della riga lo decide il tipo, non il numero', () {
      final out = MgwsMovement.fromMap(
        row(id: 1, type: 'out', warehouseId: 3),
      )!;
      final into = MgwsMovement.fromMap(
        row(id: 2, type: 'in', warehouseId: 5, stockAfter: 15),
      )!;
      expect(out.quantityDelta, -5, reason: 'i pezzi escono da quel magazzino');
      expect(into.quantityDelta, 5, reason: 'i pezzi entrano in quel magazzino');
    });

    test('uno spostamento non cambia il totale e conta i pezzi una volta', () {
      final group = groupMovements([
        MgwsMovement.fromMap(row(id: 1, type: 'out', warehouseId: 3))!,
        MgwsMovement.fromMap(
          row(id: 2, type: 'in', warehouseId: 5, stockAfter: 15),
        )!,
      ]).single;
      expect(
        group.quantityDelta,
        0,
        reason: 'il totale del prodotto e\' rimasto quello di prima',
      );
      expect(group.movedQuantity, 5, reason: 'cinque pezzi sono passati, non dieci');
    });

    test('la rotta si ricava dalle righe, non dall ordine in cui arrivano', () {
      final group = groupMovements([
        MgwsMovement.fromMap(
          row(id: 1, type: 'in', warehouseId: 5, stockAfter: 15),
        )!,
        MgwsMovement.fromMap(row(id: 2, type: 'out', warehouseId: 3))!,
      ]).single;
      final product = group.products.single;
      expect(product.warehouseFrom, 3);
      expect(product.warehouseTo, 5);
      expect(product.siteFrom, 1);
      expect(
        product.hasRoute,
        isTrue,
        reason: 'senza rotta non si puo\' ne riaprire lo spostamento ne '
            'riportare i pezzi indietro',
      );
    });

    test('una riga di rettifica si annulla col contromovimento', () {
      final plain = {
        ...row(id: 1, type: 'adjust', warehouseId: 3),
        'stock_effect': 'adjust',
        'reason_code': 'reconcile',
        'warehouse_from': 0,
        'warehouse_to': 0,
        'source': {'type': 'reconcile', 'id': 0, 'line_id': 0, 'links': {}},
      };
      final group = groupMovements([MgwsMovement.fromMap(plain)!]).single;
      expect(group.isMove, isFalse);
      expect(group.quantityDelta, 5);
      expect(group.canRevert, isTrue, reason: 'il totale si riporta a 10');
    });
  });

  group('Fornitori: anagrafica', () {
    InventorySupplierForm form({String email = '', String name = 'Acme'}) =>
        InventorySupplierForm(nameText: name, emailText: email);

    test("l'email si lascia vuota: non e' un campo obbligatorio", () {
      final parsed = form().parseCreate();
      expect(parsed, isA<InventoryFormValid<MgwsSupplierInput>>());
      expect(
        (parsed as InventoryFormValid<MgwsSupplierInput>).value.email,
        isNull,
      );
    });

    test("un'email malformata si ferma qui invece che dal server", () {
      expect(
        form(email: 'not-an-email').parseCreate(),
        isA<InventoryFormInvalid>(),
      );
    });

    test('un indirizzo valido passa e viene ripulito dagli spazi', () {
      final parsed = form(email: '  ordini@acme.it  ').parseCreate();
      expect(parsed, isA<InventoryFormValid<MgwsSupplierInput>>());
      expect(
        (parsed as InventoryFormValid<MgwsSupplierInput>).value.email,
        'ordini@acme.it',
      );
    });

    test('il nome resta obbligatorio anche senza email', () {
      expect(form(name: '   ').parseCreate(), isA<InventoryFormInvalid>());
    });

    test("l'aggiornamento valida l'email con lo stesso criterio", () {
      expect(
        form(email: 'acme.it').parsePatch(),
        isA<InventoryFormInvalid>(),
      );
      expect(form(email: 'ordini@acme.it').parsePatch(), isA<InventoryFormValid<MgwsSupplierPatch>>());
    });
  });
}
