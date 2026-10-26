// Dashboard - main view opened from Home.
//
// A dashboard is a grid of widgets the user builds: each widget shows one
// metric (sales, orders, products, customers, stock...) with the chart type
// the user picks, at the size the user picks. Widgets are moved by dragging
// their handle in edit mode.
//
// Above the grid, one row of filters applies to every widget: period (preset
// or custom range), comparison with the previous period and order statuses.
// The filters are saved with the dashboard as its default view.
//
// Dashboards are stored in MGWS. A personal dashboard is seen only by its
// owner; a shared one is seen by everyone or only by shop managers, and only
// shop managers can create or change shared dashboards.

import 'dart:async';

import 'package:flutter/material.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/query_woocommerce/woo_query_report.dart';
import '../notification/notification_service.dart';
import '../l10n/extensions.dart';
import 'dashboard.code.dart';
import 'dashboard_detailed.dart';
import 'dashboard_layout.dart';
import 'dashboard_layout_store.dart';
import 'dashboard_report.dart';
import 'dashboard_report_editor.dart';
import 'dashboard_report_export.dart';
import 'dashboard_widget_data.dart';
import 'dashboard_widget_view.dart';

class CustomizableDashboardPage extends StatefulWidget {
  const CustomizableDashboardPage({
    super.key,
    this.reportGateway,
    this.exportGateway,
    this.layoutStore,
    this.reportRunner,
    this.reportSearch,
  });

  final DashboardReportGateway? reportGateway;
  final DashboardExportGateway? exportGateway;
  final DashboardLayoutStore? layoutStore;
  final DashboardReportRunner? reportRunner;
  final DashboardReportSearch? reportSearch;

  @override
  State<CustomizableDashboardPage> createState() =>
      _CustomizableDashboardPageState();
}

class _CustomizableDashboardPageState extends State<CustomizableDashboardPage> {
  late final DashboardReportGateway _reports =
      widget.reportGateway ?? ReportService();
  late final DashboardExportGateway _exporter =
      widget.exportGateway ?? ReportExporter();
  late final DashboardLayoutStore _store =
      widget.layoutStore ?? MgwsDashboardLayoutStore();
  late final DashboardReportRunner _runReport =
      widget.reportRunner ?? DashboardReportService.instance.run;
  late final DashboardReportSearch _searchReport =
      widget.reportSearch ?? DashboardReportService.instance.search;

  DashboardCatalog? _catalog;

  /// Dashboard on screen; while editing it holds the unsaved changes.
  DashboardLayout? _layout;

  /// Last saved version, restored when editing is cancelled.
  DashboardLayout? _savedLayout;

  /// Filters on screen. They start from the dashboard's saved filters.
  var _filters = const DashboardFilters();

  var _bundle = const DashboardDataBundle();
  Object? _error;
  var _loading = true;
  var _editing = false;
  var _saving = false;
  var _exporting = false;
  var _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  // =======================================================
  // ==                 DASHBOARD CATALOG                 ==
  // =======================================================

  Future<void> _loadCatalog({String? selectId}) async {
    final catalog = await _store.load();
    if (!mounted) return;
    final wantedId = selectId ?? await _store.selectedId();
    if (!mounted) return;
    var layouts = catalog.dashboards;
    if (layouts.isEmpty) {
      // First run: the standard overview, saved as soon as it is changed.
      layouts = [DashboardLayout.standard(name: context.l10n.dashboardTitolo)];
    }
    final selected =
        layouts.where((layout) => layout.id == wantedId).firstOrNull ??
        layouts.first;
    setState(() {
      _catalog = DashboardCatalog(
        dashboards: layouts,
        canManageShared: catalog.canManageShared,
        storedOnServer: catalog.storedOnServer,
      );
    });
    _open(selected);
  }

  void _open(DashboardLayout layout) {
    setState(() {
      _layout = layout;
      _savedLayout = layout;
      _filters = layout.filters;
      _editing = false;
      _bundle = const DashboardDataBundle();
    });
    _store.setSelectedId(layout.id);
    _loadData(refresh: true);
  }

  List<DashboardLayout> get _dashboards => _catalog?.dashboards ?? const [];

  bool get _canManageShared => _catalog?.canManageShared ?? false;

  bool get _storedOnServer => _catalog?.storedOnServer ?? false;

  void _replaceInCatalog(DashboardLayout layout, {String? previousId}) {
    final catalog = _catalog;
    if (catalog == null) return;
    final list = [...catalog.dashboards];
    final index = list.indexWhere(
      (item) => item.id == (previousId ?? layout.id),
    );
    if (index >= 0) {
      list[index] = layout;
    } else {
      list.add(layout);
    }
    _catalog = DashboardCatalog(
      dashboards: list,
      canManageShared: catalog.canManageShared,
      storedOnServer: catalog.storedOnServer,
    );
  }

  // =======================================================
  // ==                       DATA                        ==
  // =======================================================

  Set<DashboardMetric> get _metrics => {
    for (final widget in _layout?.widgets ?? const []) widget.metric,
  };

  bool get _needsSalesReport => _metrics.any(
    (metric) =>
        metric == DashboardMetric.topProductsRevenue ||
        metric == DashboardMetric.topProductsQuantity ||
        metric == DashboardMetric.salesByCategory,
  );

  Set<int> get _lowStockThresholds => {
    for (final widget in _layout?.widgets ?? const <DashboardWidgetConfig>[])
      if (widget.metric.hasStockThreshold) widget.stockThreshold,
  };

