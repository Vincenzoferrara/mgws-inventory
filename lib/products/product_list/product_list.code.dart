// product_list.code.dart

import '../../l10n/error_text.dart';
import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../class_products.dart';
import '../../reuse_class/class_formtter.dart';
import '../product_filters.dart';
import '../../reuse_class/logic/global_pagination_controller.dart';
import '../../reuse_class/logic/memory_usage.dart';
import '../product_cache.dart';
import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../login/jwt_api/woo_connect.dart';
import '../../login/jwt_api/jwt_connect.dart';
import '../../log_viewer/app_logger.dart';
import '../../l10n/extensions.dart';
import '../../l10n/localized_text.dart';
import '../../inventory/inventory_movement_key.code.dart';
import '../../inventory/inventory_adjustment.code.dart';
import '../../login/mgws/connection/mgws_connection.dart';
import '../../login/mgws/query/query_mgws_inventory.dart';

// Re-export della cache prodotti: consumer della .code.dart accedono a
// ProdottiCache (pricing) e ProdottoPricingInfo senza import diretti.
export '../product_cache.dart' show ProdottiCache, ProdottoPricingInfo;

/// Definisce i tipi di ordinamento possibili per la lista dei prodotti.
enum OrdinamentoProdotti {
  nessuno, // Ordine predefinito
  nomeCrescente, // Dalla A alla Z
  nomeDecrescente, // Dalla Z alla A
  prezzoCrescente, // Dal più economico
  prezzoDecrescente, // Dal più costoso
}

enum ProductGridColumnId {
  preview,
  nome,
  sku,
  barcode,
  categoria,
  prezzo,
  sconto,
  disponibilita,
  quantita,
  varianti,
  stato,
  marca,
}

extension ProductGridColumnIdX on ProductGridColumnId {
  String get storageKey => name;
}

/// Etichetta tradotta di una colonna della griglia prodotti.
///
/// Fuori dall'estensione perche' la traduzione ha bisogno delle localizzazioni,
/// che l'enum non puo' raggiungere.
String productGridColumnLabel(
  AppLocalizations l10n,
  ProductGridColumnId colonna,
) => switch (colonna) {
  ProductGridColumnId.preview => l10n.prodottiColonnaAnteprima,
  ProductGridColumnId.nome => l10n.prodottiColonnaNome,
  ProductGridColumnId.sku => l10n.prodottiColonnaSkuV,
  ProductGridColumnId.barcode => l10n.prodottiColonnaBarcodeV,
  ProductGridColumnId.categoria => l10n.prodottiColonnaCategoria,
  ProductGridColumnId.prezzo => l10n.prodottiColonnaPrezzo,
  ProductGridColumnId.sconto => l10n.prodottiColonnaSconto,
  ProductGridColumnId.disponibilita => l10n.prodottiColonnaDisponibilitaV,
  ProductGridColumnId.quantita => l10n.prodottiColonnaQuantitaV,
  ProductGridColumnId.varianti => l10n.prodottiColonnaVarianti,
  ProductGridColumnId.stato => l10n.prodottiColonnaStatoV,
  ProductGridColumnId.marca => l10n.prodottiColonnaMarca,
};

const List<ProductGridColumnId> defaultProductGridColumns =
    <ProductGridColumnId>[
      ProductGridColumnId.preview,
      ProductGridColumnId.nome,
      ProductGridColumnId.sku,
      ProductGridColumnId.barcode,
      ProductGridColumnId.categoria,
      ProductGridColumnId.prezzo,
      ProductGridColumnId.sconto,
      ProductGridColumnId.disponibilita,
      ProductGridColumnId.quantita,
      ProductGridColumnId.varianti,
      ProductGridColumnId.stato,
    ];

const List<ProductGridColumnId> defaultMobileProductGridColumns =
    <ProductGridColumnId>[
      ProductGridColumnId.preview,
      ProductGridColumnId.nome,
      ProductGridColumnId.sku,
    ];

typedef ProductPageLoader =
    Future<List<ProdottoGlobal>> Function({
      int page,
      int perPage,
      bool includeAllStatus,
    });

typedef ProductVariationLoader =
    Future<List<VarianteProductGlobal>> Function(
      int productId, {
      String? includeStatus,
      List<AttributoVariante>? attributiProdotto,
    });

typedef ProductsByIdsLoader =
    Future<List<ProdottoGlobal>> Function(List<int> ids);

typedef ProductLoadProgress = void Function(List<ProdottoGlobal> products);

/// Classe per la gestione della logica dei prodotti
class ProdottiGestioneController {
  static List<FiltroProdotto> _sharedFiltriProdotto = <FiltroProdotto>[];
  static int _activeInstances = 0;

  List<ProdottoGlobal> _prodotti = [];
  List<ProdottoGlobal> _prodottiFiltrati = [];
  ProdottoGlobal? _prodottoSelezionato;
  final Set<int> _selectedProductIds = <int>{};
  VarianteProductGlobal? _varianteSelezionata;
  String _filtroRicerca = '';
  final List<FiltroProdotto> _filtriProdottoAttivi = <FiltroProdotto>[];
  OrdinamentoProdotti _ordinamentoCorrente = OrdinamentoProdotti.nessuno;

  final Map<String, String> _filtriVariantiAttivi = {};
  List<VarianteProductGlobal> _variantiFiltrate = [];
  LocalizedText? _lastLoadWarning;
  int _selectedProductLoadToken = 0;

  static const int _productsPerPage = 100;
  static const int _productsMaxPages = 100;
  static const Duration _variantsTtl = Duration(minutes: 30);

  /// Concorrenza del prefetch della finestra visibile (schermata prodotti).
  /// Più alta del legacy (4) perché la finestra è piccola e il riempimento
  /// delle colonne varianti deve arrivare in fretta, "come la web GUI WP".
  static const int prefetchWindowConcurrency = 8;
  final ProductPageLoader _productPageLoader;
  final ProductVariationLoader _variationLoader;
  final ProductsByIdsLoader _productsByIdsLoader;
  final bool _usesPlatformVariationLoader;

  ProdottiGestioneController({
    ProductPageLoader? productPageLoader,
    ProductVariationLoader? variationLoader,
    ProductsByIdsLoader? productsByIdsLoader,
  }) : _productPageLoader = productPageLoader ?? _loadProductPageFromPlatform,
       _variationLoader = variationLoader ?? _loadProductVariationsFromPlatform,
       _productsByIdsLoader =
           productsByIdsLoader ?? _loadProductsByIdsFromPlatform,
       _usesPlatformVariationLoader = variationLoader == null {
    _activeInstances++;
  }

  static Future<List<ProdottoGlobal>> _loadProductPageFromPlatform({
    int page = 1,
    int perPage = _productsPerPage,
    bool includeAllStatus = true,
  }) async {
    final result = await PlatformManager.prodotti.getProducts(
      page: page,
      perPage: perPage,
      includeAllStatus: includeAllStatus,
    );
    return List<ProdottoGlobal>.from(result as List);
  }

  static Future<List<ProdottoGlobal>> _loadProductsByIdsFromPlatform(
    List<int> ids,
  ) async {
    final result = await PlatformManager.prodotti.getProductsByIds(ids);
    return List<ProdottoGlobal>.from(result as List);
  }

  static Future<List<VarianteProductGlobal>> _loadProductVariationsFromPlatform(
    int productId, {
    String? includeStatus,
    List<AttributoVariante>? attributiProdotto,
  }) {
    return PlatformManager.varianti.getAllVariations(
      productId,
      includeStatus: includeStatus,
      attributiProdotto: attributiProdotto,
    );
  }

  Future<List<VarianteProductGlobal>> _loadSelectedProductVariations({
    required int productId,
    required List<AttributoVariante>? attributiProdotto,
  }) {
    if (!_usesPlatformVariationLoader) {
      return _variationLoader(productId, attributiProdotto: attributiProdotto);
    }
    return PlatformManager.varianti.getAllVariations(
      productId,
      attributiProdotto: attributiProdotto,
      logRawAttributeMapping: true,
      debugLogSource: 'PGEST',
    );
  }

  Future<void> _traceSelectedProductVariations({
    required int productId,
    required List<AttributoVariante>? attributiProdotto,
  }) async {
    if (!kDebugMode || !_usesPlatformVariationLoader) return;
    try {
      await PlatformManager.varianti.getAllVariations(
        productId,
        attributiProdotto: attributiProdotto,
        logRawAttributeMapping: true,
        debugLogSource: 'PGEST',
      );
    } catch (error) {
      log.w('PGEST_VARIANTS_TRACE_FAIL productId=$productId error=$error');
    }
  }

  void dispose() {
    _activeInstances--;
    if (_activeInstances <= 0) {
      _activeInstances = 0;
    }
  }

  bool _canUseSharedCache() {
    return ProdottiCache.hasFreshProducts();
  }

  void _publishSharedCache() {
    ProdottiCache.replaceProducts(_prodotti);
  }

  void _markSharedDirty() {
    ProdottiCache.markProductsDirty();
    ProdottiCache.clearProducts();
    ProdottiCache.clearVariants();
  }

  /// Se true, mostra solo le varianti con quantità > 0.
  bool _filtraSoloInStock = false;
  bool _nascondiProdottiEsauriti = false;

