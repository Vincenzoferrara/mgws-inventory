import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/checkout/checkout.code.dart';
import 'package:mgws_inventory/checkout/checkout_failure.dart';
import 'package:mgws_inventory/checkout/checkout_history.code.dart';
import 'package:mgws_inventory/checkout/checkout_payload.dart';
import 'package:mgws_inventory/checkout/class_receipt.dart';
import 'package:mgws_inventory/products/class_products.dart';

ProdottoGlobal _prodotto({int stock = 6}) => ProdottoGlobal(
  id: 11761,
  nome: 'MGWS test P1',
  codiceProdotto: 'MGWS-T-1',
  prezzoNormale: 10,
  quantitaTotale: stock,
  inStock: stock > 0,
  status: 'publish',
);

void main() {
  group('righe annullate', () {
    test('removing a line queues it for the movement ledger', () {
      final cassa = CassaController();
      cassa.aggiungiElemento(ElementoCassa(_prodotto()), quantita: 2);
      cassa.rimuoviRiga(0);

      expect(cassa.scontrinoCorrente.righe, isEmpty);
      final voids = cassa.annullamentiInSospeso;
      expect(voids, hasLength(1));
      expect(voids.single['reason'], 'line_removed');
      final riga = (voids.single['lines'] as List).single as Map;
      expect(riga['product_id'], 11761);
      expect(riga['quantity'], 2);
      expect(riga['unit_price'], 10.0);
    });

    test('lowering the quantity records only the pieces taken out', () {
      final cassa = CassaController();
      cassa.aggiungiElemento(ElementoCassa(_prodotto()), quantita: 5);
      cassa.aggiornaQuantitaRiga(0, 2);
      cassa.decrementaQuantitaRiga(0);
      cassa.aggiornaQuantitaRiga(0, 3); // going up is not a void

      final quantita = [
        for (final v in cassa.annullamentiInSospeso)
          ((v['lines'] as List).single as Map)['quantity'],
      ];
      expect(quantita, [3, 1]);
      expect(
        cassa.annullamentiInSospeso.map((v) => v['reason']),
        everyElement('quantity_reduced'),
      );
    });

    test('emptying the cart records every line once', () {
      final cassa = CassaController();
      cassa.aggiungiElemento(ElementoCassa(_prodotto()), quantita: 1);
      cassa.svuotaCarrello();
      cassa.svuotaCarrello(); // already empty: nothing more

      expect(cassa.annullamentiInSospeso, hasLength(1));
      expect(cassa.annullamentiInSospeso.single['reason'], 'cart_cleared');
    });
  });

  test('the payload carries the cash handed over, not only the change', () {
    final scontrino = Scontrino(id: '1', data: DateTime(2026, 11, 7));
    scontrino.aggiungiRiga(
      RigaScontrino(prodotto: _prodotto(), quantita: 2, subtotale: 20),
    );
    scontrino.importoRicevuto = 50;
    final totals =
        buildMgwsCheckoutPayload(scontrino: scontrino)['totals'] as Map;
    expect(totals['importo_ricevuto'], 50);
    expect(totals['resto'], 30);
  });

  test('an out-of-stock item can be returned but not sold', () {
    final cassa = CassaController();
    final esaurito = ElementoCassa(_prodotto(stock: 0));
    expect(cassa.bloccaEsauritoScansionato(esaurito), isTrue);
    cassa.setTipoOperazione(TipoOperazioneCassa.reso);
    expect(cassa.bloccaEsauritoScansionato(esaurito), isFalse);
  });

  group('parseImportoCassa', () {
    test('Italian comma and dot', () {
      expect(parseImportoCassa('50,50'), 50.5);
      expect(parseImportoCassa('50.50'), 50.5);
      expect(parseImportoCassa('€ 1.234,50'), 1234.5);
      expect(parseImportoCassa(''), isNull);
      expect(parseImportoCassa('abc'), isNull);
    });
  });

  test('a shift opened on another day shows its date', () {
    final adesso = DateTime(2026, 11, 7, 21, 0);
    expect(formatAperturaTurno(DateTime(2026, 11, 7, 9, 5), adesso), '09:05');
    expect(
      formatAperturaTurno(DateTime(2026, 10, 5, 21, 22), adesso),
      '05/10/2026 21:22',
    );
  });

  test('shift close: expected cash and when a reason is needed', () {
    const totali = {'contanti': 130.0, 'carta': 0.0, 'rimborsi': 55.0};
    expect(contantiAttesiTurno(0, totali), 75);
    expect(
      serveCausaleChiusura(fondo: 0, totali: totali, contanti: 75, carta: 0),
      isFalse,
    );
    expect(
      serveCausaleChiusura(fondo: 0, totali: totali, contanti: 70, carta: 0),
      isTrue,
    );
  });

  test(
    'a shift already closed on the server is not refused afterwards',
    () async {
      // The server totals counted a cancelled return: counted and expected
      // differ, but the shift is closed and must get its closing record.
      final chiusura = ChiusuraCassa(
        id: 'chiusura-turno-1',
        giornataId: '2026-11-08|cassa',
        cassaNome: 'cassa',
        data: DateTime(2026, 11, 8),
        fondoIniziale: 0,
        incassiContanti: 130,
        rimborsi: 80,
        contanteContato: 75,
      );
      expect(chiusura.hasDifferenze, isTrue);
      final storico = StoricoCassaServer();
      final prima = await storico.registraChiusura(chiusura);
      expect(prima.errore?.code, CassaFailureCode.differenceReasonRequired);
      final dopo = await storico.registraChiusura(
        chiusura,
        verificaCausale: false,
      );
      expect(
        dopo.errore?.code,
        isNot(CassaFailureCode.differenceReasonRequired),
      );
    },
  );
}
