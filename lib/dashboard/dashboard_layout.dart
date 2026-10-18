// Dashboard layout model.
//
// A dashboard is a named list of widgets plus its default filters. Each
// widget shows one metric with one chart type, at a chosen size. The layout is
// stored as JSON in MGWS (or locally when MGWS is not reachable), so every key
// is lowercase snake_case: MGWS sanitizes keys with `sanitize_key`.

import 'dart:math';

import 'dashboard.code.dart';
import 'dashboard_report.dart';

/// Who can see a dashboard.
enum DashboardVisibility {
  /// Only the user who created it.
  personal,

  /// Every logged-in user. Only shop managers can create or change it.
  everyone,

  /// Only shop managers.
  admins,
}

/// Shape of the data a metric produces; decides which charts make sense.
enum DashboardMetricShape { single, timeSeries, categories }

/// How the values of a metric are formatted.
enum DashboardValueFormat { currency, count, percent, decimal, days }

/// Data a widget can show.
enum DashboardMetric {
  salesTotal(DashboardMetricShape.single, DashboardValueFormat.currency),
  ordersCount(DashboardMetricShape.single, DashboardValueFormat.count),
  averageTicket(DashboardMetricShape.single, DashboardValueFormat.currency),
  ordersToProcess(DashboardMetricShape.single, DashboardValueFormat.count),
  productsPublished(DashboardMetricShape.single, DashboardValueFormat.count),
  productsOutOfStock(DashboardMetricShape.single, DashboardValueFormat.count),
  customersTotal(DashboardMetricShape.single, DashboardValueFormat.count),
  customersPaying(DashboardMetricShape.single, DashboardValueFormat.count),
  salesTrend(DashboardMetricShape.timeSeries, DashboardValueFormat.currency),
  ordersTrend(DashboardMetricShape.timeSeries, DashboardValueFormat.count),
  averageTicketTrend(
    DashboardMetricShape.timeSeries,
    DashboardValueFormat.currency,
  ),
  topProductsRevenue(
    DashboardMetricShape.categories,
    DashboardValueFormat.currency,
  ),
  topProductsQuantity(
    DashboardMetricShape.categories,
    DashboardValueFormat.count,
  ),
  salesByCategory(
    DashboardMetricShape.categories,
    DashboardValueFormat.currency,
  ),
  productsByCategory(
    DashboardMetricShape.categories,
    DashboardValueFormat.count,
  ),
  ordersByStatus(DashboardMetricShape.categories, DashboardValueFormat.count),
  stockStatus(DashboardMetricShape.categories, DashboardValueFormat.count),
  customersActivity(
    DashboardMetricShape.categories,
    DashboardValueFormat.count,
  ),
  lowStockProducts(DashboardMetricShape.categories, DashboardValueFormat.count),

  /// Free question answered by the MGWS report engine. Its real shape and
  /// format come from the question, see [DashboardWidgetConfig.shape].
  report(DashboardMetricShape.single, DashboardValueFormat.currency);

  const DashboardMetric(this.shape, this.format);

  final DashboardMetricShape shape;
  final DashboardValueFormat format;

  /// Chart types that can represent this metric, the first is the default.
  List<DashboardChartType> get chartTypes => dashboardChartTypesFor(shape);

  /// True when the metric is a ranking where "top N" and sorting apply.
  bool get hasItemLimit => shape == DashboardMetricShape.categories;

  /// True when the metric depends on a stock threshold.
  bool get hasStockThreshold => this == DashboardMetric.lowStockProducts;

  /// True when the metric reacts to the order status filter.
  bool get usesOrderStatusFilter => this == DashboardMetric.ordersByStatus;

  /// Metrics that are not tied to the selected period.
  bool get ignoresPeriod => switch (this) {
    DashboardMetric.productsPublished ||
    DashboardMetric.productsOutOfStock ||
    DashboardMetric.customersTotal ||
    DashboardMetric.customersPaying ||
    DashboardMetric.productsByCategory ||
    DashboardMetric.stockStatus ||
    DashboardMetric.customersActivity ||
    DashboardMetric.lowStockProducts ||
    DashboardMetric.ordersToProcess => true,
    _ => false,
  };
}