  // Getters
  List<ProdottoGlobal> get prodotti => _prodottiFiltrati;
  ProdottoGlobal? get prodottoSelezionato => _prodottoSelezionato;
  VarianteProductGlobal? get varianteSelezionata => _varianteSelezionata;
  String get filtroRicerca => _filtroRicerca;
  OrdinamentoProdotti get ordinamentoCorrente => _ordinamentoCorrente;
  List<VarianteProductGlobal> get variantiFiltrate => _variantiFiltrate;
  bool get hasFiltriVariantiAttivi => _filtriVariantiAttivi.isNotEmpty;
  Map<String, String> get filtriVariantiAttivi =>
      Map.unmodifiable(_filtriVariantiAttivi);
  LocalizedText? get lastLoadWarning => _lastLoadWarning;

  LocalizedText? consumeLastLoadWarning() {
    final w = _lastLoadWarning;
    _lastLoadWarning = null;
    return w;
  }

  bool get filtraSoloInStock => _filtraSoloInStock;
  bool get nascondiProdottiEsauriti => _nascondiProdottiEsauriti;

  int get numeroProdotti => _prodottiFiltrati.length;
  bool get hasProdottoSelezionato => _prodottoSelezionato != null;
  bool get hasVarianteSelezionata => _varianteSelezionata != null;
  bool get hasFiltroAttivo =>
      _filtroRicerca.isNotEmpty ||
      _filtriProdottoAttivi.isNotEmpty ||
      _nascondiProdottiEsauriti;
  List<FiltroProdotto> get filtriProdottoAttivi =>
      List.unmodifiable(_filtriProdottoAttivi);
  Set<int> get selectedProductIds => Set.unmodifiable(_selectedProductIds);
  List<ProdottoGlobal> get selectedProducts => _prodotti
      .where((p) => p.id != null && _selectedProductIds.contains(p.id))
      .toList();
  int get selectedProductsCount => _selectedProductIds.length;
  bool get hasSelectedProducts => _selectedProductIds.isNotEmpty;

  bool isProductSelectedForBulk(ProdottoGlobal prodotto) {
    final id = prodotto.id;
    return id != null && _selectedProductIds.contains(id);
  }

  void toggleProductBulkSelection(ProdottoGlobal prodotto) {
    final id = prodotto.id;
    if (id == null || id <= 0) return;
    if (_selectedProductIds.contains(id)) {
      _selectedProductIds.remove(id);
    } else {
      _selectedProductIds.add(id);
    }
  }

  void clearBulkSelection() {
    _selectedProductIds.clear();
  }

  void setBulkSelectionByIds(Iterable<int> productIds) {
    _selectedProductIds
      ..clear()
      ..addAll(productIds.where((id) => id > 0));
  }

  void selectOnlyProductForBulk(ProdottoGlobal prodotto) {
    final id = prodotto.id;
    if (id == null || id <= 0) return;
    _selectedProductIds
      ..clear()
      ..add(id);
  }

  void selectAllFilteredProducts() {
    for (final prodotto in _prodottiFiltrati) {
      final id = prodotto.id;
      if (id != null && id > 0) {
        _selectedProductIds.add(id);
      }
    }
  }

  void selezionaProdottoLocal(ProdottoGlobal prodotto) {
    final stopwatch = Stopwatch()..start();
    final productId = prodotto.id;
    log.d('[perf-trace] selezionaProdottoLocal START id=$productId');
    _prodottoSelezionato = prodotto;
    _varianteSelezionata = null;
    _filtraSoloInStock = false;
    cancellaFiltriVarianti();

    if (productId != null) {
      final cachedVariants = _cachedVariants(productId);
      log.d(
        '[perf-trace] selezionaProdottoLocal cache '
        '${cachedVariants == null ? 'MISS' : 'HIT'} id=$productId',
      );
      if (cachedVariants != null) {
        ProdottiCache.replaceVariants(
          productId,
          cachedVariants,
          _prodotti,
          _prodottiFiltrati,
        );
        _prodottoSelezionato = prodotto.copyWith(varianti: cachedVariants);
      }
    } else {
      log.d('[perf-trace] selezionaProdottoLocal cache MISS id=null');
    }

    final filterStopwatch = Stopwatch()..start();
    _applicaFiltriVarianti();
    log.d(
      '[perf-trace] _applicaFiltriVarianti dur=${filterStopwatch.elapsedMilliseconds}ms',
    );
    log.d(
      '[perf-trace] selezionaProdottoLocal DONE '
      'id=$productId dur=${stopwatch.elapsedMilliseconds}ms',
    );
  }

  Future<void> selezionaProdotto(ProdottoGlobal prodotto) async {
    selezionaProdottoLocal(prodotto);
  }

  Future<bool> caricaVariantiProdottoSelezionato({
    bool forceRefresh = false,
  }) async {
    final prodotto = _prodottoSelezionato;
    if (prodotto == null) return false;
    return _caricaVariantiProdotto(
      prodotto,
      forceRefresh: forceRefresh,
      onlyIfStillSelected: true,
    );
  }

  /// [products] with their variants: variable products whose variants are
  /// not cached yet are downloaded first. Used to print labels.
  Future<List<ProdottoGlobal>> productsWithVariants(
    List<ProdottoGlobal> products,
  ) async {
    final missing = products
        .where(
          (product) =>
              product.id != null &&
              product.isVariabile &&
              !product.hasVarianti &&
              _cachedVariants(product.id!) == null,
        )
        .toList();
    if (missing.isNotEmpty) {
      await prefetchVariantiVisibili(missing, maxProdotti: missing.length);
    }
    return [
      for (final product in products)
        if (!product.hasVarianti &&
            product.id != null &&
            (_cachedVariants(product.id!)?.isNotEmpty ?? false))
          product.copyWith(varianti: _cachedVariants(product.id!))
        else
          product,
    ];
  }

  List<VarianteProductGlobal>? _cachedVariants(int productId) {
    return ProdottiCache.readVariants(productId, _variantsTtl);
  }

  void _removeVariantsFromCache(int productId) {
    ProdottiCache.removeVariants(productId);
  }

  /// Rimette sulle righe le varianti gia presenti in cache: nessuna rete,
  /// nessun evento. Serve perche ogni pagina di prodotti in arrivo ricrea
  /// la lista dalle copie appena scaricate, che non hanno varianti: senza
  /// questo passaggio le varianti gia scaricate per le righe visibili si
  /// staccavano a ogni pagina, e il prefetch non le riscaricava perche in
  /// cache c'erano gia.
  void _riattaccaVariantiDaCache(List<ProdottoGlobal> lista) {
    for (int i = 0; i < lista.length; i++) {
      final prodotto = lista[i];
      final productId = prodotto.id;
      if (productId == null || productId <= 0 || !prodotto.isVariabile) {
        continue;
      }
      if (prodotto.varianti?.isNotEmpty ?? false) continue;
      if (!ProdottiCache.hasVariants(productId, _variantsTtl)) continue;
      final cached = _cachedVariants(productId);
      if (cached != null) lista[i] = prodotto.copyWith(varianti: cached);
    }
  }

  /// Toglie le varianti dalle righe fuori dalla pagina visibile, insieme
  /// alla pulizia della cache: cosi la RAM resta legata alla pagina corrente
  /// e, tornando su una pagina, le varianti vengono riscaricate fresche.
  void staccaVariantiFuori(Set<int> keepIds) {
    void stacca(List<ProdottoGlobal> lista) {
      for (int i = 0; i < lista.length; i++) {
        final prodotto = lista[i];
        final id = prodotto.id;
        if (id == null || keepIds.contains(id)) continue;
        if (prodotto.varianti?.isNotEmpty ?? false) {
          lista[i] = prodotto.copyWith(varianti: const []);
        }
      }
    }

    stacca(_prodotti);
    stacca(_prodottiFiltrati);
  }

  /// Riscarica dal server i prodotti della pagina visibile e ne invalida le
  /// varianti, cosi chi cambia pagina vede le modifiche fatte nel frattempo
  /// da altri. Il prodotto selezionato resta fuori: potrebbe essere in
  /// modifica. Un prodotto eliminato sul server resta in lista fino al
  /// prossimo aggiornamento completo.
  Future<bool> aggiornaProdottiVisibili(List<int> ids) async {
    final selezionato = _prodottoSelezionato?.id;
    final daAggiornare = ids
        .where((id) => id > 0 && id != selezionato)
        .toList();
    if (daAggiornare.isEmpty) return false;

    final List<ProdottoGlobal> freschi;
    try {
      freschi = await _productsByIdsLoader(daAggiornare);
    } catch (e) {
      log.w('Aggiornamento pagina prodotti non riuscito', e);
      return false;
    }

    final perId = <int, ProdottoGlobal>{
      for (final prodotto in freschi)
        if (prodotto.id != null) prodotto.id!: prodotto,
    };
    for (final id in perId.keys) {
      ProdottiCache.removeVariants(id);
    }
    void sostituisci(List<ProdottoGlobal> lista) {
      for (int i = 0; i < lista.length; i++) {
        final fresco = perId[lista[i].id];
        if (fresco != null) lista[i] = fresco;
      }
    }

    sostituisci(_prodotti);
    sostituisci(_prodottiFiltrati);
    _publishSharedCache();
    return true;
  }

  final Set<int> _prefetchVariantiInCorso = <int>{};

