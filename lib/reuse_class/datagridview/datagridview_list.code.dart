import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../log_viewer/app_logger.dart';
import '../logic/global_pagination_controller.dart';
import 'datagridview.code.dart';
import 'datagridview_cache.dart';
import 'datagridview_filters.dart';

/// Pagina chiesta alla schermata da [DataGridListController].
///
/// Quando la lista lavora sul server, [search], [filters] e [sort] sono
/// quelli scelti dall'utente e hanno tutti un `serverParam`: la schermata li
/// passa alla query. Quando lavora in memoria la lista chiede le pagine una
/// dopo l'altra fino alla fine, con [search] vuota, nessun filtro e nessun
/// ordinamento: filtra e ordina lei sull'elenco completo.
class DataGridPageRequest {
  final int page;
  final int perPage;
  final String search;
  final List<DataGridFilter> filters;
  final DataGridSort? sort;

  /// L'utente ha chiesto di ricaricare: la schermata non deve usare cache
  /// proprie.
  final bool forceRefresh;

  const DataGridPageRequest({
    required this.page,
    required this.perPage,
    this.search = '',
    this.filters = const <DataGridFilter>[],
    this.sort,
    this.forceRefresh = false,
  });

  /// Primo filtro attivo sul campo [fieldName], se c'e'.
  DataGridFilter? filterOn(String fieldName) {
    for (final filter in filters) {
      if (filter.fieldName == fieldName) return filter;
    }
    return null;
  }

  /// Chiave della pagina nella cache: stessa ricerca, stessi filtri, stesso
  /// ordinamento e stessa pagina danno la stessa chiave.
  String get cacheKey => [
    search.trim().toLowerCase(),
    for (final f in filters) f.logExpression,
    if (sort != null) '${sort!.fieldName}:${sort!.ascending ? 'asc' : 'desc'}',
    '$page/$perPage',
  ].join('§');
}

typedef DataGridPageLoader<T> =
    Future<PaginatedResult<T>> Function(DataGridPageRequest request);

/// Esito di un caricamento finito con un errore. [partial] e' vero quando
/// una parte degli elementi e' arrivata prima dell'errore, [usingCache]
/// quando la lista mostra i dati della volta precedente.
class DataGridLoadError {
  final Object error;
  final bool partial;
  final bool usingCache;

  const DataGridLoadError(
    this.error, {
    this.partial = false,
    this.usingCache = false,
  });
}

/// Stato e logica di una lista gestionale: ricerca, filtri, ordinamento,
/// paginazione, caricamento, riga selezionata e righe spuntate.
///
/// Decide da solo dove filtrare. Se tutti i filtri attivi, l'ordinamento e
/// la ricerca si possono chiedere al server (campi con `serverParam`), chiede
/// al server solo la pagina visibile. Altrimenti carica l'elenco completo una
/// volta, lo tiene in [DataGridViewCache] e filtra in memoria.
///
/// Ogni caricamento ha un numero: se l'utente cambia filtro mentre una
/// risposta e' ancora in viaggio, quella risposta arriva con un numero
/// vecchio e viene scartata. Vince sempre l'ultima richiesta.
class DataGridListController<T> extends ChangeNotifier {
  DataGridListController({
    required this.fields,
    required this.idOf,
    required this.loadPage,
    required String cacheKey,
    this.serverFiltering = true,
    this.serverSearch = true,
    this.localWhere,
    this.cacheTtl = const Duration(minutes: 5),
    this.localChunkSize = 100,
    this.localMaxPages = 100,
  }) : cache = DataGridViewCache.of<T>(cacheKey) {
    cache.addListener(_onCacheChanged);
  }

  List<DataGridField<T>> fields;
  final String Function(T item) idOf;
  DataGridPageLoader<T> loadPage;
  final DataGridViewCache<T> cache;

  /// La schermata sa passare filtri e ordinamento al server. Se falso la
  /// lista lavora sempre in memoria.
  bool serverFiltering;

  /// Il server sa cercare per testo libero (`search` di WordPress).
  bool serverSearch;

  /// Filtro in piu' che vive solo in memoria, come "nascondi esauriti" dei
  /// prodotti. Se attivo la lista lavora in memoria.
  bool Function(T item)? localWhere;

  final Duration cacheTtl;
  final int localChunkSize;
  final int localMaxPages;

