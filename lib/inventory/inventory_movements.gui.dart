// inventory_movements.gui.dart
//
// The MGWS ledger, read one operation at a time.
//
// A row is an operation, not a product: MGWS writes one row per product, so
// movements sharing source and document are merged by `groupMovements`. The
// operator thinks in operations ("that load last night"), so this is the
// useful cut.
//
// Double-clicking opens the operation dialog, where the operator can reopen it
// in the panel that created it or undo it with a counter-movement. Adjustments
// and transfers write a new movement. A stock-in is the one exception: it is
// edited in place through MGWS PATCH, and only while it is the last movement.
//
// Filtering uses DataGridFiltersBar (the same component as product
// management) and pagination uses GlobalPaginationBar.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../reuse_class/datagridview/datagridview_filters_bar.gui.dart';
import '../reuse_class/datagridview/datagridview_list.gui.dart';
import '../reuse_class/gui/global_pagination_bar.dart';
import '../reuse_class/gui/searchable_checkbox_dialog.dart';
import '../settings/app_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_movements_detail.gui.dart';

class InventoryMovementLedgerPanel extends StatefulWidget {
  InventoryMovementLedgerPanel({super.key, this.gateway, this.onReopen});

  final MgwsRestockGateway? gateway;
  final void Function(InventoryPanelSeed seed)? onReopen;

  @override
  State<InventoryMovementLedgerPanel> createState() =>
      _InventoryMovementLedgerPanelState();
}

