import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'prodotti_gestisci.code.dart';
import '../class_prodotti.dart';
import '../prodotto_filters.dart';
import '../prodotti_crea/prodotti_crea.gui.dart';
import 'prodotti_gestisci_view.gui.dart';
import '../../theme/theme.dart';
import '../../notification/notification_service.dart';
import '../../settings/app_settings.dart';
import '../../settings/machine_ui_preferences.dart';
import '../../reuse_class/gui/global_pagination_bar.dart';
import '../../reuse_class/logic/global_pagination_controller.dart';
import '../../reuse_class/gui/searchable_checkbox_dialog.dart';
import '../../reuse_class/gui/notification_recap_dialog.dart';
import '../../reuse_class/datagridview/datagridview.code.dart';
import '../../reuse_class/datagridview/datagridview.gui.dart';
import '../../reuse_class/datagridview/datagridview_image_preview.dart';
import '../../reuse_class/image_url_resolver.dart';
import '../../log_viewer/app_logger.dart';
import '../../traduzioni/estensioni.dart';

// ---------------------------------------------------------------------------
// Costanti
// ---------------------------------------------------------------------------

const double _kDesktopBreakpoint = 800;
const double _kCardRadius = 18;
const double _kControlGap = 8;

/// Inset orizzontale dei controlli che toccano il bordo dello schermo.
///
/// La sezione prodotti e a filo: niente padding esterno, niente cornice. Restano
/// pero' 6px, perche' `DataTable2` centra la colonna checkbox in
/// `horizontalMargin / 2`, cioe' 6px: senza questo inset la toolbar del filtro
/// risulterebbe 6px a sinistra della checkbox e le due cose sembrerebbero
/// disallineate.
const double _kEdgeInset = 6;

/// Inset verticale delle barre agganciate al bordo.
///
/// Non e' zero perche' la toolbar `Filtro` chiusa e alta quanto un `titleSmall`
/// (~20px): a zero scenderebbe sotto i 48dp di tap target minimi di Android.
const double _kEdgeInsetVertical = 4;

// TEST DISATTIVATO 1: field della colonna checkbox nativa.
// const String _kFieldSelection = '__selection';
// TEST DISATTIVATO: field prodotto usato dalla griglia reale, non dal demo docs.
// const String _kFieldProductId = '__productId';

// TEST DISATTIVATO 4: logger usato solo dalla selezione custom.
// final _log = AppLogger();

// ---------------------------------------------------------------------------
// Enum azioni contesto
// ---------------------------------------------------------------------------

enum _ProductContextAction { crea, modifica, modificaInMassa, elimina }

// ---------------------------------------------------------------------------
// Utility globale: viewer immagine
// ---------------------------------------------------------------------------

