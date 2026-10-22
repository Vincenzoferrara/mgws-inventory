import 'package:flutter/foundation.dart';

import '../../settings/app_settings.dart';
import '../../log_viewer/app_logger.dart';

enum GlobalPageMode { paged, infinite }

class GlobalPaginationOptions {
  static const List<int> defaultPageSizes = <int>[10, 20, 50, 100];
  static const int infiniteChunkSize = 50;

  /// Valore interno della modalita' infinito. Resta una parola perche' e' il
  /// valore che viaggia fra controller e barra, e deve continuare a essere
  /// riconoscibile da [isInfiniteLabel].
  static const String infiniteLabel = 'Infinito';

  /// Cosa l'utente vede al posto della parola.
  ///
  /// Il campo "righe" e' dimensionato sul contenuto piu' largo: fra le voci
  /// "Infinito" (45.1px a 14px) e "100" (24.2px) comanda "Infinito". Con il
  /// simbolo comanda invece la didascalia "Righe" (36.0px), e la larghezza
  /// smette di dipendere da quale voce e' selezionata.
  static const String infiniteDisplayLabel = '∞';

  static int normalizePageSize(int value) {
    if (value <= 0) return 20;
    return value;
  }

  static int? tryParsePageSize(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  static bool isInfiniteLabel(String raw) {
    final normalized = raw.trim().toLowerCase();
    return normalized == infiniteLabel.toLowerCase() ||
        normalized == infiniteDisplayLabel;
  }
}

class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int? totalItems;
  final int? totalPages;
  final bool? hasMore;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.perPage,
    this.totalItems,
    this.totalPages,
    this.hasMore,
  });
}

class GlobalPaginationController<T> extends ChangeNotifier {
  GlobalPaginationController({
    int initialPageSize = 20,
    GlobalPageMode initialMode = GlobalPageMode.paged,
  }) : _pageSize = GlobalPaginationOptions.normalizePageSize(initialPageSize),
       _mode = initialMode;

  final List<T> _items = <T>[];
  int _pageSize;
  int _currentPage = 1;
  int? _totalItems;
  int? _totalPages;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  GlobalPageMode _mode;

  List<T> get items => List.unmodifiable(_items);
  int get pageSize => _pageSize;
  int get currentPage => _currentPage;
  int? get totalItems => _totalItems;
  int? get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  GlobalPageMode get mode => _mode;
  bool get isInfinite => _mode == GlobalPageMode.infinite;

  bool get canGoPrevious => !isInfinite && _currentPage > 1;
  bool get canGoNext {
    if (isInfinite) return false;
    if (_totalPages != null) return _currentPage < _totalPages!;
    return _hasMore;
  }

  bool get canGoFirst => canGoPrevious;
  bool get canGoLast =>
      !isInfinite && _totalPages != null && _currentPage < _totalPages!;

  String get pageSizeText =>
      isInfinite ? GlobalPaginationOptions.infiniteLabel : _pageSize.toString();

  /// Valore del secondo livello: "1/12" in paginazione, "250 di 1200" in
  /// infinito.
  ///
  /// Va separato da [progressCaption] perche' la barra li mette su due righe e
  /// la larghezza la comanda solo questo: la didascalia puo' restare piccola
  /// senza costare nulla, il numero no.
  String get progressValue {
    if (isInfinite) {
      final loaded = _items.length;
      final total = _totalItems;
      return total == null ? '$loaded' : '$loaded di $total';
    }

    final totalPages = _totalPages;
    if (totalPages != null && totalPages > 0) {
      return '$_currentPage/$totalPages';
    }
    return '$_currentPage';
  }

  Future<void> loadFromSettings(AppSettings settings) async {
    setPageSize(settings.defaultPageSize, notify: false);
    notifyListeners();
  }

  Future<void> persistPageSize(AppSettings settings, int value) async {
    final normalized = GlobalPaginationOptions.normalizePageSize(value);
    setPageSize(normalized);
    await settings.setDefaultPageSize(normalized);
  }

  void setMode(GlobalPageMode value, {bool resetPage = true}) {
    if (_mode == value && !resetPage) return;
    final prima = _mode;
    _mode = value;
    log.d(
      '[perf-trace] paginazione setMode ${prima.name} -> ${value.name} '
      'resetPage=$resetPage',
    );
    if (resetPage) {
      _currentPage = 1;
      _items.clear();
      _totalItems = null;
      _totalPages = null;
      _hasMore = true;
    }
    notifyListeners();
  }

  void setPageSize(int value, {bool notify = true}) {
    final normalized = GlobalPaginationOptions.normalizePageSize(value);
    if (_pageSize == normalized && _currentPage == 1) {
      if (notify) notifyListeners();
      return;
    }
    if (_pageSize != normalized) {
      log.d(
        '[perf-trace] paginazione setPageSize $_pageSize -> $normalized '
        '(pagina reset a 1, items/totali azzerati)',
      );
    }
    _pageSize = normalized;
    _currentPage = 1;
    _items.clear();
    _totalItems = null;
    _totalPages = null;
    _hasMore = true;
    if (notify) notifyListeners();
  }