  /// Precarica in background le varianti dei prodotti indicati (tipicamente
  /// tutti i prodotti caricati, o il chunk appena arrivato) cosi che la cache
  /// sia calda e il click non mostri alcun ritardo. Best-effort: non tocca mai
  /// il prodotto selezionato, i filtri o i token di caricamento della selezione.
  /// Usa un pool di download concorrenti limitato, come il caricamento dei
  /// prodotti che avanza pagina per pagina; la griglia si aggiorna in tempo
  /// reale via ProdottiCache.onVariantsUpdated.
  Future<void> prefetchVariantiVisibili(
    List<ProdottoGlobal> prodotti, {
    int? maxProdotti,
    int concurrency = 4,
  }) async {
    final stopwatch = Stopwatch()..start();

    // GUARDIA PROATTIVA DI SESSIONE: se il token JWT è scaduto o mancante,
    // tenta un refresh UNA volta; se fallisce, ferma subito il prefetch con
    // un avviso esplicito invece di sparare ~100 richieste destinate al 401.
    // (Sintomo log: ogni GET .../variations risponde 401 "Expired token"
    // con header `Basic Og==` = credenziali vuote.)
    final connect = WooConnect();
    if (!connect.isAuthenticated) {
      log.i(
        '🛡️ [prefetchVarianti] Sessione JWT non autenticata: '
        'tentativo refresh proattivo...',
      );
      final refreshed = await JwtConnect().refreshToken();
      if (!refreshed || !WooConnect().isAuthenticated) {
        log.e(
          '❌ [prefetchVarianti] Sessione scaduta e refresh fallito: '
          'prefetch ANNULLATO. Effettuare nuovamente il login.',
        );
        _lastLoadWarning = (l10n) => l10n.productsWooSessionExpired;
        log.w(
          '[perf-trace] prefetchVarianti ANNULLATO per sessione scaduta '
          'dur=${stopwatch.elapsedMilliseconds}ms',
        );
        return;
      }
      log.i(
        '✅ [prefetchVarianti] Token refresh-ato a caldo, procedo col prefetch',
      );
    }

    final candidates = <ProdottoGlobal>[];
    int saltati = 0;
    log.d(
      '[perf-trace] prefetchVarianti START count=${prodotti.length} '
      'max=${maxProdotti ?? 'TUTTI'} concurrency=$concurrency',
    );
    log.d(
      '[perf-trace] prefetchVarianti diagnostica '
      'tipoVariable=${prodotti.where((p) => p.tipoProdotto == 'variable').length} '
      'conVariations=${prodotti.where((p) => p.variations?.isNotEmpty ?? false).length} '
      'sample=${prodotti.take(3).map((p) => '${p.id}:${p.tipoProdotto ?? '-'}:v${p.variations?.length ?? 0}').join(', ')}',
    );
    for (final prodotto in prodotti) {
      if (maxProdotti != null && candidates.length >= maxProdotti) break;
      final productId = prodotto.id;
      if (productId == null || productId <= 0) continue;
      if (!prodotto.isVariabile) continue;
      if (_prodottoSelezionato?.id == productId) continue;
      // Check economico su cache condivisa: `hasVariants` evita di copiare
      // la lista (List.from in readVariants) per ogni prodotto del loop.
      if (ProdottiCache.hasVariants(productId, _variantsTtl)) {
        saltati++;
        continue;
      }
      if (!_prefetchVariantiInCorso.add(productId)) continue;
      candidates.add(prodotto);
    }

    int scaricati = 0;
    int errori = 0;
    final totali = candidates.length;
    var index = 0;

    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= totali) return;
        final prodotto = candidates[i];
        final productId = prodotto.id!;
        try {
          final varianti = await _variationLoader(
            productId,
            attributiProdotto: prodotto.attributi,
          );
          ProdottiCache.replaceVariants(
            productId,
            varianti,
            _prodotti,
            _prodottiFiltrati,
          );
          scaricati++;
          if (scaricati % 100 == 0) {
            log.d(
              '[perf-trace] prefetchVarianti progress '
              'scaricati=$scaricati di $totali '
              'dur=${stopwatch.elapsedMilliseconds}ms',
            );
          }
        } catch (e) {
          errori++;
          log.w('[perf-trace] prefetchVarianti errore id=$productId: $e');
        } finally {
          _prefetchVariantiInCorso.remove(productId);
        }
      }
    }

    final workers = List.generate(
      totali < concurrency ? totali : concurrency,
      (_) => worker(),
    );
    await Future.wait(workers);

    log.d(
      '[perf-trace] prefetchVarianti DONE '
      'scaricati=$scaricati di $totali saltati=$saltati errori=$errori '
      'cacheProdotti=${ProdottiCache.variantsCacheSize()} '
      'cacheVarianti=${ProdottiCache.totalVariantsInCache()} '
      'rssMb=${residentMemoryMb()} '
      'dur=${stopwatch.elapsedMilliseconds}ms',
    );
  }

  /// Carica le varianti di un prodotto da WooCommerce
  Future<bool> _caricaVariantiProdotto(
    ProdottoGlobal prodotto, {
    bool forceRefresh = false,
    bool onlyIfStillSelected = false,
  }) async {
    final productId = prodotto.id;
    if (productId == null || productId <= 0) {
      _applicaFiltriVarianti();
      return false;
    }

    if (!forceRefresh) {
      final cachedVariants = _cachedVariants(productId);
      if (cachedVariants != null) {
        log.d(
          '[perf-trace] _caricaVariantiProdotto cache HIT '
          'id=$productId count=${cachedVariants.length}',
        );
        log.d(
          '[prodotti-grid] variants cache hit productId=$productId count=${cachedVariants.length}',
        );
        unawaited(
          _traceSelectedProductVariations(
            productId: productId,
            attributiProdotto: prodotto.attributi,
          ),
        );
        if (!onlyIfStillSelected || _prodottoSelezionato?.id == productId) {
          ProdottiCache.replaceVariants(
            productId,
            cachedVariants,
            _prodotti,
            _prodottiFiltrati,
          );
          _prodottoSelezionato = prodotto.copyWith(varianti: cachedVariants);
          _applicaFiltriVarianti();
        }
        return false;
      }
    }

    log.d(
      '[perf-trace] _caricaVariantiProdotto cache MISS '
      'id=$productId forceRefresh=$forceRefresh',
    );

    final loadToken = ++_selectedProductLoadToken;
    log.d(
      '[prodotti-grid] variants fetch start productId=$productId token=$loadToken onlyIfStillSelected=$onlyIfStillSelected',
    );
    try {
      log.i(
        '🔍 Caricamento varianti per prodotto: ${prodotto.nome} (ID: $productId)',
      );

      log.i(
        '📋 Verifica varianti per prodotto $productId (variations=${prodotto.variations})',
      );

      final variationStopwatch = Stopwatch()..start();
      final variantiComplete = await _loadSelectedProductVariations(
        productId: productId,
        attributiProdotto: prodotto.attributi,
      );
      log.d(
        '[perf-trace] _variationLoader dur=${variationStopwatch.elapsedMilliseconds}ms '
        'id=$productId count=${variantiComplete.length}',
      );
      log.i('✅ Caricate ${variantiComplete.length} varianti complete');

      ProdottiCache.replaceVariants(
        productId,
        variantiComplete,
        _prodotti,
        _prodottiFiltrati,
      );

      if (onlyIfStillSelected &&
          (_prodottoSelezionato?.id != productId ||
              loadToken != _selectedProductLoadToken)) {
        log.d(
          '[prodotti-grid] variants fetch stale productId=$productId token=$loadToken currentSelected=${_prodottoSelezionato?.id} currentToken=$_selectedProductLoadToken',
        );
        return false;
      }

      _prodottoSelezionato = prodotto.copyWith(varianti: variantiComplete);
      _applicaFiltriVarianti();

      log.i('📊 Varianti filtrate: ${_variantiFiltrate.length}');
      for (final variante in _variantiFiltrate) {
        log.i(
          '   - ${variante.nome}: ${variante.quantita} pezzi, €${variante.prezzo}',
        );
      }
      log.d(
        '[prodotti-grid] variants fetch applied productId=$productId token=$loadToken filtered=${_variantiFiltrate.length}',
      );
      return true;
    } catch (e) {
      log.e('❌ Errore caricamento varianti per prodotto $productId', e);
      if (onlyIfStillSelected &&
          (_prodottoSelezionato?.id != productId ||
              loadToken != _selectedProductLoadToken)) {
        return false;
      }
      _applicaFiltriVarianti();
      return false;
    }
  }

  void selezionaVariante(VarianteProductGlobal? variante) {
    _varianteSelezionata = variante;
  }

  bool isProdottoSelezionato(ProdottoGlobal prodotto) {
    return _prodottoSelezionato?.id == prodotto.id;
  }

  bool isVarianteSelezionata(VarianteProductGlobal variante) {
    return _varianteSelezionata?.id == variante.id;
  }

  String getCurrentImageUrl() {
    if (_varianteSelezionata?.immagineUrl != null &&
        _varianteSelezionata!.immagineUrl!.isNotEmpty) {
      return _varianteSelezionata!.immagineUrl!;
    }
    return _prodottoSelezionato?.immagineUrl ?? '';
  }

  /// Svuota la cache varianti condivisa: ogni filtro applicato dall'utente
  /// (ricerca rapida, avanzato, ordinamento, nascondi esauriti) parte da una
  /// cache fresca che il prefetch finestrato ricarica solo per la pagina
  /// visibile. Da NON chiamare in `_applicaFiltroEOrdinamento` (chiamata
  /// anche dal caricamento a chunk) né nel debounce cache del widget.
  void _resetVariantCache() {
    ProdottiCache.clearVariants();
  }

  void setFiltroRicerca(String filtro) {
    _resetVariantCache();
    _filtroRicerca = filtro.toLowerCase();
    _applicaFiltroEOrdinamento();
  }

  void addFiltroProdotto({
    required CampoFiltroProdotto campo,
    required OperatoreFiltroProdotto operatore,
    required String valoreInput,
  }) {
    final valori = valoreInput
        .split(RegExp(r'[,;]'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (valori.isEmpty) return;

    _resetVariantCache();
    _filtriProdottoAttivi.add(
      FiltroProdotto(campo: campo, operatore: operatore, valori: valori),
    );
    _sharedFiltriProdotto = List<FiltroProdotto>.from(_filtriProdottoAttivi);
    _applicaFiltroEOrdinamento();
    _logAppliedFilters(trigger: 'add');
  }

  void removeFiltroProdottoAt(int index) {
    if (index < 0 || index >= _filtriProdottoAttivi.length) return;
    _resetVariantCache();
    _filtriProdottoAttivi.removeAt(index);
    _sharedFiltriProdotto = List<FiltroProdotto>.from(_filtriProdottoAttivi);
    _applicaFiltroEOrdinamento();
    _logAppliedFilters(trigger: 'remove');
  }

  void clearFiltriProdotto() {
    _resetVariantCache();
    _filtriProdottoAttivi.clear();
    _sharedFiltriProdotto = <FiltroProdotto>[];
    _applicaFiltroEOrdinamento();
    _logAppliedFilters(trigger: 'clear');
  }

  void setPersistedAdvancedFiltersEnabled(bool enabled) {
    _resetVariantCache();
    if (enabled) {
      _filtriProdottoAttivi
        ..clear()
        ..addAll(_sharedFiltriProdotto);
    } else {
      _filtriProdottoAttivi.clear();
    }
    _applicaFiltroEOrdinamento();
  }

  List<String> getFilterValueSuggestions(
    CampoFiltroProdotto campo,
    String query, {
    int limit = 60,
  }) {
    return ProdottoFilterEngine.getFilterValueSuggestions(
      _prodotti,
      campo,
      query,
      limit: limit,
    );
  }

  void _logAppliedFilters({required String trigger}) {
    final expr = _filtriProdottoAttivi.isEmpty
        ? '(none)'
        : _filtriProdottoAttivi
              .map(
                (f) =>
                    // nel log vanno gli slug dei campi: le etichette cambiano con la
                    // lingua e renderebbero i log non confrontabili.
                    '${f.campo.name}${_opSymbol(f.operatore)}${f.valori.join('|')}',
              )
              .join(' AND ');
    log.d(
      '[filters] applied trigger=$trigger expr="$expr" matched=${_prodottiFiltrati.length}/${_prodotti.length}',
    );
  }

  String _opSymbol(OperatoreFiltroProdotto op) {
    switch (op) {
      case OperatoreFiltroProdotto.contiene:
        return '~';
      case OperatoreFiltroProdotto.nonContiene:
        return '!~';
      case OperatoreFiltroProdotto.contieneSensibile:
        return '~!';
      case OperatoreFiltroProdotto.nonContieneSensibile:
        return '!~!';
      case OperatoreFiltroProdotto.ugualeEsatto:
        return '==';
      case OperatoreFiltroProdotto.diversoEsatto:
        return '!==';
      case OperatoreFiltroProdotto.iniziaCon:
        return '^';
      case OperatoreFiltroProdotto.finisceCon:
        return r'$';
      case OperatoreFiltroProdotto.inElenco:
        return 'IN';
      case OperatoreFiltroProdotto.nonInElenco:
        return 'NOT IN';
      case OperatoreFiltroProdotto.uguale:
        return '=';
      case OperatoreFiltroProdotto.diverso:
        return '!=';
      case OperatoreFiltroProdotto.maggioreUguale:
        return '>=';
      case OperatoreFiltroProdotto.maggiore:
        return '>';
      case OperatoreFiltroProdotto.minoreUguale:
        return '<=';
      case OperatoreFiltroProdotto.minore:
        return '<';
      case OperatoreFiltroProdotto.tra:
        return 'BETWEEN';
    }
  }

  void cancellaFiltro() {
    _resetVariantCache();
    _filtroRicerca = '';
    _applicaFiltroEOrdinamento();
  }

  void setOrdinamento(OrdinamentoProdotti nuovoOrdinamento) {
    _resetVariantCache();
    _ordinamentoCorrente = nuovoOrdinamento;
    _applicaFiltroEOrdinamento();
  }

  Map<String, List<AttributoVariante>> getOpzioniFiltroDisponibili() {
    if (_prodottoSelezionato == null) return {};

    final opzioniUniche = <String, Map<String, AttributoVariante>>{};

    for (final variante in _prodottoSelezionato!.varianti ?? []) {
      for (final attributo in variante.attributi) {
        opzioniUniche[attributo.nome] ??= {};
        opzioniUniche[attributo.nome]![attributo.opzione] = attributo;
      }
    }

    final risultato = <String, List<AttributoVariante>>{};
    opzioniUniche.forEach((nomeAttributo, mappaOpzioni) {
      risultato[nomeAttributo] = mappaOpzioni.values.toList();
    });

    return risultato;
  }

  void setFiltroVariante(String nomeAttributo, String opzione) {
    if (_filtriVariantiAttivi[nomeAttributo] == opzione) {
      _filtriVariantiAttivi.remove(nomeAttributo);
    } else {
      _filtriVariantiAttivi[nomeAttributo] = opzione;
    }
    _applicaFiltriVarianti();
  }

  void cancellaFiltriVarianti() {
    _filtriVariantiAttivi.clear();
    _applicaFiltriVarianti();
  }

  bool isFiltroVarianteSelezionato(String nomeAttributo, String opzione) {
    return _filtriVariantiAttivi[nomeAttributo] == opzione;
  }

  /// Aggiorna lo stato del filtro di disponibilità e riapplica tutti i filtri.
  void setFiltraSoloInStock(bool mostraSoloDisponibili) {
    _filtraSoloInStock = mostraSoloDisponibili;
    _applicaFiltriVarianti();
  }

  void setNascondiProdottiEsauriti(bool value) {
    if (_nascondiProdottiEsauriti == value) return;
    _resetVariantCache();
    _nascondiProdottiEsauriti = value;
    _applicaFiltroEOrdinamento();
  }

  /// Filtra la lista delle varianti in base a TUTTI i filtri attivi (attributi + disponibilità).
  void _applicaFiltriVarianti() {
    if (_prodottoSelezionato == null) {
      _variantiFiltrate = [];
      return;
    }

    var variantiTemp = List<VarianteProductGlobal>.from(
      _prodottoSelezionato!.varianti ?? [],
    );
    log.i('🔍 Prodotto: ${_prodottoSelezionato!.nome}');
    log.i('📊 Varianti originali: ${variantiTemp.length}');
    log.i(
      '📦 Quantità varianti: ${variantiTemp.map((v) => '${v.nome}: ${v.quantita}').join(', ')}',
    );

    // 1. Applica i filtri per attributo (Colore, Taglia, etc.)
    if (_filtriVariantiAttivi.isNotEmpty) {
      _filtriVariantiAttivi.forEach((nomeFiltro, opzioneFiltro) {
        variantiTemp = variantiTemp.where((variante) {
          return variante.attributi.any(
            (attr) => attr.nome == nomeFiltro && attr.opzione == opzioneFiltro,
          );
        }).toList();
      });
    }

    if (_filtraSoloInStock) {
      variantiTemp = variantiTemp.where((v) => v.quantita > 0).toList();
    }

    _variantiFiltrate = variantiTemp;
    log.i('✅ Varianti finali mostrate: ${_variantiFiltrate.length}');

    if (_varianteSelezionata != null &&
        !_variantiFiltrate.contains(_varianteSelezionata)) {
      _varianteSelezionata = null;
    }
  }

  /// Applica il filtro di ricerca e l'ordinamento alla lista dei prodotti
  void _applicaFiltroEOrdinamento() {
    // 1. Applica il filtro
    _prodottiFiltrati = _prodotti.where((prodotto) {
      if (_nascondiProdottiEsauriti && !prodotto.inStock) return false;
      return _matchesLegacyTextFilter(prodotto) &&
          _matchesAdvancedFilters(prodotto);
    }).toList();

    // 2. Applica l'ordinamento
    switch (_ordinamentoCorrente) {
      case OrdinamentoProdotti.nomeCrescente:
        _prodottiFiltrati.sort(
          (a, b) => (a.nome?.toLowerCase() ?? '').compareTo(
            b.nome?.toLowerCase() ?? '',
          ),
        );
        break;
      case OrdinamentoProdotti.nomeDecrescente:
        _prodottiFiltrati.sort(
          (a, b) => (b.nome?.toLowerCase() ?? '').compareTo(
            a.nome?.toLowerCase() ?? '',
          ),
        );
        break;
      case OrdinamentoProdotti.prezzoCrescente:
        _prodottiFiltrati.sort(
          (a, b) => (a.prezzoScontato ?? a.prezzoNormale ?? 0).compareTo(
            b.prezzoScontato ?? b.prezzoNormale ?? 0,
          ),
        );
        break;
      case OrdinamentoProdotti.prezzoDecrescente:
        _prodottiFiltrati.sort(
          (a, b) => (b.prezzoScontato ?? b.prezzoNormale ?? 0).compareTo(
            a.prezzoScontato ?? a.prezzoNormale ?? 0,
          ),
        );
        break;
      case OrdinamentoProdotti.nessuno:
        break;
    }

    if (_prodottoSelezionato != null &&
        !_prodottiFiltrati.any((p) => p.id == _prodottoSelezionato!.id)) {
      _prodottoSelezionato = null;
      _varianteSelezionata = null;
    }
  }

  bool _matchesLegacyTextFilter(ProdottoGlobal prodotto) {
    return ProdottoFilterEngine.matchesQuickSearch(prodotto, _filtroRicerca);
  }

  bool _matchesAdvancedFilters(ProdottoGlobal prodotto) {
    return ProdottoFilterEngine.matchesFilters(prodotto, _filtriProdottoAttivi);
  }

  /// Prefetch delle varianti limitato alla finestra richiesta: se
  /// `prefetchLimit` è impostato carica al più quel numero di prodotti
  /// (valore del dropdown "Righe per pagina"); altrimenti mantiene il
  /// comportamento legacy su tutta la lista (cassa/inventory).
  Future<void> _prefetchWithLimit(
    List<ProdottoGlobal> source,
    int? prefetchLimit,
  ) {
    if (prefetchLimit != null && prefetchLimit > 0) {
      return prefetchVariantiVisibili(
        source.take(prefetchLimit).toList(),
        concurrency: prefetchWindowConcurrency,
      );
    }
    return prefetchVariantiVisibili(source);
  }

  /// Carica i prodotti usando PlatformManager (modello globale)
  Future<void> caricaProdotti({
    bool forceRefresh = false,
    ProductLoadProgress? onProgress,
    int? prefetchLimit,
  }) async {
    final previousLocal =
        ProdottiCache.readProducts() ??
        List<ProdottoGlobal>.from(_prodotti);
    try {
      _lastLoadWarning = null;

      if (!forceRefresh && _canUseSharedCache()) {
        _prodotti = ProdottiCache.readProducts() ?? <ProdottoGlobal>[];
        _riattaccaVariantiDaCache(_prodotti);
        _applicaFiltroEOrdinamento();
        onProgress?.call(List<ProdottoGlobal>.unmodifiable(_prodottiFiltrati));
        unawaited(_prefetchWithLimit(_prodottiFiltrati, prefetchLimit));
        return;
      }

      if (forceRefresh) {
        ProdottiCache.clearProducts();
        ProdottiCache.clearVariants();
      }

      log.i('📦 Caricamento prodotti da WooCommerce...');
      final loaded = <ProdottoGlobal>[];
      bool partial = false;

      for (int page = 1; page <= _productsMaxPages; page++) {
        try {
          final chunk = await _productPageLoader(
            page: page,
            perPage: _productsPerPage,
            includeAllStatus: true,
          );
          if (chunk.isEmpty) break;
          loaded.addAll(chunk);
          _riattaccaVariantiDaCache(loaded);
          _prodotti = List<ProdottoGlobal>.from(loaded);
          _applicaFiltroEOrdinamento();
          onProgress?.call(
            List<ProdottoGlobal>.unmodifiable(_prodottiFiltrati),
          );
          if (prefetchLimit == null) {
            unawaited(prefetchVariantiVisibili(chunk));
          }
          if (chunk.length < _productsPerPage) break;
        } catch (e) {
          partial = loaded.isNotEmpty;
          log.w('⚠️ Errore caricamento prodotti pagina $page', e);
          break;
        }
      }

      if (loaded.isNotEmpty) {
        _riattaccaVariantiDaCache(loaded);
        _prodotti = List<ProdottoGlobal>.from(loaded);
        log.i('✅ Caricati ${_prodotti.length} prodotti da WooCommerce');
        if (partial) {
          _lastLoadWarning = (l10n) => l10n.productsLoadPartial;
        }
        _publishSharedCache();
      } else if (previousLocal.isNotEmpty) {
        _prodotti = previousLocal;
        _lastLoadWarning = (l10n) => l10n.productsServerUnreachableUsingLocal;
        _publishSharedCache();
      } else {
        _prodotti = <ProdottoGlobal>[];
        _lastLoadWarning = (l10n) => l10n.productsServerUnreachableNone;
      }

      if (_prodotti.isEmpty) {
        _lastLoadWarning ??= (l10n) => l10n.productsNoneOnServer;
      }

      _applicaFiltroEOrdinamento();
      unawaited(_prefetchWithLimit(_prodottiFiltrati, prefetchLimit));
    } catch (e) {
      log.e('❌ Errore generale caricamento prodotti', e);
      log.e('   Dettagli errore: ${e.toString()}');
      if (previousLocal.isNotEmpty) {
        _prodotti = previousLocal;
        _lastLoadWarning = (l10n) => l10n.productsLoadErrorUsingCache;
        _publishSharedCache();
      } else {
        _prodotti = <ProdottoGlobal>[];
        _lastLoadWarning = (l10n) => l10n.productsLoadError;
      }
      _applicaFiltroEOrdinamento();
    }
  }

  Future<PaginatedResult<ProdottoGlobal>> caricaProdottiPaginati({
    required int page,
    required int perPage,
    bool append = false,
  }) async {
    try {
      _lastLoadWarning = null;
      final hasLocalProducts =
          _prodotti.isNotEmpty || ProdottiCache.hasProducts;
      if (!hasLocalProducts) {
        await caricaProdotti();
      }
      _applicaFiltroEOrdinamento();

      final total = _prodottiFiltrati.length;
      final totalPages = total == 0 ? 1 : (total / perPage).ceil();
      final safePage = page < 1
          ? 1
          : page > totalPages
          ? totalPages
          : page;
      final start = total == 0 ? 0 : (safePage - 1) * perPage;
      final end = total == 0 ? 0 : (start + perPage).clamp(0, total);
      final items = total == 0
          ? <ProdottoGlobal>[]
          : _prodottiFiltrati.sublist(start, end);

      return PaginatedResult<ProdottoGlobal>(
        items: List<ProdottoGlobal>.from(items),
        page: safePage,
        perPage: perPage,
        totalItems: total,
        totalPages: totalPages,
        hasMore: safePage < totalPages,
      );
    } catch (e) {
      log.e('❌ Errore caricamento prodotti paginato', e);
      if (_prodotti.isNotEmpty) {
        _lastLoadWarning = (l10n) => l10n.productsServerUnreachableUsingLocal;
        _applicaFiltroEOrdinamento();
        final total = _prodottiFiltrati.length;
        final totalPages = total == 0 ? 1 : (total / perPage).ceil();
        final safePage = page < 1
            ? 1
            : page > totalPages
            ? totalPages
            : page;
        final start = total == 0 ? 0 : (safePage - 1) * perPage;
        final end = total == 0 ? 0 : (start + perPage).clamp(0, total);
        return PaginatedResult<ProdottoGlobal>(
          items: List<ProdottoGlobal>.from(
            total == 0
                ? <ProdottoGlobal>[]
                : _prodottiFiltrati.sublist(start, end),
          ),
          page: safePage,
          perPage: perPage,
          totalItems: total,
          totalPages: totalPages,
          hasMore: safePage < totalPages,
        );
      }
      rethrow;
    }
  }

  Future<bool> eliminaProdotto(int prodottoId) async {
    try {
      log.i('🗑️ Eliminazione prodotto $prodottoId...');

      final deleted = await PlatformManager.prodotti.deleteProduct(
        prodottoId,
        force: true,
      );
      if (!deleted) {
        log.w('⚠️ Eliminazione non confermata per prodotto $prodottoId');
        return false;
      }

      _prodotti.removeWhere((p) => p.id == prodottoId);
      _prodottiFiltrati.removeWhere((p) => p.id == prodottoId);
      _selectedProductIds.remove(prodottoId);
      _removeVariantsFromCache(prodottoId);

      if (_prodottoSelezionato?.id == prodottoId) {
        _prodottoSelezionato = null;
        _varianteSelezionata = null;
        _variantiFiltrate = [];
        _filtriVariantiAttivi.clear();
        _filtraSoloInStock = false;
      }

      _applicaFiltroEOrdinamento();
      _markSharedDirty();
      log.i('✅ Prodotto $prodottoId eliminato e lista aggiornata');
      return true;
    } catch (e) {
      log.e('❌ Errore eliminazione prodotto $prodottoId', e);
      return false;
    }
  }

  /// Rettifica lo stock di un prodotto semplice
  Future<bool> rettificaStockProdotto({
    required int prodottoId,
    required int nuovaQuantita,
    String? motivo,
  }) async {
    try {
      log.i(
        '📦 Rettifica stock prodotto $prodottoId: $nuovaQuantita (motivo: $motivo)',
      );

      await PlatformManager.prodotti.updateProductStock(
        prodottoId,
        stockQuantity: nuovaQuantita,
        stockStatus: nuovaQuantita > 0 ? 'instock' : 'outofstock',
      );

      // Aggiorna il prodotto locale
      final index = _prodotti.indexWhere((p) => p.id == prodottoId);
      if (index >= 0) {
        _prodotti[index] = _prodotti[index].copyWith(
          quantitaTotale: nuovaQuantita,
          inStock: nuovaQuantita > 0,
        );
        _applicaFiltroEOrdinamento();

        // Aggiorna anche il prodotto selezionato se è lo stesso
        if (_prodottoSelezionato?.id == prodottoId) {
          _prodottoSelezionato = _prodotti[index];
        }
        _markSharedDirty();
      }

      log.i('✅ Stock prodotto $prodottoId aggiornato a $nuovaQuantita');
      return true;
    } catch (e) {
      log.e('❌ Errore rettifica stock prodotto $prodottoId', e);
      return false;
    }
  }

  /// Rettifica lo stock di una variante
  Future<bool> rettificaStockVariante({
    required int prodottoId,
    required int varianteId,
    required int nuovaQuantita,
    String? motivo,
  }) async {
    try {
      log.i(
        '📦 Rettifica stock variante $varianteId (prodotto $prodottoId): $nuovaQuantita (motivo: $motivo)',
      );

      await PlatformManager.varianti.updateVariationStock(
        productId: prodottoId,
        variationId: varianteId,
        stockQuantity: nuovaQuantita,
        stockStatus: nuovaQuantita > 0 ? 'instock' : 'outofstock',
      );

      // Aggiorna la variante locale
      final prodottoIndex = _prodotti.indexWhere((p) => p.id == prodottoId);
      if (prodottoIndex >= 0) {
        final varianti = _prodotti[prodottoIndex].varianti;
        if (varianti != null) {
          final varianteIndex = varianti.indexWhere((v) => v.id == varianteId);
          if (varianteIndex >= 0) {
            final varianteAggiornata = varianti[varianteIndex].copyWith(
              quantita: nuovaQuantita,
              attiva: nuovaQuantita > 0,
            );
            varianti[varianteIndex] = varianteAggiornata;

            // Aggiorna la variante selezionata se è la stessa
            if (_varianteSelezionata?.id == varianteId) {
              _varianteSelezionata = varianteAggiornata;
            }
            ProdottiCache.replaceVariants(
              prodottoId,
              varianti,
              _prodotti,
              _prodottiFiltrati,
            );
          }
        }

        // Aggiorna anche il prodotto selezionato
        if (_prodottoSelezionato?.id == prodottoId) {
          _prodottoSelezionato = _prodotti[prodottoIndex];
          _applicaFiltriVarianti();
        }
        _markSharedDirty();
      }

      log.i('✅ Stock variante $varianteId aggiornato a $nuovaQuantita');
      return true;
    } catch (e) {
      log.e('❌ Errore rettifica stock variante $varianteId', e);
      return false;
    }
  }

  Future<BulkCategoryUpdateResult> bulkUpdateSelectedProductCategories({
    required List<CategoriaProdotto> categorie,
    bool replaceExisting = false,
  }) async {
    if (_selectedProductIds.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: (l10n) => l10n.productsNoProductSelected,
      );
    }

    final selectedProducts = _prodotti.where(
      (p) => p.id != null && _selectedProductIds.contains(p.id),
    );

    final categoryMap = <int, CategoriaProdotto>{
      for (final c in categorie)
        if (c.id > 0) c.id: c,
    };

    if (categoryMap.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) => l10n.productsNoValidCategorySelected,
      );
    }

    try {
      final updates = <Map<String, dynamic>>[];

      for (final prodotto in selectedProducts) {
        final productId = prodotto.id;
        if (productId == null || productId <= 0) continue;

        final merged = <int, CategoriaProdotto>{
          if (!replaceExisting)
            for (final c in (prodotto.categoria ?? const <CategoriaProdotto>[]))
              if (c.id > 0) c.id: c,
          ...categoryMap,
        };

        updates.add({
          'id': productId,
          'categories': merged.keys.map((id) => {'id': id}).toList(),
        });
      }

      if (updates.isEmpty) {
        return BulkCategoryUpdateResult(
          successCount: 0,
          failedCount: _selectedProductIds.length,
          message: (l10n) => l10n.productsNoUpdatableProduct,
        );
      }

      const chunkSize = 25;
      final successfulProductIds = <int>{};
      final failedProductIds = <int>{};

      for (int i = 0; i < updates.length; i += chunkSize) {
        final chunk = updates.sublist(
          i,
          i + chunkSize > updates.length ? updates.length : i + chunkSize,
        );

        try {
          final response = await PlatformManager.prodotti.batchUpdateProducts(
            update: chunk,
          );

          final expectedIds = chunk
              .map((item) => item['id'])
              .whereType<int>()
              .toSet();

          final updated = response['update'];
          if (updated is List) {
            final updatedIds = updated
                .map((item) => item is Map<String, dynamic> ? item['id'] : null)
                .whereType<int>()
                .toSet();

            successfulProductIds.addAll(updatedIds);

            final missingIds = expectedIds.difference(updatedIds);
            failedProductIds.addAll(missingIds);

            final errors = response['errors'];
            if (errors is List) {
              for (final errorItem in errors) {
                if (errorItem is Map<String, dynamic>) {
                  final errorId = errorItem['id'];
                  if (errorId is int) {
                    failedProductIds.add(errorId);
                  }
                }
              }
            }
          } else {
            successfulProductIds.addAll(expectedIds);
          }
        } catch (e) {
          log.e('❌ Errore chunk batch categorie', e);
          for (final item in chunk) {
            final id = item['id'];
            if (id is int) {
              failedProductIds.add(id);
            }
          }
        }
      }

      final successCount = successfulProductIds.length;
      final failedCount = failedProductIds.length;

      final newCategories = categoryMap.values.toList();
      for (int i = 0; i < _prodotti.length; i++) {
        final id = _prodotti[i].id;
        if (id != null && successfulProductIds.contains(id)) {
          final current = _prodotti[i].categoria ?? const <CategoriaProdotto>[];
          final merged = <int, CategoriaProdotto>{
            if (!replaceExisting)
              for (final c in current)
                if (c.id > 0) c.id: c,
            for (final c in newCategories)
              if (c.id > 0) c.id: c,
          };
          _prodotti[i] = _prodotti[i].copyWith(
            categoria: merged.values.toList(),
          );
        }
      }

      if (_prodottoSelezionato?.id != null &&
          successfulProductIds.contains(_prodottoSelezionato!.id)) {
        final updatedProduct = _prodotti.firstWhere(
          (p) => p.id == _prodottoSelezionato!.id,
          orElse: () => _prodottoSelezionato!,
        );
        _prodottoSelezionato = updatedProduct;
      }

      _applicaFiltroEOrdinamento();
      _markSharedDirty();

      return BulkCategoryUpdateResult(
        successCount: successCount,
        failedCount: failedCount,
        message: failedCount == 0
            ? (l10n) => l10n.productsBulkUpdateDone(successCount)
            : (l10n) =>
                  l10n.productsBulkUpdatePartial(successCount, failedCount),
      );
    } catch (e) {
      log.e('❌ Errore bulk update categorie', e);
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) =>
            l10n.productsCategoryUpdateError(localizedErrorText(l10n, e)),
      );
    }
  }

  Future<BulkCategoryUpdateResult> updateSelectedProductCategoriesByNames({
    required List<String> categoryNames,
    bool replaceExisting = false,
  }) async {
    final prodotto = _prodottoSelezionato;
    if (prodotto == null || prodotto.id == null || prodotto.id! <= 0) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 1,
        message: (l10n) => l10n.productsNoValidProductSelected,
      );
    }

    final normalized =
        categoryNames
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (normalized.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 1,
        message: (l10n) => l10n.productsNoCategorySelected,
      );
    }

    try {
      final existing = await PlatformManager.categorie.getCategories(
        perPage: 100,
      );
      final byName = <String, CategoriaProdotto>{
        for (final c in existing) c.nome.toLowerCase(): c,
      };

      final missing = normalized
          .where((name) => !byName.containsKey(name.toLowerCase()))
          .toList();

      if (missing.isNotEmpty) {
        final created = await PlatformManager.categorie
            .createCategoryIfNotExists(
              missing
                  .map(
                    (name) => CategoriaProdotto(
                      nome: name,
                      slug: name.toLowerCase().replaceAll(' ', '-'),
                    ),
                  )
                  .toList(),
            );

        for (final c in created) {
          byName[c.nome.toLowerCase()] = c;
        }
      }

      final selectedCategories = normalized
          .map((name) => byName[name.toLowerCase()])
          .whereType<CategoriaProdotto>()
          .where((c) => c.id > 0)
          .toList();

      _selectedProductIds
        ..clear()
        ..add(prodotto.id!);

      return await bulkUpdateSelectedProductCategories(
        categorie: selectedCategories,
        replaceExisting: replaceExisting,
      );
    } catch (e) {
      log.e('❌ Errore aggiornamento categorie da nomi', e);
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 1,
        message: (l10n) =>
            l10n.productsCategoryUpdateError(localizedErrorText(l10n, e)),
      );
    }
  }

  Future<List<CategoriaProdotto>> resolveCategoryNames({
    required List<String> categoryNames,
  }) async {
    final normalized =
        categoryNames
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (normalized.isEmpty) {
      return const <CategoriaProdotto>[];
    }

    final existing = await PlatformManager.categorie.getCategories(
      perPage: 100,
    );
    final byName = <String, CategoriaProdotto>{
      for (final c in existing) c.nome.toLowerCase(): c,
    };

    final missing = normalized
        .where((name) => !byName.containsKey(name.toLowerCase()))
        .toList();

    if (missing.isNotEmpty) {
      final created = await PlatformManager.categorie.createCategoryIfNotExists(
        missing
            .map(
              (name) => CategoriaProdotto(
                nome: name,
                slug: name.toLowerCase().replaceAll(' ', '-'),
              ),
            )
            .toList(),
      );
      for (final c in created) {
        byName[c.nome.toLowerCase()] = c;
      }
    }

    return normalized
        .map((name) => byName[name.toLowerCase()])
        .whereType<CategoriaProdotto>()
        .where((c) => c.id > 0)
        .toList();
  }

  Future<List<TagProdotto>> resolveTagNames({
    required List<String> tagNames,
  }) async {
    final normalized =
        tagNames
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (normalized.isEmpty) {
      return const <TagProdotto>[];
    }

    final existing = await PlatformManager.tag.getTags(perPage: 100);
    final byName = <String, TagProdotto>{
      for (final t in existing) t.nome.toLowerCase(): t,
    };

    final missing = normalized
        .where((name) => !byName.containsKey(name.toLowerCase()))
        .toList();

    if (missing.isNotEmpty) {
      final created = await PlatformManager.tag.createTagIfNotExists(
        missing
            .map(
              (name) => TagProdotto(
                nome: name,
                slug: name.toLowerCase().replaceAll(' ', '-'),
              ),
            )
            .toList(),
      );
      for (final t in created) {
        byName[t.nome.toLowerCase()] = t;
      }
    }

    return normalized
        .map((name) => byName[name.toLowerCase()])
        .whereType<TagProdotto>()
        .where((t) => t.id > 0)
        .toList();
  }

  Future<BulkCategoryUpdateResult> bulkUpdateSelectedProductTags({
    required List<TagProdotto> tags,
    bool replaceExisting = false,
  }) async {
    if (_selectedProductIds.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: (l10n) => l10n.productsNoProductSelected,
      );
    }

    final tagMap = <int, TagProdotto>{
      for (final t in tags)
        if (t.id > 0) t.id: t,
    };
    if (tagMap.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) => l10n.productsNoValidTagSelected,
      );
    }

    final selectedProducts = _prodotti.where(
      (p) => p.id != null && _selectedProductIds.contains(p.id),
    );
    final updates = <Map<String, dynamic>>[];
    for (final prodotto in selectedProducts) {
      final productId = prodotto.id;
      if (productId == null || productId <= 0) continue;
      final merged = <int, TagProdotto>{
        if (!replaceExisting)
          for (final t in (prodotto.tag ?? const <TagProdotto>[]))
            if (t.id > 0) t.id: t,
        ...tagMap,
      };
      updates.add({
        'id': productId,
        'tags': merged.keys.map((id) => {'id': id}).toList(),
      });
    }

    try {
      final response = await PlatformManager.prodotti.batchUpdateProducts(
        update: updates,
      );
      final updated = response['update'];
      final updatedIds = <int>{};
      if (updated is List) {
        for (final item in updated) {
          if (item is Map<String, dynamic> && item['id'] is int) {
            updatedIds.add(item['id'] as int);
          }
        }
      }

      for (int i = 0; i < _prodotti.length; i++) {
        final id = _prodotti[i].id;
        if (id != null && updatedIds.contains(id)) {
          final current = _prodotti[i].tag ?? const <TagProdotto>[];
          final merged = <int, TagProdotto>{
            if (!replaceExisting)
              for (final t in current)
                if (t.id > 0) t.id: t,
            for (final t in tagMap.values)
              if (t.id > 0) t.id: t,
          };
          _prodotti[i] = _prodotti[i].copyWith(tag: merged.values.toList());
        }
      }
      _applicaFiltroEOrdinamento();
      _markSharedDirty();
      return BulkCategoryUpdateResult(
        successCount: updatedIds.length,
        failedCount: _selectedProductIds.length - updatedIds.length,
        message: (l10n) => l10n.productsTagsUpdated(updatedIds.length),
      );
    } catch (e) {
      log.e('❌ Errore bulk tag update', e);
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) =>
            l10n.productsTagUpdateError(localizedErrorText(l10n, e)),
      );
    }
  }

  Future<BulkCategoryUpdateResult> bulkUpdateSelectedProductsStatus({
    required String status,
  }) async {
    if (_selectedProductIds.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: (l10n) => l10n.productsNoProductSelected,
      );
    }

    final normalized = status.trim().toLowerCase();
    const allowed = {'publish', 'private', 'draft', 'pending'};
    if (!allowed.contains(normalized)) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) => l10n.productsInvalidStatus(status),
      );
    }

    final updates = _selectedProductIds
        .map((id) => {'id': id, 'status': normalized})
        .toList();
    try {
      final response = await PlatformManager.prodotti.batchUpdateProducts(
        update: updates,
      );
      final updated = response['update'];
      final updatedIds = <int>{};
      if (updated is List) {
        for (final item in updated) {
          if (item is Map<String, dynamic> && item['id'] is int) {
            updatedIds.add(item['id'] as int);
          }
        }
      }

      for (int i = 0; i < _prodotti.length; i++) {
        final id = _prodotti[i].id;
        if (id != null && updatedIds.contains(id)) {
          _prodotti[i] = _prodotti[i].copyWith(status: normalized);
        }
      }

      if (_prodottoSelezionato?.id != null &&
          updatedIds.contains(_prodottoSelezionato!.id)) {
        _prodottoSelezionato = _prodotti.firstWhere(
          (p) => p.id == _prodottoSelezionato!.id,
          orElse: () => _prodottoSelezionato!,
        );
      }

      _applicaFiltroEOrdinamento();
      _markSharedDirty();

      return BulkCategoryUpdateResult(
        successCount: updatedIds.length,
        failedCount: _selectedProductIds.length - updatedIds.length,
        message: (l10n) => l10n.productsStatusUpdated(updatedIds.length),
      );
    } catch (e) {
      log.e('❌ Errore bulk status update', e);
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: _selectedProductIds.length,
        message: (l10n) =>
            l10n.productsStatusUpdateError(localizedErrorText(l10n, e)),
      );
    }
  }

  Future<BulkCategoryUpdateResult> deleteSelectedProducts({
    required bool force,
  }) async {
    if (_selectedProductIds.isEmpty) {
      return BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: (l10n) => l10n.productsNoProductSelected,
      );
    }

    int success = 0;
    int failed = 0;
    final ids = _selectedProductIds.toList();
    for (final id in ids) {
      try {
        final deleted = await PlatformManager.prodotti.deleteProduct(
          id,
          force: force,
        );
        if (deleted) {
          success++;
          _prodotti.removeWhere((p) => p.id == id);
          _prodottiFiltrati.removeWhere((p) => p.id == id);
          _removeVariantsFromCache(id);
        } else {
          failed++;
        }
      } catch (e) {
        failed++;
        log.e('❌ Errore delete prodotto $id', e);
      }
    }

    _selectedProductIds.clear();
    if (_prodottoSelezionato?.id != null &&
        !_prodotti.any((p) => p.id == _prodottoSelezionato!.id)) {
      _prodottoSelezionato = null;
      _varianteSelezionata = null;
      _variantiFiltrate = [];
    }
    _applicaFiltroEOrdinamento();
    _markSharedDirty();

    return BulkCategoryUpdateResult(
      successCount: success,
      failedCount: failed,
      message: force
          ? (l10n) => l10n.productsPermanentDeleteResult(success, failed)
          : (l10n) => l10n.productsTrashResult(success, failed),
    );
  }

  /// Deletes [variants] of the product [productId].
  ///
  /// Each variant is first brought to 0 on MGWS, on every site that holds
  /// pieces, with a stock movement explained by [stockReason]; all the
  /// variants of one deletion share one movement. Only then the variant is
  /// deleted from WooCommerce, for good (`force: true`, variations have no
  /// trash). When MGWS is unavailable or refuses the movement, the variant is
  /// not deleted: a variant left in place is better than stock with no
  /// product. The product and the other variants stay; the cache and the shown
  /// product lose the deleted ones.
  Future<VariantDeleteResult> deleteVariants({
    required int productId,
    required List<VarianteProductGlobal> variants,
    required String stockReason,
    MgwsInventoryGateway? inventory,
  }) async {
    final deletedIds = <int>{};
    var failed = 0;
    var stockNotZeroed = 0;
    if (!await MgwsConnection.instance.ensureConnected()) {
      return VariantDeleteResult(
        deleted: 0,
        failed: variants.length,
        stockNotZeroed: variants.length,
      );
    }
    final gateway = inventory ?? QueryMgwsInventory();
    final movementKey = newInventoryMovementKey();
    for (final variant in variants) {
      final zeroed = await _zeroVariantStock(
        gateway: gateway,
        productId: productId,
        variationId: variant.id,
        reason: stockReason,
        movementKey: movementKey,
      );
      if (!zeroed) {
        failed++;
        stockNotZeroed++;
        continue;
      }
      try {
        final deleted = await PlatformManager.varianti.deleteVariation(
          productId: productId,
          variationId: variant.id,
          force: true,
        );
        if (deleted == true) {
          deletedIds.add(variant.id);
        } else {
          failed++;
        }
      } catch (error) {
        failed++;
        log.e('❌ Errore eliminazione variante ${variant.id}', error);
      }
    }

    if (deletedIds.isNotEmpty) {
      final productIndex = _prodotti.indexWhere((p) => p.id == productId);
      if (productIndex >= 0) {
        final remaining =
            (_prodotti[productIndex].varianti ??
                    const <VarianteProductGlobal>[])
                .where((variant) => !deletedIds.contains(variant.id))
                .toList();
        ProdottiCache.replaceVariants(
          productId,
          remaining,
          _prodotti,
          _prodottiFiltrati,
        );
        if (_prodottoSelezionato?.id == productId) {
          _prodottoSelezionato = _prodotti[productIndex];
          if (deletedIds.contains(_varianteSelezionata?.id)) {
            _varianteSelezionata = null;
          }
          _applicaFiltriVarianti();
        }
      } else {
        _removeVariantsFromCache(productId);
      }
      _markSharedDirty();
    }
    return VariantDeleteResult(
      deleted: deletedIds.length,
      failed: failed,
      stockNotZeroed: stockNotZeroed,
    );
  }

  /// Rewrites to 0 the MGWS total of one variant on every site holding
  /// pieces. True when nothing is left in stock.
  Future<bool> _zeroVariantStock({
    required MgwsInventoryGateway gateway,
    required int productId,
    required int variationId,
    required String reason,
    required String movementKey,
  }) async {
    try {
      final snapshot = InventoryStockSnapshot.fromRecord(
        await gateway.getProductStock(productId, variationId: variationId),
      );
      final piecesBySite = <int, int>{};
      for (final level in snapshot?.levels ?? const <InventoryStockLevel>[]) {
        piecesBySite[level.siteId] =
            (piecesBySite[level.siteId] ?? 0) + level.qty;
      }
      // A total without per-site detail still has to go: on a single-site
      // shop site 0 stands for the only site.
      if (piecesBySite.isEmpty && (snapshot?.currentStock ?? 0) != 0) {
        piecesBySite[0] = snapshot!.currentStock;
      }
      for (final entry in piecesBySite.entries) {
        if (entry.value == 0) continue;
        final result = await gateway.reconcileStock(
          productId: productId,
          variationId: variationId,
          correctStock: 0,
          siteId: entry.key,
          reason: reason,
          movementKey: movementKey,
        );
        if (!result.success || result.errors.isNotEmpty) {
          log.w(
            '⚠️ Stock MGWS della variante $variationId non azzerato '
            '(sede ${entry.key}): ${result.message}',
          );
          return false;
        }
      }
      return true;
    } catch (error) {
      log.e('❌ Azzeramento stock MGWS variante $variationId fallito', error);
      return false;
    }
  }

  Future<QuickVariantSaveResult> saveVariantQuickEdits({
    required int productId,
    required Map<int, QuickVariantEdit> edits,
  }) async {
    if (edits.isEmpty) {
      return QuickVariantSaveResult(
        updated: 0,
        failed: 0,
        message: (l10n) => l10n.productsNoVariantChangeToSave,
      );
    }

    int updated = 0;
    int failed = 0;

    final updatedVariantsById = <int, VarianteProductGlobal>{};

    for (final entry in edits.entries) {
      final variationId = entry.key;
      final edit = entry.value;
      try {
        final varianteAggiornata = await PlatformManager.varianti
            .updateVariation(
              productId: productId,
              variante: VarianteProductGlobal(
                id: variationId,
                nome: edit.nome,
                attributi: edit.attributi,
                barcodeInterno: edit.barcodeInterno,
                prezzo: edit.prezzo,
                prezzoScontato: edit.prezzoScontato,
                quantita: edit.quantita,
                immagineUrl: edit.immagineUrl,
                immaginiAggiuntive: edit.immaginiAggiuntive,
                peso: edit.peso,
                dimensioni: edit.dimensioni,
                attiva: edit.attiva,
              ),
            );
        updatedVariantsById[variationId] = varianteAggiornata;
        updated++;
      } catch (e) {
        failed++;
        log.e('❌ Errore salvataggio variante $variationId', e);
      }
    }

    if (updatedVariantsById.isNotEmpty) {
      final prodottoIndex = _prodotti.indexWhere((p) => p.id == productId);
      if (prodottoIndex >= 0) {
        final current = _prodotti[prodottoIndex];
        final currentVariants =
            current.varianti ?? const <VarianteProductGlobal>[];
        final merged = currentVariants
            .map((v) => updatedVariantsById[v.id] ?? v)
            .toList();
        ProdottiCache.replaceVariants(
          productId,
          merged,
          _prodotti,
          _prodottiFiltrati,
        );

        if (_prodottoSelezionato?.id == productId) {
          _prodottoSelezionato = _prodotti[prodottoIndex];
          _applicaFiltriVarianti();
        }
        _markSharedDirty();
      }
    }

    return QuickVariantSaveResult(
      updated: updated,
      failed: failed,
      message: failed == 0
          ? (l10n) => l10n.productsVariantsSaved(updated)
          : (l10n) => l10n.productsVariantsPartial(updated, failed),
    );
  }
}

