import 'dart:async';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/error_text.dart';
import '../../l10n/extensions.dart';
import '../../notification/notification_service.dart';
import '../../settings/app_settings.dart';
import '../../theme/theme.dart';
import '../gui/global_pagination_bar.dart';
import '../gui/searchable_checkbox_dialog.dart';
import 'datagridview.code.dart';
import 'datagridview.gui.dart';
import 'datagridview_filters.dart';
import 'datagridview_filters_bar.gui.dart';
import 'datagridview_list.code.dart';

export 'datagridview.code.dart';
export 'datagridview_cache.dart';
export 'datagridview_filters.dart';
export 'datagridview_filters_bar.gui.dart'
    show DataGridCommandIconButton, kDataGridControlGap;
export 'datagridview_list.code.dart';
export '../logic/global_pagination_controller.dart'
    show PaginatedResult, GlobalPageMode;

/// Sotto questa larghezza la lista usa il layout telefono: niente pannello
/// dettagli accanto, il dettaglio si apre in una pagina.
const double kDataGridDesktopBreakpoint = 800;

/// Lista gestionale completa: barra filtri, griglia [DataGridView],
/// [GlobalPaginationBar], pannello dettagli su desktop e pagina dettagli su
/// telefono, overlay di caricamento e scelta colonne.
///
/// E' generica sul modello [T] e lavora per nome di campo: la schermata
/// passa i [fields] del modello, come leggere l'id ([idOf]), come caricare
/// una pagina ([loadPage]) e come mostrare il dettaglio ([detailsOf]).
/// Tutto il resto (filtri, ricerca con debounce, ordinamento, paginazione,
/// cache, risposte fuori ordine) e' della libreria.
class DataGridListView<T> extends StatefulWidget {
  final List<DataGridField<T>> fields;
  final String Function(T item) idOf;
  final DataGridPageLoader<T> loadPage;

  /// Chiave della cache condivisa ([DataGridViewCache]) e delle preferenze
  /// della lista (colonne, divisione del pannello).
  final String cacheKey;

  /// Dettaglio dell'elemento. [inPage] e' vero su telefono, quando il
  /// dettaglio si apre in una pagina a parte e deve avere il suo Scaffold.
  final Widget Function(BuildContext context, T item, bool inPage) detailsOf;

  final List<DataGridViewContextAction<T>> Function(BuildContext context)?
  contextActions;

  /// Celle personalizzate per nome di campo. I campi che mancano usano il
  /// testo del campo.
  final Map<String, Widget> Function(BuildContext context, T item)? cellsOf;

  final Color? Function(BuildContext context, T item)? foregroundOf;
  final Color? Function(BuildContext context, T item)? backgroundOf;

  /// Colonne visibili all'inizio, per nome di campo. Senza preferenze
  /// salvate e senza [initialColumns] si usano queste.
  final List<String>? defaultColumns;
  final List<String>? defaultMobileColumns;

  /// Colonne salvate dalla schermata con un suo meccanismo; se null la
  /// libreria le salva da sola con [cacheKey].
  final List<String>? initialColumns;
  final Future<void> Function(List<String> columns)? onColumnsChanged;

  /// Divisione fra lista e dettaglio su desktop (quota della lista).
  final double? initialSplitRatio;
  final ValueChanged<double>? onSplitRatioChanged;
  final double minSplitRatio;
  final double maxSplitRatio;

  /// Controller esterno, se la schermata deve leggere o comandare la lista.
  final DataGridListController<T>? controller;

  /// La schermata passa filtri e ordinamento al server (vedi
  /// [DataGridListController.serverFiltering]).
  final bool serverFiltering;
  final bool serverSearch;

  /// Filtro solo in memoria in piu' (vedi
  /// [DataGridListController.localWhere]).
  final bool Function(T item)? localWhere;

  // Barra filtri.
  /// Pulsante "Aggiorna": senza, ricarica la lista scartando la cache.
  final Future<void> Function()? onRefresh;
  final List<Widget> toolbarActions;
  final List<Widget> extraFilters;
  final List<Widget> extraActiveChips;
  final bool hasExtraFilters;
  final VoidCallback? onClearExtraFilters;
  final String? filterValueHint;