  /// Loads everything the widgets need. With [refresh] every source is read
  /// again; otherwise only the sources not loaded yet.
  Future<void> _loadData({bool refresh = false}) async {
    final requestVersion = ++_requestVersion;
    final period = _filters.toPeriod();
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _bundle = DashboardDataBundle(summary: _bundle.summary);
      });
      try {
        final summary = await _reports.getDashboard(
          periodo: period,
          forceRefresh: true,
        );
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          _bundle = DashboardDataBundle(summary: summary);
          _loading = false;
        });
      } catch (error) {
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          _error = error;
          _loading = false;
        });
        return;
      }
    }
    // Heavier sources arrive later, without holding back the main numbers.
    _loadSecondary(requestVersion, period);
  }

  void _loadSecondary(int requestVersion, PeriodoReport period) {
    bool current() => mounted && requestVersion == _requestVersion;

    if (_needsSalesReport &&
        _bundle.salesReport == null &&
        !_bundle.salesReportFailed) {
      _reports
          .getReportVendite(periodo: period)
          .then((report) {
            if (current()) {
              setState(() => _bundle = _bundle.copyWith(salesReport: report));
            }
          })
          .catchError((Object error) {
            log.w('Dashboard sales report not available: $error');
            if (current()) {
              setState(
                () => _bundle = _bundle.copyWith(salesReportFailed: true),
              );
            }
          });
    }
    if (_metrics.contains(DashboardMetric.productsByCategory) &&
        _bundle.productsByCategory == null &&
        !_bundle.productsByCategoryFailed) {
      _reports
          .getProductsByCategory()
          .then((categories) {
            if (current()) {
              setState(
                () =>
                    _bundle = _bundle.copyWith(productsByCategory: categories),
              );
            }
          })
          .catchError((Object error) {
            log.w('Dashboard categories not available: $error');
            if (current()) {
              setState(
                () =>
                    _bundle = _bundle.copyWith(productsByCategoryFailed: true),
              );
            }
          });
    }
    for (final threshold in _lowStockThresholds) {
      if (_bundle.lowStockByThreshold.containsKey(threshold) ||
          _bundle.lowStockFailed.contains(threshold)) {
        continue;
      }
      _reports
          .getProdottiStockBasso(soglia: threshold)
          .then((rows) {
            if (current()) {
              setState(
                () => _bundle = _bundle.copyWith(
                  lowStockByThreshold: {
                    ..._bundle.lowStockByThreshold,
                    threshold: rows,
                  },
                ),
              );
            }
          })
          .catchError((Object error) {
            log.w('Dashboard low stock not available: $error');
            if (current()) {
              setState(
                () => _bundle = _bundle.copyWith(
                  lowStockFailed: {..._bundle.lowStockFailed, threshold},
                ),
              );
            }
          });
    }
    _loadReports(requestVersion);
  }

  /// Asks MGWS the questions of the report widgets not answered yet.
  void _loadReports(int requestVersion) {
    bool current() => mounted && requestVersion == _requestVersion;
    final pending = <String>{};
    for (final config in _layout?.widgets ?? const <DashboardWidgetConfig>[]) {
      final query = config.report;
      if (config.metric != DashboardMetric.report || query == null) continue;
      final request = dashboardReportRequest(config, _filters);
      final key = dashboardReportKey(request);
      if (_bundle.reportResults.containsKey(key) ||
          _bundle.reportFailures.containsKey(key) ||
          !pending.add(key)) {
        continue;
      }
      _runReport(query, request)
          .then((result) {
            if (current()) {
              setState(
                () => _bundle = _bundle.copyWith(
                  reportResults: {..._bundle.reportResults, key: result},
                ),
              );
            }
          })
          .catchError((Object error) {
            final failure = error is DashboardReportException
                ? error.failure
                : ReportFailure.failed;
            if (failure == ReportFailure.failed) {
              log.w('Dashboard report not available: $error');
            }
            if (current()) {
              setState(
                () => _bundle = _bundle.copyWith(
                  reportFailures: {..._bundle.reportFailures, key: failure},
                ),
              );
            }
          });
    }
  }

  void _setFilters(DashboardFilters filters, {bool reload = true}) {
    setState(() {
      _filters = filters;
      if (_editing) _layout = _layout?.copyWith(filters: filters);
    });
    if (reload) {
      _loadData(refresh: true);
    } else {
      // Report questions depend on every filter, not only on the period.
      _loadReports(_requestVersion);
    }
  }

  // =======================================================
  // ==                      EDITING                      ==
  // =======================================================

  void _startEditing() {
    setState(() {
      _editing = true;
      _layout = _layout?.copyWith(filters: _filters);
    });
  }

  void _cancelEditing() {
    final saved = _savedLayout;
    setState(() {
      _editing = false;
      _layout = saved;
      if (saved != null) _filters = saved.filters;
    });
    _loadData(refresh: true);
  }

  Future<void> _saveEditing() async {
    final layout = _layout;
    if (layout == null) return;
    final saved = await _persist(layout.copyWith(filters: _filters));
    if (saved == null || !mounted) return;
    setState(() {
      _editing = false;
      _layout = saved;
      _savedLayout = saved;
    });
  }

  /// Saves [layout] and updates the catalog. Returns null when it failed.
  Future<DashboardLayout?> _persist(
    DashboardLayout layout, {
    String? previousId,
  }) async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final saved = await _store.save(layout);
      if (!mounted) return null;
      setState(() => _replaceInCatalog(saved, previousId: previousId));
      NotificationService.instance.messageBar(
        'successo',
        'dashboard',
        l10n.dashboardLayoutSaved,
      );
      return saved;
    } catch (error) {
      log.e('Dashboard save failed', error);
      NotificationService.instance.messageBar(
        'errore',
        'dashboard',
        l10n.dashboardLayoutSaveFailed(error),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateWidgets(List<DashboardWidgetConfig> widgets) {
    setState(() => _layout = _layout?.copyWith(widgets: widgets));
    _loadSecondary(_requestVersion, _filters.toPeriod());
  }

  void _moveWidget(String draggedId, String targetId) {
    final widgets = [...?_layout?.widgets];
    final from = widgets.indexWhere((widget) => widget.id == draggedId);
    final to = widgets.indexWhere((widget) => widget.id == targetId);
    if (from < 0 || to < 0 || from == to) return;
    final moved = widgets.removeAt(from);
    // Dropping on a later widget places it after that widget, on an earlier
    // one before it: the dragged widget always lands where it was dropped.
    widgets.insert(to.clamp(0, widgets.length), moved);
    _updateWidgets(widgets);
  }

  void _moveWidgetToEnd(String draggedId) {
    final widgets = [...?_layout?.widgets];
    final from = widgets.indexWhere((widget) => widget.id == draggedId);
    if (from < 0) return;
    widgets.add(widgets.removeAt(from));
    _updateWidgets(widgets);
  }

  void _shiftWidget(String id, int offset) {
    final widgets = [...?_layout?.widgets];
    final from = widgets.indexWhere((widget) => widget.id == id);
    final to = from + offset;
    if (from < 0 || to < 0 || to >= widgets.length) return;
    widgets.insert(to, widgets.removeAt(from));
    _updateWidgets(widgets);
  }

  void _replaceWidget(DashboardWidgetConfig updated) {
    _updateWidgets([
      for (final widget in _layout?.widgets ?? const <DashboardWidgetConfig>[])
        widget.id == updated.id ? updated : widget,
    ]);
  }

  void _removeWidget(String id) {
    _updateWidgets([
      for (final widget in _layout?.widgets ?? const <DashboardWidgetConfig>[])
        if (widget.id != id) widget,
    ]);
  }

  Future<void> _addWidget() async {
    final created = await _showWidgetEditor(
      DashboardWidgetConfig.create(DashboardMetric.salesTrend),
      isNew: true,
    );
    if (created == null) return;
    _updateWidgets([...?_layout?.widgets, created]);
  }

  Future<void> _editWidget(DashboardWidgetConfig config) async {
    final updated = await _showWidgetEditor(config, isNew: false);
    if (updated != null) _replaceWidget(updated);
  }

  Future<DashboardWidgetConfig?> _showWidgetEditor(
    DashboardWidgetConfig config, {
    required bool isNew,
  }) => showDialog<DashboardWidgetConfig>(
    context: context,
    builder: (_) => _WidgetEditorDialog(
      initial: config,
      isNew: isNew,
      bundle: _bundle,
      filters: _filters,
      runReport: _runReport,
      searchReport: _searchReport,
    ),
  );

  Future<void> _resetToStandard() async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      title: l10n.dashboardLayoutResetTitle,
      message: l10n.dashboardLayoutResetMessage,
      action: l10n.dashboardLayoutReset,
    );
    if (!confirmed) return;
    _updateWidgets(DashboardLayout.standard(name: '').widgets);
  }

  // =======================================================
  // ==                DASHBOARD MANAGEMENT               ==
  // =======================================================

  Future<void> _createDashboard({DashboardLayout? from}) async {
    final l10n = context.l10n;
    final result = await showDialog<_DashboardSettings>(
      context: context,
      builder: (_) => _DashboardSettingsDialog(
        title: from == null
            ? l10n.dashboardLayoutNew
            : l10n.dashboardLayoutDuplicate,
        initialName: from == null
            ? ''
            : l10n.dashboardLayoutCopyName(from.name),
        initialVisibility: DashboardVisibility.personal,
        canManageShared: _canManageShared,
        storedOnServer: _storedOnServer,
      ),
    );
    if (result == null || !mounted) return;
    final source = from;
    final layout = DashboardLayout(
      id: newDashboardId('d'),
      name: result.name,
      visibility: result.visibility,
      filters: source?.filters ?? _filters,
      widgets: source == null
          ? const []
          : [
              for (final widget in source.widgets)
                DashboardWidgetConfig.fromJson({
                  ...widget.toJson(),
                  'id': newDashboardId('w'),
                })!,
            ],
    );
    final saved = await _persist(layout);
    if (saved == null || !mounted) return;
    _open(saved);
    if (saved.widgets.isEmpty) _startEditing();
  }

  Future<void> _editDashboardSettings() async {
    final layout = _layout;
    if (layout == null) return;
    final l10n = context.l10n;
    final result = await showDialog<_DashboardSettings>(
      context: context,
      builder: (_) => _DashboardSettingsDialog(
        title: l10n.dashboardLayoutSettings,
        initialName: layout.name,
        initialVisibility: layout.visibility,
        canManageShared: _canManageShared,
        storedOnServer: _storedOnServer,
      ),
    );
    if (result == null || !mounted) return;
    final changed = layout.copyWith(
      name: result.name,
      visibility: result.visibility,
    );
    if (_editing) {
      // Saved together with the other changes.
      setState(() => _layout = changed);
      return;
    }
    final saved = await _persist(changed);
    if (saved == null || !mounted) return;
    setState(() {
      _layout = saved;
      _savedLayout = saved;
    });
  }

  Future<void> _deleteDashboard() async {
    final layout = _savedLayout;
    if (layout == null) return;
    final l10n = context.l10n;
    final confirmed = await _confirm(
      title: l10n.dashboardLayoutDeleteTitle,
      message: l10n.dashboardLayoutDeleteMessage(layout.name),
      action: l10n.commonDelete,
    );
    if (!confirmed || !mounted) return;
    try {
      await _store.delete(layout);
    } catch (error) {
      log.e('Dashboard delete failed', error);
      NotificationService.instance.messageBar(
        'errore',
        'dashboard',
        l10n.dashboardLayoutSaveFailed(error),
      );
      return;
    }
    if (!mounted) return;
    await _loadCatalog();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // =======================================================
  // ==                  EXPORT / REPORTS                 ==
  // =======================================================

  Future<void> _export() async {
    final dashboard = _bundle.summary;
    if (_exporting || dashboard == null) return;
    final choice = await showDialog<DashboardExportChoice>(
      context: context,
      builder: (_) => ExportDialog(dashboardData: dashboard),
    );
    if (choice == null || !mounted) return;
    final l10n = context.l10n;
    final period = _filters.toPeriod();
    setState(() => _exporting = true);
    try {
      final file = switch ((choice.scope, choice.format)) {
        (DashboardExportScope.dashboard, DashboardExportFormat.csv) =>
          await _exporter.exportDashboardToCsv(dashboard, l10n),
        (DashboardExportScope.dashboard, DashboardExportFormat.pdf) =>
          await _exporter.exportDashboardToPdf(dashboard, l10n),
        (DashboardExportScope.vendite, DashboardExportFormat.csv) =>
          await _exporter.exportVenditeToCsv(
            await _reports.getReportVendite(periodo: period),
            l10n,
          ),
        (DashboardExportScope.vendite, DashboardExportFormat.pdf) =>
          await _exporter.exportVenditeToPdf(
            await _reports.getReportVendite(periodo: period),
            l10n,
          ),
      };
      final saved = await _exporter.saveFile(
        file,
        dialogTitle: choice.title(l10n),
      );
      // Finestra annullata: nessun messaggio.
      if (saved == null) return;
      NotificationService.instance.messageBar(
        'successo',
        'dashboard',
        l10n.dashboardReportGenerato(saved),
      );
    } catch (error) {
      log.e('Dashboard export failed', error);
      NotificationService.instance.messageBar(
        'errore',
        'dashboard',
        l10n.dashboardExportFallito(error),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // =======================================================
  // ==                       BUILD                       ==
  // =======================================================

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    return Scaffold(
      body: SafeArea(
        child: layout == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToolbar(layout),
                  _FilterBar(filters: _filters, onChanged: _setFilters),
                  if (_editing) _buildEditBar(layout),
                  SizedBox(
                    height: 2,
                    child: (_loading && _bundle.summary != null) || _saving
                        ? const LinearProgressIndicator(minHeight: 2)
                        : null,
                  ),
                  Expanded(child: _buildContent(layout)),
                ],
              ),
      ),
    );
  }

  Widget _buildToolbar(DashboardLayout layout) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canEdit = layout.editable;

    final selector = PopupMenuButton<String>(
      enabled: !_editing,
      tooltip: l10n.dashboardLayoutChoose,
      onSelected: (id) {
        if (id == '_new') {
          _createDashboard();
          return;
        }
        final picked = _dashboards.where((item) => item.id == id).firstOrNull;
        if (picked != null && picked.id != layout.id) _open(picked);
      },
      itemBuilder: (_) => [
        for (final item in _dashboards)
          PopupMenuItem(
            value: item.id,
            child: ListTile(
              dense: true,
              selected: item.id == layout.id,
              leading: Icon(_visibilityIcon(item.visibility)),
              title: Text(item.name),
              subtitle: Text(_visibilityLabel(l10n, item.visibility)),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '_new',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.add),
            title: Text(l10n.dashboardLayoutNew),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              layout.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more,
            color: _editing
                ? theme.disabledColor
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    final narrow = MediaQuery.sizeOf(context).width < 600;
    final visibilityIcon = Icon(
      layout.editable ? _visibilityIcon(layout.visibility) : Icons.lock,
      size: 16,
    );
    final visibilityChip = Tooltip(
      message: layout.editable
          ? _visibilityLabel(l10n, layout.visibility)
          : l10n.dashboardLayoutReadOnly,
      child: narrow
          ? visibilityIcon
          : Chip(
              visualDensity: VisualDensity.compact,
              avatar: visibilityIcon,
              label: Text(_visibilityLabel(l10n, layout.visibility)),
            ),
    );

    final menu = PopupMenuButton<String>(
      tooltip: l10n.dashboardLayoutMore,
      icon: _exporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'new':
            _createDashboard();
          case 'duplicate':
            _createDashboard(from: _layout);
          case 'settings':
            _editDashboardSettings();
          case 'delete':
            _deleteDashboard();
          case 'export':
            _export();
          case 'top':
            _push(TopProductsReportPage(periodo: _filters.toPeriod()));
          case 'performance':
            _push(PerformanceTimelineReportPage(periodo: _filters.toPeriod()));
          case 'orders':
            _push(const OrdersDetailedReportPage());
        }
      },
      itemBuilder: (_) => [
        _menuItem('new', Icons.add, l10n.dashboardLayoutNew, !_editing),
        _menuItem(
          'duplicate',
          Icons.copy_outlined,
          l10n.dashboardLayoutDuplicate,
          !_editing,
        ),
        _menuItem(
          'settings',
          Icons.tune,
          l10n.dashboardLayoutSettings,
          canEdit,
        ),
        _menuItem(
          'delete',
          Icons.delete_outline,
          l10n.dashboardLayoutDelete,
          canEdit && !_editing && _dashboards.length > 1,
        ),
        const PopupMenuDivider(),
        _menuItem(
          'export',
          Icons.file_download_outlined,
          l10n.dashboardEsportaReport,
          _bundle.summary != null && !_exporting,
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          height: 32,
          child: Text(
            l10n.dashboardReportDettagliati,
            style: theme.textTheme.labelMedium,
          ),
        ),
        _menuItem('top', Icons.star_outline, l10n.dashboardTopProdotti, true),
        _menuItem(
          'performance',
          Icons.show_chart,
          l10n.dashboardPerformanceTemporale,
          true,
        ),
        _menuItem(
          'orders',
          Icons.receipt_long_outlined,
          l10n.dashboardAnalisiOrdini,
          true,
        ),
      ],
    );

    final actions = <Widget>[
      IconButton(
        onPressed: () => _loadData(refresh: true),
        tooltip: l10n.commonRefresh,
        icon: const Icon(Icons.refresh),
      ),
      if (canEdit && !_editing)
        IconButton(
          onPressed: _startEditing,
          tooltip: l10n.dashboardLayoutEdit,
          icon: const Icon(Icons.dashboard_customize_outlined),
        ),
      menu,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Flexible(child: selector),
          SizedBox(width: narrow ? 8 : 12),
          visibilityChip,
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    bool enabled,
  ) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: ListTile(dense: true, leading: Icon(icon), title: Text(label)),
  );

  Widget _buildEditBar(DashboardLayout layout) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.edit_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          Text(
            l10n.dashboardLayoutEditingHint,
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _addWidget,
            icon: const Icon(Icons.add),
            label: Text(l10n.dashboardWidgetAdd),
          ),
          OutlinedButton.icon(
            onPressed: _editDashboardSettings,
            icon: Icon(_visibilityIcon(layout.visibility)),
            label: Text(l10n.dashboardLayoutSettings),
          ),
          TextButton(
            onPressed: _resetToStandard,
            child: Text(l10n.dashboardLayoutReset),
          ),
          TextButton(
            onPressed: _saving ? null : _cancelEditing,
            child: Text(l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _saveEditing,
            icon: const Icon(Icons.check),
            label: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DashboardLayout layout) {
    final l10n = context.l10n;
    if (_bundle.summary == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: l10n.dashboardImpossibileCaricare,
        detail: _errorText(_error),
        action: FilledButton.icon(
          onPressed: () => _loadData(refresh: true),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.inventoryRiprova),
        ),
      );
    }

    final format = DashboardFormat.of(context);
    final period = _filters.toPeriod();
    final summary = _bundle.summary!;
    final header = [
      format.range(period),
      if (_filters.compareWithPrevious)
        l10n.dashboardConfrontoCon(format.range(period.periodoPrecedente)),
      l10n.dashboardAggiornatoAlle(format.time(summary.ultimoAggiornamento)),
    ].join('  ·  ');

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      child: AnimatedOpacity(
        // While reloading, the old data stays visible, dimmed.
        opacity: _loading ? 0.55 : 1,
        duration: const Duration(milliseconds: 150),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      header,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorNotice(text: _errorText(_error) ?? ''),
                    ],
                    const SizedBox(height: 16),
                    if (layout.widgets.isEmpty)
                      _EmptyDashboard(
                        canEdit: layout.editable,
                        onAdd: () {
                          if (!_editing) _startEditing();
                          _addWidget();
                        },
                      )
                    else
                      _WidgetGrid(
                        width: (constraints.maxWidth - 40)
                            .clamp(0, 1600)
                            .toDouble(),
                        widgets: layout.widgets,
                        editing: _editing,
                        datasetOf: (config) => resolveDashboardDataset(
                          widget: config,
                          bundle: _bundle,
                          filters: _filters,
                          l10n: l10n,
                        ),
                        onMove: _moveWidget,
                        onMoveToEnd: _moveWidgetToEnd,
                        onShift: _shiftWidget,
                        onEdit: _editWidget,
                        onRemove: _removeWidget,
                        onResize: _replaceWidget,
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

  String? _errorText(Object? error) {
    if (error == null) return null;
    if (error is ReportException) return error.userMessage(context.l10n);
    return error.toString();
  }
}

String _visibilityLabel(AppLocalizations l10n, DashboardVisibility v) =>
    switch (v) {
      DashboardVisibility.personal => l10n.dashboardVisibilityPersonal,
      DashboardVisibility.everyone => l10n.dashboardVisibilityEveryone,
      DashboardVisibility.admins => l10n.dashboardVisibilityAdmins,
    };

IconData _visibilityIcon(DashboardVisibility v) => switch (v) {
  DashboardVisibility.personal => Icons.person_outline,
  DashboardVisibility.everyone => Icons.groups_outlined,
  DashboardVisibility.admins => Icons.admin_panel_settings_outlined,
};

// =======================================================
// ==                    FILTER BAR                     ==
// =======================================================

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged});

  final DashboardFilters filters;
  final void Function(DashboardFilters filters, {bool reload}) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = DashboardFormat.of(context);
    final custom = filters.periodPreset == DashboardPeriodPreset.custom;
    final statuses = filters.orderStatuses;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownMenu<DashboardPeriodPreset>(
            initialSelection: filters.periodPreset,
            leadingIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            width: 220,
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            label: Text(l10n.dashboardFilterPeriod),
            onSelected: (preset) async {
              if (preset == null) return;
              if (preset == DashboardPeriodPreset.custom) {
                await _pickRange(context);
                return;
              }
              onChanged(filters.copyWith(periodPreset: preset));
            },
            dropdownMenuEntries: [
              for (final preset in DashboardPeriodPreset.values)
                DropdownMenuEntry(
                  value: preset,
                  label: _presetLabel(l10n, preset),
                ),
            ],
          ),
          if (custom)
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(format.range(filters.toPeriod())),
              onPressed: () => _pickRange(context),
            ),
          FilterChip(
            label: Text(l10n.dashboardFilterCompare),
            selected: filters.compareWithPrevious,
            onSelected: (value) => onChanged(
              filters.copyWith(compareWithPrevious: value),
              reload: false,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.dashboardFilterOrderStatus,
            itemBuilder: (_) => [
              for (final status in WooQueryReport.orderStatuses)
                CheckedPopupMenuItem(
                  value: status,
                  checked: statuses.isEmpty || statuses.contains(status),
                  child: Text(dashboardOrderStatusLabel(l10n, status)),
                ),
            ],
            onSelected: (status) {
              final current = statuses.isEmpty
                  ? WooQueryReport.orderStatuses.toSet()
                  : {...statuses};
              current.contains(status)
                  ? current.remove(status)
                  : current.add(status);
              final all = current.length == WooQueryReport.orderStatuses.length;
              onChanged(
                filters.copyWith(orderStatuses: all ? const {} : current),
                reload: false,
              );
            },
            child: Chip(
              avatar: const Icon(Icons.filter_list, size: 18),
              label: Text(
                statuses.isEmpty
                    ? l10n.dashboardFilterAllStatuses
                    : l10n.dashboardFilterStatusesCount(statuses.length),
              ),
            ),
          ),
          if (filters.periodPreset != DashboardPeriodPreset.month ||
              statuses.isNotEmpty ||
              !filters.compareWithPrevious)
            TextButton.icon(
              onPressed: () => onChanged(const DashboardFilters()),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(l10n.dashboardFilterReset),
            ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final period = filters.toPeriod();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: period.dataInizio,
        end: period.dataFine.isAfter(now) ? now : period.dataFine,
      ),
    );
    if (range == null) return;
    onChanged(
      filters.copyWith(
        periodPreset: DashboardPeriodPreset.custom,
        customStart: range.start,
        customEnd: range.end,
      ),
    );
  }

  static String _presetLabel(AppLocalizations l10n, DashboardPeriodPreset p) =>
      switch (p) {
        DashboardPeriodPreset.today => l10n.dashboardOggi,
        DashboardPeriodPreset.week => l10n.dashboardQuestaSettimana,
        DashboardPeriodPreset.month => l10n.dashboardQuestoMese,
        DashboardPeriodPreset.year => l10n.dashboardQuestAnno,
        DashboardPeriodPreset.last7Days => l10n.dashboardFilterLast7Days,
        DashboardPeriodPreset.last30Days => l10n.dashboardFilterLast30Days,
        DashboardPeriodPreset.last90Days => l10n.dashboardFilterLast90Days,
        DashboardPeriodPreset.custom => l10n.dashboardFilterCustomRange,
      };
}