/// Chart types that can represent data of [shape], the first is the default.
List<DashboardChartType> dashboardChartTypesFor(DashboardMetricShape shape) =>
    switch (shape) {
      DashboardMetricShape.single => const [
        DashboardChartType.number,
        DashboardChartType.gauge,
      ],
      DashboardMetricShape.timeSeries => const [
        DashboardChartType.bar,
        DashboardChartType.line,
        DashboardChartType.area,
        DashboardChartType.table,
      ],
      DashboardMetricShape.categories => const [
        DashboardChartType.horizontalBar,
        DashboardChartType.bar,
        DashboardChartType.pie,
        DashboardChartType.donut,
        DashboardChartType.table,
      ],
    };

/// How a widget draws its data.
enum DashboardChartType {
  number,
  gauge,
  bar,
  horizontalBar,
  line,
  area,
  pie,
  donut,
  table,
}

/// Widget width on a 12-column grid.
enum DashboardWidgetWidth {
  quarter(3),
  third(4),
  half(6),
  twoThirds(8),
  threeQuarters(9),
  full(12);

  const DashboardWidgetWidth(this.columns);

  final int columns;
}

/// Widget height.
enum DashboardWidgetHeight {
  compact(150),
  medium(320),
  tall(460);

  const DashboardWidgetHeight(this.pixels);

  final double pixels;
}

/// Order of the items of a ranking.
enum DashboardSortOrder { natural, valueDesc, valueAsc, labelAsc }

/// Period the dashboard reads.
enum DashboardPeriodPreset {
  today,
  week,
  month,
  year,
  last7Days,
  last30Days,
  last90Days,
  custom,
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

int _intOr(Object? raw, int fallback) {
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

bool _boolOr(Object? raw, bool fallback) {
  if (raw is bool) return raw;
  final text = raw?.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

final _random = Random();

/// Short unique id, lowercase so it is valid for MGWS keys and routes.
String newDashboardId(String prefix) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 30).toRadixString(36);
  return '$prefix$time$noise';
}

/// Filters applied to every widget of a dashboard.
class DashboardFilters {
  const DashboardFilters({
    this.periodPreset = DashboardPeriodPreset.month,
    this.customStart,
    this.customEnd,
    this.orderStatuses = const {},
    this.compareWithPrevious = true,
  });

  final DashboardPeriodPreset periodPreset;
  final DateTime? customStart;
  final DateTime? customEnd;

  /// WooCommerce order statuses to include; empty means all.
  final Set<String> orderStatuses;

  /// Shows the change against the previous period on number widgets.
  final bool compareWithPrevious;

  DashboardFilters copyWith({
    DashboardPeriodPreset? periodPreset,
    DateTime? customStart,
    DateTime? customEnd,
    Set<String>? orderStatuses,
    bool? compareWithPrevious,
  }) => DashboardFilters(
    periodPreset: periodPreset ?? this.periodPreset,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
    orderStatuses: orderStatuses ?? this.orderStatuses,
    compareWithPrevious: compareWithPrevious ?? this.compareWithPrevious,
  );

  /// Concrete date range for the report service.
  PeriodoReport toPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    PeriodoReport lastDays(int days) => PeriodoReport(
      dataInizio: today.subtract(Duration(days: days - 1)),
      dataFine: now,
    );
    return switch (periodPreset) {
      DashboardPeriodPreset.today => PeriodoReport.oggi(),
      DashboardPeriodPreset.week => PeriodoReport.settimana(),
      DashboardPeriodPreset.month => PeriodoReport.mese(),
      DashboardPeriodPreset.year => PeriodoReport.anno(),
      DashboardPeriodPreset.last7Days => lastDays(7),
      DashboardPeriodPreset.last30Days => lastDays(30),
      DashboardPeriodPreset.last90Days => lastDays(90),
      DashboardPeriodPreset.custom => PeriodoReport(
        dataInizio: customStart ?? today,
        dataFine: customEnd == null
            ? now
            : DateTime(
                customEnd!.year,
                customEnd!.month,
                customEnd!.day,
                23,
                59,
                59,
              ),
      ),
    };
  }

  Map<String, dynamic> toJson() => {
    'period': periodPreset.name,
    if (customStart != null)
      'custom_start': customStart!.toIso8601String().substring(0, 10),
    if (customEnd != null)
      'custom_end': customEnd!.toIso8601String().substring(0, 10),
    'order_statuses': orderStatuses.toList(),
    'compare': compareWithPrevious,
  };

