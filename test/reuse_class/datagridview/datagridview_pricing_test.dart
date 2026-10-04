import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/prodotti/class_prodotti.dart';
import 'package:mgws_inventory/reuse_class/datagridview/datagridview_cache.dart';

void main() {
  tearDown(DataGridViewCache.clearAll);

  group('DataGridViewCache pricing', () {
    test('ricalcola il prezzo dalle varianti dopo il fallback del padre', () {
      final prodotti = <ProdottoGlobal>[
        ProdottoGlobal(
          id: 11658,
          nome: 'Brian Rush maglia polo',
          tipoProdotto: 'variable',
          prezzoNormale: 30,
          prezzoScontato: 30,
          variations: const [11659, 11660, 11661],
        ),
      ];
      final filtrati = List<ProdottoGlobal>.from(prodotti);

      final pricingPadre = DataGridViewCache.getPricingInfo(prodotti.single);
      expect(pricingPadre.prezzoLabel, '€30.00');
      expect(pricingPadre.scontoLabel, '€30.00');

      DataGridViewCache.replaceVariants(
        11658,
        [
          VarianteProductGlobal(id: 11659, prezzo: 120, prezzoScontato: 30),
          VarianteProductGlobal(id: 11660, prezzo: 120, prezzoScontato: 30),
          VarianteProductGlobal(id: 11661, prezzo: 120, prezzoScontato: 30),
        ],
        prodotti,
        filtrati,
      );

      final pricingVarianti = DataGridViewCache.getPricingInfo(prodotti.single);
      expect(pricingVarianti.prezzoLabel, '€120.00');
      expect(pricingVarianti.scontoLabel, '€30.00');
      expect(filtrati.single.varianti, hasLength(3));
    });

    test(
      'mostra Prezzi variabili quando gli sconti delle varianti differiscono',
      () {
        final prodotto = ProdottoGlobal(
          id: 1,
          nome: 'Prodotto variabile',
          varianti: [
            VarianteProductGlobal(id: 11, prezzo: 300, prezzoScontato: 20),
            VarianteProductGlobal(id: 12, prezzo: 300, prezzoScontato: 25),
          ],
        );

        final pricing = DataGridViewCache.getPricingInfo(prodotto);

        expect(pricing.prezzoLabel, '€300.00');
        expect(pricing.scontoLabel, 'Prezzi variabili');
        expect(pricing.prezzoCompletoLabel, 'Prezzi variabili');
      },
    );

    test(
      'usa la cache condivisa su istanza fresca senza varianti agganciate',
      () {
        // Simula il caso reale a fine caricamento: `caricaProdotti` ricrea le
        // istanze da WooCommerce (senza `varianti` agganciate) e il prefetch
        // successivo salta i prodotti già in cache. La cache condivisa deve
        // essere comunque la fonte autorevole del pricing.
        final prodottoFresco = ProdottoGlobal(
          id: 11658,
          nome: 'Brian Rush maglia polo',
          tipoProdotto: 'variable',
          prezzoNormale: 30,
          prezzoScontato: 30,
          variations: const [11659, 11660, 11661],
        );

        expect(prodottoFresco.varianti, isNull);

        DataGridViewCache.writeVariants(11658, [
          VarianteProductGlobal(id: 11659, prezzo: 120, prezzoScontato: 30),
          VarianteProductGlobal(id: 11660, prezzo: 120, prezzoScontato: 30),
          VarianteProductGlobal(id: 11661, prezzo: 120, prezzoScontato: 30),
        ]);

        final pricing = DataGridViewCache.getPricingInfo(prodottoFresco);

        expect(pricing.prezzoLabel, '€120.00');
        expect(pricing.scontoLabel, '€30.00');
        expect(pricing.prezzoCompletoLabel, '€30.00 (era €120.00)');
      },
    );

    test('cache condivisa vuota: istanza fresca ricade sui campi padre', () {
      final prodottoFresco = ProdottoGlobal(
        id: 11658,
        nome: 'Brian Rush maglia polo',
        tipoProdotto: 'variable',
        prezzoNormale: 30,
        prezzoScontato: 30,
        variations: const [11659, 11660, 11661],
      );

      final pricing = DataGridViewCache.getPricingInfo(prodottoFresco);

      expect(pricing.prezzoLabel, '€30.00');
      expect(pricing.scontoLabel, '€30.00');
    });
  });
}