// =======================================================
// ==                     WIDGET GRID                   ==
// =======================================================

/// 12-column grid. On medium screens narrow widgets take half the width, on
/// phones every widget takes the full width.
class _WidgetGrid extends StatelessWidget {
  const _WidgetGrid({
    required this.width,
    required this.widgets,
    required this.editing,
    required this.datasetOf,
    required this.onMove,
    required this.onMoveToEnd,
    required this.onShift,
    required this.onEdit,
    required this.onRemove,
    required this.onResize,
  });

  static const gap = 16.0;

  final double width;
  final List<DashboardWidgetConfig> widgets;
  final bool editing;
  final DashboardDataset Function(DashboardWidgetConfig config) datasetOf;
  final void Function(String draggedId, String targetId) onMove;
  final ValueChanged<String> onMoveToEnd;
  final void Function(String id, int offset) onShift;
  final ValueChanged<DashboardWidgetConfig> onEdit;
  final ValueChanged<String> onRemove;
  final ValueChanged<DashboardWidgetConfig> onResize;

  int _columnsFor(DashboardWidgetWidth widgetWidth) {
    if (width >= 1000) return widgetWidth.columns;
    if (width >= 640) return widgetWidth.columns <= 6 ? 6 : 12;
    return 12;
  }

  double _pixelsFor(DashboardWidgetWidth widgetWidth) {
    final columns = _columnsFor(widgetWidth);
    final column = (width - gap * 11) / 12;
    // A hair less than the exact width so rounding never wraps a full row.
    return column * columns + gap * (columns - 1) - 0.01;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (var index = 0; index < widgets.length; index++)
          SizedBox(
            width: _pixelsFor(widgets[index].width),
            child: editing
                ? _EditableTile(
                    config: widgets[index],
                    dataset: datasetOf(widgets[index]),
                    isFirst: index == 0,
                    isLast: index == widgets.length - 1,
                    onMove: onMove,
                    onShift: onShift,
                    onEdit: onEdit,
                    onRemove: onRemove,
                    onResize: onResize,
                  )
                : DashboardWidgetCard(
                    config: widgets[index],
                    dataset: datasetOf(widgets[index]),
                  ),
          ),
        if (editing)
          SizedBox(
            width: width,
            child: _EndDropZone(onDrop: onMoveToEnd),
          ),
      ],
    );
  }
}

