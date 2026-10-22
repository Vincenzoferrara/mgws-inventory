import 'dart:async';

import '../../products/class_products.dart';
import '../../l10n/generated/app_localizations.dart';
import '../class_formtter.dart';

/// Informazioni di pricing derivate per un prodotto (prezzo, sconto,
/// variabilità). Vivono nel layer datagrid perché sono i valori che le
/// griglie mostrano nelle colonne Prezzo/Sconto.
///
/// La cache non ha un BuildContext: conserva solo i valori formattati e i
/// flag di variabilità; il testo tradotto per i casi variabili si sceglie al
/// momento della visualizzazione, così segue la lingua corrente.
class ProdottoPricingInfo {
  final String _prezzo;
  final String _sconto;
  final String _percentualeSconto;
  final String _prezzoCompleto;
  final bool hasSconto;
  final bool prezzoVariabile;
  final bool scontoVariabile;
  final bool percentualeVariabile;

  const ProdottoPricingInfo({
    required String prezzo,
    required String sconto,
    required String percentualeSconto,
    required String prezzoCompleto,
    required this.hasSconto,
    required this.prezzoVariabile,
    required this.scontoVariabile,
    this.percentualeVariabile = false,
  }) : _prezzo = prezzo,
       _sconto = sconto,
       _percentualeSconto = percentualeSconto,
       _prezzoCompleto = prezzoCompleto;

  String prezzoLabel(AppLocalizations l10n) =>
      prezzoVariabile ? l10n.productsVariablePrices : _prezzo;

  String scontoLabel(AppLocalizations l10n) =>
      hasSconto && scontoVariabile ? l10n.productsVariablePrices : _sconto;

  String percentualeScontoLabel(AppLocalizations l10n) => percentualeVariabile
      ? l10n.productsVariablePercentage
      : _percentualeSconto;

  String prezzoCompletoLabel(AppLocalizations l10n) =>
      prezzoVariabile || (hasSconto && scontoVariabile)
      ? l10n.productsVariablePrices
      : _prezzoCompleto;
}

class DataGridViewCache {
  static List<ProdottoGlobal>? _products;
  static DateTime? _productsAt;
  static bool _productsDirty = true;

  static final Map<int, List<VarianteProductGlobal>> _variants =
      <int, List<VarianteProductGlobal>>{};
  static final Map<int, DateTime> _variantsAt = <int, DateTime>{};

  /// Cache pricing precomputata (productId → pricingInfo).
  static final Map<int, ProdottoPricingInfo> _pricingCache =
      <int, ProdottoPricingInfo>{};

  /// Notifica i subscriber che le varianti di un prodotto sono state
  /// aggiornate (es. prefetch completato). Le griglie iscritte devono
  /// riallineare lo snapshot paginato e ricomporsi.
  static final StreamController<int> _onVariantsUpdated =
      StreamController<int>.broadcast();
  static Stream<int> get onVariantsUpdated => _onVariantsUpdated.stream;

  static bool get hasProducts => _products != null && _products!.isNotEmpty;

  static bool hasFreshProducts([Duration? ttl]) {
    if (_productsDirty || _products == null || _productsAt == null) {
      return false;
    }
    if (ttl == null) return true;
    return DateTime.now().difference(_productsAt!) <= ttl;
  }

  static List<ProdottoGlobal>? readProducts() {
    final products = _products;
    if (products == null) return null;
    return List<ProdottoGlobal>.from(products);
  }

  static void writeProducts(List<ProdottoGlobal> products) {
    _products = List<ProdottoGlobal>.from(products);
    _productsAt = DateTime.now();
    _productsDirty = false;
    // Prodotti sostituiti: il pricing derivato potrebbe non essere più valido.
    _pricingCache.clear();
  }

  static void replaceProducts(List<ProdottoGlobal> products) {
    writeProducts(products);
  }

  static void appendProducts(List<ProdottoGlobal> products) {
    final current = _products ?? <ProdottoGlobal>[];
    _products = <ProdottoGlobal>[...current, ...products];
    _productsAt = DateTime.now();
    _productsDirty = false;
  }

  static void markProductsDirty() {
    _productsDirty = true;
  }

  static void clearProducts() {
    _products = null;
    _productsAt = null;
    _productsDirty = true;
    _pricingCache.clear();
  }

  static void clearVariants() {
    _variants.clear();
    _variantsAt.clear();
    _pricingCache.clear();
  }

  static void clearAll() {
    clearProducts();
    clearVariants();
  }