  final GlobalPaginationController<T> pagination =
      GlobalPaginationController<T>();

  /// Riga evidenziata: e' quella che il pannello dettagli mostra.
  final ValueNotifier<T?> selected = ValueNotifier<T?>(null);

  /// Chiamato quando arriva un errore di caricamento. Senza, l'errore
  /// finisce in [lastError].
  void Function(DataGridLoadError error)? onLoadError;

  /// Chiamato ogni volta che cambiano le righe della pagina visibile.
  void Function(List<T> items)? onVisibleItemsChanged;

  String _search = '';
  final List<DataGridFilter> _filters = <DataGridFilter>[];
  DataGridSort? _sort;
  final Set<String> _checkedIds = <String>{};
  List<T> _filtered = <T>[];
  int _requestSeq = 0;
  bool _loading = false;
  bool _disposed = false;
  bool? _lastModeServer;
  DataGridLoadError? _lastError;
  Timer? _cacheRefreshThrottle;
  int _appliedRevision = -1;

  int _busyDepth = 0;
  String? _busyMessage;

  String get search => _search;
  List<DataGridFilter> get filters => List.unmodifiable(_filters);
  DataGridSort? get sort => _sort;
  bool get isLoading => _loading;
  bool get isBusy => _busyDepth > 0;
  String? get busyMessage => _busyMessage;
  DataGridLoadError? get lastError => _lastError;
  List<T> get visibleItems => pagination.items;

  /// Elementi che passano ricerca e filtri, quando la lista lavora in
  /// memoria. Sul server e' solo la pagina visibile.
  List<T> get filteredItems => List.unmodifiable(_filtered);

  /// Righe trovate in tutto: in memoria quelle filtrate, sul server il
  /// totale dichiarato dal server.
  int get totalRows => usesServer
      ? (pagination.totalItems ?? pagination.items.length)
      : _filtered.length;

  bool get hasActiveFilters =>
      _search.trim().isNotEmpty || _filters.isNotEmpty || _sort != null;

  Set<String> get checkedIds => Set.unmodifiable(_checkedIds);
  int get checkedCount => _checkedIds.length;

  /// Elementi spuntati tra quelli che la lista conosce.
  List<T> get checkedItems {
    if (_checkedIds.isEmpty) return <T>[];
    final source = usesServer ? pagination.items : cache.items;
    return source.where((item) => _checkedIds.contains(idOf(item))).toList();
  }

  DataGridField<T>? field(String name) =>
      DataGridFilterEngine.fieldByName(fields, name);

  /// La lista chiede al server la sola pagina visibile.
  bool get usesServer {
    if (!serverFiltering || localWhere != null) return false;
    if (_search.trim().isNotEmpty && !serverSearch) return false;
    for (final filter in _filters) {
      if (field(filter.fieldName)?.serverParam == null) return false;
    }
    final sort = _sort;
    if (sort != null && field(sort.fieldName)?.serverParam == null) {
      return false;
    }
    return true;
  }