class _InventoryMovementLedgerPanelState
    extends State<InventoryMovementLedgerPanel> {
  late final MgwsRestockGateway _gateway;
  late final DataGridListController<InventoryMovementGroup> _controller;

  /// Undo has its own controller because its restore plan differs from a
  /// normal adjustment: it checks the current stock before changing it.
  final _revert = InventoryMovementRevertController();

  static const String _columnsKey = 'inventory-movement-columns';
  static const String _pageSizeKey = 'inventory-movement-page-size';
  static const int _defaultPageSize = 100;
  static const List<String> _defaultColumns = <String>[
    'time',
    'kind',
    'operator',
    'delta',
    'products',
    'last',
    'reason',
  ];

  InventoryActionFeedback? _feedback;
  List<String> _visibleColumns = _defaultColumns;

  @override
  void initState() {
    super.initState();
    _loadVisibleColumns();
    _gateway = widget.gateway ?? QueryMgwsInventory();
    _controller = DataGridListController<InventoryMovementGroup>(
      fields: _fields(),
      idOf: (g) => g.key,
      loadPage: _loadPage,
      cacheKey: 'inventory-movements',
      serverFiltering: true,
      serverSearch: true,
    );
    // MGWS returns one row per product: to merge an operation into a single
    // row, its products must be in the same page. 100 is the server maximum
    // and the panel's historical default; the operator can still change it
    // from the pagination bar. The value is kept per ledger, not in the
    // global page-size setting shared by every grid.
    _controller.pagination.setPageSize(_defaultPageSize, notify: false);
    _controller.addListener(_onControllerChanged);
    unawaited(_loadPageSizeAndList());
  }

  /// Applies the ledger's saved page size before the first request, so the
  /// global grid default can never override the 100-row grouping default.
  Future<void> _loadPageSizeAndList() async {
    var size = _defaultPageSize;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_pageSizeKey);
      if (saved != null && saved > 0) size = saved;
    } catch (_) {
      // A storage failure must not hide the ledger.
    }
    if (!mounted) return;
    _controller.pagination.setPageSize(size, notify: false);
    await _load();
  }

  Future<void> _persistPageSize(int size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pageSizeKey, size);
    } catch (_) {
      // A storage failure must not break pagination.
    }
  }

  Future<void> _loadVisibleColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_columnsKey);
      if (!mounted || saved == null || saved.isEmpty) return;
      final known = _defaultColumns.toSet();
      final next = saved.where(known.contains).toList();
      if (next.isNotEmpty) setState(() => _visibleColumns = next);
    } catch (_) {
      // A storage failure must not hide the ledger.
    }
  }

  Future<void> _openColumnPicker() async {
    final columns = _allColumns();
    final labels = <String, String>{
      for (final column in columns) column.id: column.label,
    };
    final selected = await SearchableCheckboxDialog.show(
      context,
      title: context.l10n.prodottiColonneVisibili,
      inputLabel: context.l10n.prodottiCercaColonna,
      input_list: [for (final id in _defaultColumns) labels[id]!],
      preselected_list: [
        for (final id in _visibleColumns)
          if (labels.containsKey(id)) labels[id]!,
      ],
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    final next = _defaultColumns
        .where((id) => selected.contains(labels[id]))
        .toList();
    if (next.isEmpty) return;
    setState(() => _visibleColumns = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_columnsKey, next);
    } catch (_) {
      // The choice still applies for this session.
    }
  }

  List<DataGridField<InventoryMovementGroup>> _fields() {
    return <DataGridField<InventoryMovementGroup>>[
      DataGridField<InventoryMovementGroup>(
        name: 'product_id',
        label: (l) => l.inventoryEtichettaProductId,
        type: DataGridFieldType.numero,
        read: (g) => [for (final p in g.products) p.productId],
        serverParam: 'product_id',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'variation_id',
        label: (l) => l.inventoryEtichettaVariationId,
        type: DataGridFieldType.numero,
        read: (g) => [for (final p in g.products) p.variationId],
        serverParam: 'variation_id',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'date_from',
        label: (l) => l.inventoryEtichettaDaData,
        type: DataGridFieldType.data,
        read: (g) => [
          DateTime.tryParse(g.occurredAtGmt.replaceFirst(' ', 'T')),
        ],
        serverParam: 'date_from',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'date_to',
        label: (l) => l.inventoryEtichettaAData,
        type: DataGridFieldType.data,
        read: (g) => [
          DateTime.tryParse(g.occurredAtGmt.replaceFirst(' ', 'T')),
        ],
        serverParam: 'date_to',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'source_type',
        label: (l) => l.inventoryEtichettaSource,
        type: DataGridFieldType.testo,
        read: (g) => [g.sourceType],
        serverParam: 'source_type',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'operator',
        label: (l) => l.inventoryEtichettaOperatore,
        type: DataGridFieldType.numero,
        read: (g) => [g.operatorUserId],
        serverParam: 'user_id',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'reason',
        label: (l) => l.inventoryEtichettaReason,
        type: DataGridFieldType.testo,
        read: (g) => [g.reason],
        serverParam: 'reason_code',
        filterable: true,
        column: false,
      ),
      DataGridField<InventoryMovementGroup>(
        name: 'stock_effect',
        label: (l) => l.inventoryEtichettaEffetto,
        type: DataGridFieldType.testo,
        read: (g) => [
          g.movements.isNotEmpty ? g.movements.first.stockEffect : '',
        ],
        serverParam: 'stock_effect',
        filterable: true,
        column: false,
      ),
    ];
  }

  Future<PaginatedResult<InventoryMovementGroup>> _loadPage(
    DataGridPageRequest request,
  ) async {
    // Convert the DataGrid filters into MgwsMovementFilter.
    int? productId;
    int? variationId;
    String? dateFrom;
    String? dateTo;
    String? sourceType;
    int? operatorUserId;
    String? reasonCode;
    String? stockEffect;

    for (final f in request.filters) {
      final val = f.valori.isNotEmpty ? f.valori.first : '';
      switch (f.fieldName) {
        case 'product_id':
          productId = int.tryParse(val);
          break;
        case 'variation_id':
          variationId = int.tryParse(val);
          break;
        case 'date_from':
          dateFrom = val.isNotEmpty ? val : null;
          break;
        case 'date_to':
          dateTo = val.isNotEmpty ? val : null;
          break;
        case 'source_type':
          sourceType = val.isNotEmpty ? val : null;
          break;
        case 'operator':
          operatorUserId = int.tryParse(val);
          break;
        case 'reason':
          reasonCode = val.isNotEmpty ? val : null;
          break;
        case 'stock_effect':
          stockEffect = val.isNotEmpty ? val : null;
          break;
      }
    }

    final filter = MgwsMovementFilter(
      productId: productId,
      variationId: variationId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      sourceType: sourceType,
      operatorUserId: operatorUserId,
      reasonCode: reasonCode,
      stockEffect: stockEffect,
      page: request.page,
      perPage: request.perPage,
    );

    final result = await _gateway.listMovements(filter);
    if (!result.success || result.data == null) {
      return PaginatedResult<InventoryMovementGroup>(
        items: const [],
        page: request.page,
        perPage: request.perPage,
        totalItems: 0,
      );
    }
    final groups = groupMovements(result.data!.items);
    return PaginatedResult<InventoryMovementGroup>(
      items: groups,
      page: result.data!.page,
      perPage: result.data!.perPage,
      totalItems: result.data!.total,
      hasMore: result.data!.page < result.data!.totalPages,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _controller.reload(force: true);
  }

  List<InventoryMovementGroup> get _groups => _controller.visibleItems;

  /// True when MGWS has more rows than the loaded page.
  ///
  /// Do not compare the number of groups with the total: MGWS counts movement
  /// rows (one per product), while several rows can make one group here.
  /// The meaningful comparison is between pages, not between rows.
  bool get _pageIsTruncated => _controller.pagination.hasMore;

  /// Whether [group] holds the most recent movement of the whole ledger.
  ///
  /// Only an unfiltered first page is ordered newest-first end to end, so any
  /// search, filter, custom sort, or later page makes the answer unknown. In
  /// that case we say "not latest" and let the server reject an edit that is
  /// no longer valid; a false "latest" here would offer an action that cannot
  /// succeed.
  bool _isLatestMovement(InventoryMovementGroup group) =>
      !_controller.hasActiveFilters &&
      _controller.pagination.currentPage == 1 &&
      _groups.isNotEmpty &&
      _groups.first.key == group.key;

  Future<void> _openGroup(InventoryMovementGroup group) async {
    final action = await showInventoryMovementDialog(
      context,
      group,
      isLatestMovement: _isLatestMovement(group),
    );
    if (!mounted) return;
    switch (action) {
      case InventoryMovementAction.reopen:
        _reopen(group);
      case InventoryMovementAction.revert:
        await _revertGroup(group);
      case null:
        break;
    }
  }

  void _reopen(InventoryMovementGroup group) {
    final callback = widget.onReopen;
    final module = group.resumeModule;
    if (callback == null || module == null) return;
    callback(
      InventoryPanelSeed(
        module: module,
        movements: group.movements,
        products: group.products,
        reason: group.reason,
        details: group.note,
      ),
    );
  }

  Future<void> _revertGroup(InventoryMovementGroup group) async {
    setState(() => _feedback = null);
    final prepared = await _revert.prepare(group);
    if (!mounted) return;
    final plan = _revert.lastPlan;
    if (plan == null || !plan.canRevert) {
      setState(() => _feedback = prepared as InventoryActionFeedback?);
      return;
    }
    final confirmed = await _confirmRevert(plan);
    if (!mounted || confirmed != true) return;
    final feedback = await _revert.execute(context.l10n, plan);
    if (!mounted) return;
    setState(() => _feedback = feedback);
    await _load();
  }

  Future<bool?> _confirmRevert(InventoryMovementRevertPlan plan) {
    final isMove = plan.group.isMove;
    final lines = <String>[
      for (final line in plan.revertable)
        if (line.isReverseMove)
          '${line.productLabel(context.l10n)}: ${line.quantity} '
              '${context.l10n.inventoryParolaPezzi}, ${line.routeText}'
        else
          '${line.productLabel(context.l10n)}: '
              '${context.l10n.inventoryParolaDa(line.currentStock ?? '?')} '
              '${context.l10n.inventoryParolaA(line.restoreTo)}',
      for (final line in plan.blocked)
        '${line.productLabel(context.l10n)}: '
            '${context.l10n.inventoryMovimentiRigaSaltata(line.blockMessage(context.l10n))}',
    ];
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('inventory-movement-revert-confirm'),
        title: Text(context.l10n.inventoryAnnullareMovimento),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMove
                      ? context.l10n.inventoryAnnullamentoNotaSpostamento
                      : context.l10n.inventoryAnnullamentoNotaRettifica,
                ),
                const SizedBox(height: 12),
                for (final line in lines) Text(line),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isMove
                  ? context.l10n.inventorySpostaIndietro
                  : context.l10n.inventoryRiportaIndietro,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final groups = _groups;
    return Card(
      key: const ValueKey('inventory-movements-panel'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.timeline, color: theme.colorScheme.primary),
              title: Text(
                context.l10n.inventoryMovimentiTitolo,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                context.l10n.inventoryMovimentiSottotitolo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.subtitleColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            DataGridFiltersBar<InventoryMovementGroup>(
              controller: _controller,
              fields: _controller.fields,
              onRefresh: () => _controller.reload(force: true),
              onOpenColumns: _openColumnPicker,
            ),
            const SizedBox(height: 10),
            if (_pageIsTruncated) ...[
              _truncationNotice(),
              const SizedBox(height: 10),
            ],
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (groups.isEmpty)
              _empty(colors)
            else
              SizedBox(height: 320, child: _grid(groups)),
            const SizedBox(height: 10),
            GlobalPaginationBar(
              settings: context.read<AppSettings>(),
              controller: _controller.pagination,
              totalRows: _controller.totalRows,
              selectedRows: 0,
              onFirstPage: () => _controller.goToFirstPage(),
              onPreviousPage: () => _controller.goToPreviousPage(),
              onNextPage: () => _controller.goToNextPage(),
              onLastPage: () => _controller.goToLastPage(),
              onModeOrPageSizeChanged: (mode, size) =>
                  _controller.pageSizeOrModeChanged(),
              persistPageSize: _persistPageSize,
            ),
            const SizedBox(height: 10),
            if (_feedback != null)
              InventoryMovementFeedback(feedback: _feedback!),
          ],
        ),
      ),
    );
  }

  List<DataGridViewColumn> _allColumns() => <DataGridViewColumn>[
    DataGridViewColumn(id: 'time', label: context.l10n.commonDate, width: 175),
    DataGridViewColumn(
      id: 'kind',
      label: context.l10n.inventoryEtichettaTipo,
      width: 120,
    ),
    DataGridViewColumn(
      id: 'operator',
      label: context.l10n.inventoryEtichettaOperatore,
      width: 110,
    ),
    DataGridViewColumn(
      id: 'delta',
      label: context.l10n.inventoryEtichettaPezzi,
      width: 80,
      numeric: true,
    ),
    DataGridViewColumn(
      id: 'products',
      label: context.l10n.inventoryEtichettaProdotti,
      width: 90,
      numeric: true,
    ),
    DataGridViewColumn(
      id: 'last',
      label: context.l10n.inventoryEtichettaUltimaModifica,
      width: 175,
    ),
    DataGridViewColumn(
      id: 'reason',
      label: context.l10n.inventoryEtichettaMotivoEDettagli,
      flexible: true,
    ),
  ];

  Widget _grid(List<InventoryMovementGroup> groups) {
    final allColumns = _allColumns();
    final visible = allColumns
        .where((column) => _visibleColumns.contains(column.id))
        .toList();
    final columns = visible.isEmpty ? allColumns : visible;
    return DataGridView<InventoryMovementGroup>(
      columns: columns,
      rows: [for (final group in groups) _row(group)],
      selectedRowId: _controller.selected.value?.key ?? '',
      onRowSelected: (group) => _controller.select(group),
      onRowDoubleTap: _openGroup,
      onRowTap: MediaQuery.sizeOf(context).width < 600 ? _openGroup : null,
      contextActions: [
        DataGridViewContextAction<InventoryMovementGroup>(
          label: context.l10n.inventoryApriMovimento,
          icon: Icons.open_in_new,
          onSelected: _openGroup,
        ),
      ],
    );
  }

  DataGridViewRowData<InventoryMovementGroup> _row(
    InventoryMovementGroup group,
  ) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final tone = group.quantityDelta == 0
        ? Theme.of(context).colorScheme.onSurface
        : (group.quantityDelta > 0
              ? colors.successColor
              : colors.errorColorStatus);
    final deltaCell = group.isMove
        ? Text('${group.movedQuantity} ${context.l10n.inventoryParolaPezzi}')
        : Text(movementSigned(group.quantityDelta));
    return DataGridViewRowData(
      id: group.key,
      value: group,
      foregroundColor: tone,
      cells: {
        'time': Text(formatMovementDate(group.occurredAtGmt)),
        'kind': Text(
          group.kind == InventoryMovementKind.altro
              ? '${group.kindLabel(context.l10n)} (${group.rawType})'
              : group.kindLabel(context.l10n),
        ),
        'operator': Text('#${group.operatorUserId}'),
        'delta': deltaCell,
        'products': Text('${group.productCount}'),
        'last': Text(formatMovementDate(group.lastModifiedGmt)),
        'reason': Text(group.reasonAndDetails),
      },
    );
  }

  Widget _truncationNotice() {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final total = _controller.totalRows;
    // Raw MGWS movement rows loaded so far, not groups: groups are always
    // fewer than or equal to the rows.
    final shown =
        _controller.pagination.currentPage * _controller.pagination.pageSize;
    final shownCapped = total < shown ? total : shown;
    return Container(
      key: const ValueKey('inventory-movement-truncated'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warningColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.inventoryMovimentiAvviso('$shownCapped', '$total'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppColorExtension colors) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.priceBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(context.l10n.inventoryMovimentiNessuno),
  );
}