class BulkCategoryUpdateResult {
  final int successCount;
  final int failedCount;
  final LocalizedText message;

  const BulkCategoryUpdateResult({
    required this.successCount,
    required this.failedCount,
    required this.message,
  });
}

class VariantDeleteResult {
  final int deleted;
  final int failed;

  /// Variants kept because their MGWS stock could not be brought to 0.
  final int stockNotZeroed;

  const VariantDeleteResult({
    required this.deleted,
    required this.failed,
    this.stockNotZeroed = 0,
  });
}

class QuickVariantEdit {
  final String nome;
  final List<AttributoVariante> attributi;
  final String barcodeInterno;
  final double prezzo;
  final double? prezzoScontato;
  final int quantita;
  final String? immagineUrl;
  final List<String> immaginiAggiuntive;
  final String? peso;
  final DimensioniProdotto? dimensioni;
  final bool attiva;

  const QuickVariantEdit({
    required this.nome,
    required this.attributi,
    required this.barcodeInterno,
    required this.prezzo,
    required this.prezzoScontato,
    required this.quantita,
    required this.immagineUrl,
    required this.immaginiAggiuntive,
    required this.peso,
    required this.dimensioni,
    required this.attiva,
  });

  factory QuickVariantEdit.fromVariante(VarianteProductGlobal variante) {
    return QuickVariantEdit(
      nome: variante.nome,
      attributi: variante.attributi,
      barcodeInterno: variante.barcodeInterno,
      prezzo: variante.prezzo,
      prezzoScontato: variante.prezzoScontato,
      quantita: variante.quantita,
      immagineUrl: variante.immagineUrl,
      immaginiAggiuntive: variante.immaginiAggiuntive,
      peso: variante.peso,
      dimensioni: variante.dimensioni,
      attiva: variante.attiva,
    );
  }
}

