// Turns the shop reports into the data a dashboard widget draws.
//
// Every metric becomes either a single value (with an optional reference to
// compare against) or a list of labelled points. Charts only know these two
// shapes, so any chart can draw any metric of the matching shape.

import 'dart:convert';

import 'package:intl/intl.dart';

import '../login/jwt_api/query_woocommerce/woo_query_report.dart';
import '../l10n/extensions.dart';
import 'dashboard.code.dart';
import 'dashboard_layout.dart';
import 'dashboard_report.dart';

/// Everything the dashboard has loaded for the current filters.
class DashboardDataBundle {
  const DashboardDataBundle({
    this.summary,
    this.salesReport,
    this.lowStockByThreshold = const {},
    this.productsByCategory,
    this.salesReportFailed = false,
    this.productsByCategoryFailed = false,
    this.lowStockFailed = const {},
    this.reportResults = const {},
    this.reportFailures = const {},
  });

  final DashboardData? summary;
  final ReportVenditeDettagliato? salesReport;
  final Map<int, List<Map<String, dynamic>>> lowStockByThreshold;
  final Map<String, int>? productsByCategory;
  final bool salesReportFailed;
  final bool productsByCategoryFailed;
  final Set<int> lowStockFailed;

  /// MGWS report answers, keyed by [dashboardReportKey].
  final Map<String, DashboardReportResult> reportResults;
  final Map<String, ReportFailure> reportFailures;

  DashboardDataBundle copyWith({
    DashboardData? summary,
    ReportVenditeDettagliato? salesReport,
    Map<int, List<Map<String, dynamic>>>? lowStockByThreshold,
    Map<String, int>? productsByCategory,
    bool? salesReportFailed,
    bool? productsByCategoryFailed,
    Set<int>? lowStockFailed,
    Map<String, DashboardReportResult>? reportResults,
    Map<String, ReportFailure>? reportFailures,
  }) => DashboardDataBundle(
    summary: summary ?? this.summary,
    salesReport: salesReport ?? this.salesReport,
    lowStockByThreshold: lowStockByThreshold ?? this.lowStockByThreshold,
    productsByCategory: productsByCategory ?? this.productsByCategory,
    salesReportFailed: salesReportFailed ?? this.salesReportFailed,
    productsByCategoryFailed:
        productsByCategoryFailed ?? this.productsByCategoryFailed,
    lowStockFailed: lowStockFailed ?? this.lowStockFailed,
    reportResults: reportResults ?? this.reportResults,
    reportFailures: reportFailures ?? this.reportFailures,
  );
}

/// MGWS request of a report widget under the dashboard filters.
Map<String, dynamic> dashboardReportRequest(
  DashboardWidgetConfig widget,
  DashboardFilters filters,
) {
  final query = widget.report ?? const DashboardReportQuery();
  return query.toRequest(
    period: filters.toPeriod(),
    // Only a single value shows the comparison, so only it asks for it.
    compare: filters.compareWithPrevious && query.dimension == null,
    sort: switch (widget.sortOrder) {
      DashboardSortOrder.natural => '',
      DashboardSortOrder.valueDesc => 'value_desc',
      DashboardSortOrder.valueAsc => 'value_asc',
      DashboardSortOrder.labelAsc => 'key_asc',
    },
    limit: widget.itemLimit,
  );
}

/// Stable key of a report request, shared by identical widgets.
String dashboardReportKey(Map<String, dynamic> request) => jsonEncode(request);

/// One labelled value of a series.
class DashboardPoint {
  const DashboardPoint({required this.label, required this.value, this.date});

  final String label;
  final double value;

  /// Set for time series, used for axis and tooltip labels.
  final DateTime? date;
}

/// State of a widget's data.
enum DashboardDatasetStatus { ready, loading, unavailable }

/// Data ready to draw.
class DashboardDataset {
  const DashboardDataset._({
    required this.status,
    required this.format,
    this.value,
    this.reference,
    this.referenceIsPrevious = false,
    this.points = const [],
    this.monthly = false,
    this.message,
  });

  const DashboardDataset.loading(DashboardValueFormat format)
    : this._(status: DashboardDatasetStatus.loading, format: format);

  const DashboardDataset.unavailable(
    DashboardValueFormat format, {
    String? message,
  }) : this._(
         status: DashboardDatasetStatus.unavailable,
         format: format,
         message: message,
       );