  // ── Comandi ─────────────────────────────────────────────────────────────

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _restart();
  }

  void addFilter(DataGridFilter filter) {
    _filters.add(filter);
    _logFilters('add');
    _restart();
  }

  void removeFilterAt(int index) {
    if (index < 0 || index >= _filters.length) return;
    _filters.removeAt(index);
    _logFilters('remove');
    _restart();
  }

  void setFilters(List<DataGridFilter> filters) {
    _filters
      ..clear()
      ..addAll(filters);
    _restart();
  }

  void clearFilters() {
    if (_filters.isEmpty && _search.isEmpty) return;
    _filters.clear();
    _search = '';
    _logFilters('clear');
    _restart();
  }

  void setSort(DataGridSort? sort) {
    if (_sort == sort) return;
    _sort = sort;
    _restart();
  }

  /// Da chiamare quando cambia [localWhere] o un dato letto dai campi.
  void refresh() {
    if (_disposed) return;
    if (usesServer) {
      notifyListeners();
      return;
    }
    _applyLocal();
  }

  /// Ricarica i dati. Con [force] scarta le cache e torna alla prima pagina.
  Future<void> reload({bool force = false}) async {
    if (force) {
      pagination.goToFirstPage();
      cache.markDirty();
    }
    await _load(force: force);
  }

  Future<void> goToFirstPage() => _goTo(pagination.goToFirstPage);
  Future<void> goToPreviousPage() => _goTo(pagination.goToPreviousPage);
  Future<void> goToNextPage() => _goTo(pagination.goToNextPage);
  Future<void> goToLastPage() => _goTo(pagination.goToLastPage);

  /// Cambio di "righe per pagina" o di modalita' dalla barra: la barra ha
  /// gia' aggiornato [pagination].
  Future<void> pageSizeOrModeChanged() async {
    pagination.goToFirstPage();
    await _load();
  }

  /// Scorrimento in fondo alla lista nella modalita' infinita.
  Future<void> loadMore() async {
    if (_loading || !pagination.isInfinite || !pagination.hasMore) return;
    if (usesServer) {
      await _loadServer(append: true);
    } else {
      pagination.goToNextPage();
      _applyLocal(keepPage: true);
    }
  }

  void select(T? item) {
    selected.value = item;
  }

  void setChecked(T item, bool checked) {
    final id = idOf(item);
    final changed = checked ? _checkedIds.add(id) : _checkedIds.remove(id);
    if (changed) notifyListeners();
  }

  void setCheckedIds(Iterable<String> ids) {
    _checkedIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Spunta o toglie la spunta a tutte le righe della pagina visibile.
  void setAllVisibleChecked(bool checked) {
    final ids = pagination.items.map(idOf);
    if (checked) {
      _checkedIds.addAll(ids);
    } else {
      _checkedIds.removeAll(ids.toSet());
    }
    notifyListeners();
  }

  void clearChecked() {
    if (_checkedIds.isEmpty) return;
    _checkedIds.clear();
    notifyListeners();
  }

  /// Esegue [action] mostrando l'overlay "operazione in corso".
  Future<R> runBusy<R>(String message, Future<R> Function() action) async {
    _busyDepth++;
    _busyMessage = message;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busyDepth--;
      if (_busyDepth <= 0) {
        _busyDepth = 0;
        _busyMessage = null;
      }
      if (!_disposed) notifyListeners();
    }
  }

  // ── Caricamento ─────────────────────────────────────────────────────────

  Future<void> _goTo(VoidCallback move) async {
    if (isBusy) return;
    move();
    if (usesServer) {
      await _loadServer();
    } else {
      _applyLocal(keepPage: true);
    }
  }

  /// Filtri, ricerca o ordinamento cambiati: si riparte dalla prima pagina.
  void _restart() {
    pagination.goToFirstPage();
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    if (_disposed) return;
    final server = usesServer;
    if (_lastModeServer != null && _lastModeServer != server) {
      log.d('[datagrid] ${cache.key} modo ${server ? 'server' : 'memoria'}');
    }
    _lastModeServer = server;
    if (server) {
      _filtered = <T>[];
      await _loadServer(force: force);
    } else {
      await _loadLocal(force: force);
    }
  }

  Future<void> _loadServer({bool force = false, bool append = false}) async {
    final seq = ++_requestSeq;
    final request = DataGridPageRequest(
      page: append ? pagination.nextInfinitePage() : pagination.currentPage,
      perPage: pagination.requestPerPage(),
      search: _search.trim(),
      filters: List<DataGridFilter>.from(_filters),
      sort: _sort,
      forceRefresh: force,
    );
    final cached = force
        ? null
        : cache.readPage(request.cacheKey, ttl: cacheTtl);
    if (cached != null) {
      pagination.applyResult(cached, append: append);
      _visibleChanged();
      return;
    }
    _setLoading(true);
    try {
      final result = await loadPage(request);
      if (_disposed || seq != _requestSeq) return;
      cache.writePage(request.cacheKey, result);
      pagination.applyResult(result, append: append);
      _lastError = null;
      _visibleChanged();
    } catch (error) {
      if (_disposed || seq != _requestSeq) return;
      log.w('[datagrid] ${cache.key} errore pagina ${request.page}', error);
      _reportError(DataGridLoadError(error));
    } finally {
      if (!_disposed && seq == _requestSeq) _setLoading(false);
    }
  }

  Future<void> _loadLocal({bool force = false}) async {
    if (!force && cache.isFresh(cacheTtl)) {
      _applyLocal(keepPage: true);
      return;
    }
    // Un elenco gia' completo e solo "sporco" resta visibile mentre arriva
    // quello nuovo; uno incompleto si mostra comunque per non lasciare la
    // griglia vuota.
    if (cache.hasItems) _applyLocal(keepPage: true);

    final seq = ++_requestSeq;
    final previous = cache.read();
    final loaded = <T>[];
    _setLoading(true);
    try {
      for (var page = 1; page <= localMaxPages; page++) {
        final result = await loadPage(
          DataGridPageRequest(
            page: page,
            perPage: localChunkSize,
            forceRefresh: force,
          ),
        );
        if (_disposed || seq != _requestSeq) return;
        loaded.addAll(result.items);
        final last = result.items.isEmpty || !_hasMore(result);
        if (page == 1) {
          cache.replace(loaded, complete: last);
        } else {
          cache.append(result.items, complete: last);
        }
        // Le righe arrivano man mano: la pagina corrente resta quella
        // scelta, cosi' l'utente non torna alla prima a ogni blocco.
        _applyLocal(keepPage: true);
        if (last) break;
      }
      _lastError = null;
    } catch (error) {
      if (_disposed || seq != _requestSeq) return;
      log.w('[datagrid] ${cache.key} errore caricamento elenco', error);
      if (loaded.isNotEmpty) {
        cache.replace(loaded);
        _reportError(DataGridLoadError(error, partial: true));
      } else if (previous != null && previous.isNotEmpty) {
        cache.replace(previous);
        _reportError(DataGridLoadError(error, usingCache: true));
      } else {
        _reportError(DataGridLoadError(error));
      }
      _applyLocal(keepPage: true);
    } finally {
      if (!_disposed && seq == _requestSeq) _setLoading(false);
    }
  }

  bool _hasMore(PaginatedResult<T> result) {
    if (result.hasMore != null) return result.hasMore!;
    if (result.totalPages != null) return result.page < result.totalPages!;
    if (result.totalItems != null) {
      return result.page * result.perPage < result.totalItems!;
    }
    return result.items.length >= result.perPage;
  }

  void _applyLocal({bool keepPage = false}) {
    if (_disposed) return;
    _cacheRefreshThrottle?.cancel();
    _appliedRevision = cache.revision;
    _filtered = DataGridFilterEngine.apply(
      cache.items,
      fields,
      search: _search,
      filtri: _filters,
      sort: _sort,
      where: localWhere,
    );
    if (!keepPage) pagination.goToFirstPage();
    pagination.syncLocalItems(_filtered);
    _syncSelected();
    _visibleChanged();
  }

  /// La riga selezionata puo' essere stata sostituita da una copia nuova
  /// (varianti arrivate, stock modificato): il pannello deve mostrare
  /// quella aggiornata, o niente se la riga non c'e' piu'.
  void _syncSelected() {
    final current = selected.value;
    if (current == null) return;
    final id = idOf(current);
    for (final item in cache.items) {
      if (idOf(item) == id) {
        if (!identical(item, current)) selected.value = item;
        return;
      }
    }
  }

  void _onCacheChanged() {
    if (_disposed || _loading || usesServer) return;
    if (cache.revision == _appliedRevision) return;
    // Throttle e non debounce: con molte modifiche ravvicinate (varianti che
    // arrivano una dopo l'altra) la griglia si aggiorna al piu' ogni 300 ms,
    // invece di aspettare l'ultima.
    if (_cacheRefreshThrottle?.isActive ?? false) return;
    _cacheRefreshThrottle = Timer(
      const Duration(milliseconds: 300),
      () => _applyLocal(keepPage: true),
    );
  }

  void _visibleChanged() {
    onVisibleItemsChanged?.call(pagination.items);
    if (!_disposed) notifyListeners();
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    if (!_disposed) notifyListeners();
  }

  void _reportError(DataGridLoadError error) {
    _lastError = error;
    final handler = onLoadError;
    if (handler != null) handler(error);
    if (!_disposed) notifyListeners();
  }

  void _logFilters(String trigger) {
    final expr = _filters.isEmpty
        ? '(none)'
        : _filters.map((f) => f.logExpression).join(' AND ');
    log.d('[filters] ${cache.key} applied trigger=$trigger expr="$expr"');
  }

  @override
  void dispose() {
    _disposed = true;
    _cacheRefreshThrottle?.cancel();
    cache.removeListener(_onCacheChanged);
    pagination.dispose();
    selected.dispose();
    super.dispose();
  }
}