class _EditableTile extends StatelessWidget {
  const _EditableTile({
    required this.config,
    required this.dataset,
    required this.isFirst,
    required this.isLast,
    required this.onMove,
    required this.onShift,
    required this.onEdit,
    required this.onRemove,
    required this.onResize,
  });

  final DashboardWidgetConfig config;
  final DashboardDataset dataset;
  final bool isFirst;
  final bool isLast;
  final void Function(String draggedId, String targetId) onMove;
  final void Function(String id, int offset) onShift;
  final ValueChanged<DashboardWidgetConfig> onEdit;
  final ValueChanged<String> onRemove;
  final ValueChanged<DashboardWidgetConfig> onResize;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = dashboardWidgetTitle(l10n, config);

    final handle = Draggable<String>(
      data: config.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.inverseSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dashboardChartIcon(config.chartType),
                size: 18,
                color: theme.colorScheme.onInverseSurface,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: theme.colorScheme.onInverseSurface),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: l10n.dashboardWidgetDragHint,
          child: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.drag_indicator, size: 20),
          ),
        ),
      ),
    );

    final menu = PopupMenuButton<String>(
      tooltip: l10n.dashboardWidgetOptions,
      icon: const Icon(Icons.more_horiz, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit(config);
          case 'before':
            onShift(config.id, -1);
          case 'after':
            onShift(config.id, 1);
          case 'remove':
            onRemove(config.id);
          default:
            if (value.startsWith('width:')) {
              final name = value.substring(6);
              onResize(
                config.copyWith(
                  width: DashboardWidgetWidth.values.byName(name),
                ),
              );
            } else if (value.startsWith('height:')) {
              final name = value.substring(7);
              onResize(
                config.copyWith(
                  height: DashboardWidgetHeight.values.byName(name),
                ),
              );
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.tune),
            title: Text(l10n.dashboardWidgetEdit),
          ),
        ),
        PopupMenuItem(
          value: 'before',
          enabled: !isFirst,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_back),
            title: Text(l10n.dashboardWidgetMoveBefore),
          ),
        ),
        PopupMenuItem(
          value: 'after',
          enabled: !isLast,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_forward),
            title: Text(l10n.dashboardWidgetMoveAfter),
          ),
        ),
        const PopupMenuDivider(),
        for (final widgetWidth in DashboardWidgetWidth.values)
          CheckedPopupMenuItem(
            value: 'width:${widgetWidth.name}',
            checked: config.width == widgetWidth,
            child: Text(dashboardWidthLabel(l10n, widgetWidth)),
          ),
        const PopupMenuDivider(),
        for (final widgetHeight in DashboardWidgetHeight.values)
          CheckedPopupMenuItem(
            value: 'height:${widgetHeight.name}',
            checked: config.height == widgetHeight,
            child: Text(dashboardHeightLabel(l10n, widgetHeight)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.dashboardWidgetRemove),
          ),
        ),
      ],
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != config.id,
      onAcceptWithDetails: (details) => onMove(details.data, config.id),
      builder: (context, candidates, _) => DashboardWidgetCard(
        config: config,
        dataset: dataset,
        highlighted: candidates.isNotEmpty,
        leading: handle,
        trailing: menu,
      ),
    );
  }
}