  const DashboardDataset.single({
    required DashboardValueFormat format,
    required double value,
    double? reference,
    bool referenceIsPrevious = false,
  }) : this._(
         status: DashboardDatasetStatus.ready,
         format: format,
         value: value,
         reference: reference,
         referenceIsPrevious: referenceIsPrevious,
       );

  const DashboardDataset.series({
    required DashboardValueFormat format,
    required List<DashboardPoint> points,
    bool monthly = false,
  }) : this._(
         status: DashboardDatasetStatus.ready,
         format: format,
         points: points,
         monthly: monthly,
       );

  final DashboardDatasetStatus status;
  final DashboardValueFormat format;

  /// Single value.
  final double? value;

  /// Value to compare with: the previous period, or the whole the value is
  /// part of (used as the gauge maximum).
  final double? reference;

  /// True when [reference] is the previous period, false when it is a total.
  final bool referenceIsPrevious;

  final List<DashboardPoint> points;

  /// Time series grouped by month instead of by day.
  final bool monthly;

  /// Why the data is unavailable, when known.
  final String? message;

  /// No value to show. A time series of zeros counts as empty, a ranking of
  /// zeros does not: a product with no stock left is still a row to show.
  bool get isEmpty =>
      status == DashboardDatasetStatus.ready &&
      value == null &&
      (points.isEmpty ||
          (points.first.date != null &&
              points.every((point) => point.value == 0)));
}

String dashboardOrderStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'completed' => l10n.ordiniStatusCompletato,
      'processing' => l10n.ordiniStatusInElaborazione,
      'on-hold' => l10n.ordiniStatusInSospeso,
      'pending' => l10n.ordiniStatusInAttesa,
      'cancelled' => l10n.ordiniStatusAnnullato,
      'refunded' => l10n.ordiniStatusRimborsato,
      'failed' => l10n.ordiniStatusFallito,
      _ => status,
    };

