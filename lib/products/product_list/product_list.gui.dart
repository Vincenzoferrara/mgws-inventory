import '../../l10n/error_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'product_list.code.dart';
import '../class_products.dart';
import '../product_grid_fields.dart';
import '../product_editor/product_editor.gui.dart';
import 'product_list_view.gui.dart';
import '../../theme/theme.dart';
import '../../notification/notification_service.dart';
import '../../settings/app_settings.dart';
import '../../settings/machine_ui_preferences.dart';
import '../../reuse_class/logic/memory_usage.dart';
import '../../reuse_class/gui/notification_recap_dialog.dart';
import '../../reuse_class/datagridview/datagridview_list.gui.dart';
import '../../reuse_class/datagridview/datagridview_image_preview.dart';
import '../../reuse_class/image_url_resolver.dart';
import '../../log_viewer/app_logger.dart';
import '../../l10n/extensions.dart';
import '../../home/home_section_requests.dart';
import '../../report/print_job.dart';

// ---------------------------------------------------------------------------
// Costanti
// ---------------------------------------------------------------------------

const double _kControlGap = kDataGridControlGap;

// TEST DISATTIVATO 1: field della colonna checkbox nativa.
// const String _kFieldSelection = '__selection';
// TEST DISATTIVATO: field prodotto usato dalla griglia reale, non dal demo docs.
// const String _kFieldProductId = '__productId';

// TEST DISATTIVATO 4: logger usato solo dalla selezione custom.
// final _log = AppLogger();

// ---------------------------------------------------------------------------
// Enum azioni contesto
// ---------------------------------------------------------------------------

enum _ProductContextAction {
  crea,
  modifica,
  modificaInMassa,
  printLabels,
  elimina,
}

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