class QuickVariantSaveResult {
  final int updated;
  final int failed;
  final LocalizedText message;

  const QuickVariantSaveResult({
    required this.updated,
    required this.failed,
    required this.message,
  });
}

class ProdottoUtils {
  /// Etichetta tradotta dello stato di pubblicazione di un prodotto.
  static String getStatusLabel(AppLocalizations l10n, String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'publish':
        return l10n.prodottiStatusPubblico;
      case 'private':
        return l10n.prodottiStatusPrivato;
      case 'pending':
        return l10n.prodottiStatusInRevisione;
      case 'draft':
      default:
        return l10n.prodottiStatusBozza;
    }
  }

  static ProdottoPricingInfo getPricingInfo(ProdottoGlobal prodotto) {
    return ProdottiCache.getPricingInfo(prodotto);
  }
}

class ProdottoDisplayInfo {
  final String id;
  final String nome;
  final String codiceProdotto;
  final String barcodeInterno;
  final String categoria;
  final String prezzo;
  final String sconto;
  final String status;
  final String disponibilita;
  final String variantiCount;
  final bool inStock;
  final bool hasSconto;
  final bool prezzoVariabile;
  final bool scontoVariabile;
  ProdottoDisplayInfo({
    required this.id,
    required this.nome,
    required this.codiceProdotto,
    required this.barcodeInterno,
    required this.categoria,
    required this.prezzo,
    required this.sconto,
    required this.status,
    required this.disponibilita,
    required this.variantiCount,
    required this.inStock,
    required this.hasSconto,
    required this.prezzoVariabile,
    required this.scontoVariabile,
  });
  factory ProdottoDisplayInfo.fromProdotto(
    ProdottoGlobal prodotto,
    AppLocalizations l10n,
  ) {
    final pricing = ProdottoUtils.getPricingInfo(prodotto);
    return ProdottoDisplayInfo(
      id: prodotto.id?.toString() ?? '',
      nome: prodotto.nome ?? '',
      codiceProdotto: prodotto.codiceProdotto ?? '',
      barcodeInterno: prodotto.barcodeInterno ?? '',
      categoria: prodotto.categoria?.map((c) => c.nome).join(', ') ?? '',
      prezzo: pricing.prezzoCompletoLabel(l10n),
      sconto: pricing.scontoLabel(l10n),
      status: ProdottoUtils.getStatusLabel(l10n, prodotto.status),
      disponibilita: ClassFormtter.getDisponibilitaText(l10n, prodotto.inStock),
      variantiCount: ClassFormtter.getVariantiCountText(
        l10n,
        prodotto.varianti?.length ?? 0,
      ),
      inStock: prodotto.inStock,
      hasSconto: pricing.hasSconto,
      prezzoVariabile: pricing.prezzoVariabile,
      scontoVariabile: pricing.scontoVariabile,
    );
  }
}

class QuickEditSelectionUtils {
  static List<String> categoryNamesFromProduct(ProdottoGlobal prodotto) {
    return _normalizeNames(
      (prodotto.categoria ?? const <CategoriaProdotto>[]).map((c) => c.nome),
    );
  }

  static List<String> tagNamesFromProduct(ProdottoGlobal prodotto) {
    return _normalizeNames(
      (prodotto.tag ?? const <TagProdotto>[]).map((t) => t.nome),
    );
  }

  static List<String> normalizeNames(Iterable<dynamic> values) {
    return _normalizeNames(values);
  }

  static bool hasSameNames(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    final leftNormalized = left.map((v) => v.trim().toLowerCase()).toList()
      ..sort();
    final rightNormalized = right.map((v) => v.trim().toLowerCase()).toList()
      ..sort();
    for (int i = 0; i < leftNormalized.length; i++) {
      if (leftNormalized[i] != rightNormalized[i]) return false;
    }
    return true;
  }

  static List<String> _normalizeNames(Iterable<dynamic> values) {
    final names = <String>{};
    for (final value in values) {
      final name = value.toString().trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    final list = names.toList()..sort();
    return list;
  }
}