/// Builds the dataset of [widget] from [bundle].
DashboardDataset resolveDashboardDataset({
  required DashboardWidgetConfig widget,
  required DashboardDataBundle bundle,
  required DashboardFilters filters,
  required AppLocalizations l10n,
}) {
  final metric = widget.metric;
  final format = widget.format;
  if (metric == DashboardMetric.report) {
    return _resolveReport(widget, bundle, filters, l10n);
  }
  final summary = bundle.summary;
  if (summary == null) return DashboardDataset.loading(format);
  final sales = summary.vendite;
  final compare = filters.compareWithPrevious;

  DashboardDataset single(
    double value, {
    double? reference,
    bool previous = false,
  }) => DashboardDataset.single(
    format: format,
    value: value,
    reference: previous && !compare ? null : reference,
    referenceIsPrevious: previous,
  );

  DashboardDataset trend(double Function(DashboardPoint point, int orders) of) {
    return DashboardDataset.series(
      format: format,
      monthly: sales.andamentoMensile,
      points: [
        for (final day in sales.andamentoGiornaliero)
          DashboardPoint(
            label: '',
            date: day.data,
            value: of(DashboardPoint(label: '', value: day.totale), day.ordini),
          ),
      ],
    );
  }

  DashboardDataset ranking(Iterable<DashboardPoint> items) =>
      DashboardDataset.series(format: format, points: _rank(widget, items));

  DashboardDataset fromSalesReport(
    Iterable<DashboardPoint> Function(ReportVenditeDettagliato report) of,
  ) {
    final report = bundle.salesReport;
    if (report == null) {
      return bundle.salesReportFailed
          ? DashboardDataset.unavailable(format)
          : DashboardDataset.loading(format);
    }
    return ranking(of(report));
  }

  final products = summary.prodotti;
  final customers = summary.clienti;
  final orders = summary.ordini;

  switch (metric) {
    case DashboardMetric.report:
      // Handled before the summary is needed.
      return DashboardDataset.loading(format);
    case DashboardMetric.salesTotal:
      return single(
        sales.totaleVendite,
        reference: sales.totalePrecedente,
        previous: true,
      );
    case DashboardMetric.ordersCount:
      return single(
        sales.numeroOrdini.toDouble(),
        reference: sales.ordiniPrecedenti?.toDouble(),
        previous: true,
      );
    case DashboardMetric.averageTicket:
      return single(
        sales.ticketMedio,
        reference: sales.ticketMedioPrecedente,
        previous: true,
      );
    case DashboardMetric.ordersToProcess:
      return single(orders.ordiniDaGestire.toDouble());
    case DashboardMetric.productsPublished:
      return single(products.totaleProdotti.toDouble());
    case DashboardMetric.productsOutOfStock:
      return single(
        products.prodottiOutOfStock.toDouble(),
        reference: (products.prodottiInStock + products.prodottiOutOfStock)
            .toDouble(),
      );
    case DashboardMetric.customersTotal:
      if (customers == null) return DashboardDataset.unavailable(format);
      return single(customers.totaleClienti.toDouble());
    case DashboardMetric.customersPaying:
      if (customers == null) return DashboardDataset.unavailable(format);
      return single(
        customers.clientiAttivi.toDouble(),
        reference: customers.totaleClienti.toDouble(),
      );
    case DashboardMetric.salesTrend:
      return trend((point, _) => point.value);
    case DashboardMetric.ordersTrend:
      return trend((_, orderCount) => orderCount.toDouble());
    case DashboardMetric.averageTicketTrend:
      return trend(
        (point, orderCount) => orderCount > 0 ? point.value / orderCount : 0,
      );
    case DashboardMetric.topProductsRevenue:
      return fromSalesReport(
        (report) => report.topProdotti.map(
          (product) => DashboardPoint(
            label: product.titolo,
            value: product.totaleVendite,
          ),
        ),
      );
    case DashboardMetric.topProductsQuantity:
      return fromSalesReport(
        (report) => report.topProdotti.map(
          (product) => DashboardPoint(
            label: product.titolo,
            value: product.quantitaVenduta.toDouble(),
          ),
        ),
      );
    case DashboardMetric.salesByCategory:
      return fromSalesReport(
        (report) => report.venditePerCategoria.entries.map(
          (entry) => DashboardPoint(label: entry.key, value: entry.value),
        ),
      );
    case DashboardMetric.productsByCategory:
      final categories = bundle.productsByCategory;
      if (categories == null) {
        return bundle.productsByCategoryFailed
            ? DashboardDataset.unavailable(format)
            : DashboardDataset.loading(format);
      }
      return ranking(
        categories.entries.map(
          (entry) =>
              DashboardPoint(label: entry.key, value: entry.value.toDouble()),
        ),
      );
    case DashboardMetric.ordersByStatus:
      final selected = filters.orderStatuses;
      return ranking([
        for (final status in WooQueryReport.orderStatuses)
          if (selected.isEmpty || selected.contains(status))
            if ((orders.ordiniPerStato[status] ?? 0) > 0)
              DashboardPoint(
                label: dashboardOrderStatusLabel(l10n, status),
                value: orders.ordiniPerStato[status]!.toDouble(),
              ),
      ]);
    case DashboardMetric.stockStatus:
      return ranking([
        DashboardPoint(
          label: l10n.dashboardDisponibili,
          value: products.prodottiInStock.toDouble(),
        ),
        DashboardPoint(
          label: l10n.dashboardEsauriti,
          value: products.prodottiOutOfStock.toDouble(),
        ),
      ]);
    case DashboardMetric.customersActivity:
      if (customers == null) return DashboardDataset.unavailable(format);
      final paying = customers.clientiAttivi;
      return ranking([
        DashboardPoint(
          label: l10n.dashboardWidgetCustomersWithOrders,
          value: paying.toDouble(),
        ),
        DashboardPoint(
          label: l10n.dashboardWidgetCustomersWithoutOrders,
          value: (customers.totaleClienti - paying)
              .clamp(0, 1 << 31)
              .toDouble(),
        ),
      ]);
    case DashboardMetric.lowStockProducts:
      final rows = bundle.lowStockByThreshold[widget.stockThreshold];
      if (rows == null) {
        return bundle.lowStockFailed.contains(widget.stockThreshold)
            ? DashboardDataset.unavailable(format)
            : DashboardDataset.loading(format);
      }
      return ranking(
        rows.map(
          (row) => DashboardPoint(
            label: row['name']?.toString() ?? '—',
            value:
                double.tryParse(row['stock_quantity']?.toString() ?? '') ?? 0,
          ),
        ),
      );
  }
}

/// Text filter, sorting and "top N" of a ranking.
List<DashboardPoint> _rank(
  DashboardWidgetConfig widget,
  Iterable<DashboardPoint> items,
) {
  var points = items.toList();
  final query = widget.itemFilter.trim().toLowerCase();
  if (query.isNotEmpty) {
    points = points
        .where((point) => point.label.toLowerCase().contains(query))
        .toList();
  }
  switch (widget.sortOrder) {
    case DashboardSortOrder.natural:
      break;
    case DashboardSortOrder.valueDesc:
      points.sort((a, b) => b.value.compareTo(a.value));
    case DashboardSortOrder.valueAsc:
      points.sort((a, b) => a.value.compareTo(b.value));
    case DashboardSortOrder.labelAsc:
      points.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
  }
  return points.take(widget.itemLimit).toList();
}