class _EndDropZone extends StatelessWidget {
  const _EndDropZone({required this.onDrop});

  final ValueChanged<String> onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<String>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: candidates.isEmpty ? 48 : 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: candidates.isEmpty ? scheme.outlineVariant : scheme.primary,
            width: candidates.isEmpty ? 1 : 2,
          ),
        ),
        child: Text(
          context.l10n.dashboardWidgetDropAtEnd,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

String dashboardWidthLabel(AppLocalizations l10n, DashboardWidgetWidth w) =>
    switch (w) {
      DashboardWidgetWidth.quarter => l10n.dashboardWidgetWidthQuarter,
      DashboardWidgetWidth.third => l10n.dashboardWidgetWidthThird,
      DashboardWidgetWidth.half => l10n.dashboardWidgetWidthHalf,
      DashboardWidgetWidth.twoThirds => l10n.dashboardWidgetWidthTwoThirds,
      DashboardWidgetWidth.threeQuarters =>
        l10n.dashboardWidgetWidthThreeQuarters,
      DashboardWidgetWidth.full => l10n.dashboardWidgetWidthFull,
    };

String dashboardHeightLabel(AppLocalizations l10n, DashboardWidgetHeight h) =>
    switch (h) {
      DashboardWidgetHeight.compact => l10n.dashboardWidgetHeightCompact,
      DashboardWidgetHeight.medium => l10n.dashboardWidgetHeightMedium,
      DashboardWidgetHeight.tall => l10n.dashboardWidgetHeightTall,
    };

String _sortLabel(AppLocalizations l10n, DashboardSortOrder order) =>
    switch (order) {
      DashboardSortOrder.natural => l10n.dashboardWidgetSortNatural,
      DashboardSortOrder.valueDesc => l10n.dashboardWidgetSortValueDesc,
      DashboardSortOrder.valueAsc => l10n.dashboardWidgetSortValueAsc,
      DashboardSortOrder.labelAsc => l10n.dashboardWidgetSortLabel,
    };

String _shapeLabel(AppLocalizations l10n, DashboardMetricShape shape) =>
    switch (shape) {
      DashboardMetricShape.single => l10n.dashboardWidgetGroupNumbers,
      DashboardMetricShape.timeSeries => l10n.dashboardWidgetGroupTrends,
      DashboardMetricShape.categories => l10n.dashboardWidgetGroupRankings,
    };

// =======================================================
// ==                   WIDGET EDITOR                   ==
// =======================================================

class _WidgetEditorDialog extends StatefulWidget {
  const _WidgetEditorDialog({
    required this.initial,
    required this.isNew,
    required this.bundle,
    required this.filters,
    required this.runReport,
    required this.searchReport,
  });

  final DashboardWidgetConfig initial;
  final bool isNew;
  final DashboardDataBundle bundle;
  final DashboardFilters filters;
  final DashboardReportRunner runReport;
  final DashboardReportSearch searchReport;

  @override
  State<_WidgetEditorDialog> createState() => _WidgetEditorDialogState();
}

class _WidgetEditorDialogState extends State<_WidgetEditorDialog> {
  late var _config = widget.initial;
  late final _titleController = TextEditingController(
    text: widget.initial.title,
  );
  late final _filterController = TextEditingController(
    text: widget.initial.itemFilter,
  );

  static const _limits = [3, 5, 10, 15, 20];

  /// Answers loaded for the preview of report questions.
  final _reportResults = <String, DashboardReportResult>{};
  final _reportFailures = <String, ReportFailure>{};
  Timer? _reportDebounce;

  @override
  void initState() {
    super.initState();
    _scheduleReport();
  }

  @override
  void dispose() {
    _reportDebounce?.cancel();
    _titleController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _update(DashboardWidgetConfig config) {
    setState(() => _config = config);
    _scheduleReport();
  }

  void _scheduleReport() {
    final query = _config.report;
    if (_config.metric != DashboardMetric.report || query == null) return;
    final request = dashboardReportRequest(_config, widget.filters);
    final key = dashboardReportKey(request);
    if (widget.bundle.reportResults.containsKey(key) ||
        _reportResults.containsKey(key) ||
        _reportFailures.containsKey(key)) {
      return;
    }
    _reportDebounce?.cancel();
    _reportDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await widget.runReport(query, request);
        if (mounted) setState(() => _reportResults[key] = result);
      } catch (error) {
        if (!mounted) return;
        setState(
          () => _reportFailures[key] = error is DashboardReportException
              ? error.failure
              : ReportFailure.failed,
        );
      }
    });
  }

  void _setMetric(DashboardMetric metric) {
    final defaults = DashboardWidgetConfig.create(metric);
    final next = _config.copyWith(metric: metric, report: defaults.report);
    _update(
      next.copyWith(
        chartType: next.chartTypes.first,
        // A new widget follows the sensible size of the new metric.
        width: widget.isNew ? defaults.width : null,
        height: widget.isNew ? defaults.height : null,
      ),
    );
  }

  void _setReport(DashboardReportQuery query) {
    final previousShape = _config.shape;
    final next = _config.copyWith(report: query);
    if (next.shape == previousShape) {
      _update(next);
      return;
    }
    // A different shape needs another chart and, for a new widget, size.
    final sized = next.withSizeForShape();
    _update(
      widget.isNew
          ? sized
          : sized.copyWith(width: _config.width, height: _config.height),
    );
  }

  Future<void> _applyPreset(ReportPreset preset) async {
    final model = dashboardReportPresetWidget(preset);
    _titleController.clear();
    final applied = _config.copyWith(
      report: model.report,
      chartType: model.chartType,
      sortOrder: model.sortOrder,
      itemLimit: model.itemLimit,
      title: '',
      width: widget.isNew ? model.width : null,
      height: widget.isNew ? model.height : null,
    );
    _update(applied);
    final required = preset.requiredFilter;
    if (required == null) return;
    final picked = await pickReportFilters(
      context,
      kind: required,
      initial: const [],
      search: widget.searchReport,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _setReport(
      (_config.report ?? const DashboardReportQuery()).copyWith(
        filters: picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final metric = _config.metric;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<DashboardMetric>(
          initialValue: metric,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.dashboardWidgetData,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<DashboardMetric>(
              value: DashboardMetric.report,
              child: Row(
                children: [
                  Icon(
                    Icons.query_stats,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.dashboardReportCustom,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            for (final shape in DashboardMetricShape.values) ...[
              DropdownMenuItem<DashboardMetric>(
                enabled: false,
                child: Text(
                  _shapeLabel(l10n, shape),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final option in DashboardMetric.values)
                if (option.shape == shape && option != DashboardMetric.report)
                  DropdownMenuItem(
                    value: option,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(dashboardMetricLabel(l10n, option)),
                    ),
                  ),
            ],
          ],
          onChanged: (value) {
            if (value != null) _setMetric(value);
          },
        ),
        if (metric == DashboardMetric.report) ...[
          const SizedBox(height: 16),
          DashboardReportQueryEditor(
            query: _config.report ?? const DashboardReportQuery(),
            onChanged: _setReport,
            onPreset: _applyPreset,
            search: widget.searchReport,
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.dashboardWidgetChartType, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chart in _config.chartTypes)
              ChoiceChip(
                avatar: Icon(dashboardChartIcon(chart), size: 18),
                label: Text(dashboardChartLabel(l10n, chart)),
                selected: _config.chartType == chart,
                onSelected: (_) => _update(_config.copyWith(chartType: chart)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: l10n.dashboardWidgetTitle,
            hintText: dashboardWidgetTitle(l10n, _config.copyWith(title: '')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _update(_config.copyWith(title: value)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DashboardWidgetWidth>(
                initialValue: _config.width,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.dashboardWidgetWidth,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final value in DashboardWidgetWidth.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(dashboardWidthLabel(l10n, value)),
                    ),
                ],
                onChanged: (value) => _update(_config.copyWith(width: value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<DashboardWidgetHeight>(
                initialValue: _config.height,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.dashboardWidgetHeight,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final value in DashboardWidgetHeight.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(dashboardHeightLabel(l10n, value)),
                    ),
                ],
                onChanged: (value) => _update(_config.copyWith(height: value)),
              ),
            ),
          ],
        ),
        if (_config.hasItemLimit) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _limits.contains(_config.itemLimit)
                      ? _config.itemLimit
                      : 5,
                  decoration: InputDecoration(
                    labelText: l10n.dashboardWidgetItemLimit,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final limit in _limits)
                      DropdownMenuItem(value: limit, child: Text('$limit')),
                  ],
                  onChanged: (value) =>
                      _update(_config.copyWith(itemLimit: value)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<DashboardSortOrder>(
                  initialValue: _config.sortOrder,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.dashboardWidgetSort,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final order in DashboardSortOrder.values)
                      DropdownMenuItem(
                        value: order,
                        child: Text(_sortLabel(l10n, order)),
                      ),
                  ],
                  onChanged: (value) =>
                      _update(_config.copyWith(sortOrder: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filterController,
            decoration: InputDecoration(
              labelText: l10n.dashboardWidgetItemFilter,
              helperText: l10n.dashboardWidgetItemFilterHelp,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _update(_config.copyWith(itemFilter: value)),
          ),
        ],
        if (metric.hasStockThreshold) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: '${_config.stockThreshold}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.dashboardWidgetStockThreshold,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                _update(_config.copyWith(stockThreshold: parsed));
              }
            },
          ),
        ],
        if (metric.usesOrderStatusFilter) ...[
          const SizedBox(height: 12),
          Text(
            l10n.dashboardWidgetUsesStatusFilter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final preview = DashboardWidgetCard(
      config: _config.copyWith(
        // The preview keeps a readable size whatever the chosen height.
        height: _config.height == DashboardWidgetHeight.compact
            ? DashboardWidgetHeight.compact
            : DashboardWidgetHeight.medium,
      ),
      dataset: resolveDashboardDataset(
        widget: _config,
        bundle: widget.bundle.copyWith(
          reportResults: {...widget.bundle.reportResults, ..._reportResults},
          reportFailures: {...widget.bundle.reportFailures, ..._reportFailures},
        ),
        filters: widget.filters,
        l10n: l10n,
      ),
    );

    return AlertDialog(
      title: Text(
        widget.isNew ? l10n.dashboardWidgetAdd : l10n.dashboardWidgetEdit,
      ),
      content: SizedBox(
        width: 860,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            final previewBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.dashboardWidgetPreview,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                preview,
              ],
            );
            if (wide) {
              return SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: form),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: previewBlock),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, const SizedBox(height: 20), previewBlock],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _config),
          child: Text(widget.isNew ? l10n.dashboardWidgetAdd : l10n.commonSave),
        ),
      ],
    );
  }
}