  /// Spunte controllate dalla schermata invece che dalla lista, con il loro
  /// callback (es. il selettore prodotti della cassa).
  final Set<String>? checkedIds;
  final void Function(T item, bool checked)? onRowChecked;
  final VoidCallback? onClearChecked;

  /// Testo della barra delle righe spuntate.
  final String Function(int count)? checkedLabel;

  /// Canc sulla griglia e "Elimina" sulla barra delle righe spuntate. Riceve
  /// la riga evidenziata, o null quando si eliminano le righe spuntate.
  final Future<void> Function(T? anchor)? onDelete;

  final ValueChanged<T>? onRowSelected;

  /// Doppio clic o Invio su desktop.
  final ValueChanged<T>? onRowActivated;

  /// Barra in fondo (es. "Annulla/Aggiungi" del selettore).
  final Widget? bottomBar;

  /// Righe da mostrare come spuntate nel contatore della paginazione, quando
  /// la schermata conta qualcosa di diverso dalle righe (es. varianti).
  final int? selectedRowsCount;

  /// Mostra la barra di avanzamento in alto anche fuori dal caricamento
  /// della lista (es. prefetch delle varianti).
  final bool extraLoading;

  final IconData emptyDetailsIcon;
  final String Function(BuildContext context)? emptyDetailsTitle;
  final String Function(BuildContext context)? emptyDetailsSubtitle;

  final void Function(BuildContext context, DataGridLoadError error)?
  onLoadError;

  /// Durata della cache dell'elenco (vedi [DataGridListController.cacheTtl]).
  /// Vale solo quando la lista crea il proprio controller.
  final Duration? cacheTtl;
  final ValueChanged<List<T>>? onVisibleItemsChanged;

  const DataGridListView({
    super.key,
    required this.fields,
    required this.idOf,
    required this.loadPage,
    required this.cacheKey,
    required this.detailsOf,
    this.contextActions,
    this.cellsOf,
    this.foregroundOf,
    this.backgroundOf,
    this.defaultColumns,
    this.defaultMobileColumns,
    this.initialColumns,
    this.onColumnsChanged,
    this.initialSplitRatio,
    this.onSplitRatioChanged,
    this.minSplitRatio = 0.45,
    this.maxSplitRatio = 0.75,
    this.controller,
    this.serverFiltering = true,
    this.serverSearch = true,
    this.localWhere,
    this.onRefresh,
    this.toolbarActions = const <Widget>[],
    this.extraFilters = const <Widget>[],
    this.extraActiveChips = const <Widget>[],
    this.hasExtraFilters = false,
    this.onClearExtraFilters,
    this.filterValueHint,
    this.checkedIds,
    this.onRowChecked,
    this.onClearChecked,
    this.checkedLabel,
    this.onDelete,
    this.onRowSelected,
    this.onRowActivated,
    this.bottomBar,
    this.selectedRowsCount,
    this.extraLoading = false,
    this.emptyDetailsIcon = Icons.list_alt_outlined,
    this.emptyDetailsTitle,
    this.emptyDetailsSubtitle,
    this.onLoadError,
    this.onVisibleItemsChanged,
    this.cacheTtl = const Duration(minutes: 5),
  });

  @override
  State<DataGridListView<T>> createState() => _DataGridListViewState<T>();
}