  factory DashboardFilters.fromJson(Object? raw) {
    if (raw is! Map) return const DashboardFilters();
    final statuses = raw['order_statuses'];
    return DashboardFilters(
      periodPreset: _enumByName(
        DashboardPeriodPreset.values,
        raw['period'],
        DashboardPeriodPreset.month,
      ),
      customStart: DateTime.tryParse(raw['custom_start']?.toString() ?? ''),
      customEnd: DateTime.tryParse(raw['custom_end']?.toString() ?? ''),
      orderStatuses: statuses is List
          ? statuses.map((status) => status.toString()).toSet()
          : const {},
      compareWithPrevious: _boolOr(raw['compare'], true),
    );
  }
}

/// One widget on the dashboard.
class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.id,
    required this.metric,
    required this.chartType,
    this.width = DashboardWidgetWidth.third,
    this.height = DashboardWidgetHeight.medium,
    this.title = '',
    this.itemLimit = 5,
    this.stockThreshold = 5,
    this.itemFilter = '',
    this.sortOrder = DashboardSortOrder.natural,
    this.report,
  });

  factory DashboardWidgetConfig.create(
    DashboardMetric metric, {
    DashboardReportQuery? report,
  }) {
    final base = DashboardWidgetConfig(
      id: newDashboardId('w'),
      metric: metric,
      chartType: DashboardChartType.number,
      report: metric == DashboardMetric.report
          ? (report ?? const DashboardReportQuery())
          : null,
    );
    return base.withSizeForShape();
  }

  /// The same widget with the default chart and size of its data shape.
  DashboardWidgetConfig withSizeForShape() {
    final single = shape == DashboardMetricShape.single;
    return copyWith(
      chartType: chartTypes.first,
      width: single
          ? DashboardWidgetWidth.quarter
          : (shape == DashboardMetricShape.timeSeries
                ? DashboardWidgetWidth.twoThirds
                : DashboardWidgetWidth.third),
      height: single
          ? DashboardWidgetHeight.compact
          : DashboardWidgetHeight.medium,
    );
  }

  final String id;
  final DashboardMetric metric;
  final DashboardChartType chartType;
  final DashboardWidgetWidth width;
  final DashboardWidgetHeight height;

  /// Custom title; empty uses the metric name.
  final String title;

  /// Items shown by rankings.
  final int itemLimit;

  /// Stock level under which a product counts as low.
  final int stockThreshold;

  /// Shows only the items whose label contains this text.
  final String itemFilter;

  final DashboardSortOrder sortOrder;

  /// The question, when [metric] is [DashboardMetric.report].
  final DashboardReportQuery? report;

  /// Shape of the data; for a report it follows the chosen split.
  DashboardMetricShape get shape {
    if (metric != DashboardMetric.report) return metric.shape;
    final dimension = report?.dimension;
    if (dimension == null) return DashboardMetricShape.single;
    return dimension.isTime
        ? DashboardMetricShape.timeSeries
        : DashboardMetricShape.categories;
  }

  List<DashboardChartType> get chartTypes => dashboardChartTypesFor(shape);

  DashboardValueFormat get format {
    if (metric != DashboardMetric.report) return metric.format;
    return switch ((report ?? const DashboardReportQuery())
        .measureInfo
        .format) {
      ReportValueFormat.currency => DashboardValueFormat.currency,
      ReportValueFormat.count => DashboardValueFormat.count,
      ReportValueFormat.percent => DashboardValueFormat.percent,
      ReportValueFormat.decimal => DashboardValueFormat.decimal,
      ReportValueFormat.days => DashboardValueFormat.days,
    };
  }

  /// True when "top N", sorting and the text filter apply.
  bool get hasItemLimit => shape == DashboardMetricShape.categories;

  DashboardWidgetConfig copyWith({
    DashboardMetric? metric,
    DashboardChartType? chartType,
    DashboardWidgetWidth? width,
    DashboardWidgetHeight? height,
    String? title,
    int? itemLimit,
    int? stockThreshold,
    String? itemFilter,
    DashboardSortOrder? sortOrder,
    DashboardReportQuery? report,
  }) {
    final nextMetric = metric ?? this.metric;
    final nextReport = nextMetric == DashboardMetric.report
        ? (report ?? this.report ?? const DashboardReportQuery())
        : null;
    final shapeProbe = DashboardWidgetConfig(
      id: id,
      metric: nextMetric,
      chartType: DashboardChartType.number,
      report: nextReport,
    );
    var nextChart = chartType ?? this.chartType;
    if (!shapeProbe.chartTypes.contains(nextChart)) {
      nextChart = shapeProbe.chartTypes.first;
    }
    return DashboardWidgetConfig(
      id: id,
      metric: nextMetric,
      report: nextReport,
      chartType: nextChart,
      width: width ?? this.width,
      height: height ?? this.height,
      title: title ?? this.title,
      itemLimit: itemLimit ?? this.itemLimit,
      stockThreshold: stockThreshold ?? this.stockThreshold,
      itemFilter: itemFilter ?? this.itemFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'metric': metric.name,
    'chart': chartType.name,
    'width': width.name,
    'height': height.name,
    'title': title,
    'limit': itemLimit,
    'threshold': stockThreshold,
    'item_filter': itemFilter,
    'sort': sortOrder.name,
    if (report != null) 'report': report!.toJson(),
  };

  static DashboardWidgetConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final metricName = raw['metric']?.toString();
    final metric = DashboardMetric.values
        .where((value) => value.name == metricName)
        .firstOrNull;
    if (metric == null) return null;
    final report = metric == DashboardMetric.report
        ? DashboardReportQuery.fromJson(raw['report'])
        : null;
    final id = raw['id']?.toString() ?? '';
    return DashboardWidgetConfig(
      id: id.isEmpty ? newDashboardId('w') : id,
      metric: metric,
      report: report,
      // copyWith below swaps a chart that does not fit the data shape.
      chartType: _enumByName(
        DashboardChartType.values,
        raw['chart'],
        DashboardChartType.number,
      ),
      width: _enumByName(
        DashboardWidgetWidth.values,
        raw['width'],
        DashboardWidgetWidth.third,
      ),
      height: _enumByName(
        DashboardWidgetHeight.values,
        raw['height'],
        DashboardWidgetHeight.medium,
      ),
      title: raw['title']?.toString() ?? '',
      itemLimit: _intOr(raw['limit'], 5).clamp(1, 50),
      stockThreshold: _intOr(raw['threshold'], 5).clamp(0, 10000),
      itemFilter: raw['item_filter']?.toString() ?? '',
      sortOrder: _enumByName(
        DashboardSortOrder.values,
        raw['sort'],
        DashboardSortOrder.natural,
      ),
    ).copyWith();
  }
}