// =======================================================
// ==              DASHBOARD SETTINGS DIALOG            ==
// =======================================================

class _DashboardSettings {
  const _DashboardSettings(this.name, this.visibility);

  final String name;
  final DashboardVisibility visibility;
}

class _DashboardSettingsDialog extends StatefulWidget {
  const _DashboardSettingsDialog({
    required this.title,
    required this.initialName,
    required this.initialVisibility,
    required this.canManageShared,
    required this.storedOnServer,
  });

  final String title;
  final String initialName;
  final DashboardVisibility initialVisibility;
  final bool canManageShared;
  final bool storedOnServer;

  @override
  State<_DashboardSettingsDialog> createState() =>
      _DashboardSettingsDialogState();
}

class _DashboardSettingsDialogState extends State<_DashboardSettingsDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late var _visibility = widget.initialVisibility;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _DashboardSettings(name, _visibility));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canShare = widget.canManageShared && widget.storedOnServer;

    String description(DashboardVisibility v) => switch (v) {
      DashboardVisibility.personal => l10n.dashboardVisibilityPersonalHelp,
      DashboardVisibility.everyone => l10n.dashboardVisibilityEveryoneHelp,
      DashboardVisibility.admins => l10n.dashboardVisibilityAdminsHelp,
    };

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: l10n.commonName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.dashboardVisibilityTitle,
                style: theme.textTheme.labelLarge,
              ),
              RadioGroup<DashboardVisibility>(
                groupValue: _visibility,
                onChanged: (value) {
                  if (value != null) setState(() => _visibility = value);
                },
                child: Column(
                  children: [
                    for (final option in DashboardVisibility.values)
                      RadioListTile<DashboardVisibility>(
                        value: option,
                        enabled:
                            option == DashboardVisibility.personal || canShare,
                        secondary: Icon(_visibilityIcon(option)),
                        title: Text(_visibilityLabel(l10n, option)),
                        subtitle: Text(description(option)),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (!widget.storedOnServer)
                Text(
                  l10n.dashboardVisibilityLocalOnly,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (!widget.canManageShared)
                Text(
                  l10n.dashboardVisibilityManagersOnly,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

// =======================================================
// ==                  SHARED ELEMENTS                  ==
// =======================================================

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.canEdit, required this.onAdd});

  final bool canEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: _Message(
        icon: Icons.dashboard_customize_outlined,
        title: l10n.dashboardLayoutEmpty,
        detail: canEdit ? l10n.dashboardLayoutEmptyHint : null,
        action: canEdit
            ? FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.dashboardWidgetAdd),
              )
            : null,
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
