// Test di widget dei pannelli del modulo inventario.
//
// Il focus e' sul comportamento che porta a sbagliare il magazzino: il verso
// della rettifica e il conteggio inseriti contro convalidati. I pannelli
// ricevono controller gia' popolati, quindi nessun test prova a parlare con
// MGWS.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/inventory/inventory_add_products.code.dart';
import 'package:mgws_inventory/inventory/inventory_add_products.gui.dart';
import 'package:mgws_inventory/inventory/inventory_quick_load.code.dart';
import 'package:mgws_inventory/inventory/inventory_rettifica.code.dart';
import 'package:mgws_inventory/inventory/inventory_rettifica.gui.dart';
import 'package:mgws_inventory/inventory/inventory_suppliers.code.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/theme/theme.dart';
import 'package:mgws_inventory/traduzioni/estensioni.dart';

/// I pannelli leggono `AppColorExtension` dal tema: senza il tema reale
/// l'albero non si costruisce e il test fallisce su finder vuoti, non sul
/// comportamento che si vuole verificare.
Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    // I pannelli leggono le stringhe con `context.l10n`: senza i delegati le
    // traduzioni non ci sono nell'albero e il widget non si costruisce.
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Le asserzioni di questo file confrontano il testo italiano, quindi la
    // lingua va fissata: senza, l'app parte in inglese e i confronti falliscono.
    locale: const Locale('it'),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 900, child: child)),
    ),
  );
}

/// Il prodotto che il controller ha gia' caricato finisce in lista come riga
/// unica, quindi le chiavi dei suoi controlli portano la sua identita'.
const _prodotto = '7:0';

InventoryRettificaController _rettificaControllerWith(int stock) {
  final controller = InventoryRettificaController();
  controller.lastSnapshot = InventoryStockSnapshot(
    productId: 7,
    productName: 'Camicia',
    currentStock: stock,
    levels: const [
      InventoryStockLevel(
        siteId: 1,
        warehouseId: 2,
        qty: 10,
        locationLabel: 'Stanza Retro · Scaffale A1',
      ),
    ],
  );
  return controller;
}

/// Le due radio del verso della correzione.
///
/// Sono una scelta della sezione, non della riga: il verso risponde alla
/// domanda "quando scanno un barcode, aumento o diminuisco?", quindi sta una
/// volta sola accanto alla spunta e le sue chiavi non portano il prodotto.
Finder _radio(String verso) =>
    find.byKey(ValueKey('inventory-rettifica-direction-$verso'));

/// Il contatore di quanti pezzi la correzione muove.
Finder _contatore(String verso) =>
    find.byKey(ValueKey('inventory-rettifica-amount-$verso-$_prodotto'));

