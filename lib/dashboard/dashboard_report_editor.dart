// Editor section of a free report question.
//
// The user picks what to count (measure), what to split it by (dimension)
// and which products, customers, registers... to include (filters). Ready
// made questions fill all three in one tap.

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import 'dashboard_report.dart';
import 'dashboard_widget_view.dart';

class DashboardReportQueryEditor extends StatelessWidget {
  const DashboardReportQueryEditor({
    super.key,
    required this.query,
    required this.onChanged,
    required this.onPreset,
    required this.search,
  });

  final DashboardReportQuery query;
  final ValueChanged<DashboardReportQuery> onChanged;
  final ValueChanged<ReportPreset> onPreset;
  final DashboardReportSearch search;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final source = query.source;
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.dashboardReportPresets, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in ReportPreset.values)
              ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(reportPresetLabel(l10n, preset)),
                onPressed: () => onPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // A new key rebuilds the field when a preset changes the value.
          key: ValueKey('measure-${query.measure}'),
          initialValue: query.measure,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.dashboardReportMeasure,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final area in ReportArea.values) ...[
              DropdownMenuItem<String>(
                enabled: false,
                child: Text(
                  _areaLabel(l10n, area),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final measure in reportMeasures)
                if (measure.area == area)
                  DropdownMenuItem(
                    value: measure.key,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(reportMeasureLabel(l10n, measure.key)),
                    ),
                  ),
            ],
          ],
          onChanged: (value) {
            if (value != null) onChanged(query.copyWith(measure: value));
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ReportDimension?>(
          key: ValueKey('dimension-${query.dimension}-${query.measure}'),
          initialValue: query.dimension,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.dashboardReportSplitBy,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<ReportDimension?>(
              value: null,
              child: Text(l10n.dashboardReportNoSplit),
            ),
            for (final dimension in ReportDimension.values)
              if (dimension.sources.contains(source))
                DropdownMenuItem(
                  value: dimension,
                  child: Text(reportDimensionLabel(l10n, dimension)),
                ),
          ],
          onChanged: (value) => onChanged(
            value == null
                ? query.copyWith(clearDimension: true)
                : query.copyWith(dimension: value),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.dashboardReportFilters,
                style: theme.textTheme.labelLarge,
              ),
            ),
            PopupMenuButton<ReportFilterKind>(
              tooltip: l10n.dashboardReportAddFilter,
              onSelected: (kind) => _addFilter(context, kind),
              itemBuilder: (_) => [
                for (final kind in ReportFilterKind.values)
                  if (kind.appliesTo(source))
                    PopupMenuItem(
                      value: kind,
                      child: Text(reportFilterKindLabel(l10n, kind)),
                    ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.dashboardReportAddFilter,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (query.filters.isEmpty)
          Text(l10n.dashboardReportNoFilters, style: hint)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final filter in query.filters)
                InputChip(
                  label: Text(
                    '${reportFilterKindLabel(l10n, filter.kind)}: '
                    '${filter.label}',
                  ),
                  onDeleted: () => onChanged(
                    query.copyWith(
                      filters: [
                        for (final item in query.filters)
                          if (item != filter) item,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          source == ReportSource.closings
              ? l10n.dashboardReportClosingsHint
              : l10n.dashboardReportSalesHint,
          style: hint,
        ),
      ],
    );
  }

  Future<void> _addFilter(BuildContext context, ReportFilterKind kind) async {
    final l10n = context.l10n;
    final List<ReportFilterValue>? picked;
    if (kind == ReportFilterKind.channel) {
      picked = await showDialog<List<ReportFilterValue>>(
        context: context,
        builder: (_) => ReportFilterPickerDialog(
          kind: kind,
          initial: query.filters
              .where((filter) => filter.kind == kind)
              .toList(),
          search: (kind, term) async => [
            ReportFilterValue(
              kind: kind,
              id: 'store',
              label: l10n.dashboardReportChannelStore,
            ),
            ReportFilterValue(
              kind: kind,
              id: 'online',
              label: l10n.dashboardReportChannelOnline,
            ),
          ],
        ),
      );
    } else {
      picked = await pickReportFilters(
        context,
        kind: kind,
        initial: query.filters.where((filter) => filter.kind == kind).toList(),
        search: search,
      );
    }
    if (picked == null) return;
    onChanged(
      query.copyWith(
        filters: [
          for (final filter in query.filters)
            if (filter.kind != kind) filter,
          ...picked,
        ],
      ),
    );
  }

  static String _areaLabel(AppLocalizations l10n, ReportArea area) =>
      switch (area) {
        ReportArea.sales => l10n.dashboardReportAreaSales,
        ReportArea.products => l10n.dashboardReportAreaProducts,
        ReportArea.customers => l10n.dashboardReportAreaCustomers,
        ReportArea.cash => l10n.dashboardReportAreaCash,
      };
}

/// Opens the picker for [kind]; returns null when cancelled.
Future<List<ReportFilterValue>?> pickReportFilters(
  BuildContext context, {
  required ReportFilterKind kind,
  required List<ReportFilterValue> initial,
  required DashboardReportSearch search,
}) => showDialog<List<ReportFilterValue>>(
  context: context,
  builder: (_) =>
      ReportFilterPickerDialog(kind: kind, initial: initial, search: search),
);

String reportPresetLabel(AppLocalizations l10n, ReportPreset preset) =>
    switch (preset) {
      ReportPreset.productSales => l10n.dashboardReportPresetProductSales,
      ReportPreset.bestCustomers => l10n.dashboardReportPresetBestCustomers,
      ReportPreset.averageTicketPerCustomer =>
        l10n.dashboardReportPresetAverageTicketPerCustomer,
      ReportPreset.averagePricePerCustomer =>
        l10n.dashboardReportPresetAveragePricePerCustomer,
      ReportPreset.revenuePerCustomer =>
        l10n.dashboardReportPresetRevenuePerCustomer,
      ReportPreset.newCustomers => l10n.dashboardReportPresetNewCustomers,
      ReportPreset.dormantCustomers =>
        l10n.dashboardReportPresetDormantCustomers,
      ReportPreset.salesByHour => l10n.dashboardReportPresetSalesByHour,
      ReportPreset.salesByWeekday => l10n.dashboardReportPresetSalesByWeekday,
      ReportPreset.salesByOperator => l10n.dashboardReportPresetSalesByOperator,
      ReportPreset.salesByPaymentMethod =>
        l10n.dashboardReportPresetSalesByPaymentMethod,
      ReportPreset.salesByChannel => l10n.dashboardReportPresetSalesByChannel,
      ReportPreset.cashDifferences => l10n.dashboardReportPresetCashDifferences,
    };

/// Searchable multi-select list of products, customers, categories...
class ReportFilterPickerDialog extends StatefulWidget {
  const ReportFilterPickerDialog({
    super.key,
    required this.kind,
    required this.initial,
    required this.search,
  });

  final ReportFilterKind kind;
  final List<ReportFilterValue> initial;
  final DashboardReportSearch search;

  @override
  State<ReportFilterPickerDialog> createState() =>
      _ReportFilterPickerDialogState();
}

class _ReportFilterPickerDialogState extends State<ReportFilterPickerDialog> {
  final _controller = TextEditingController();
  late final _selected = <ReportFilterValue>{...widget.initial};
  List<ReportFilterValue> _results = const [];
  var _loading = false;
  var _failed = false;
  Timer? _debounce;
  var _searchVersion = 0;

  /// Products and customers are too many to list without a search term.
  bool get _needsTerm =>
      widget.kind == ReportFilterKind.product ||
      widget.kind == ReportFilterKind.customer;

  @override
  void initState() {
    super.initState();
    if (!_needsTerm) _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String term) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(term),
    );
  }

  Future<void> _runSearch(String term) async {
    if (_needsTerm && term.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    final version = ++_searchVersion;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await widget.search(widget.kind, term);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Selected items stay visible even when the search no longer finds them.
    final shown = [
      ..._selected.where((item) => !_results.contains(item)),
      ..._results,
    ];

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_failed) {
      body = Center(child: Text(l10n.dashboardWidgetDataUnavailable));
    } else if (shown.isEmpty) {
      body = Center(
        child: Text(
          _needsTerm
              ? l10n.dashboardReportSearchHint
              : l10n.dashboardNessunDato,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      body = ListView(
        children: [
          for (final item in shown)
            CheckboxListTile(
              dense: true,
              value: _selected.contains(item),
              title: Text(item.label),
              onChanged: (checked) => setState(() {
                checked == true ? _selected.add(item) : _selected.remove(item);
              }),
            ),
        ],
      );
    }

    return AlertDialog(
      title: Text(reportFilterKindLabel(l10n, widget.kind)),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            if (widget.kind != ReportFilterKind.channel)
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.commonSearch,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onChanged,
              ),
            const SizedBox(height: 8),
            Expanded(child: body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