  void goToPage(int page) {
    final safePage = page < 1 ? 1 : page;
    log.d(
      '[perf-trace] paginazione goToPage richiesta=$page applicata=$safePage '
      'corrente=$_currentPage mode=${isInfinite ? "infinite" : "paged"} '
      'totalePagine=${_totalPages ?? "-"} totaleItems=${_totalItems ?? "-"}',
    );
    if (_currentPage == safePage) return;
    _currentPage = safePage;
    notifyListeners();
  }

  void goToFirstPage() => goToPage(1);

  void goToLastPage() {
    if (_totalPages == null) return;
    goToPage(_totalPages!);
  }

  void goToNextPage() => goToPage(_currentPage + 1);

  void goToPreviousPage() => goToPage(_currentPage - 1);

  void reset() {
    _currentPage = 1;
    _items.clear();
    _totalItems = null;
    _totalPages = null;
    _hasMore = true;
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  void syncLocalItems(List<T> allItems) {
    final totalCount = allItems.length;
    if (isInfinite) {
      final paginaPrima = _currentPage;
      final totalPages = totalCount == 0
          ? 1
          : (totalCount / GlobalPaginationOptions.infiniteChunkSize).ceil();
      if (_currentPage > totalPages) {
        _currentPage = totalPages;
      }
      if (_currentPage < 1) {
        _currentPage = 1;
      }
      final visibleCount = totalCount == 0
          ? 0
          : (_currentPage * GlobalPaginationOptions.infiniteChunkSize).clamp(
              0,
              totalCount,
            );
      _items
        ..clear()
        ..addAll(allItems.take(visibleCount));
      _totalItems = totalCount;
      _totalPages = totalPages;
      _hasMore = visibleCount < totalCount;
      _isLoading = false;
      _isLoadingMore = false;
      log.d(
        '[perf-trace] paginazione syncLocalItems mode=infinite tot=$totalCount '
        'chunk=${GlobalPaginationOptions.infiniteChunkSize} '
        'paginaPrima=$paginaPrima paginaDopo=$_currentPage '
        'clamp=${_currentPage != paginaPrima ? "SI" : "no"} '
        'totalePagine=$totalPages visibili=${_items.length}',
      );
      notifyListeners();
      return;
    }

    final totalPages = totalCount == 0 ? 1 : (totalCount / _pageSize).ceil();
    final paginaPrima = _currentPage;
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final start = totalCount == 0 ? 0 : (_currentPage - 1) * _pageSize;
    final end = totalCount == 0 ? 0 : (start + _pageSize).clamp(0, totalCount);
    _items
      ..clear()
      ..addAll(allItems.sublist(start, end));
    _totalItems = totalCount;
    _totalPages = totalPages;
    _hasMore = _currentPage < totalPages;
    _isLoading = false;
    _isLoadingMore = false;
    log.d(
      '[perf-trace] paginazione syncLocalItems mode=paged tot=$totalCount '
      'pageSize=$_pageSize paginaPrima=$paginaPrima paginaDopo=$_currentPage '
      'clamp=${_currentPage != paginaPrima ? "SI" : "no"} '
      'range=${totalCount == 0 ? 0 : start + 1}-$end '
      'totalePagine=$totalPages visibili=${_items.length}',
    );
    notifyListeners();
  }

  void startLoading({bool loadingMore = false}) {
    if (loadingMore) {
      _isLoadingMore = true;
    } else {
      _isLoading = true;
    }
    notifyListeners();
  }

  void stopLoading({bool loadingMore = false}) {
    if (loadingMore) {
      _isLoadingMore = false;
    } else {
      _isLoading = false;
    }
    notifyListeners();
  }

  void applyResult(PaginatedResult<T> result, {bool append = false}) {
    if (append) {
      _items.addAll(result.items);
    } else {
      _items
        ..clear()
        ..addAll(result.items);
    }

    _currentPage = result.page < 1 ? 1 : result.page;
    _pageSize = GlobalPaginationOptions.normalizePageSize(result.perPage);
    _totalItems = result.totalItems;
    _totalPages =
        result.totalPages ??
        _deriveTotalPages(result.totalItems, result.perPage);
    _hasMore = result.hasMore ?? _deriveHasMore(result);
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  int nextInfinitePage() {
    if (!isInfinite) return _currentPage;
    if (_items.isEmpty) return 1;
    return _currentPage + 1;
  }

  int requestPerPage() {
    return isInfinite ? GlobalPaginationOptions.infiniteChunkSize : _pageSize;
  }

  int? _deriveTotalPages(int? totalItems, int perPage) {
    if (totalItems == null || perPage <= 0) return null;
    return (totalItems / perPage).ceil();
  }

  bool _deriveHasMore(PaginatedResult<T> result) {
    if (result.totalPages != null) {
      return result.page < result.totalPages!;
    }
    if (result.totalItems != null) {
      return result.page * result.perPage < result.totalItems!;
    }
    return result.items.length >= result.perPage;
  }
}