class _DataGridListViewState<T> extends State<DataGridListView<T>>
    with AutomaticKeepAliveClientMixin<DataGridListView<T>> {
  final _appSettings = AppSettings();
  final _scrollController = ScrollController();
  late final MultiSplitViewController _splitViewController;
  late DataGridListController<T> _controller;
  bool _ownsController = false;
  List<String>? _visibleColumns;
  double _splitRatio = 0.6;
  bool _openingDetails = false;

  String get _columnsKey => 'datagridview_columns_${widget.cacheKey}';
  String get _splitKey => 'datagridview_split_${widget.cacheKey}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _splitRatio = _normalizeRatio(widget.initialSplitRatio ?? 0.6);
    _splitViewController = MultiSplitViewController(
      areas: _splitAreasForRatio(_splitRatio),
    );
    _attachController();
    _scrollController.addListener(_onScroll);
    unawaited(_init());
  }

  void _attachController() {
    final external = widget.controller;
    _ownsController = external == null;
    _controller =
        external ??
        DataGridListController<T>(
          fields: widget.fields,
          idOf: widget.idOf,
          loadPage: widget.loadPage,
          cacheKey: widget.cacheKey,
          cacheTtl: widget.cacheTtl,
        );
    _configureController();
    _controller.addListener(_onControllerChanged);
  }

  void _configureController() {
    _controller
      ..fields = widget.fields
      ..loadPage = widget.loadPage
      ..serverFiltering = widget.serverFiltering
      ..serverSearch = widget.serverSearch
      ..localWhere = widget.localWhere
      ..onVisibleItemsChanged = _visibleItemsChanged
      ..onLoadError = _loadError;
  }

  @override
  void didUpdateWidget(covariant DataGridListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) _controller.dispose();
      _attachController();
    } else {
      _configureController();
    }
  }

  Future<void> _init() async {
    await _appSettings.init();
    if (!mounted) return;
    await _controller.pagination.loadFromSettings(_appSettings);
    _visibleColumns = await _loadColumns();
    if (widget.initialSplitRatio == null && widget.onSplitRatioChanged == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getDouble(_splitKey);
        if (stored != null) {
          _splitRatio = _normalizeRatio(stored);
          _splitViewController.areas = _splitAreasForRatio(_splitRatio);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    await _controller.reload();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _scrollController.dispose();
    _splitViewController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _visibleItemsChanged(List<T> items) {
    widget.onVisibleItemsChanged?.call(items);
  }

  void _loadError(DataGridLoadError error) {
    if (!mounted) return;
    final custom = widget.onLoadError;
    if (custom != null) {
      custom(context, error);
      return;
    }
    final l10n = context.l10n;
    final message = error.partial
        ? l10n.dataGridLoadPartial
        : error.usingCache
        ? l10n.dataGridLoadErrorUsingCache
        : l10n.dataGridLoadError(localizedErrorText(l10n, error.error));
    NotificationService.instance.messageBar(
      error.partial || error.usingCache ? 'warning' : 'errore',
      widget.cacheKey,
      message,
    );
  }

  // ── Colonne ──────────────────────────────────────────────────────────────

  List<DataGridField<T>> get _columnFields =>
      widget.fields.where((f) => f.column).toList();

  /// Le colonne salvate si leggono per nome o per alias del campo: cosi' una
  /// colonna salvata con il nome di prima continua a valere dopo che il campo
  /// e' stato rinominato.
  List<String> _resolveColumns(Iterable<String> keys) {
    final resolved = <String>{};
    for (final key in keys) {
      final normalized = key.trim().toLowerCase();
      for (final field in _columnFields) {
        if (field.name == key ||
            field.name.toLowerCase() == normalized ||
            field.aliases.contains(normalized)) {
          resolved.add(field.name);
          break;
        }
      }
    }
    return _columnFields
        .map((f) => f.name)
        .where(resolved.contains)
        .toList();
  }

  Future<List<String>> _loadColumns() async {
    var stored = widget.initialColumns;
    if (stored == null && widget.onColumnsChanged == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        stored = prefs.getStringList(_columnsKey);
      } catch (_) {}
    }
    final resolved = _resolveColumns(stored ?? const <String>[]);
    if (resolved.isNotEmpty) return resolved;
    // Senza preferenze si parte da un set coerente con la larghezza, ma una
    // volta scelto non segue il resize: le checkbox del selettore devono
    // mostrare le stesse colonne della tabella.
    final isSmall =
        mounted &&
        MediaQuery.sizeOf(context).width < kDataGridDesktopBreakpoint;
    final defaults = isSmall
        ? (widget.defaultMobileColumns ?? widget.defaultColumns)
        : widget.defaultColumns;
    final fromDefaults = _resolveColumns(
      defaults ?? _columnFields.map((f) => f.name),
    );
    return fromDefaults.isEmpty
        ? _columnFields.map((f) => f.name).toList()
        : fromDefaults;
  }

  Future<void> _openColumnPicker() async {
    if (_controller.isBusy) return;
    final l10n = context.l10n;
    final current = _visibleColumns ?? const <String>[];
    final selected = await SearchableCheckboxDialog.show(
      context,
      title: l10n.prodottiColonneVisibili,
      inputLabel: l10n.prodottiCercaColonna,
      input_list: _columnFields.map((f) => f.headerLabel(l10n)).toList(),
      preselected_list: _columnFields
          .where((f) => current.contains(f.name))
          .map((f) => f.headerLabel(l10n))
          .toList(),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    final next = _columnFields
        .where((f) => selected.contains(f.headerLabel(l10n)))
        .map((f) => f.name)
        .toList();
    if (next.isEmpty) return;
    final save = widget.onColumnsChanged;
    if (save != null) {
      await save(next);
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_columnsKey, next);
      } catch (_) {}
    }
    if (mounted) setState(() => _visibleColumns = next);
  }

  // ── Divisione del pannello ──────────────────────────────────────────────

  double _normalizeRatio(double value) =>
      value.clamp(widget.minSplitRatio, widget.maxSplitRatio).toDouble();

  List<Area> _splitAreasForRatio(double ratio) {
    final normalized = _normalizeRatio(ratio);
    return [
      Area(
        id: 'list',
        flex: normalized,
        min: widget.minSplitRatio,
        max: widget.maxSplitRatio,
      ),
      Area(
        id: 'details',
        flex: 1 - normalized,
        min: 1 - widget.maxSplitRatio,
        max: 1 - widget.minSplitRatio,
      ),
    ];
  }

  void _saveCurrentSplitRatio() {
    final listFlex = _splitViewController.getArea(0).flex;
    final detailFlex = _splitViewController.getArea(1).flex;
    if (listFlex == null || detailFlex == null) return;
    final totalFlex = listFlex + detailFlex;
    if (totalFlex <= 0) return;
    final ratio = _normalizeRatio(listFlex / totalFlex);
    _splitRatio = ratio;
    final save = widget.onSplitRatioChanged;
    if (save != null) {
      save(ratio);
      return;
    }
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setDouble(_splitKey, ratio),
      ),
    );
  }

  // ── Scorrimento e paginazione ────────────────────────────────────────────

  void _onScroll() {
    if (!mounted || _controller.isBusy) return;
    final pagination = _controller.pagination;
    if (!pagination.isInfinite ||
        !pagination.hasMore ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 240) return;
    unawaited(_controller.loadMore());
  }

  Future<void> _paged(Future<void> Function() move) async {
    await move();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  // ── Selezione ────────────────────────────────────────────────────────────

  Set<String> get _checkedIds => widget.checkedIds ?? _controller.checkedIds;

  void _onRowChecked(T item, bool checked) {
    final external = widget.onRowChecked;
    if (external != null) {
      external(item, checked);
    } else {
      _controller.setChecked(item, checked);
    }
  }

  void _clearChecked() {
    final external = widget.onClearChecked;
    if (external != null) {
      external();
    } else {
      _controller.clearChecked();
    }
  }

  void _selectItem(T item) {
    _controller.select(item);
    widget.onRowSelected?.call(item);
  }

  void _openDetailsPage(T item) {
    // Il doppio tocco arriva dopo il tocco singolo: senza guardia la
    // pagina di dettaglio si aprirebbe due volte.
    if (_openingDetails) return;
    _openingDetails = true;
    Future<void>(() async {
      try {
        _selectItem(item);
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<T?>(
              valueListenable: _controller.selected,
              builder: (context, selected, _) {
                final shown =
                    selected != null && widget.idOf(selected) == widget.idOf(item)
                    ? selected
                    : item;
                return widget.detailsOf(context, shown, true);
              },
            ),
          ),
        );
        if (mounted) setState(() {});
      } finally {
        _openingDetails = false;
      }
    });
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
          // La sezione e a filo: senza SafeArea, aperta da una rotta senza
          // AppBar la lista finiva sotto la status bar. Dalla home l'AppBar
          // esterna ha gia' consumato l'inset e qui non si aggiunge nulla.
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
                  final isSmall =
                      constraints.maxWidth < kDataGridDesktopBreakpoint;
                  return isSmall
                      ? _buildListPane(showDetailsInPage: true)
                      : _buildDesktopLayout();
                },
              ),
            ),
          ),
        ),
        if (_controller.isLoading || widget.extraLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (_controller.isBusy)
          Positioned.fill(
            child: _BusyOverlay(
              message: _controller.busyMessage ?? context.l10n.commonLoading,
            ),
          ),
      ],
    );
  }

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
          if (area.index == 0) return _buildListPane();
          // Come la lista: a filo, senza cornice. La separazione fra i due
          // e' solo la linea verticale trascinabile.
          return DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.84),
            ),
            child: ValueListenableBuilder<T?>(
              valueListenable: _controller.selected,
              builder: (context, selected, _) => selected != null
                  ? widget.detailsOf(context, selected, false)
                  : _buildEmptyDetails(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListPane({bool showDetailsInPage = false}) {
    final theme = Theme.of(context);
    // A filo: niente padding, niente cornice, niente ombra.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
      ),
      child: Column(
        children: [
          Expanded(child: _buildList(showDetailsInPage: showDetailsInPage)),
          if (widget.bottomBar != null) widget.bottomBar!,
        ],
      ),
    );
  }

  Widget _buildList({required bool showDetailsInPage}) {
    final pagination = _controller.pagination;
    return Column(
      children: [
        DataGridFiltersBar<T>(
          controller: _controller,
          fields: widget.fields,
          onRefresh: widget.onRefresh ?? () => _controller.reload(force: true),
          onOpenColumns: _openColumnPicker,
          actions: widget.toolbarActions,
          extraFilters: widget.extraFilters,
          extraActiveChips: widget.extraActiveChips,
          hasExtraFilters: widget.hasExtraFilters,
          onClearExtraFilters: widget.onClearExtraFilters,
          filterValueHint: widget.filterValueHint,
        ),
        Expanded(child: _buildGrid(showDetailsInPage: showDetailsInPage)),
        GlobalPaginationBar(
          settings: _appSettings,
          controller: pagination,
          totalRows: _controller.totalRows,
          selectedRows: widget.selectedRowsCount ?? _checkedIds.length,
          onFirstPage: () => _paged(_controller.goToFirstPage),
          onPreviousPage: () => _paged(_controller.goToPreviousPage),
          onNextPage: () => _paged(_controller.goToNextPage),
          onLastPage: () => _paged(_controller.goToLastPage),
          onModeOrPageSizeChanged: (mode, size) =>
              _paged(_controller.pageSizeOrModeChanged),
        ),
      ],
    );
  }

  List<DataGridViewColumn> _buildColumns() {
    final visible = _visibleColumns ?? const <String>[];
    return _columnFields
        .where((f) => visible.contains(f.name))
        .map((f) => f.toColumn(context.l10n))
        .toList();
  }

  List<DataGridViewRowData<T>> _buildRows() {
    final l10n = context.l10n;
    final visible = (_visibleColumns ?? const <String>[]).toSet();
    final columnFields = _columnFields
        .where((f) => visible.contains(f.name))
        .toList();
    return _controller.visibleItems.map((item) {
      final custom = widget.cellsOf?.call(context, item) ?? const {};
      return DataGridViewRowData<T>(
        id: widget.idOf(item),
        value: item,
        foregroundColor: widget.foregroundOf?.call(context, item),
        backgroundColor: widget.backgroundOf?.call(context, item),
        cells: <String, Widget>{
          for (final field in columnFields)
            field.name:
                custom[field.name] ??
                Text(
                  _cellText(l10n, field, item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        },
      );
    }).toList();
  }

  String _cellText(
    AppLocalizations l10n,
    DataGridField<T> field,
    T item,
  ) {
    final format = field.format;
    if (format != null) return format(l10n, item);
    final values = DataGridFilterEngine.textValues(
      field,
      item,
    ).map((v) => field.optionLabel(l10n, v));
    return values.isEmpty ? '-' : values.join(', ');
  }

  Widget _buildGrid({required bool showDetailsInPage}) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final checkedCount = _checkedIds.length;
    final showEmpty =
        _controller.visibleItems.isEmpty &&
        !_controller.isLoading &&
        _visibleColumns != null;
    // Nessuna card attorno alla tabella: il pane che ci ospita ha gia il suo
    // bordo, e aggiungerne uno qui produrrebbe due cornici a 12px di distanza.
    return Column(
      children: [
        if (checkedCount > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              kDataGridEdgeInset,
              kDataGridEdgeInsetVertical,
              kDataGridEdgeInset,
              kDataGridEdgeInsetVertical,
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
              spacing: kDataGridControlGap,
              runSpacing: kDataGridControlGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.checklist_rtl, size: 20, color: theme.primaryColor),
                Text(
                  widget.checkedLabel?.call(checkedCount) ??
                      context.l10n.dataGridSelectedCount(checkedCount),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _clearChecked,
                  icon: const Icon(Icons.clear_all),
                  label: Text(context.l10n.prodottiDeseleziona),
                ),
                if (widget.onDelete != null)
                  FilledButton.icon(
                    onPressed: () => widget.onDelete!(null),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.l10n.commonDelete),
                  ),
              ],
            ),
          ),
          const SizedBox(height: kDataGridControlGap),
        ],
        Expanded(
          child: Stack(
            children: [
              // Le colonne salvate arrivano in modo asincrono: senza colonne
              // `DataTable` non si puo' costruire.
              Positioned.fill(
                child: _buildColumns().isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _buildDataGrid(showDetailsInPage),
              ),
              if (showEmpty)
                Center(
                  child: Text(
                    context.l10n.dataGridNoResults,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataGrid(bool showDetailsInPage) {
    final selected = _controller.selected.value;
    return DataGridView<T>(
      columns: _buildColumns(),
      rows: _buildRows(),
      // Il pane genitore disegna gia l'unica cornice della sezione: la
      // griglia non ne aggiunge una seconda sopra.
      framed: false,
      verticalScrollController: _scrollController,
      selectedRowId: selected == null ? '' : widget.idOf(selected),
      selectedRowIds: _checkedIds,
      showCheckboxes: true,
      selectAllShortcut: _appSettings.shortcutSelectAll,
      deleteShortcut: _appSettings.shortcutDelete,
      escapeShortcut: _appSettings.shortcutEscape,
      onRowChecked: _onRowChecked,
      onSelectAll: (checked) {
        if (widget.onRowChecked != null) {
          // Spunte della schermata: la casella di testa le toglie soltanto.
          _clearChecked();
        } else {
          _controller.setAllVisibleChecked(checked);
        }
      },
      onDeleteShortcut: widget.onDelete == null
          ? null
          : (item) => widget.onDelete!(_checkedIds.isNotEmpty ? null : item),
      onEscapeShortcut: _clearChecked,
      onRowSelected: (item) => Future<void>(() => _selectItem(item)),
      onRowDoubleTap: showDetailsInPage
          ? _openDetailsPage
          : (item) => widget.onRowActivated?.call(item),
      // Su telefono il dettaglio non ha un pannello accanto alla tabella:
      // senza tocco singolo si aprirebbe solo con un doppio tocco, che
      // nessuno prova.
      onRowTap: showDetailsInPage ? _openDetailsPage : null,
      contextActions: widget.contextActions?.call(context) ?? const [],
    );
  }

  Widget _buildEmptyDetails() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.emptyDetailsIcon,
            size: 64,
            color: theme.iconTheme.color?.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyDetailsTitle?.call(context) ??
                context.l10n.dataGridSelectItem,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            widget.emptyDetailsSubtitle?.call(context) ??
                context.l10n.productsToSeeDetails,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay "operazione in corso" sopra la lista.
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
                      context.l10n.productsOperationRunning,
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

/// Etichetta colorata a pillola per gli stati nelle celle della griglia.
class DataGridStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const DataGridStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

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
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