/// La lista Prodotti e' una [DataGridListView] sui campi di [ProdottoGlobal]:
/// filtri, ricerca, ordinamento, colonne e paginazione sono della libreria.
/// Qui restano le cose che solo i prodotti hanno: varianti caricate per la
/// pagina visibile, prezzi calcolati dalle varianti, "nascondi esauriti",
/// stampa etichette e il selettore della cassa.
class ProdottiGestisciPageState extends State<ProdottiGestisciPage>
    with AutomaticKeepAliveClientMixin<ProdottiGestisciPage> {
  // ── Controller e settings ────────────────────────────────────────────────
  final _controller = ProdottiGestioneController();
  final _appSettings = AppSettings();
  final _machineUiPreferences = MachineUiPreferences();
  late final DataGridListController<ProdottoGlobal> _listController;
  final ValueNotifier<ProdottoGlobal?> _selectedProductNotifier =
      ValueNotifier<ProdottoGlobal?>(null);
  final ValueNotifier<bool> _selectedProductVariantsLoading =
      ValueNotifier<bool>(false);

  /// Cambia a ogni spunta della cassa. La pagina di dettaglio su telefono è
  /// una route a parte: il setState di questa pagina non la ricostruisce,
  /// quindi le caselle restavano ferme senza questo segnale.
  final ValueNotifier<int> _cassaSelectionVersion = ValueNotifier<int>(0);
  final Map<int, Set<int>> _selectedCassaVariantIdsByProductId =
      <int, Set<int>>{};

  /// Prodotti semplici selezionati per la cassa (senza varianti).
  final Set<int> _selectedCassaSimpleProductIds = <int>{};

  bool _settingsReady = false;
  bool _nascondiEsauriti = false;
  bool _disposed = false;

  bool get _alive => mounted && !_disposed;
  int get _selectedCassaVariantsCount =>
      _selectedCassaVariantIdsByProductId.values.fold<int>(
        0,
        (sum, ids) => sum + ids.length,
      ) +
      _selectedCassaSimpleProductIds.length;

  Timer? _prefetchDebounce;

  /// Contatore dei prefetch di finestra in corso: la barra in alto mostra il
  /// riempimento "in tempo reale" della cache varianti (cambio pagina,
  /// filtro, righe per pagina, apertura iniziale) oltre al caricamento.
  int _cacheRefillDepth = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _listController = DataGridListController<ProdottoGlobal>(
      fields: ProdottoGlobal.gridFields,
      idOf: _idOf,
      loadPage: _loadPage,
      cacheKey: ProdottiCache.cacheKey,
      // I filtri dei prodotti guardano anche dentro le varianti, che il
      // server non sa filtrare: la lista lavora sempre sull'elenco completo.
      serverFiltering: false,
      // Il controller prodotti segna la cache da ricaricare quando modifica
      // qualcosa: fino ad allora l'elenco vale senza scadenza, come prima.
      cacheTtl: null,
    );
    _listController.addListener(_onListChanged);
    unawaited(_initSettings());
  }

  @override
  void dispose() {
    _disposed = true;
    _prefetchDebounce?.cancel();
    _listController.removeListener(_onListChanged);
    _listController.dispose();
    _selectedProductNotifier.dispose();
    _selectedProductVariantsLoading.dispose();
    _cassaSelectionVersion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  static String _idOf(ProdottoGlobal product) => '${product.id ?? 0}';

  static bool _soloDisponibili(ProdottoGlobal product) => product.inStock;

  Future<void> _initSettings() async {
    await _appSettings.init();
    await _machineUiPreferences.init();
    if (!_alive) return;
    _nascondiEsauriti = _appSettings.hideOutOfStockProducts;
    _listController.localWhere = _nascondiEsauriti ? _soloDisponibili : null;
    if (_appSettings.persistProductFilters) {
      _listController.restore(
        filters: ProdottiGestioneController.sharedFiltriProdotto,
      );
    }
    setState(() => _settingsReady = true);
  }

  Future<PaginatedResult<ProdottoGlobal>> _loadPage(
    DataGridPageRequest request,
  ) {
    return _controller.caricaPaginaProdotti(
      page: request.page,
      perPage: request.perPage,
      forceRefresh: request.forceRefresh,
    );
  }

  /// La lista e' cambiata: la selezione multipla torna al controller prodotti
  /// (stampa, eliminazione e modifica in massa la leggono da li') e i filtri
  /// avanzati restano ricordati per la prossima apertura.
  void _onListChanged() {
    if (!_alive) return;
    if (!widget.modalitaCassa) {
      _controller.setBulkSelectionByIds(
        _listController.checkedIds.map(int.tryParse).whereType<int>(),
      );
    }
    ProdottiGestioneController.sharedFiltriProdotto = List<DataGridFilter>.of(
      _listController.filters,
    );
    setState(() {});
  }

  Future<void> _setHideOutOfStockProducts(
    bool value, {
    bool persist = true,
  }) async {
    setState(() => _nascondiEsauriti = value);
    _listController.localWhere = value ? _soloDisponibili : null;
    _listController.refresh();
    if (persist) await _appSettings.setHideOutOfStockProducts(value);
  }

  Future<void> _reloadProducts() => _listController.reload(force: true);

  void _onLoadError(BuildContext context, DataGridLoadError error) {
    final l10n = context.l10n;
    NotificationService.instance.messageBar(
      'warning',
      'prodotti_gestisci',
      error.partial
          ? l10n.productsLoadPartial
          : error.usingCache
          ? l10n.productsServerUnreachableUsingLocal
          : l10n.productsServerUnreachableNone,
    );
  }

  // ── Varianti della pagina visibile ───────────────────────────────────────

  // Pre-fetch varianti della pagina visibile (valore esatto del dropdown),
  // separato dal ridisegno della griglia. Parte da ogni cambio delle righe
  // visibili: caricamento iniziale, cambio pagina, cambio righe per pagina,
  // applicazione filtro, scroll infinito.
  void _schedulePagePrefetch(List<ProdottoGlobal> _) {
    if (_disposed) return;
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(
      const Duration(milliseconds: 200),
      _prefetchCurrentWindow,
    );
  }

  /// Righe visibili all'ultimo aggiornamento dal server, per riconoscere un
  /// vero cambio pagina dai ridisegni dovuti all'arrivo delle varianti.
  String? _ultimaFinestraAggiornata;

  void _prefetchCurrentWindow() {
    if (!_alive) return;
    final items = _listController.visibleItems;
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
    final rimossi = ProdottiCache.pruneVariantsOutside(keepIds);
    _controller.staccaVariantiFuori(keepIds);

    // Questo metodo parte a ogni ridisegno, anche per ogni variante che
    // arriva: il server si interroga solo quando cambia l'insieme di righe
    // visibili (cambio pagina, filtro, ordinamento). Durante il primo
    // caricamento i prodotti sono appena scaricati, quindi si annota solo
    // la finestra.
    final firma = (keepIds.toList()..sort()).join(',');
    final finestraNuova = firma != _ultimaFinestraAggiornata;
    _ultimaFinestraAggiornata = firma;
    final aggiornaDalServer = finestraNuova && !_listController.isLoading;

    _cacheRefillDepth++;
    setState(() {});
    unawaited(
      Future<void>(() async {
        if (aggiornaDalServer) {
          await _controller.aggiornaProdottiVisibili(keepIds.toList());
        }
        await _controller.prefetchVariantiVisibili(
          items,
          concurrency: ProdottiGestioneController.prefetchWindowConcurrency,
        );
      }).whenComplete(() {
        if (!_alive) return;
        if (rimossi > 0) {
          log.i(
            '[perf-trace] cache finestra prune rimossi=$rimossi '
            'keep=${keepIds.length} '
            'rssMb=${residentMemoryMb()}',
          );
        }
        final warning = _controller.consumeLastLoadWarning();
        if (warning != null) {
          NotificationService.instance.messageBar(
            'warning',
            'prodotti_gestisci',
            warning(context.l10n),
          );
        }
        _cacheRefillDepth--;
        setState(() {});
      }),
    );
  }

  void _syncSelectedProductDisplay() {
    _selectedProductNotifier.value = _controller.prodottoSelezionato;
    if (_selectedProductNotifier.value == null) {
      _selectedProductVariantsLoading.value = false;
      _listController.select(null);
    }
  }

  void _handleProductSelected(ProdottoGlobal product) {
    _controller.selezionaProdottoLocal(product);
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

  // ── Azioni prodotto ──────────────────────────────────────────────────────

  Future<void> _handleProductAction(
    _ProductContextAction action,
    ProdottoGlobal product,
  ) async {
    switch (action) {
      case _ProductContextAction.crea:
        final created = await openProductEditor(context);
        if (created == true) await _reloadProducts();

      case _ProductContextAction.modifica:
        final updated = await openProductEditor(
          context,
          prodottoIdDaModificare: product.id,
          codiceProdotto: product.codiceProdotto,
        );
        if (updated == true) await _reloadProducts();

      case _ProductContextAction.modificaInMassa:
        if (_controller.selectedProductsCount <= 1) return;
        _controller.selezionaProdotto(product);
        _syncSelectedProductDisplay();

      case _ProductContextAction.printLabels:
        final selected = _controller.selectedProducts;
        final useSelection = selected.any((entry) => entry.id == product.id);
        await _printLabels(useSelection ? selected : [product]);

      case _ProductContextAction.elimina:
        await _deleteProducts(product);
    }
  }

  /// Opens "Templates and print" on labels for [products]: one line per
  /// variant, one label per piece in stock. Missing variants are loaded first.
  Future<void> _printLabels(List<ProdottoGlobal> products) async {
    if (products.isEmpty) return;
    final localeName = context.l10n.localeName;
    try {
      final withVariants = await _controller.productsWithVariants(products);
      final job = labelJobFromProducts(withVariants, localeName);
      if (job.rows.isEmpty) {
        if (!mounted) return;
        NotificationService.instance.messageBar(
          'warning',
          'prodotti',
          context.l10n.productsPrintLabelsNoStock,
        );
        return;
      }
      pendingPrintJob.value = job;
      requestHomeSection(printSectionId);
    } catch (error) {
      if (!mounted) return;
      NotificationService.instance.messageBar(
        'errore',
        'prodotti',
        context.l10n.productsPrintLabelsError(
          localizedErrorText(context.l10n, error),
        ),
      );
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
        ? context.l10n.productsDeletingMany(toDelete.length)
        : context.l10n.productsDeletingOne;

    final (bulkResult, success) = await _listController.runBusy(
      label,
      () async {
        if (useBulk) {
          final r = await _controller.deleteSelectedProducts(
            force: _appSettings.forceDelete,
          );
          return (r, r.failedCount == 0);
        } else {
          final ok = await _controller.eliminaProdotto(anchor.id ?? 0);
          return (null, ok);
        }
      },
    );

    if (!mounted) return;

    final severity = success
        ? 'successo'
        : (bulkResult?.successCount ?? 0) > 0
        ? 'warning'
        : 'errore';

    final l10n = context.l10n;
    final message = success
        ? useBulk
              ? bulkResult!.message(l10n)
              : l10n.productsDeletedOne
        : useBulk
        ? (bulkResult?.message(l10n) ?? l10n.productsDeletePartial)
        : l10n.productsDeleteFailed;

    NotificationService.instance.messageBar(
      severity,
      'prodotti_gestisci',
      message,
    );
    if (success || (bulkResult?.successCount ?? 0) > 0) {
      _listController.clearChecked();
      await _reloadProducts();
    }
  }

  /// Canc sulla griglia ed "Elimina" della barra di selezione: con righe
  /// spuntate elimina quelle, altrimenti la riga evidenziata.
  Future<void> _deleteFromGrid(ProdottoGlobal? product) async {
    if (_listController.isBusy) return;
    if (_controller.hasSelectedProducts) {
      final selected = _controller.selectedProducts;
      if (selected.isEmpty) return;
      await _deleteProducts(selected.first);
      return;
    }
    if (product != null) await _deleteProducts(product);
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
    _cassaSelectionVersion.value++;
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
    _cassaSelectionVersion.value++;
  }

  /// Righe spuntate nella griglia del selettore: un prodotto e' spuntato se e'
  /// scelto lui (semplice) o almeno una delle sue varianti.
  Set<String> get _pickerCheckedIds => <String>{
    for (final id in _selectedCassaSimpleProductIds) '$id',
    for (final id in _selectedCassaVariantIdsByProductId.keys) '$id',
  };

  /// Spunta di una riga nel selettore, come la selezione multipla dell'elenco.
  ///
  /// Un prodotto variabile entra con tutte le varianti: e' il prodotto intero
  /// che l'operatore ha spuntato, e il dettaglio resta il posto dove togliere
  /// quelle che non servono.
  Future<void> _togglePickerRow(ProdottoGlobal product, bool selected) async {
    final productId = product.id;
    if (productId == null || productId <= 0) return;
    if (!selected) {
      setState(() {
        _selectedCassaSimpleProductIds.remove(productId);
        _selectedCassaVariantIdsByProductId.remove(productId);
      });
      _cassaSelectionVersion.value++;
      return;
    }
    if (!product.isVariabile) {
      _toggleCassaSimpleProductSelection(product, true);
      return;
    }
    final loaded = await _listController.runBusy(
      context.l10n.productsLoadingVariants,
      () => _controller.productsWithVariants([product]),
    );
    if (!_alive) return;
    final ids = (loaded.first.varianti ?? const <VarianteProductGlobal>[])
        .map((variant) => variant.id)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return;
    setState(() => _selectedCassaVariantIdsByProductId[productId] = ids);
    _cassaSelectionVersion.value++;
  }

  void _clearPickerSelection() {
    if (_pickerCheckedIds.isEmpty) return;
    setState(() {
      _selectedCassaSimpleProductIds.clear();
      _selectedCassaVariantIdsByProductId.clear();
    });
    _cassaSelectionVersion.value++;
  }

  /// I prodotti scelti, ognuno con dentro le sole varianti spuntate.
  ///
  /// Le varianti di una riga spuntata dalla griglia possono essere state
  /// staccate dalla lista nel frattempo (la RAM resta legata alla pagina
  /// visibile): vanno quindi riprese prima di filtrarle.
  Future<List<ProdottoGlobal>> _buildCassaSelectedProducts() async {
    final selectedProducts = <ProdottoGlobal>[];
    final productsById = <int, ProdottoGlobal>{
      for (final product in ProdottiCache.prodotti.items)
        if (product.id != null && product.id! > 0) product.id!: product,
      if (_controller.prodottoSelezionato?.id != null &&
          _controller.prodottoSelezionato!.id! > 0)
        _controller.prodottoSelezionato!.id!: _controller.prodottoSelezionato!,
    };
    final missingVariants = [
      for (final product in productsById.values)
        if (_selectedCassaVariantIdsByProductId.containsKey(product.id) &&
            !product.hasVarianti)
          product,
    ];
    if (missingVariants.isNotEmpty) {
      for (final product in await _controller.productsWithVariants(
        missingVariants,
      )) {
        productsById[product.id!] = product;
      }
    }
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

  List<DataGridViewContextAction<ProdottoGlobal>> _buildContextActions(
    BuildContext context,
  ) {
    if (widget.modalitaCassa) {
      return const <DataGridViewContextAction<ProdottoGlobal>>[];
    }
    final actions = <DataGridViewContextAction<ProdottoGlobal>>[
      DataGridViewContextAction<ProdottoGlobal>(
        label: context.l10n.commonNew,
        icon: Icons.add_circle_outline,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.crea, product),
      ),
      DataGridViewContextAction<ProdottoGlobal>(
        label: context.l10n.commonEdit,
        icon: Icons.edit_outlined,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.modifica, product),
      ),
    ];
    if (_controller.selectedProductsCount > 1) {
      actions.add(
        DataGridViewContextAction<ProdottoGlobal>(
          label: context.l10n.productsBulkEdit,
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
        label: context.l10n.productsPrintLabels,
        icon: Icons.print_outlined,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.printLabels, product),
      ),
    );
    actions.add(
      DataGridViewContextAction<ProdottoGlobal>(
        label: context.l10n.commonDelete,
        icon: Icons.delete_outline,
        onSelected: (product) =>
            _handleProductAction(_ProductContextAction.elimina, product),
      ),
    );
    return actions;
  }

  // ── Refresh stato ────────────────────────────────────────────────────────

  void _refresh() {
    if (!mounted) return;
    _syncSelectedProductDisplay();
    _listController.refresh();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_settingsReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return DataGridListView<ProdottoGlobal>(
      controller: _listController,
      fields: ProdottoGlobal.gridFields,
      idOf: _idOf,
      loadPage: _loadPage,
      cacheKey: ProdottiCache.cacheKey,
      serverFiltering: false,
      localWhere: _nascondiEsauriti ? _soloDisponibili : null,
      detailsOf: _buildDetails,
      cellsOf: _buildCells,
      foregroundOf: _rowForeground,
      backgroundOf: _rowBackground,
      contextActions: _buildContextActions,
      defaultColumns: defaultProductGridColumns,
      defaultMobileColumns: defaultMobileProductGridColumns,
      initialColumns: _appSettings.visibleProductGridColumns,
      onColumnsChanged: _appSettings.setVisibleProductGridColumns,
      initialSplitRatio: _machineUiPreferences.productsManageSplitRatio,
      onSplitRatioChanged: (ratio) =>
          unawaited(_machineUiPreferences.setProductsManageSplitRatio(ratio)),
      minSplitRatio: MachineUiPreferences.minProductsManageSplitRatio,
      maxSplitRatio: MachineUiPreferences.maxProductsManageSplitRatio,
      filterValueHint: context.l10n.productsQuickSearchExample,
      toolbarActions: [
        if (!widget.modalitaCassa)
          DataGridCommandIconButton(
            onPressed: _controller.selectedProductsCount == 0
                ? null
                : () => _printLabels(_controller.selectedProducts),
            icon: Icons.print_outlined,
            tooltip: _controller.selectedProductsCount == 0
                ? context.l10n.productsPrintLabelsSelect
                : context.l10n.productsPrintLabels,
            color: theme.colorScheme.primary,
          ),
      ],
      extraFilters: [
        FilterChip(
          selected: _nascondiEsauriti,
          showCheckmark: true,
          avatar: const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(context.l10n.prodottiNonMostrareEsauriti),
          onSelected: (value) => _setHideOutOfStockProducts(value),
        ),
      ],
      extraActiveChips: [
        if (_nascondiEsauriti)
          InputChip(
            label: Text(context.l10n.prodottiEsauritiNascosti),
            onDeleted: () => _setHideOutOfStockProducts(false),
          ),
      ],
      hasExtraFilters: _nascondiEsauriti,
      // "Cancella tutti" spegne il filtro per questa volta senza cambiare
      // l'impostazione salvata, come prima.
      onClearExtraFilters: () =>
          _setHideOutOfStockProducts(false, persist: false),
      // Nel selettore le spunte non sono la selezione dell'elenco (che serve
      // a stampare o cancellare) ma quella da restituire: stesse caselle,
      // stato diverso.
      checkedIds: widget.modalitaCassa ? _pickerCheckedIds : null,
      onRowChecked: widget.modalitaCassa
          ? (product, selected) =>
                unawaited(_togglePickerRow(product, selected))
          : null,
      onClearChecked: widget.modalitaCassa ? _clearPickerSelection : null,
      checkedLabel: (count) => context.l10n.productsSelectedCount(count),
      // Il selettore non cancella nulla: Canc li' non ha niente da fare.
      onDelete: widget.modalitaCassa ? null : _deleteFromGrid,
      onRowSelected: _handleProductSelected,
      selectedRowsCount: widget.modalitaCassa
          ? _selectedCassaVariantsCount
          : null,
      bottomBar: widget.modalitaCassa ? _buildPickerActionBar(theme) : null,
      extraLoading: _cacheRefillDepth > 0,
      emptyDetailsIcon: Icons.inventory_2_outlined,
      emptyDetailsTitle: (context) => context.l10n.productsSelectAProduct,
      emptyDetailsSubtitle: (context) => context.l10n.productsToSeeDetails,
      onLoadError: _onLoadError,
      onVisibleItemsChanged: _schedulePagePrefetch,
    );
  }

  /// Dettaglio del prodotto: pannello su desktop, pagina su telefono. Ascolta
  /// i segnali della selezione: il prodotto arriva senza varianti e le riceve
  /// dopo il caricamento, e le spunte della cassa cambiano qui.
  Widget _buildDetails(
    BuildContext context,
    ProdottoGlobal product,
    bool inPage,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _selectedProductNotifier,
        _selectedProductVariantsLoading,
        _cassaSelectionVersion,
      ]),
      builder: (context, _) {
        final caricato = _selectedProductNotifier.value;
        final prodotto = caricato?.id == product.id ? caricato! : product;
        return ProdottoDettagliView(
          prodotto: prodotto,
          varianteSelezionata: _controller.varianteSelezionata,
          controller: _controller,
          modalitaSelezioneCassa: widget.modalitaCassa,
          variantiSelezionateCassa: _selectedCassaVariantIdsFor(prodotto),
          onVarianteCassaChecked: (variante, selected) =>
              _toggleCassaVariantSelection(prodotto, variante, selected),
          prodottoSempliceSelezionatoCassa: _selectedCassaSimpleProductIds
              .contains(prodotto.id ?? -1),
          onProdottoSempliceCassaChecked: widget.modalitaCassa
              ? (selected) =>
                    _toggleCassaSimpleProductSelection(prodotto, selected)
              : null,
          variantsLoading:
              caricato?.id == product.id &&
              _selectedProductVariantsLoading.value,
          shortcutToggleEdit: _appSettings.shortcutToggleEdit,
          shortcutSave: _appSettings.shortcutSave,
          shortcutEscape: _appSettings.shortcutEscape,
          showCloseButton: inPage,
          onReload: _reloadProducts,
          onProductDeleted: _refresh,
          onVariantsChanged: _refresh,
        );
      },
    );
  }

  Color? _rowForeground(BuildContext context, ProdottoGlobal product) {
    final customColors = Theme.of(context).extension<AppColorExtension>()!;
    if (!product.isDisponibile) return Theme.of(context).colorScheme.error;
    return _isDraft(product) ? customColors.warningColor : null;
  }

  Color? _rowBackground(BuildContext context, ProdottoGlobal product) {
    final customColors = Theme.of(context).extension<AppColorExtension>()!;
    if (!product.isDisponibile) {
      return customColors.stockUnavailable.withValues(alpha: 0.12);
    }
    return _isDraft(product)
        ? customColors.warningColor.withValues(alpha: 0.12)
        : null;
  }

  static bool _isDraft(ProdottoGlobal product) =>
      product.status.trim().toLowerCase() == 'draft';

  Map<String, Widget> _buildCells(BuildContext context, ProdottoGlobal product) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final info = ProdottoDisplayInfo.fromProdotto(product, context.l10n);
    final pricing = ProdottoUtils.getPricingInfo(product);
    final statusColor = switch (product.status.trim()) {
      'publish' => customColors.successColor,
      'draft' || 'pending' => customColors.warningColor,
      'private' => theme.colorScheme.secondary,
      _ => theme.primaryColor,
    };
    return <String, Widget>{
      'preview': Center(
        child: DataGridViewImagePreview(
          imageUrl: product.immagineUrl,
          semanticLabel: context.l10n.productsPreviewOf(info.nome),
          size: 56,
          hoverPreviewSize: 300,
          muted: !info.inStock,
        ),
      ),
      // Sotto il nome non ripetiamo il codice articolo: esiste gia' la
      // colonna dedicata, e la riga resta alta quanto la miniatura.
      'nome': Text(
        info.nome,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      'codiceArticolo': Text(
        info.codiceProdotto.isEmpty ? '-' : info.codiceProdotto,
        overflow: TextOverflow.ellipsis,
      ),
      'barcode': Text(
        info.barcodeInterno.isEmpty ? '-' : info.barcodeInterno,
        overflow: TextOverflow.ellipsis,
      ),
      'categoria': Text(info.categoria, overflow: TextOverflow.ellipsis),
      'prezzo': Text(pricing.prezzoLabel(context.l10n)),
      'sconto': Text(pricing.scontoLabel(context.l10n)),
      'disponibilita': _StatusChip(
        label: info.disponibilita,
        color: info.inStock
            ? customColors.stockAvailable
            : customColors.stockUnavailable,
      ),
      'giacenza': _QuantityChip(
        value: product.quantitaTotaleVarianti,
        color: product.quantitaTotaleVarianti > 0
            ? customColors.stockAvailable
            : customColors.stockUnavailable,
      ),
      'varianti': Text('${product.varianti?.length ?? 0}'),
      'status': _StatusChip(label: info.status, color: statusColor),
      'marchio': Text(product.marca ?? '-', overflow: TextOverflow.ellipsis),
    };
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
                  : () async {
                      final selected = await _listController.runBusy(
                        context.l10n.productsLoadingVariants,
                        _buildCassaSelectedProducts,
                      );
                      if (!mounted) return;
                      widget.onAggiungiProdotti?.call(selected);
                      Navigator.of(context).pop<List<ProdottoGlobal>>(selected);
                    },
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                selectedCount == 0
                    ? context.l10n.cassaAdd
                    : context.l10n.productsAddCount(selectedCount),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.extension<AppColorExtension>()?.successColor ??
                    context.colors.successColor,
                foregroundColor: context.colors.onColoredSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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