  static List<VarianteProductGlobal>? readVariants(
    int productId,
    Duration ttl,
  ) {
    final cachedAt = _variantsAt[productId];
    final cached = _variants[productId];
    if (cachedAt == null || cached == null) return null;
    if (DateTime.now().difference(cachedAt) > ttl) {
      removeVariants(productId);
      return null;
    }
    return List<VarianteProductGlobal>.from(cached);
  }

  /// Vero se esiste una voce in cache per [productId] ancora fresca (TTL),
  /// senza copiare la lista. Check economico per prefetch/loop.
  static bool hasVariants(int productId, Duration ttl) {
    final cachedAt = _variantsAt[productId];
    if (cachedAt == null || !_variants.containsKey(productId)) return false;
    if (DateTime.now().difference(cachedAt) > ttl) {
      removeVariants(productId);
      return false;
    }
    return true;
  }

  /// Limita la cache varianti ai soli prodotti in [keepByIds] (finestra
  /// visibile): rimuove tutte le altre voci, così la RAM resta proporzionata
  /// alla pagina corrente e non cresce con il numero di pagine visitate.
  /// Ritorna il numero di voci rimosse.
  static int pruneVariantsOutside(Set<int> keepByIds) {
    int rimossi = 0;
    for (final id in List<int>.from(_variants.keys)) {
      if (!keepByIds.contains(id)) {
        removeVariants(id);
        rimossi++;
      }
    }
    return rimossi;
  }

  /// Conteggio voci varianti in cache (per diagnostica memoria).
  static int variantsCacheSize() => _variants.length;

  /// Conteggio totale oggetti variante in cache (per diagnostica memoria).
  static int totalVariantsInCache() {
    int tot = 0;
    for (final list in _variants.values) {
      tot += list.length;
    }
    return tot;
  }

  static void writeVariants(
    int productId,
    List<VarianteProductGlobal> variants,
  ) {
    _variants[productId] = List<VarianteProductGlobal>.from(variants);
    _variantsAt[productId] = DateTime.now();
    // Le varianti sono la fonte autorevole dei prezzi per i prodotti variabili.
    // Se il pricing era già stato calcolato dal prodotto padre WooCommerce
    // (che su wc/v3 può esporre solo il prezzo attivo), va scartato prima di
    // ricalcolare le label della griglia.
    _pricingCache.remove(productId);
  }

  static void removeVariants(int productId) {
    _variants.remove(productId);
    _variantsAt.remove(productId);
    _pricingCache.remove(productId);
  }

  /// Aggiorna la cache varianti, aggancia le varianti a entrambe le liste
  /// prodotto (allProducts e filteredProducts) con i nuovi oggetti, ricalcola
  /// il pricing del prodotto toccato e notifica i subscriber.
  ///
  /// Sostituisce `_storeVariantsInCache` + `_replaceProductVariantsInLists`
  /// presenti nel controller prodotti: il merge dei dati aggiornati è
  /// responsabilità del layer griglia, non del business logic.
  ///
  /// Ritorna `true` se ha realmente sostituito almeno un'istanza.
  static bool replaceVariants(
    int productId,
    List<VarianteProductGlobal> variants,
    List<ProdottoGlobal> allProducts,
    List<ProdottoGlobal> filteredProducts,
  ) {
    writeVariants(productId, variants);

    bool replaced = false;
    for (int i = 0; i < allProducts.length; i++) {
      if (allProducts[i].id == productId) {
        allProducts[i] = allProducts[i].copyWith(varianti: variants);
        replaced = true;
      }
    }
    for (int i = 0; i < filteredProducts.length; i++) {
      if (filteredProducts[i].id == productId) {
        filteredProducts[i] = filteredProducts[i].copyWith(varianti: variants);
        replaced = true;
      }
    }

    if (replaced) {
      // Ricalcola il pricing dal prodotto aggiornato (che ora ha le varianti).
      ProdottoGlobal? aggiornato;
      for (final prodotto in allProducts) {
        if (prodotto.id == productId) {
          aggiornato = prodotto;
          break;
        }
      }
      if (aggiornato == null) {
        for (final prodotto in filteredProducts) {
          if (prodotto.id == productId) {
            aggiornato = prodotto;
            break;
          }
        }
      }
      if (aggiornato != null) {
        _pricingCache[productId] = getPricingInfo(aggiornato);
      }
      _onVariantsUpdated.add(productId);
    }
    return replaced;
  }