/// A complete dashboard.
class DashboardLayout {
  const DashboardLayout({
    required this.id,
    required this.name,
    required this.widgets,
    this.visibility = DashboardVisibility.personal,
    this.filters = const DashboardFilters(),
    this.editable = true,
    this.ownerId = 0,
    this.updatedAt,
  });

  final String id;
  final String name;
  final DashboardVisibility visibility;
  final List<DashboardWidgetConfig> widgets;

  /// Filters saved with the dashboard and applied when it opens.
  final DashboardFilters filters;

  /// False when the current user can only look at it.
  final bool editable;
  final int ownerId;
  final DateTime? updatedAt;

  bool get isShared => visibility != DashboardVisibility.personal;

  DashboardLayout copyWith({
    String? id,
    String? name,
    DashboardVisibility? visibility,
    List<DashboardWidgetConfig>? widgets,
    DashboardFilters? filters,
    bool? editable,
  }) => DashboardLayout(
    id: id ?? this.id,
    name: name ?? this.name,
    visibility: visibility ?? this.visibility,
    widgets: widgets ?? this.widgets,
    filters: filters ?? this.filters,
    editable: editable ?? this.editable,
    ownerId: ownerId,
    updatedAt: updatedAt,
  );

  /// The part MGWS stores as the opaque `layout` object.
  Map<String, dynamic> layoutJson() => {
    'version': 1,
    'filters': filters.toJson(),
    'widgets': widgets.map((widget) => widget.toJson()).toList(),
  };