DashboardDataset _resolveReport(
  DashboardWidgetConfig widget,
  DashboardDataBundle bundle,
  DashboardFilters filters,
  AppLocalizations l10n,
) {
  final format = widget.format;
  final key = dashboardReportKey(dashboardReportRequest(widget, filters));
  final failure = bundle.reportFailures[key];
  if (failure != null) {
    return DashboardDataset.unavailable(
      format,
      message: switch (failure) {
        ReportFailure.unavailable => l10n.dashboardReportNeedsMgws,
        ReportFailure.forbidden => l10n.dashboardReportForbidden,
        ReportFailure.failed => l10n.dashboardWidgetDataUnavailable,
      },
    );
  }
  final result = bundle.reportResults[key];
  if (result == null) return DashboardDataset.loading(format);

  final dimension = result.dimension;
  if (dimension == null) {
    return DashboardDataset.single(
      format: format,
      value: result.total ?? 0,
      reference: result.compareTotal,
      referenceIsPrevious: true,
    );
  }
  if (!dimension.isTime) {
    return DashboardDataset.series(
      format: format,
      points: _rank(widget, [
        for (final row in result.rows)
          DashboardPoint(
            label: _reportRowLabel(l10n, dimension, row),
            value: row.value ?? 0,
          ),
      ]),
    );
  }
  return DashboardDataset.series(
    format: format,
    monthly: dimension == ReportDimension.month,
    points: _timePoints(l10n, result),
  );
}

String _reportRowLabel(
  AppLocalizations l10n,
  ReportDimension dimension,
  ReportRow row,
) {
  if (dimension == ReportDimension.channel) {
    return switch (row.key) {
      'store' => l10n.dashboardReportChannelStore,
      'online' => l10n.dashboardReportChannelOnline,
      _ => row.key,
    };
  }
  if (row.label.isNotEmpty) return row.label;
  if (dimension == ReportDimension.customer)
    return l10n.dashboardReportAnonymous;
  return row.key.isEmpty ? '—' : row.key;
}

/// Time rows as a continuous series: empty hours, days and months are zero,
/// so lines and columns do not skip time.
List<DashboardPoint> _timePoints(
  AppLocalizations l10n,
  DashboardReportResult result,
) {
  final byKey = {for (final row in result.rows) row.key: row.value ?? 0.0};
  final from = result.dateFrom;
  final to = result.dateTo;
  switch (result.dimension) {
    case ReportDimension.hour:
      return [
        for (var hour = 0; hour < 24; hour++)
          DashboardPoint(
            label: '${hour.toString().padLeft(2, '0')}:00',
            value: byKey[hour.toString().padLeft(2, '0')] ?? 0,
          ),
      ];
    case ReportDimension.weekday:
      final names = DateFormat('EEE', l10n.localeName);
      return [
        for (var day = 1; day <= 7; day++)
          DashboardPoint(
            // 1 January 2024 was a Monday.
            label: names.format(DateTime(2024, 1, day)),
            value: byKey['$day'] ?? 0,
          ),
      ];
    case ReportDimension.day when from != null && to != null:
      final keyFormat = DateFormat('yyyy-MM-dd');
      return [
        for (
          var day = DateTime(from.year, from.month, from.day);
          !day.isAfter(to);
          day = DateTime(day.year, day.month, day.day + 1)
        )
          DashboardPoint(
            label: '',
            date: day,
            value: byKey[keyFormat.format(day)] ?? 0,
          ),
      ];
    case ReportDimension.month when from != null && to != null:
      final keyFormat = DateFormat('yyyy-MM');
      return [
        for (
          var month = DateTime(from.year, from.month);
          !month.isAfter(to);
          month = DateTime(month.year, month.month + 1)
        )
          DashboardPoint(
            label: '',
            date: month,
            value: byKey[keyFormat.format(month)] ?? 0,
          ),
      ];
    case ReportDimension.week:
      return [
        for (final row in result.rows)
          DashboardPoint(
            label: row.key,
            date: DateTime.tryParse(row.key),
            value: row.value ?? 0,
          ),
      ];
    default:
      return [
        for (final row in result.rows)
          DashboardPoint(label: row.key, value: row.value ?? 0),
      ];
  }
}