  /// Calcola informazioni di prezzo/sconto per un prodotto.
  ///
  /// Regole (priorità alle varianti quando presenti):
  /// - varianti caricate con tutte lo stesso prezzo → valore unico;
  /// - varianti con prezzi o sconti diversi → flag di variabilità;
  /// - varianti assenti → campi base del prodotto (prezzoNormale/prezzoScontato).
  static ProdottoPricingInfo getPricingInfo(ProdottoGlobal prodotto) {
    final productId = prodotto.id;
    if (productId != null && _pricingCache.containsKey(productId)) {
      return _pricingCache[productId]!;
    }

    final info = _computePricingInfo(prodotto);
    if (productId != null) {
      _pricingCache[productId] = info;
    }
    return info;
  }

  /// Varianti da usare per il pricing: prima quelle agganciate all'istanza
  /// prodotto (durante il prefetch), poi la cache condivisa.
  ///
  /// La cache condivisa è la fonte autorevole anche quando l'istanza prodotto
  /// è fresca, cioè priva di varianti agganciate: è il caso della riscrittura
  /// finale del caricamento (`caricaProdotti` ricrea le istanze da WooCommerce
  /// e il prefetch successivo salta i prodotti già in cache). Senza questo
  /// fallback la griglia tornerebbe a mostrare i prezzi del prodotto padre
  /// (es. €30/€30) invece di quelli reali delle varianti (€120/€30).
  static List<VarianteProductGlobal> _pricingVariants(ProdottoGlobal prodotto) {
    final prodotti = prodotto.varianti;
    if (prodotti != null && prodotti.isNotEmpty) return prodotti;
    final productId = prodotto.id;
    if (productId != null) {
      final cached = _variants[productId];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    return const <VarianteProductGlobal>[];
  }

  static ProdottoPricingInfo _computePricingInfo(ProdottoGlobal prodotto) {
    final varianti = _pricingVariants(prodotto);
    if (varianti.isEmpty) {
      final prezzoLabel = ClassFormtter.formatPrezzo(
        prodotto.prezzoNormale ?? 0,
      );
      final scontoLabel = prodotto.prezzoScontato != null
          ? ClassFormtter.formatPrezzo(prodotto.prezzoScontato!)
          : '-';
      final percentualeScontoLabel = prodotto.percentualeSconto == null
          ? '-'
          : '${prodotto.percentualeSconto!.toStringAsFixed(0)}%';
      return ProdottoPricingInfo(
        prezzo: prezzoLabel,
        sconto: scontoLabel,
        percentualeSconto: percentualeScontoLabel,
        prezzoCompleto: ClassFormtter.formatPrezzoConSconto(
          prodotto.prezzoNormale ?? 0,
          prodotto.prezzoScontato,
        ),
        hasSconto: prodotto.prezzoScontato != null,
        prezzoVariabile: false,
        scontoVariabile: false,
      );
    }

    final regularPrices = varianti.map((v) => v.prezzo).toSet();
    final saleValues = varianti.map((v) => v.prezzoScontato).toSet();

    final prezzoVariabile = regularPrices.length > 1;
    final scontoVariabile = saleValues.length > 1;
    final hasSconto = saleValues.any((value) => value != null);
    final percentualiSconto = varianti
        .where((variante) => variante.percentualeSconto != null)
        .map((variante) => variante.percentualeSconto!)
        .toSet();
    final percentualeVariabile = percentualiSconto.length > 1;
    final percentualeScontoLabel = percentualiSconto.isEmpty
        ? '-'
        : percentualeVariabile
        ? ''
        : '${percentualiSconto.first.toStringAsFixed(0)}%';

    // Nei casi variabili il valore resta vuoto: il testo tradotto lo sceglie
    // ProdottoPricingInfo in base ai flag.
    final prezzoLabel = prezzoVariabile
        ? ''
        : ClassFormtter.formatPrezzo(regularPrices.first);
    final scontoLabel = !hasSconto
        ? '-'
        : scontoVariabile
        ? ''
        : ClassFormtter.formatPrezzo(saleValues.first!);

    final prezzoCompletoLabel = hasSconto
        ? prezzoVariabile || scontoVariabile
              ? ''
              : ClassFormtter.formatPrezzoConSconto(
                  regularPrices.first,
                  saleValues.first,
                )
        : prezzoLabel;

    return ProdottoPricingInfo(
      prezzo: prezzoLabel,
      sconto: scontoLabel,
      percentualeSconto: percentualeScontoLabel,
      prezzoCompleto: prezzoCompletoLabel,
      hasSconto: hasSconto,
      prezzoVariabile: prezzoVariabile,
      scontoVariabile: scontoVariabile,
      percentualeVariabile: percentualeVariabile,
    );
  }
}