  /// Full record, used for the local copy.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'visibility': visibility.name,
    'owner_id': ownerId,
    'layout': layoutJson(),
    'editable': editable,
  };

  factory DashboardLayout.fromJson(Map<String, dynamic> raw) {
    final layout = raw['layout'];
    final widgetsRaw = layout is Map ? layout['widgets'] : null;
    // PHP turns an empty object into an empty list, and a list with holes
    // into a map: accept both.
    final widgetItems = widgetsRaw is List
        ? widgetsRaw
        : (widgetsRaw is Map ? widgetsRaw.values.toList() : const []);
    return DashboardLayout(
      id: raw['id']?.toString() ?? newDashboardId('d'),
      name: raw['name']?.toString() ?? '',
      visibility: _enumByName(
        DashboardVisibility.values,
        raw['visibility'],
        DashboardVisibility.personal,
      ),
      widgets: [
        for (final item in widgetItems)
          if (DashboardWidgetConfig.fromJson(item) case final widget?) widget,
      ],
      filters: DashboardFilters.fromJson(
        layout is Map ? layout['filters'] : null,
      ),
      editable: _boolOr(raw['editable'], true),
      ownerId: _intOr(raw['owner_id'], 0),
      updatedAt: DateTime.tryParse(raw['updated_at_gmt']?.toString() ?? ''),
    );
  }

  /// Starting dashboard: one widget for every available metric, so the user
  /// sees everything and removes what is not needed.
  factory DashboardLayout.standard({required String name}) {
    const quarter = DashboardWidgetWidth.quarter;
    const third = DashboardWidgetWidth.third;
    const half = DashboardWidgetWidth.half;
    const compact = DashboardWidgetHeight.compact;
    const medium = DashboardWidgetHeight.medium;

    // Rows of the 12-column grid: each row adds up to 12 columns.
    final plan =
        <
          (
            DashboardMetric,
            DashboardChartType,
            DashboardWidgetWidth,
            DashboardWidgetHeight,
          )
        >[
          (
            DashboardMetric.salesTotal,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.ordersCount,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.averageTicket,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.ordersToProcess,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.productsPublished,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.productsOutOfStock,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.customersTotal,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.customersPaying,
            DashboardChartType.number,
            quarter,
            compact,
          ),
          (
            DashboardMetric.salesTrend,
            DashboardChartType.bar,
            DashboardWidgetWidth.twoThirds,
            medium,
          ),
          (
            DashboardMetric.topProductsRevenue,
            DashboardChartType.horizontalBar,
            third,
            medium,
          ),
          (DashboardMetric.ordersTrend, DashboardChartType.line, half, medium),
          (
            DashboardMetric.averageTicketTrend,
            DashboardChartType.area,
            half,
            medium,
          ),
          (
            DashboardMetric.topProductsQuantity,
            DashboardChartType.horizontalBar,
            third,
            medium,
          ),
          (
            DashboardMetric.salesByCategory,
            DashboardChartType.donut,
            third,
            medium,
          ),
          (
            DashboardMetric.productsByCategory,
            DashboardChartType.pie,
            third,
            medium,
          ),
          (
            DashboardMetric.ordersByStatus,
            DashboardChartType.donut,
            third,
            medium,
          ),
          (DashboardMetric.stockStatus, DashboardChartType.pie, third, medium),
          (
            DashboardMetric.customersActivity,
            DashboardChartType.donut,
            third,
            medium,
          ),
          (
            DashboardMetric.lowStockProducts,
            DashboardChartType.table,
            DashboardWidgetWidth.full,
            medium,
          ),
        ];
    assert(
      plan.map((entry) => entry.$1).toSet().length ==
          DashboardMetric.values.length - 1,
      'The standard dashboard must show every built-in metric',
    );
    return DashboardLayout(
      id: newDashboardId('d'),
      name: name,
      widgets: [
        for (final (metric, chart, width, height) in plan)
          DashboardWidgetConfig(
            id: newDashboardId('w'),
            metric: metric,
            chartType: chart,
            width: width,
            height: height,
          ),
        // Report questions answered by MGWS.
        for (final (preset, width) in const [
          (ReportPreset.bestCustomers, third),
          (ReportPreset.averageTicketPerCustomer, third),
          (ReportPreset.averagePricePerCustomer, third),
          (ReportPreset.salesByHour, half),
          (ReportPreset.salesByPaymentMethod, half),
        ])
          dashboardReportPresetWidget(preset).copyWith(width: width),
      ],
    );
  }
}

/// Widget answering [preset], with the chart and order that suit it.
DashboardWidgetConfig dashboardReportPresetWidget(ReportPreset preset) {
  final widget = DashboardWidgetConfig.create(
    DashboardMetric.report,
    report: preset.query,
  );
  return switch (preset) {
    ReportPreset.bestCustomers ||
    ReportPreset.salesByOperator => widget.copyWith(
      chartType: DashboardChartType.horizontalBar,
      sortOrder: DashboardSortOrder.valueDesc,
      itemLimit: 10,
    ),
    ReportPreset.averageTicketPerCustomer ||
    ReportPreset.averagePricePerCustomer ||
    ReportPreset.dormantCustomers => widget.copyWith(
      chartType: DashboardChartType.table,
      sortOrder: DashboardSortOrder.valueDesc,
      itemLimit: 10,
    ),
    ReportPreset.salesByPaymentMethod || ReportPreset.salesByChannel =>
      widget.copyWith(chartType: DashboardChartType.donut),
    _ => widget,
  };
}