// DISATTIVATO baseline DataGrid: viewer immagine usato dal renderer custom.
// ignore: unused_element
Future<void> _openImageViewer(
  BuildContext context,
  String? imageUrl, {
  required String title,
}) async {
  final safeUrl = (resolveImageUrl(imageUrl) ?? '').trim();
  if (safeUrl.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Image.network(
                        safeUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _confirmDeleteDialog(
  BuildContext context, {
  required List<ProdottoGlobal> products,
}) {
  return NotificationRecapDialog.delete(
    context,
    items: products,
    itemLabel: (product) =>
        '${product.nome ?? 'Prodotto senza nome'}'
        '${(product.barcodeInterno ?? '').trim().isEmpty ? '' : ' (Barcode interno: ${product.barcodeInterno})'}',
    isDestructive: true,
  );
}

// ===========================================================================
// ProdottiGestisciPage — root widget
// ===========================================================================

class ProdottiGestisciPage extends StatefulWidget {
  /// Se true la pagina entra in "modalità cassa": serve da selettore prodotti
  /// per la cassa. Vengono nascoste le azioni di modifica/eliminazione e in
  /// basso compaiono i pulsanti "Annulla" (chiude senza risultato) e
  /// "Aggiungi" (restituisce i prodotti selezionati alla cassa).
  final bool modalitaCassa;

  /// Callback chiamato in modalità cassa quando l'utente preme "Aggiungi",
  /// con la lista dei prodotti selezionati. Se null la pagina si limita a
  /// restituire il risultato al Navigator (pop con la lista selezionata).
  final ValueChanged<List<ProdottoGlobal>>? onAggiungiProdotti;

  const ProdottiGestisciPage({
    super.key,
    this.modalitaCassa = false,
    this.onAggiungiProdotti,
  });

  @override
  ProdottiGestisciPageState createState() => ProdottiGestisciPageState();
}

class ProdottiGestisciPageState extends State<ProdottiGestisciPage>
    with AutomaticKeepAliveClientMixin<ProdottiGestisciPage> {
  // ── Controller e settings ────────────────────────────────────────────────
  final _controller = ProdottiGestioneController();
  final _appSettings = AppSettings();
  final _machineUiPreferences = MachineUiPreferences();
  late final MultiSplitViewController _splitViewController;
  final _paginationController = GlobalPaginationController<ProdottoGlobal>();
  final _scrollController = ScrollController();
  final _gridKey = GlobalKey<_ProductsGridState>();
  final ValueNotifier<ProdottoGlobal?> _selectedProductNotifier =
      ValueNotifier<ProdottoGlobal?>(null);
  final ValueNotifier<bool> _selectedProductVariantsLoading =
      ValueNotifier<bool>(false);
  final Map<int, Set<int>> _selectedCassaVariantIdsByProductId =
      <int, Set<int>>{};

  /// Prodotti semplici selezionati per la cassa (senza varianti).
  final Set<int> _selectedCassaSimpleProductIds = <int>{};

  // ── Stato colonne ────────────────────────────────────────────────────────
  // Unico stato delle colonne: alimenta sia il preselezionato del selettore
  // sia le colonne effettivamente renderizzate dalla griglia.
  Set<ProductGridColumnId> _visibleColumns = defaultProductGridColumns.toSet();
  double _productPaneRatio =
      MachineUiPreferences.defaultProductsManageSplitRatio;

  // ── Busy overlay ─────────────────────────────────────────────────────────
  int _busyDepth = 0;
  String _busyMessage = 'Caricamento in corso...';
  bool _productsLoading = false;
  bool _disposed = false;

  bool get _isBusy => _busyDepth > 0;
  bool get _alive => mounted && !_disposed;
  List<ProdottoGlobal> get _visibleProducts => _paginationController.items;
  int get _selectedCassaVariantsCount =>
      _selectedCassaVariantIdsByProductId.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      ) +
      _selectedCassaSimpleProductIds.length;

  StreamSubscription<int>? _variantsUpdateSubscription;
  Timer? _cacheRefreshDebounce;
  Timer? _prefetchDebounce;

  /// Contatore dei prefetch di finestra in corso: la barra rossa in alto
  /// mostra il refill "in tempo reale" della cache varianti (cambio pagina,
  /// filtro, dropdown, apertura iniziale) oltre al caricamento prodotti.
  int _cacheRefillDepth = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _splitViewController = MultiSplitViewController(
      areas: _splitAreasForRatio(_productPaneRatio),
    );
    _scrollController.addListener(_onScroll);
    // Le varianti agganciate dal datagrid cache cambiano i valori Prezzo/Sconto
    // della griglia: riallinea lo snapshot paginato e ricompone le righe.
    // Durante il prefetch la cache emette un evento per ogni chunk: un refresh
    // immediato per ciascuno comporrebbe la griglia ~86 volte di fila e
    // riporterebbe l'utente alla prima pagina. Il debounce raggruppa il burst
    // in un unico refresh a fine caricamento.
    _variantsUpdateSubscription = DataGridViewCache.onVariantsUpdated.listen(
      (_) => _scheduleCacheRefresh(),
    );
    _loadProducts();
    _initSettings();
  }

  void _scheduleCacheRefresh() {
    if (_disposed) return;
    _cacheRefreshDebounce?.cancel();
    _cacheRefreshDebounce = Timer(const Duration(milliseconds: 500), _refresh);
  }

  // Pre-fetch varianti della pagina visibile (valore esatto del dropdown),
  // separato dal debounce di ricomposizione della griglia. Parte da ogni
  // sincronizzazione di paginazione: caricamento iniziale, cambio pagina,
  // cambio dropdown, applicazione filtro, scroll infinito.
  void _schedulePagePrefetch() {
    if (_disposed) return;
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(
      const Duration(milliseconds: 200),
      _prefetchCurrentWindow,
    );
  }

  void _prefetchCurrentWindow() {
    if (!_alive) return;
    final items = _paginationController.items;
    if (items.isEmpty) return;
    // Limita la cache varianti alla sola finestra visibile (come la web GUI
    // di WordPress): le voci fuori pagina vengono rimosse, così la RAM resta
    // proporzionata alla pagina corrente e NON cresce con il numero di pagine
    // visitate. Il prodotto selezionato è mantenuto per non svuotare la scheda
    // laterale durante la navigazione.
    final keepIds = <int>{
      ...items.map((p) => p.id).whereType<int>().where((id) => id > 0),
    };
    final selectedId = _controller.prodottoSelezionato?.id;
    if (selectedId is int && selectedId > 0) keepIds.add(selectedId);
    final rimossi = DataGridViewCache.pruneVariantsOutside(keepIds);
    _cacheRefillDepth++;
    setState(() {});
    unawaited(
      _controller
          .prefetchVariantiVisibili(
            items,
            concurrency: ProdottiGestioneController.prefetchWindowConcurrency,
          )
          .whenComplete(() {
            if (!_alive) return;
            if (rimossi > 0) {
              log.i(
                '[perf-trace] cache finestra prune rimossi=$rimossi '
                'keep=${keepIds.length} '
                'rssMb=${(ProcessInfo.currentRss / (1024 * 1024)).round()}',
              );
            }
            _cacheRefillDepth--;
            setState(() {});
          }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _cacheRefreshDebounce?.cancel();
    _prefetchDebounce?.cancel();
    _variantsUpdateSubscription?.cancel();
    _scrollController.dispose();
    _paginationController.dispose();
    _splitViewController.dispose();
    _selectedProductNotifier.dispose();
    _selectedProductVariantsLoading.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ── Busy helpers ─────────────────────────────────────────────────────────

  void _pushBusy(String message) => _setBusy(_busyDepth + 1, message);
  void _popBusy() {
    if (_busyDepth <= 0) return;
    _setBusy(
      _busyDepth - 1,
      _busyDepth == 1 ? 'Caricamento in corso...' : _busyMessage,
    );
  }

  void _setBusy(int depth, String message) {
    if (_disposed) return;
    _busyDepth = depth;
    _busyMessage = message;
    if (mounted) setState(() {});
  }

  List<Area> _splitAreasForRatio(double ratio) {
    final normalized = MachineUiPreferences.normalizeProductsManageSplitRatio(
      ratio,
    );
    return [
      Area(
        id: 'products',
        flex: normalized,
        min: MachineUiPreferences.minProductsManageSplitRatio,
        max: MachineUiPreferences.maxProductsManageSplitRatio,
      ),
      Area(
        id: 'details',
        flex: 1 - normalized,
        min: 1 - MachineUiPreferences.maxProductsManageSplitRatio,
        max: 1 - MachineUiPreferences.minProductsManageSplitRatio,
      ),
    ];
  }

  void _saveCurrentSplitRatio() {
    final productFlex = _splitViewController.getArea(0).flex;
    final detailFlex = _splitViewController.getArea(1).flex;
    if (productFlex == null || detailFlex == null) return;
    final totalFlex = productFlex + detailFlex;
    if (totalFlex <= 0) return;
    final ratio = MachineUiPreferences.normalizeProductsManageSplitRatio(
      productFlex / totalFlex,
    );
    _productPaneRatio = ratio;
    unawaited(_machineUiPreferences.setProductsManageSplitRatio(ratio));
  }

  Future<T> _runBusy<T>(String message, Future<T> Function() action) async {
    _pushBusy(message);
    try {
      return await action();
    } finally {
      _popBusy();
    }
  }

  // ── Inizializzazione ─────────────────────────────────────────────

  Future<void> _initSettings() async {
    await _runBusy('Inizializzazione...', () async {
      await _appSettings.init();
      await _machineUiPreferences.init();
      if (!_alive) return;
      _productPaneRatio = _machineUiPreferences.productsManageSplitRatio;
      _splitViewController.areas = _splitAreasForRatio(_productPaneRatio);
      await _paginationController.loadFromSettings(_appSettings);
      if (!_alive) return;
      _controller.setPersistedAdvancedFiltersEnabled(
        _appSettings.persistProductFilters,
      );
      _controller.setNascondiProdottiEsauriti(
        _appSettings.hideOutOfStockProducts,
      );
      _visibleColumns = _initialVisibleColumns();
      _syncPagination();
      if (mounted) setState(() {});
    });
  }

  Future<void> _setHideOutOfStockProducts(bool value) async {
    _controller.setNascondiProdottiEsauriti(value);
    await _appSettings.setHideOutOfStockProducts(value);
    _refresh();
  }

  /// Le checkbox del selettore colonne sono l'unica fonte di verita: questo
  /// set e sia il preselezionato mostrato dal dialog sia le colonne che la
  /// griglia renderizza. Senza preferenze salvate si parte da un set coerente
  /// con la larghezza corrente, ma una volta scelto non segue il resize,
  /// altrimenti le checkbox mostrerebbero colonne diverse da quelle in tabella.
  Set<ProductGridColumnId> _initialVisibleColumns() {
    final stored = _appSettings.visibleProductGridColumns;
    if (stored.isNotEmpty) return _resolveColumns(stored);
    final isSmall =
        mounted && MediaQuery.sizeOf(context).width < _kDesktopBreakpoint;
    return isSmall
        ? defaultMobileProductGridColumns.toSet()
        : defaultProductGridColumns.toSet();
  }

  Set<ProductGridColumnId> _resolveColumns(List<String> keys) {
    if (keys.isEmpty) return defaultProductGridColumns.toSet();
    final resolved = <ProductGridColumnId>{};
    for (final key in keys) {
      for (final col in ProductGridColumnId.values) {
        if (col.storageKey == key) {
          resolved.add(col);
          break;
        }
      }
    }
    return resolved.isEmpty ? defaultProductGridColumns.toSet() : resolved;
  }

  // ── Caricamento prodotti ─────────────────────────────────────────────────

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    if (_productsLoading) return;
    setState(() => _productsLoading = true);
    try {
      await _controller.caricaProdotti(
        forceRefresh: forceRefresh,
        prefetchLimit: _paginationController.pageSize,
        onProgress: (_) {
          if (!_alive) return;
          // Non resettare MAI la pagina durante il caricamento progressivo:
          // un `goToFirstPage` qui scatta a ogni chunk (decine di volte) e
          // butta l'utente alla pagina 1 ogni volta che la cache si popola.
          // `syncLocalItems` riallinea totali/pagine senza cambiare la pagina
          // corrente (clamp solo se eccede). Il reset esplicito resta solo nei
          // comandi voluti (prima pagina, cambio filtri/modalità, refresh).
          _syncPagination();
          setState(() {});
        },
      );
      if (!_alive) return;
      // Riparti dalla prima pagina SOLO per i caricamenti espliciti (refresh
      // utente, cambio filtri): qui `forceRefresh` è il discriminante reale.
      // I riempimenti progressivi in background (prefetch, chunk paginati)
      // selezionano il ramo `else` e preservano la pagina corrente.
      if (forceRefresh) {
        _paginationController.goToFirstPage();
        _syncPagination(jumpTop: true);
      } else {
        _syncPagination();
      }
      _syncSelectedProductDisplay();
      final warning = _controller.consumeLastLoadWarning();
      if (mounted && warning != null && warning.isNotEmpty) {
        NotificationService.instance.messageBar(
          'warning',
          'prodotti_gestisci',
          warning,
        );
      }
      if (_alive) setState(() {});
    } finally {
      if (_alive) setState(() => _productsLoading = false);
    }
  }

  void _syncPagination({bool jumpTop = false}) {
    if (!_alive) return;
    final p = _paginationController;
    p.syncLocalItems(_visibleProductsSource);
    log.d(
      '[perf-trace] paginazione sync visibili=${p.items.length} '
      'pagina=${p.currentPage}/${p.totalPages ?? "-"} '
      'tot=${p.totalItems ?? "-"} perPagina=${p.pageSize} jumpTop=$jumpTop',
    );
    _schedulePagePrefetch();
    if (jumpTop && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  List<ProdottoGlobal> get _visibleProductsSource => _controller.prodotti;

  void _syncSelectedProductDisplay() {
    _selectedProductNotifier.value = _controller.prodottoSelezionato;
    if (_selectedProductNotifier.value == null) {
      _selectedProductVariantsLoading.value = false;
    }
  }

  void _handleProductSelected(ProdottoGlobal product) {
    _selectedProductNotifier.value = _controller.prodottoSelezionato;
    final needsVariants = product.isVariabile;
    if (!needsVariants || (product.varianti?.isNotEmpty ?? false)) {
      _selectedProductVariantsLoading.value = false;
      return;
    }
    _selectedProductVariantsLoading.value = true;
    unawaited(_loadSelectedProductVariants(product));
  }

  Future<void> _loadSelectedProductVariants(ProdottoGlobal product) async {
    final productId = product.id;
    if (productId == null || productId <= 0) {
      _selectedProductVariantsLoading.value = false;
      return;
    }

    await _controller.caricaVariantiProdottoSelezionato();
    if (!_alive) return;

    if (_selectedProductNotifier.value?.id == productId) {
      _selectedProductNotifier.value =
          _controller.prodottoSelezionato ?? product;
    }
    _selectedProductVariantsLoading.value = false;
  }

  // ── Scroll infinito ──────────────────────────────────────────────────────

  void _onScroll() {
    if (!_alive) return;
    if (_isBusy ||
        !_paginationController.isInfinite ||
        !_paginationController.hasMore ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 240) return;

    _paginationController.goToNextPage();
    _syncPagination();
  }

  // ── Paginazione ──────────────────────────────────────────────────────────

  Future<void> _handlePageSizeOrModeChanged(
    GlobalPageMode mode,
    int size,
  ) async {
    if (!_alive || _isBusy) return;
    log.d(
      '[perf-trace] paginazione action=pageSize/mode -> size=$size '
      'mode=${mode.name}',
    );
    // La cache varianti deve rispecchiare il valore esatto del nuovo dropdown
    // ("Righe per pagina"): svuotala e lascia che il flusso normale
    // (_syncPagination → _schedulePagePrefetch → _prefetchCurrentWindow)
    // rifempia la cache con la sola nuova finestra. Stesso principio dei
    // filtri (R2): il cambio 100→50 o 50→100 parte dalla cache vuota.
    DataGridViewCache.clearVariants();
    _syncPagination(jumpTop: true);
    if (_alive) setState(() {});
  }

  Future<void> _goFirstPage() async {
    if (!_alive || _isBusy) return;
    log.d('[perf-trace] paginazione action=prima');
    _paginationController.goToFirstPage();
    _syncPagination(jumpTop: true);
  }

  Future<void> _goPreviousPage() async {
    if (!_alive || _isBusy) return;
    log.d('[perf-trace] paginazione action=precedente');
    _paginationController.goToPreviousPage();
    _syncPagination(jumpTop: true);
  }

  Future<void> _goNextPage() async {
    if (!_alive || _isBusy) return;
    log.d('[perf-trace] paginazione action=successiva');
    _paginationController.goToNextPage();
    _syncPagination(jumpTop: true);
  }

  Future<void> _goLastPage() async {
    if (!_alive || _isBusy) return;
    log.d('[perf-trace] paginazione action=ultima');
    _paginationController.goToLastPage();
    _syncPagination(jumpTop: true);
  }

  // ── Azioni prodotto ──────────────────────────────────────────────────────

  Future<void> _handleProductAction(
    _ProductContextAction action,
    ProdottoGlobal product,
  ) async {
    switch (action) {
      case _ProductContextAction.crea:
        final created = await openProductEditor(context);
        if (created == true) await _loadProducts(forceRefresh: true);

      case _ProductContextAction.modifica:
        final updated = await openProductEditor(
          context,
          prodottoIdDaModificare: product.id,
          codiceProdotto: product.codiceProdotto,
        );
        if (updated == true) await _loadProducts(forceRefresh: true);

      case _ProductContextAction.modificaInMassa:
        if (_controller.selectedProductsCount <= 1) return;
        _controller.selezionaProdotto(product);
        _syncSelectedProductDisplay();

      case _ProductContextAction.elimina:
        await _deleteProducts(product);
    }
  }

  Future<void> _deleteProducts(ProdottoGlobal anchor) async {
    final selected = _controller.selectedProducts;
    final useBulk =
        _controller.selectedProductsCount > 1 &&
        selected.any((p) => p.id == anchor.id);
    final toDelete = useBulk ? selected : [anchor];

    final confirmed = await _confirmDeleteDialog(context, products: toDelete);
    if (!confirmed || !mounted) return;

    final label = useBulk
        ? 'Eliminazione ${toDelete.length} prodotti...'
        : 'Eliminazione prodotto...';

    final (bulkResult, success) = await _runBusy(label, () async {
      if (useBulk) {
        final r = await _controller.deleteSelectedProducts(
          force: _appSettings.forceDelete,
        );
        return (r, r.failedCount == 0);
      } else {
        final ok = await _controller.eliminaProdotto(anchor.id ?? 0);
        return (null, ok);
      }
    });

    if (!mounted) return;

    final severity = success
        ? 'successo'
        : (bulkResult?.successCount ?? 0) > 0
        ? 'warning'
        : 'errore';

    final message = success
        ? useBulk
              ? bulkResult!.message
              : 'Prodotto eliminato con successo.'
        : useBulk
        ? (bulkResult?.message ?? 'Eliminazione parziale.')
        : 'Eliminazione non riuscita.';

    NotificationService.instance.messageBar(
      'prodotti_gestisci',
      severity,
      message,
    );
    if (success || (bulkResult?.successCount ?? 0) > 0) {
      await _loadProducts(forceRefresh: true);
    }
  }

  Future<void> _deleteSelectedProducts() async {
    if (_isBusy) return;
    final selected = _controller.selectedProducts;
    if (selected.isEmpty) return;
    await _deleteProducts(selected.first);
  }

  Future<void> _deleteFromGrid(ProdottoGlobal? product) async {
    if (_isBusy) return;
    if (_controller.hasSelectedProducts) {
      await _deleteSelectedProducts();
      return;
    }
    if (product != null) await _deleteProducts(product);
  }

  void _clearGridSelection() {
    if (_controller.hasSelectedProducts) {
      _controller.clearBulkSelection();
      _refresh();
    }
  }

  Set<int> _selectedCassaVariantIdsFor(ProdottoGlobal prodotto) {
    final productId = prodotto.id;
    if (productId == null || productId <= 0) return const <int>{};
    return Set<int>.unmodifiable(
      _selectedCassaVariantIdsByProductId[productId] ?? const <int>{},
    );
  }

  void _toggleCassaVariantSelection(
    ProdottoGlobal prodotto,
    VarianteProductGlobal variante,
    bool selected,
  ) {
    final productId = prodotto.id;
    if (productId == null || productId <= 0 || variante.id <= 0) return;
    final ids = _selectedCassaVariantIdsByProductId.putIfAbsent(
      productId,
      () => <int>{},
    );
    if (selected) {
      ids.add(variante.id);
    } else {
      ids.remove(variante.id);
      if (ids.isEmpty) _selectedCassaVariantIdsByProductId.remove(productId);
    }
    setState(() {});
  }

  void _toggleCassaSimpleProductSelection(
    ProdottoGlobal prodotto,
    bool selected,
  ) {
    final productId = prodotto.id;
    if (productId == null || productId <= 0) return;
    setState(() {
      if (selected) {
        _selectedCassaSimpleProductIds.add(productId);
      } else {
        _selectedCassaSimpleProductIds.remove(productId);
      }
    });
  }

  List<ProdottoGlobal> _buildCassaSelectedProducts() {
    final selectedProducts = <ProdottoGlobal>[];
    final productsById = <int, ProdottoGlobal>{
      for (final product in _controller.prodotti)
        if (product.id != null && product.id! > 0) product.id!: product,
      if (_controller.prodottoSelezionato?.id != null &&
          _controller.prodottoSelezionato!.id! > 0)
        _controller.prodottoSelezionato!.id!: _controller.prodottoSelezionato!,
    };
    for (final product in productsById.values) {
      final productId = product.id;
      if (productId == null || productId <= 0) continue;
      final selectedVariantIds = _selectedCassaVariantIdsByProductId[productId];
      if (selectedVariantIds != null && selectedVariantIds.isNotEmpty) {
        final selectedVariants = (product.varianti ?? <VarianteProductGlobal>[])
            .where((variant) => selectedVariantIds.contains(variant.id))
            .toList();
        if (selectedVariants.isNotEmpty) {
          selectedProducts.add(product.copyWith(varianti: selectedVariants));
        }
        continue;
      }
      // Prodotto semplice selezionato per la cassa: nessuna variante.
      if (_selectedCassaSimpleProductIds.contains(productId)) {
        selectedProducts.add(
          product.copyWith(varianti: const <VarianteProductGlobal>[]),
        );
      }
    }
    return selectedProducts;
  }

  List<DataGridViewContextAction<ProdottoGlobal>> _buildContextActions() {
    final actions = <DataGridViewContextAction<ProdottoGlobal>>[
      DataGridViewContextAction<ProdottoGlobal>(
        label: 'Nuovo',
        icon: Icons.add_circle_outline,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.crea, product),
      ),
      DataGridViewContextAction<ProdottoGlobal>(
        label: 'Modifica',
        icon: Icons.edit_outlined,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.modifica, product),
      ),
    ];
    if (_controller.selectedProductsCount > 1) {
      actions.add(
        DataGridViewContextAction<ProdottoGlobal>(
          label: 'Modifica in massa',
          icon: Icons.edit_note_outlined,
          onSelected: (product) => _handleProductAction(
            _ProductContextAction.modificaInMassa,
            product,
          ),
        ),
      );
    }
    actions.add(
      DataGridViewContextAction<ProdottoGlobal>(
        label: 'Elimina',
        icon: Icons.delete_outline,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.elimina, product),
      ),
    );
    return actions;
  }

  // ── Colonne ──────────────────────────────────────────────────────────────

  Future<void> _openColumnPicker() async {
    if (_isBusy) return;
    final allLabels = ProductGridColumnId.values
        .map((c) => productGridColumnLabel(context.l10n, c))
        .toList();
    final selected = await SearchableCheckboxDialog.show(
      context,
      title: context.l10n.prodottiColonneVisibili,
      inputLabel: context.l10n.prodottiCercaColonna,
      input_list: allLabels,
      preselected_list: ProductGridColumnId.values
          .where(_visibleColumns.contains)
          .map((c) => productGridColumnLabel(context.l10n, c))
          .toList(),
    );
    if (!mounted || selected == null || selected.isEmpty) return;

    final next = ProductGridColumnId.values
        .where(
          (c) => selected.contains(productGridColumnLabel(context.l10n, c)),
        )
        .toSet();
    if (next.isEmpty) return;

    await _appSettings.setVisibleProductGridColumns(
      ProductGridColumnId.values
          .where(next.contains)
          .map((c) => c.storageKey)
          .toList(),
    );
    setState(() => _visibleColumns = next);
  }

  // ── Refresh stato ────────────────────────────────────────────────────────

  void _refresh() {
    if (!mounted) return;
    _syncSelectedProductDisplay();
    setState(() => _syncPagination());
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          // La sezione e a filo: senza questo, aperta dalla cassa (rotta senza
          // AppBar, `cassa.gui.dart`) la card finiva sotto la status bar. Dalla
          // home l'AppBar esterna ha gia' consumato l'inset, quindi `Scaffold`
          // passa `padding.top == 0` al body e qui non aggiunge nulla.
          body: SafeArea(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    customColors.gradientStart.withValues(alpha: 0.72),
                    theme.colorScheme.surface,
                    customColors.gradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < _kDesktopBreakpoint;
                  return isSmall ? _buildMobileLayout() : _buildDesktopLayout();
                },
              ),
            ),
          ),
        ),
        if (_productsLoading || _cacheRefillDepth > 0)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (_isBusy)
          Positioned.fill(child: _BusyOverlay(message: _busyMessage)),
      ],
    );
  }

  Widget _buildMobileLayout() => _buildProductPane(showDetailsInPage: true);

  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 8,
        dividerPainter: DividerPainters.background(
          color: Colors.transparent,
          highlightedColor: theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: MultiSplitView(
        controller: _splitViewController,
        axis: Axis.horizontal,
        onDividerDragEnd: (_) => _saveCurrentSplitRatio(),
        dividerBuilder: (axis, index, resizable, dragging, highlighted, data) {
          return MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: ColoredBox(
              color: highlighted || dragging
                  ? theme.dividerColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              child: Center(
                child: Container(
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          );
        },
        builder: (context, area) {
          if (area.index == 0) return _buildProductPane();
          // Come il pannello prodotti: a filo, senza cornice. La separazione
          // fra i due e' solo la linea verticale trascinabile: niente spazio
          // vuoto tra griglia e dettaglio.
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.84),
            ),
            child: ValueListenableBuilder<ProdottoGlobal?>(
              valueListenable: _selectedProductNotifier,
              builder: (context, selectedProduct, _) {
                return Stack(
                  children: [
                    selectedProduct != null
                        ? ValueListenableBuilder<bool>(
                            valueListenable: _selectedProductVariantsLoading,
                            builder: (context, isLoading, __) {
                              return ProdottoDettagliView(
                                prodotto: selectedProduct,
                                varianteSelezionata:
                                    _controller.varianteSelezionata,
                                controller: _controller,
                                modalitaSelezioneCassa: widget.modalitaCassa,
                                variantiSelezionateCassa:
                                    _selectedCassaVariantIdsFor(
                                      selectedProduct,
                                    ),
                                onVarianteCassaChecked: (variante, selected) =>
                                    _toggleCassaVariantSelection(
                                      selectedProduct,
                                      variante,
                                      selected,
                                    ),
                                prodottoSempliceSelezionatoCassa:
                                    _selectedCassaSimpleProductIds.contains(
                                      selectedProduct.id ?? -1,
                                    ),
                                onProdottoSempliceCassaChecked:
                                    widget.modalitaCassa
                                    ? (selected) =>
                                          _toggleCassaSimpleProductSelection(
                                            selectedProduct,
                                            selected,
                                          )
                                    : null,
                                variantsLoading: isLoading,
                                shortcutToggleEdit:
                                    _appSettings.shortcutToggleEdit,
                                shortcutSave: _appSettings.shortcutSave,
                                shortcutEscape: _appSettings.shortcutEscape,
                                onReload: () =>
                                    _loadProducts(forceRefresh: true),
                                onProductDeleted: _refresh,
                              );
                            },
                          )
                        : _buildEmptyState(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductPane({bool showDetailsInPage = false}) {
    final theme = Theme.of(context);
    // A filo: niente padding, niente cornice, niente ombra. Il raggio di 24px
    // e l'ombra esistevano per far leggere il pannello come una card galleggiante
    // sul gradiente; a contatto con il bordo dello schermo diventerebbero angoli
    // mozzi e un repaint che non si vede.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
      ),
      child: Column(
        children: [
          Expanded(
            child: _buildProductList(showDetailsInPage: showDetailsInPage),
          ),
          if (widget.modalitaCassa) _buildPickerActionBar(theme),
        ],
      ),
    );
  }

  /// Barra inferiore della modalità cassa: "Annulla" chiude senza risultato,
  /// "Aggiungi" restituisce i prodotti selezionati alla cassa.
  Widget _buildPickerActionBar(ThemeData theme) {
    final selectedCount = _selectedCassaVariantsCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: Text(context.l10n.commonAnnulla),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      final selected = _buildCassaSelectedProducts();
                      widget.onAggiungiProdotti?.call(selected);
                      Navigator.of(context).pop<List<ProdottoGlobal>>(selected);
                    },
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                selectedCount == 0 ? 'Aggiungi' : 'Aggiungi ($selectedCount)',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.extension<AppColorExtension>()?.successColor ??
                    context.colors.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList({bool showDetailsInPage = false}) {
    return Column(
      children: [
        _FiltersBar(
          controller: _controller,
          selectedCount: _controller.selectedProductsCount,
          onStateChanged: _refresh,
          onHideOutOfStockChanged: _setHideOutOfStockProducts,
          onRefresh: () => _loadProducts(forceRefresh: true),
          onOpenColumns: _openColumnPicker,
        ),
        Expanded(
          child: _ProductsGrid(
            key: _gridKey,
            controller: _controller,
            products: _visibleProducts,
            scrollController: _scrollController,
            visibleColumns: _visibleColumns,
            showSelectionControls: !widget.modalitaCassa,
            onStateChanged: _refresh,
            contextActions: widget.modalitaCassa
                ? const <DataGridViewContextAction<ProdottoGlobal>>[]
                : _buildContextActions(),
            onDeleteSelected: widget.modalitaCassa
                ? null
                : _deleteSelectedProducts,
            onClearSelection: _clearGridSelection,
            onDeleteFromGrid: widget.modalitaCassa ? (_) {} : _deleteFromGrid,
            onProductSelected: _handleProductSelected,
            selectAllShortcut: _appSettings.shortcutSelectAll,
            deleteShortcut: _appSettings.shortcutDelete,
            escapeShortcut: _appSettings.shortcutEscape,
            onOpenProductDetails: showDetailsInPage
                ? (product) async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ProdottoDettagliView(
                          prodotto: product,
                          varianteSelezionata: _controller.varianteSelezionata,
                          controller: _controller,
                          modalitaSelezioneCassa: widget.modalitaCassa,
                          variantiSelezionateCassa: _selectedCassaVariantIdsFor(
                            product,
                          ),
                          onVarianteCassaChecked: (variante, selected) =>
                              _toggleCassaVariantSelection(
                                product,
                                variante,
                                selected,
                              ),
                          prodottoSempliceSelezionatoCassa:
                              _selectedCassaSimpleProductIds.contains(
                                product.id ?? -1,
                              ),
                          onProdottoSempliceCassaChecked: widget.modalitaCassa
                              ? (selected) =>
                                    _toggleCassaSimpleProductSelection(
                                      product,
                                      selected,
                                    )
                              : null,
                          variantsLoading: false,
                          shortcutToggleEdit: _appSettings.shortcutToggleEdit,
                          shortcutSave: _appSettings.shortcutSave,
                          shortcutEscape: _appSettings.shortcutEscape,
                          showCloseButton: true,
                          onReload: () => _loadProducts(forceRefresh: true),
                          onProductDeleted: _refresh,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  }
                : null,
          ),
        ),
        GlobalPaginationBar(
          settings: _appSettings,
          controller: _paginationController,
          totalRows: _controller.hasFiltroAttivo
              ? _controller.prodotti.length
              : _paginationController.totalItems ?? _controller.prodotti.length,
          selectedRows: widget.modalitaCassa
              ? _selectedCassaVariantsCount
              : _controller.selectedProductsCount,
          onFirstPage: _goFirstPage,
          onPreviousPage: _goPreviousPage,
          onNextPage: _goNextPage,
          onLastPage: _goLastPage,
          onModeOrPageSizeChanged: _handlePageSizeOrModeChanged,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: theme.iconTheme.color?.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Seleziona un prodotto',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            'per vedere i dettagli',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _ProductsGrid — griglia riusabile stile DataGridView C#
// ===========================================================================

class _ProductsGrid extends StatefulWidget {
  final ProdottiGestioneController controller;
  final List<ProdottoGlobal> products;
  final ScrollController scrollController;
  final Set<ProductGridColumnId> visibleColumns;
  final bool showSelectionControls;
  final VoidCallback onStateChanged;
  final List<DataGridViewContextAction<ProdottoGlobal>> contextActions;
  final Future<void> Function(ProdottoGlobal)? onOpenProductDetails;
  final Future<void> Function()? onDeleteSelected;
  final VoidCallback onClearSelection;
  final ValueChanged<ProdottoGlobal?> onDeleteFromGrid;
  final void Function(ProdottoGlobal product) onProductSelected;
  final String selectAllShortcut;
  final String deleteShortcut;
  final String escapeShortcut;

  const _ProductsGrid({
    super.key,
    required this.controller,
    required this.products,
    required this.scrollController,
    required this.visibleColumns,
    this.showSelectionControls = true,
    required this.onStateChanged,
    required this.contextActions,
    required this.onClearSelection,
    required this.onDeleteFromGrid,
    required this.onProductSelected,
    required this.selectAllShortcut,
    required this.deleteShortcut,
    required this.escapeShortcut,
    this.onOpenProductDetails,
    this.onDeleteSelected,
  });

  @override
  State<_ProductsGrid> createState() => _ProductsGridState();
}

class _ProductsGridState extends State<_ProductsGrid> {
  List<DataGridViewColumn> _buildColumns() {
    return ProductGridColumnId.values
        .where(widget.visibleColumns.contains)
        .map(
          (colId) => DataGridViewColumn(
            id: colId.storageKey,
            label: productGridColumnLabel(context.l10n, colId),
            width: _columnWidth(colId),
            numeric: _isNumericColumn(colId),
            // Il nome e' l'unica colonna che guadagna dalla larghezza extra:
            // e' il testo lungo che merita le decine di pixel rimaste libere,
            // e su schermi stretti le colonne in piu' restano raggiungibili
            // con lo scorrimento orizzontale.
            flexible: colId == ProductGridColumnId.nome,
          ),
        )
        .toList();
  }

  List<DataGridViewRowData<ProdottoGlobal>> _buildRows() {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final errorColor = theme.colorScheme.error;
    return widget.products.map((product) {
      final info = ProdottoDisplayInfo.fromProdotto(product, context.l10n);
      final pricing = ProdottoUtils.getPricingInfo(product);
      final statusColor = switch (product.status.trim()) {
        'publish' => customColors.successColor,
        'draft' || 'pending' => customColors.warningColor,
        'private' => theme.colorScheme.secondary,
        _ => theme.primaryColor,
      };
      final isDraft = product.status.trim().toLowerCase() == 'draft';
      return DataGridViewRowData<ProdottoGlobal>(
        id: '${product.id ?? 0}',
        value: product,
        foregroundColor: !info.inStock
            ? errorColor
            : (isDraft ? customColors.warningColor : null),
        backgroundColor: !info.inStock
            ? customColors.stockUnavailable.withValues(alpha: 0.12)
            : (isDraft
                  ? customColors.warningColor.withValues(alpha: 0.12)
                  : null),
        cells: <String, Widget>{
          ProductGridColumnId.preview.storageKey: Center(
            child: DataGridViewImagePreview(
              imageUrl: product.immagineUrl,
              semanticLabel: 'Anteprima ${info.nome}',
              size: 56,
              hoverPreviewSize: 300,
              muted: !info.inStock,
            ),
          ),
          // Sotto il nome non ripetiamo piu' il codice articolo: esiste gia'
          // la colonna dedicata, e la riga resta cosi' alta quanto la
          // miniatura, non il doppio.
          ProductGridColumnId.nome.storageKey: Text(
            info.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          ProductGridColumnId.sku.storageKey: Text(
            info.codiceProdotto.isEmpty ? '-' : info.codiceProdotto,
            overflow: TextOverflow.ellipsis,
          ),
          ProductGridColumnId.barcode.storageKey: Text(
            info.barcodeInterno.isEmpty ? '-' : info.barcodeInterno,
            overflow: TextOverflow.ellipsis,
          ),
          ProductGridColumnId.categoria.storageKey: Text(
            info.categoria,
            overflow: TextOverflow.ellipsis,
          ),
          ProductGridColumnId.prezzo.storageKey: Text(pricing.prezzoLabel),
          ProductGridColumnId.sconto.storageKey: Text(pricing.scontoLabel),
          ProductGridColumnId.disponibilita.storageKey: _StatusChip(
            label: info.disponibilita,
            color: info.inStock
                ? customColors.stockAvailable
                : customColors.stockUnavailable,
          ),
          ProductGridColumnId.quantita.storageKey: _QuantityChip(
            value: product.quantitaTotaleVarianti,
            color: product.quantitaTotaleVarianti > 0
                ? customColors.stockAvailable
                : customColors.stockUnavailable,
          ),
          ProductGridColumnId.varianti.storageKey: Text(
            '${product.varianti?.length ?? 0}',
          ),
          ProductGridColumnId.stato.storageKey: _StatusChip(
            label: info.status,
            color: statusColor,
          ),
          ProductGridColumnId.marca.storageKey: Text(
            product.marca ?? '-',
            overflow: TextOverflow.ellipsis,
          ),
        },
      );
    }).toList();
  }

  static double _columnWidth(ProductGridColumnId id) => switch (id) {
    ProductGridColumnId.preview => 112,
    ProductGridColumnId.nome => 240,
    ProductGridColumnId.sku => 150,
    ProductGridColumnId.barcode => 150,
    ProductGridColumnId.categoria => 180,
    ProductGridColumnId.prezzo || ProductGridColumnId.sconto => 120,
    ProductGridColumnId.disponibilita => 140,
    ProductGridColumnId.quantita || ProductGridColumnId.varianti => 100,
    ProductGridColumnId.stato => 120,
    ProductGridColumnId.marca => 140,
  };

  static bool _isNumericColumn(ProductGridColumnId id) =>
      id == ProductGridColumnId.prezzo ||
      id == ProductGridColumnId.sconto ||
      id == ProductGridColumnId.quantita ||
      id == ProductGridColumnId.varianti;

  Future<void> _selectProduct(ProdottoGlobal product) async {
    widget.controller.selezionaProdottoLocal(product);
    widget.onProductSelected(product);
  }

  void _toggleBulkSelection(ProdottoGlobal product, bool selected) {
    final id = product.id;
    if (id == null || id <= 0) return;
    final current = widget.controller.selectedProductIds;
    final next = <int>{...current};
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.controller.setBulkSelectionByIds(next);
    widget.onStateChanged();
  }

  void _toggleAllVisible(bool selected) {
    if (selected) {
      final ids = widget.products
          .map((product) => product.id)
          .whereType<int>()
          .where((id) => id > 0);
      widget.controller.setBulkSelectionByIds({
        ...widget.controller.selectedProductIds,
        ...ids,
      });
    } else {
      final visibleIds = widget.products
          .map((product) => product.id)
          .whereType<int>()
          .toSet();
      widget.controller.setBulkSelectionByIds(
        widget.controller.selectedProductIds.where(
          (id) => !visibleIds.contains(id),
        ),
      );
    }
    widget.onStateChanged();
  }

  Widget _buildDesktopGrid() {
    return DataGridView<ProdottoGlobal>(
      columns: _buildColumns(),
      rows: _buildRows(),
      // Il pane genitore disegna gia l'unica cornice della sezione: la
      // griglia non ne aggiunge una seconda sopra.
      framed: false,
      verticalScrollController: widget.scrollController,
      selectedRowId: '${widget.controller.prodottoSelezionato?.id ?? ''}',
      selectedRowIds: widget.controller.selectedProductIds
          .map((id) => '$id')
          .toSet(),
      showCheckboxes: widget.showSelectionControls,
      selectAllShortcut: widget.selectAllShortcut,
      deleteShortcut: widget.deleteShortcut,
      escapeShortcut: widget.escapeShortcut,
      onRowChecked: widget.showSelectionControls ? _toggleBulkSelection : null,
      onSelectAll: widget.showSelectionControls
          ? (selected) {
              _toggleAllVisible(false);
            }
          : null,
      onDeleteShortcut: widget.showSelectionControls
          ? widget.onDeleteFromGrid
          : null,
      onEscapeShortcut: widget.showSelectionControls
          ? widget.onClearSelection
          : null,
      onRowSelected: (product) {
        Future<void>(() => _selectProduct(product));
      },
      onRowDoubleTap: (product) {
        if (widget.onOpenProductDetails == null) return;
        Future<void>(() async {
          await _selectProduct(product);
          await widget.onOpenProductDetails!(product);
        });
      },
      contextActions: widget.contextActions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.controller.selectedProductsCount;
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    // Nessuna card attorno alla tabella: il pane che ci ospita ha gia il suo
    // bordo, e aggiungerne uno qui produceva due cornici a 12px di distanza
    // (il "bordo dentro il bordo") tolgendo 25px per lato alle colonne, che
    // su smartphone sono la larghezza che rende leggibile il nome prodotto.
    return Column(
      children: [
        if (selectedCount > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              _kEdgeInset,
              _kEdgeInsetVertical,
              _kEdgeInset,
              _kEdgeInsetVertical,
            ),
            decoration: BoxDecoration(
              color: customColors.selectedCardBackground,
              border: Border(
                bottom: BorderSide(
                  color: theme.primaryColor.withValues(alpha: 0.22),
                ),
              ),
            ),
            child: Wrap(
              spacing: _kControlGap,
              runSpacing: _kControlGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.checklist_rtl, size: 20, color: theme.primaryColor),
                Text(
                  '$selectedCount prodotti selezionati',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.controller.clearBulkSelection();
                    widget.onStateChanged();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: Text(context.l10n.prodottiDeseleziona),
                ),
                FilledButton.icon(
                  onPressed: widget.onDeleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.commonDelete),
                ),
              ],
            ),
          ),
          const SizedBox(height: _kControlGap),
        ],
        Expanded(child: _buildDesktopGrid()),
      ],
    );
  }
}

// ===========================================================================
// _BusyOverlay
// ===========================================================================

class _BusyOverlay extends StatelessWidget {
  final String message;
  const _BusyOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AbsorbPointer(
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(18),
              color: theme.dialogTheme.backgroundColor ?? theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Operazione in corso',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// _StatusChip
// ===========================================================================

// TEST DISATTIVATO: renderer custom della griglia reale.
// ignore: unused_element
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  final int value;
  final Color color;

  const _QuantityChip({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kControlGap,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          '$value',
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// _ImageCell
// ===========================================================================

// TEST DISATTIVATO: renderer custom della griglia reale.
// ignore: unused_element
class _ImageCell extends StatelessWidget {
  final String? imageUrl;
  final String semanticLabel;
  final VoidCallback onOpenLarge;

  const _ImageCell({
    required this.imageUrl,
    required this.semanticLabel,
    required this.onOpenLarge,
  });

  @override
  Widget build(BuildContext context) {
    final safeUrl = (resolveImageUrl(imageUrl) ?? '').trim();
    final hasImage = safeUrl.isNotEmpty;
    final theme = Theme.of(context);

    return Tooltip(
      waitDuration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      richMessage: hasImage
          ? TextSpan(
              children: [
                WidgetSpan(
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        safeUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 264,
                        cacheHeight: 264,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const TextSpan(text: ''),
      child: GestureDetector(
        onTap: hasImage ? onOpenLarge : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.18),
            ),
            color: theme.primaryColor.withValues(alpha: 0.04),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: hasImage
                ? Image.network(
                    safeUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                    cacheHeight: 96,
                    errorBuilder: (_, __, ___) => _placeholder(context),
                  )
                : _placeholder(context),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Icon(
    Icons.image_outlined,
    color: Theme.of(context).primaryColor.withValues(alpha: 0.55),
    semanticLabel: semanticLabel,
  );
}

// ===========================================================================
// _FiltersBar
// ===========================================================================

class _FiltersBar extends StatefulWidget {
  final ProdottiGestioneController controller;
  final int selectedCount;
  final VoidCallback onStateChanged;
  final ValueChanged<bool> onHideOutOfStockChanged;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenColumns;

  const _FiltersBar({
    required this.controller,
    required this.selectedCount,
    required this.onStateChanged,
    required this.onHideOutOfStockChanged,
    this.onRefresh,
    this.onOpenColumns,
  });

  @override
  _FiltersBarState createState() => _FiltersBarState();
}

class _FiltersBarState extends State<_FiltersBar> {
  final _valueCtrl = TextEditingController();
  final _campoCtrl = TextEditingController();
  Timer? _searchDebounce;
  CampoFiltroProdotto _campo = CampoFiltroProdotto.ricercaRapida;
  OperatoreFiltroProdotto _operatore = OperatoreFiltroProdotto.contiene;
  // null = default automatico (retratto su stretto, espanso su desktop).
  // Dopo il primo tap manuale il valore resta sotto controllo utente.
  bool? _espanso;

  @override
  void initState() {
    super.initState();
    _valueCtrl.text = widget.controller.filtroRicerca;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _campoCtrl.text = _campoLabel(context, _campo);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _valueCtrl.dispose();
    _campoCtrl.dispose();
    super.dispose();
  }

  String _campoLabel(BuildContext context, CampoFiltroProdotto c) =>
      ProdottoFilterEngine.campoLabel(context.l10n, c);
  String _operatoreLabel(BuildContext context, OperatoreFiltroProdotto o) =>
      ProdottoFilterEngine.operatoreLabel(context.l10n, o);
  String _operatoreTooltip(BuildContext context, OperatoreFiltroProdotto o) =>
      ProdottoFilterEngine.operatoreTooltip(context.l10n, o);
  bool _operatoreDisponibile(OperatoreFiltroProdotto o) =>
      ProdottoFilterEngine.supportsOperator(_campo, o);
  List<OperatoreFiltroProdotto> _operators() =>
      ProdottoFilterEngine.orderedOperators();

  String _ordinamentoLabel(OrdinamentoProdotti o) => switch (o) {
    OrdinamentoProdotti.nomeCrescente => 'Nome (A-Z)',
    OrdinamentoProdotti.nomeDecrescente => 'Nome (Z-A)',
    OrdinamentoProdotti.prezzoCrescente => 'Prezzo (Crescente)',
    OrdinamentoProdotti.prezzoDecrescente => 'Prezzo (Decrescente)',
    OrdinamentoProdotti.nessuno => 'Ordina per...',
  };

  void _scheduleQuickSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.controller.setFiltroRicerca(value);
      widget.onStateChanged();
    });
  }

  void _onCampoChanged(CampoFiltroProdotto value) {
    final text = _valueCtrl.text;
    setState(() {
      if (_campo == CampoFiltroProdotto.ricercaRapida &&
          value != CampoFiltroProdotto.ricercaRapida) {
        _searchDebounce?.cancel();
        widget.controller.cancellaFiltro();
      }
      _campo = value;
      _campoCtrl.text = _campoLabel(context, value);
      if (!_operatoreDisponibile(_operatore)) {
        _operatore =
            ProdottoFilterEngine.isNumericField(value) ||
                ProdottoFilterEngine.isBooleanField(value)
            ? OperatoreFiltroProdotto.uguale
            : OperatoreFiltroProdotto.contiene;
      }
      _valueCtrl.text = text;
      _valueCtrl.selection = TextSelection.collapsed(offset: text.length);
    });
    if (value == CampoFiltroProdotto.ricercaRapida) {
      _searchDebounce?.cancel();
      widget.controller.setFiltroRicerca(text);
    }
    widget.onStateChanged();
  }

  void _applyFilter() {
    final raw = _valueCtrl.text.trim();
    if (raw.isEmpty) return;
    final resolved =
        ProdottoFilterEngine.resolveCampoFromInput(
          context.l10n,
          _campoCtrl.text,
        ) ??
        _campo;
    if (resolved == CampoFiltroProdotto.ricercaRapida) {
      _searchDebounce?.cancel();
      widget.controller.setFiltroRicerca(raw);
      widget.onStateChanged();
      return;
    }
    if (!_operatoreDisponibile(_operatore)) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_gestisci',
        'Operatore non disponibile per il campo selezionato.',
      );
      return;
    }
    widget.controller.addFiltroProdotto(
      campo: resolved,
      operatore: _operatore,
      valoreInput: raw,
    );
    _valueCtrl.clear();
    widget.onStateChanged();
  }

  void _clearAll() {
    _valueCtrl.clear();
    widget.controller.cancellaFiltro();
    widget.controller.clearFiltriProdotto();
    widget.controller.setNascondiProdottiEsauriti(false);
    widget.onStateChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final searchWidth = narrow ? constraints.maxWidth : 320.0;
        // Default automatico solo finche l'utente non sceglie: retratto su
        // smartphone per lasciare spazio al datagrid, espanso su desktop.
        // Dopo il primo tap vale solo la scelta manuale.
        final espanso = _espanso ?? !narrow;
        void toggleEspanso() => setState(() => _espanso = !espanso);
        // Chiuso e una toolbar: solo icona, etichetta e freccia, senza riquadro
        // per non contendere spazio alla griglia. Aperto diventa un pannello con
        // riempimento tonale, che lo distingue dal fondo del pane senza
        // aggiungere un secondo bordo accanto a quello del pane stesso.
        return Container(
          margin: const EdgeInsets.fromLTRB(
            _kEdgeInset,
            _kEdgeInsetVertical,
            _kEdgeInset,
            _kEdgeInsetVertical,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kEdgeInset,
            vertical: _kEdgeInsetVertical,
          ),
          decoration: BoxDecoration(
            color: espanso
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: toggleEspanso,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            color: theme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: _kControlGap),
                          Text(
                            'Filtro',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: toggleEspanso,
                            tooltip: espanso
                                ? 'Riduci filtri'
                                : 'Espandi filtri',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              espanso ? Icons.expand_less : Icons.expand_more,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _CommandIconButton(
                    onPressed: widget.onOpenColumns,
                    icon: Icons.view_column_outlined,
                    tooltip: context.l10n.prodottiScegliColonne,
                    color: theme.primaryColor,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: espanso
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: _kControlGap),
                          Wrap(
                            spacing: _kControlGap,
                            runSpacing: _kControlGap,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: searchWidth,
                                child: TextField(
                                  controller: _valueCtrl,
                                  decoration: InputDecoration(
                                    labelText:
                                        _campo ==
                                            CampoFiltroProdotto.ricercaRapida
                                        ? 'Ricerca rapida'
                                        : 'Valore filtro',
                                    hintText:
                                        _campo ==
                                            CampoFiltroProdotto.ricercaRapida
                                        ? 'Cerca su tutti i campi'
                                        : 'Es: Nike, 1, disponibile',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _valueCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchDebounce?.cancel();
                                              setState(
                                                () => _valueCtrl.clear(),
                                              );
                                              if (_campo ==
                                                  CampoFiltroProdotto
                                                      .ricercaRapida) {
                                                widget.controller
                                                    .cancellaFiltro();
                                                widget.onStateChanged();
                                              }
                                            },
                                          )
                                        : null,
                                  ),
                                  onChanged: (v) {
                                    if (_campo ==
                                        CampoFiltroProdotto.ricercaRapida) {
                                      _scheduleQuickSearch(v);
                                    }
                                    setState(() {});
                                  },
                                  onSubmitted: (_) => _applyFilter(),
                                ),
                              ),
                              SizedBox(
                                width: narrow
                                    ? (constraints.maxWidth - _kControlGap) / 2
                                    : 220,
                                child:
                                    DropdownButtonFormField<
                                      CampoFiltroProdotto
                                    >(
                                      initialValue: _campo,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText:
                                            context.l10n.prodottiCampoFiltro,
                                        isDense: true,
                                      ),
                                      onChanged: (v) {
                                        if (v != null) _onCampoChanged(v);
                                      },
                                      items: CampoFiltroProdotto.values
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                _campoLabel(context, c),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                              ),
                              SizedBox(
                                width: narrow
                                    ? (constraints.maxWidth - _kControlGap) / 2
                                    : 180,
                                child:
                                    DropdownButtonFormField<
                                      OperatoreFiltroProdotto
                                    >(
                                      initialValue: _operatore,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText:
                                            context.l10n.prodottiOperatore,
                                        isDense: true,
                                      ),
                                      onChanged: (v) {
                                        if (v != null)
                                          setState(() => _operatore = v);
                                      },
                                      items: _operators()
                                          .where(_operatoreDisponibile)
                                          .map(
                                            (o) => DropdownMenuItem(
                                              value: o,
                                              child: Tooltip(
                                                waitDuration: const Duration(
                                                  milliseconds: 850,
                                                ),
                                                message: _operatoreTooltip(
                                                  context,
                                                  o,
                                                ),
                                                child: Text(
                                                  _operatoreLabel(context, o),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                              ),
                              FilledButton.icon(
                                onPressed: _applyFilter,
                                icon: const Icon(Icons.add),
                                label: Text(
                                  _campo == CampoFiltroProdotto.ricercaRapida
                                      ? 'Applica ricerca'
                                      : 'Aggiungi filtro',
                                ),
                              ),
                              _CommandIconButton(
                                onPressed: widget.onRefresh == null
                                    ? null
                                    : () => widget.onRefresh!(),
                                icon: Icons.refresh,
                                tooltip: context.l10n.prodottiAggiornaCache,
                                color: theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: _kControlGap),
                          Wrap(
                            spacing: _kControlGap,
                            runSpacing: _kControlGap,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: narrow ? constraints.maxWidth : 260,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.inputDecorationTheme.fillColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child:
                                          DropdownButton<OrdinamentoProdotti>(
                                            value: widget
                                                .controller
                                                .ordinamentoCorrente,
                                            isExpanded: true,
                                            icon: Icon(
                                              Icons.sort,
                                              color: theme.primaryColor,
                                            ),
                                            onChanged: (v) {
                                              if (v != null) {
                                                widget.controller
                                                    .setOrdinamento(v);
                                                widget.onStateChanged();
                                              }
                                            },
                                            items: OrdinamentoProdotti.values
                                                .map(
                                                  (o) => DropdownMenuItem(
                                                    value: o,
                                                    child: Text(
                                                      _ordinamentoLabel(o),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              FilterChip(
                                selected:
                                    widget.controller.nascondiProdottiEsauriti,
                                showCheckmark: true,
                                avatar: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.prodottiNonMostrareEsauriti,
                                ),
                                onSelected: (value) {
                                  widget.onHideOutOfStockChanged(value);
                                  setState(() {});
                                },
                              ),
                              TextButton.icon(
                                onPressed: widget.controller.hasFiltroAttivo
                                    ? _clearAll
                                    : null,
                                icon: const Icon(Icons.clear_all),
                                label: Text(context.l10n.prodottiCancellaTutti),
                              ),
                            ],
                          ),
                          if (widget.controller.nascondiProdottiEsauriti ||
                              widget
                                  .controller
                                  .filtriProdottoAttivi
                                  .isNotEmpty) ...[
                            const SizedBox(height: _kControlGap),
                            Wrap(
                              spacing: _kControlGap,
                              runSpacing: _kControlGap,
                              children: [
                                if (widget.controller.nascondiProdottiEsauriti)
                                  InputChip(
                                    label: Text(
                                      context.l10n.prodottiEsauritiNascosti,
                                    ),
                                    onDeleted: () {
                                      widget.onHideOutOfStockChanged(false);
                                      setState(() {});
                                    },
                                  ),
                                for (
                                  int i = 0;
                                  i <
                                      widget
                                          .controller
                                          .filtriProdottoAttivi
                                          .length;
                                  i++
                                )
                                  InputChip(
                                    label: Text(
                                      widget.controller.filtriProdottoAttivi[i]
                                          .chipLabel(context.l10n),
                                    ),
                                    onDeleted: () {
                                      widget.controller.removeFiltroProdottoAt(
                                        i,
                                      );
                                      widget.onStateChanged();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommandIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final Color color;

  const _CommandIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.10),
        foregroundColor: color,
      ),
    );
  }
}