/// Il pannello e' piu' alto dello schermo di test, quindi ogni interazione
/// passa da [_vedi]: senza, il tasto puo' essere fuori viewport e il tap cade
/// nel vuoto senza toccare niente.
Future<void> _vedi(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Sede su cui viene corretto il totale.
///
/// Il campo sta sulla pagina, non dentro il pannello: i test lo simulano
/// passando un controller gia' valorizzato, come farebbe la pagina per un
/// operatore che ha scelto (o ha di riferimento) la sede 1.
TextEditingController _sedeController([String value = '1']) =>
    TextEditingController(text: value);

/// Toglie la spunta del modo rapido: senza, ogni riga chiede il conteggio
/// scritto a mano invece dei due tasti da un pezzo.
Future<void> _disattivaModoRapido(WidgetTester tester) async {
  final checkbox = find.byKey(
    const ValueKey('inventory-rettifica-auto-checkbox'),
  );
  await _vedi(tester, checkbox);
  await tester.tap(checkbox);
  await tester.pump();
}

/// Sceglie il verso [verso] con la sua radio.
Future<void> _scegliVerso(WidgetTester tester, String verso) async {
  await _vedi(tester, _radio(verso));
  await tester.tap(_radio(verso));
  await tester.pump();
}

/// Aggiunge [volte] pezzi alla correzione, senza cambiarne il verso.
Future<void> _aggiungiPezzi(WidgetTester tester, [int volte = 1]) async {
  for (var i = 0; i < volte; i++) {
    await _vedi(tester, _contatore('plus'));
    await tester.tap(_contatore('plus'));
    await tester.pump();
  }
}

void main() {
  group('Rettifica: verso della correzione', () {
    testWidgets('partendo da 10, scegliere diminuzione porta a 9', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(InventoryRettificaPanel(controller: _rettificaControllerWith(10))),
      );

      expect(
        find.byKey(ValueKey('inventory-rettifica-preview-$_prodotto')),
        findsOneWidget,
        reason: 'il prodotto scansionato deve avere la sua anteprima',
      );
      await _scegliVerso(tester, 'decrease');

      expect(
        find.text('10 -> 9 (delta -1)'),
        findsOneWidget,
        reason: 'la diminuzione deve togliere pezzi, non aggiungerne',
      );
    });

    testWidgets('tre pezzi aggiunti sommano fino a 13', (tester) async {
      await tester.pumpWidget(
        _app(InventoryRettificaPanel(controller: _rettificaControllerWith(10))),
      );

      await _aggiungiPezzi(tester, 3);

      expect(find.text('10 -> 13 (delta +3)'), findsOneWidget);
    });

    testWidgets('cambiare verso riparte da un pezzo', (tester) async {
      await tester.pumpWidget(
        _app(InventoryRettificaPanel(controller: _rettificaControllerWith(10))),
      );

      await _aggiungiPezzi(tester, 2);
      expect(find.text('10 -> 12 (delta +2)'), findsOneWidget);

      await _scegliVerso(tester, 'decrease');
      expect(
        find.text('10 -> 9 (delta -1)'),
        findsOneWidget,
        reason: 'il cambio di verso non deve sommare alla delta precedente',
      );
    });

    testWidgets('il verso si sceglie prima di scansionare, non dopo', (
      tester,
    ) async {
      // Le radio stanno in testa alla sezione proprio per questo: dentro la
      // riga comparivano solo dopo la scansione, cioe' quando la domanda
      // "aumento o diminuisco?" era gia' stata posta.
      await tester.pumpWidget(_app(const InventoryRettificaPanel()));

      expect(
        _radio('increase'),
        findsOneWidget,
        reason: 'il verso deve essere visibile anche a lista vuota',
      );
      expect(_radio('decrease'), findsOneWidget);
    });

    testWidgets('senza correzione il pulsante di invio resta disabilitato', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          InventoryRettificaPanel(
            controller: _rettificaControllerWith(10),
            siteController: _sedeController(),
          ),
        ),
      );
      final submit = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('inventory-rettifica-submit')),
      );
      expect(submit.onPressed, isNull);

      await _aggiungiPezzi(tester);

      final ready = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('inventory-rettifica-submit')),
      );
      expect(ready.onPressed, isNotNull);
    });

    testWidgets('senza dettaglio il pulsante di invio resta abilitato', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          InventoryRettificaPanel(
            controller: _rettificaControllerWith(10),
            siteController: _sedeController(),
          ),
        ),
      );
      await _aggiungiPezzi(tester);
      // Il dettaglio e' facoltativo e si scrive nel campo globale in alto, non
      // dentro il pannello: con sede e correzione basta, l'invio e' possibile.
      // La sede invece e' di pagina: il controller la porta gia' valorizzata.
      final submit = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('inventory-rettifica-submit')),
      );
      expect(
        submit.onPressed,
        isNotNull,
        reason: 'il dettaglio facoltativo non deve tenere spento l\'invio',
      );
    });

    testWidgets('il valore digitato vince sulla delta', (tester) async {
      await tester.pumpWidget(
        _app(InventoryRettificaPanel(controller: _rettificaControllerWith(10))),
      );
      await _disattivaModoRapido(tester);

      final counted = find.byKey(
        ValueKey('inventory-rettifica-counted-$_prodotto'),
      );
      await _vedi(tester, counted);
      await tester.enterText(counted, '4');
      await tester.pump();

      expect(find.text('10 -> 4 (delta -6)'), findsOneWidget);
    });

    testWidgets('senza stock caricato non si mostra il pannello correzione', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const InventoryRettificaPanel()));

      expect(
        find.byKey(ValueKey('inventory-rettifica-preview-$_prodotto')),
        findsNothing,
      );
      final submit = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('inventory-rettifica-submit')),
      );
      expect(submit.onPressed, isNull);
    });
  });

  group('Aggiungi prodotto: inseriti contro convalidati', () {
    InventoryAddProductsPlan plan({
      InventoryAddMode mode = InventoryAddMode.simple,
      bool validated = false,
    }) {
      return InventoryAddProductsPlan(
        mode: mode,
        supplier: null,
        validated: validated,
        siteIdText: '1',
        documentNumberText: 'AGG-1',
        lines: [
          const InventoryQuickLoadLineDraft(
            productId: 1,
            variationId: 0,
            label: 'Camicia',
            quantity: 2,
            idempotencyKey: 'a',
          ),
          const InventoryQuickLoadLineDraft(
            productId: 2,
            variationId: 0,
            label: 'Pantalone',
            quantity: 3,
            idempotencyKey: 'b',
          ),
        ],
      );
    }

    testWidgets('modalita semplice: 5 inseriti, nessuna convalida', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(InventoryAddProductsDeltaPanel(plan: plan())),
      );

      expect(find.text('Righe: 2'), findsOneWidget);
      expect(find.text('Inseriti: 5'), findsOneWidget);
      expect(find.text('Convalidati: 0'), findsOneWidget);
      expect(find.text('Differenza: 5'), findsOneWidget);
    });

    testWidgets('ordine convalidato: differenza zero', (tester) async {
      await tester.pumpWidget(
        _app(
          InventoryAddProductsDeltaPanel(
            plan: plan(mode: InventoryAddMode.order, validated: true),
          ),
        ),
      );

      expect(find.text('Convalidati: 5'), findsOneWidget);
      expect(find.text('Nessuna differenza'), findsOneWidget);
    });

    testWidgets('ordine in bozza: avvisa quanta merce resta da convalidare', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          InventoryAddProductsDeltaPanel(
            plan: plan(mode: InventoryAddMode.order),
          ),
        ),
      );

      expect(find.text('Differenza: 5'), findsOneWidget);
      expect(find.textContaining('5 risultano da convalidare'), findsOneWidget);
    });
  });

  group('Numero documento proposto', () {
    test('ha il formato AGG-AAAAMMGG-HHMMSS', () {
      final value = inventoryAddProductsDocumentNumber(
        DateTime(2026, 3, 7, 9, 5, 4),
      );
      expect(value, 'AGG-20260307-090504');
    });
  });

  group('Aggiungi prodotto in modalita ordine: scelta del fornitore', () {
    /// Il pannello parte sempre in modalita semplice, quindi l'ordine si
    /// ottiene scegliendolo dal menu come fa l'operatore: impostarlo da fuori
    /// verificherebbe uno stato che nessuno raggiunge.
    Future<void> _scegliOrdine(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('inventory-add-mode-simple')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          inventoryAddModeLabel(
            AppLocalizations.of(
              tester.element(find.byType(InventoryAddProductsPanel)),
            ),
            order,
          ),
        ).last,
      );
      await tester.pumpAndSettle();
    }

    Future<void> _pannelloInOrdine(
      WidgetTester tester,
      _SupplierGateway gateway,
    ) async {
      await tester.pumpWidget(
        _app(
          InventoryAddProductsPanel(
            controller: InventoryAddProductsController(),
            supplierController: InventorySupplierController(gateway: gateway),
          ),
        ),
      );
      await _scegliOrdine(tester);
    }

    testWidgets('con fornitori registrati il menu e scegliabile', (
      tester,
    ) async {
      await _pannelloInOrdine(
        tester,
        _SupplierGateway(suppliers: const [_fornitore]),
      );

      expect(find.text('Fornitore *'), findsOneWidget);
      expect(find.textContaining('nessun fornitore registrato'), findsNothing);
    });

    testWidgets("senza fornitori il vuoto e' vero e ha una via d'uscita", (
      tester,
    ) async {
      await _pannelloInOrdine(tester, _SupplierGateway());

      // Nessun menu: non c'e' nulla da scegliere, e il pulsante e' l'unica
      // via d'uscita senza abbandonare l'ordine.
      expect(find.text('Fornitore *'), findsNothing);
      expect(
        find.textContaining('nessun fornitore registrato'),
        findsOneWidget,
      );
      expect(find.text('Aggiungi fornitore'), findsOneWidget);
    });

    testWidgets('una lettura fallita offre di riprovare, non un form', (
      tester,
    ) async {
      await _pannelloInOrdine(
        tester,
        _SupplierGateway(failureMessage: 'MGWS non risponde'),
      );

      expect(find.textContaining('MGWS non risponde'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Aggiungi fornitore'), findsNothing);
    });

    testWidgets('il retry ripete la lettura invece di rifare il form', (
      tester,
    ) async {
      final gateway = _SupplierGateway(failureMessage: 'MGWS non risponde');
      await _pannelloInOrdine(tester, gateway);
      expect(gateway.listCalls, 1);

      await tester.tap(
        find.byKey(const ValueKey('inventory-add-supplier-empty-action')),
      );
      await tester.pumpAndSettle();
      expect(gateway.listCalls, 2);
    });

    testWidgets("la modalita semplice non chiede l'anagrafica fornitori", (
      tester,
    ) async {
      final gateway = _SupplierGateway();
      await tester.pumpWidget(
        _app(
          InventoryAddProductsPanel(
            controller: InventoryAddProductsController(),
            supplierController: InventorySupplierController(gateway: gateway),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La semplice non fa ordini: chiedere i fornitori sarebbe una chiamata
      // sprecata a ogni inserimento.
      expect(gateway.listCalls, 0);
    });
  });
}

/// Il fornitore che il controller ha gia' caricato finisce gia' nel menu.
const _fornitore = MgwsSupplier(
  id: 4,
  name: 'Acme Italia',
  taxId: '',
  email: '',
  phone: '',
  active: true,
  notes: '',
  paymentTermsDays: 0,
  iban: '',
  leadTimeDays: 0,
  createdAtGmt: '2026-01-01 00:00:00',
  updatedAtGmt: '2026-01-01 00:00:00',
);

const order = InventoryAddMode.order;

/// Gateway finto: risponde solo a `listSuppliers`.
///
/// Il resto dell'interfaccia non serve a questi test, e `noSuchMethod` lo
/// dichiara invece di scrivere trenta metodi che nessuno chiama.
class _SupplierGateway implements MgwsRestockGateway {
  _SupplierGateway({this.suppliers = const [], this.failureMessage});

  final List<MgwsSupplier> suppliers;
  final String? failureMessage;
  int listCalls = 0;

  @override
  Future<MgwsRestockResult<List<MgwsSupplier>>> listSuppliers() async {
    listCalls++;
    final failure = failureMessage;
    if (failure != null) {
      return MgwsRestockResult.failure(
        MgwsRestockError(code: 'mgws_unreachable', message: failure),
      );
    }
    return MgwsRestockResult.success(suppliers);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    "${invocation.memberName} non e' usato da questo test",
  );
}
