// Dashboard widget rendering.
//
// One card per widget, drawn with the chart type the user picked. Visual
// rules: one blue for a single series, the fixed categorical order for parts
// of a whole (anything past the 7th item folds into "Other"), text always in
// theme ink, status colors only with an icon, thin marks and a recessive grid.

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/extensions.dart';
import 'dashboard.code.dart';
import 'dashboard_layout.dart';
import 'dashboard_report.dart';
import 'dashboard_widget_data.dart';

/// Data colors. Series and categorical hues are validated for contrast and
/// color vision deficiency on light and dark surfaces; status colors are
/// reserved for good / warning / critical and always come with an icon.
class DashboardPalette {
  const DashboardPalette._({
    required this.series,
    required this.seriesWash,
    required this.categorical,
    required this.other,
    required this.grid,
    required this.baseline,
    required this.good,
    required this.warning,
    required this.critical,
    required this.deltaUp,
    required this.deltaDown,
  });

  final Color series;
  final Color seriesWash;
  final List<Color> categorical;
  final Color other;
  final Color grid;
  final Color baseline;
  final Color good;
  final Color warning;
  final Color critical;
  final Color deltaUp;
  final Color deltaDown;

  static DashboardPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final series = dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
    return DashboardPalette._(
      series: series,
      seriesWash: series.withValues(alpha: .12),
      categorical: dark
          ? const [
              Color(0xFF3987E5),
              Color(0xFFD95926),
              Color(0xFF199E70),
              Color(0xFFC98500),
              Color(0xFFD55181),
              Color(0xFF008300),
              Color(0xFF9085E9),
            ]
          : const [
              Color(0xFF2A78D6),
              Color(0xFFEB6834),
              Color(0xFF1BAF7A),
              Color(0xFFEDA100),
              Color(0xFFE87BA4),
              Color(0xFF008300),
              Color(0xFF6250D6),
            ],
      other: theme.colorScheme.outline,
      grid: theme.colorScheme.outlineVariant.withValues(alpha: .5),
      baseline: theme.colorScheme.outlineVariant,
      good: const Color(0xFF0CA30C),
      warning: dark ? const Color(0xFFFAB219) : const Color(0xFFC98500),
      critical: const Color(0xFFD03B3B),
      deltaUp: dark ? const Color(0xFF0CA30C) : const Color(0xFF006300),
      deltaDown: dark ? const Color(0xFFE66767) : const Color(0xFFD03B3B),
    );
  }
}

/// Numbers and dates in the app language.
class DashboardFormat {
  DashboardFormat(this.locale, {this.l10n})
    : _currency = NumberFormat.currency(locale: locale, symbol: '€'),
      _count = NumberFormat.decimalPattern(locale),
      _decimal = NumberFormat('#,##0.##', locale),
      _compact = NumberFormat.compact(locale: locale);

  factory DashboardFormat.of(BuildContext context) => DashboardFormat(
    Localizations.localeOf(context).toLanguageTag(),
    l10n: context.l10n,
  );

  final String locale;
  final AppLocalizations? l10n;
  final NumberFormat _currency;
  final NumberFormat _count;
  final NumberFormat _decimal;
  final NumberFormat _compact;

  String currency(double value) => _currency.format(value);
  String count(num value) => _count.format(value);

  String value(double value, DashboardValueFormat format) => switch (format) {
    DashboardValueFormat.currency => currency(value),
    DashboardValueFormat.count => count(value.round()),
    // Report percentages arrive already multiplied by 100.
    DashboardValueFormat.percent => '${_decimal.format(value)} %',
    DashboardValueFormat.decimal => _decimal.format(value),
    DashboardValueFormat.days =>
      l10n?.dashboardReportDaysValue(value.round()) ?? count(value.round()),
  };

  String compact(double value, DashboardValueFormat format) {
    final text = value.abs() >= 1000
        ? _compact.format(value)
        : (format == DashboardValueFormat.decimal
              ? _decimal.format(value)
              : _count.format(value.round()));
    return switch (format) {
      DashboardValueFormat.currency => '$text €',
      DashboardValueFormat.percent => '$text %',
      _ => text,
    };
  }

  String percent(double fraction) =>
      NumberFormat.percentPattern(locale).format(fraction);

  String shortDay(DateTime date) => DateFormat('d/M', locale).format(date);
  String longDay(DateTime date) => DateFormat('EEE d MMM', locale).format(date);
  String shortMonth(DateTime date) => DateFormat('MMM', locale).format(date);
  String longMonth(DateTime date) => DateFormat('MMMM y', locale).format(date);
  String time(DateTime date) => DateFormat('HH:mm', locale).format(date);
  String date(DateTime date) => DateFormat.yMMMd(locale).format(date);

  String pointLabel(DashboardPoint point, {required bool monthly}) {
    final date = point.date;
    if (date == null) return point.label;
    return monthly ? longMonth(date) : longDay(date);
  }

  String axisLabel(DashboardPoint point, {required bool monthly}) {
    final date = point.date;
    if (date == null) return point.label;
    return monthly ? shortMonth(date) : shortDay(date);
  }

  String range(PeriodoReport period) {
    final start = period.dataInizio;
    final end = period.dataFine;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('EEEE d MMMM y', locale).format(start);
    }
    final startFormat = DateFormat(
      start.year == end.year ? 'd MMM' : 'd MMM y',
      locale,
    );
    return '${startFormat.format(start)} – '
        '${DateFormat('d MMM y', locale).format(end)}';
  }
}

/// Localized metric name.
String dashboardMetricLabel(
  AppLocalizations l10n,
  DashboardMetric metric,
) => switch (metric) {
  DashboardMetric.salesTotal => l10n.dashboardKpiVendite,
  DashboardMetric.ordersCount => l10n.dashboardKpiOrdini,
  DashboardMetric.averageTicket => l10n.dashboardKpiScontrinoMedio,
  DashboardMetric.ordersToProcess => l10n.dashboardKpiDaEvadere,
  DashboardMetric.productsPublished =>
    l10n.dashboardWidgetMetricProductsPublished,
  DashboardMetric.productsOutOfStock =>
    l10n.dashboardWidgetMetricProductsOutOfStock,
  DashboardMetric.customersTotal => l10n.dashboardClientiRegistrati,
  DashboardMetric.customersPaying => l10n.dashboardWidgetMetricCustomersPaying,
  DashboardMetric.salesTrend => l10n.dashboardAndamentoVendite,
  DashboardMetric.ordersTrend => l10n.dashboardWidgetMetricOrdersTrend,
  DashboardMetric.averageTicketTrend =>
    l10n.dashboardWidgetMetricAverageTicketTrend,
  DashboardMetric.topProductsRevenue => l10n.dashboardTopProdotti,
  DashboardMetric.topProductsQuantity =>
    l10n.dashboardWidgetMetricTopProductsQuantity,
  DashboardMetric.salesByCategory => l10n.dashboardWidgetMetricSalesByCategory,
  DashboardMetric.productsByCategory =>
    l10n.dashboardWidgetMetricProductsByCategory,
  DashboardMetric.ordersByStatus => l10n.dashboardOrdiniDelPeriodo,
  DashboardMetric.stockStatus => l10n.dashboardMagazzino,
  DashboardMetric.customersActivity =>
    l10n.dashboardWidgetMetricCustomersActivity,
  DashboardMetric.lowStockProducts =>
    l10n.dashboardWidgetMetricLowStockProducts,
  DashboardMetric.report => l10n.dashboardReportCustom,
};

/// Title of a widget: the custom one, or a description of its data.
String dashboardWidgetTitle(
  AppLocalizations l10n,
  DashboardWidgetConfig config,
) {
  final custom = config.title.trim();
  if (custom.isNotEmpty) return custom;
  final report = config.report;
  if (config.metric != DashboardMetric.report || report == null) {
    return dashboardMetricLabel(l10n, config.metric);
  }
  final measure = reportMeasureLabel(l10n, report.measure);
  final dimension = report.dimension;
  return dimension == null
      ? measure
      : l10n.dashboardReportTitleBy(
          measure,
          reportDimensionLabel(l10n, dimension).toLowerCase(),
        );
}

String reportMeasureLabel(AppLocalizations l10n, String key) => switch (key) {
  'revenue' => l10n.dashboardReportMeasureRevenue,
  'net_revenue' => l10n.dashboardReportMeasureNetRevenue,
  'tax' => l10n.dashboardReportMeasureTax,
  'documents' => l10n.dashboardReportMeasureDocuments,
  'average_ticket' => l10n.dashboardReportMeasureAverageTicket,
  'units_per_document' => l10n.dashboardReportMeasureUnitsPerDocument,
  'discount' => l10n.dashboardReportMeasureDiscount,
  'discount_rate' => l10n.dashboardReportMeasureDiscountRate,
  'returns_value' => l10n.dashboardReportMeasureReturnsValue,
  'returns_rate' => l10n.dashboardReportMeasureReturnsRate,
  'quantity' => l10n.dashboardReportMeasureQuantity,
  'quantity_sold' => l10n.dashboardReportMeasureQuantitySold,
  'quantity_returned' => l10n.dashboardReportMeasureQuantityReturned,
  'average_unit_price' => l10n.dashboardReportMeasureAverageUnitPrice,
  'distinct_products' => l10n.dashboardReportMeasureDistinctProducts,
  'customers' => l10n.dashboardReportMeasureCustomers,
  'new_customers' => l10n.dashboardReportMeasureNewCustomers,
  'returning_customers' => l10n.dashboardReportMeasureReturningCustomers,
  'revenue_per_customer' => l10n.dashboardReportMeasureRevenuePerCustomer,
  'documents_per_customer' => l10n.dashboardReportMeasureDocumentsPerCustomer,
  'days_since_last_purchase' =>
    l10n.dashboardReportMeasureDaysSinceLastPurchase,
  'collected_total' => l10n.dashboardReportMeasureCollectedTotal,
  'cash_collected' => l10n.dashboardReportMeasureCashCollected,
  'card_collected' => l10n.dashboardReportMeasureCardCollected,
  'other_collected' => l10n.dashboardReportMeasureOtherCollected,
  'refunds_paid' => l10n.dashboardReportMeasureRefundsPaid,
  'manual_in' => l10n.dashboardReportMeasureManualIn,
  'manual_out' => l10n.dashboardReportMeasureManualOut,
  'cash_expected' => l10n.dashboardReportMeasureCashExpected,
  'cash_counted' => l10n.dashboardReportMeasureCashCounted,
  'cash_difference' => l10n.dashboardReportMeasureCashDifference,
  'card_difference' => l10n.dashboardReportMeasureCardDifference,
  'closings' => l10n.dashboardReportMeasureClosings,
  _ => key,
};

String reportDimensionLabel(AppLocalizations l10n, ReportDimension d) =>
    switch (d) {
      ReportDimension.hour => l10n.dashboardReportDimensionHour,
      ReportDimension.weekday => l10n.dashboardReportDimensionWeekday,
      ReportDimension.day => l10n.dashboardReportDimensionDay,
      ReportDimension.week => l10n.dashboardReportDimensionWeek,
      ReportDimension.month => l10n.dashboardReportDimensionMonth,
      ReportDimension.quarter => l10n.dashboardReportDimensionQuarter,
      ReportDimension.year => l10n.dashboardReportDimensionYear,
      ReportDimension.product => l10n.dashboardReportDimensionProduct,
      ReportDimension.variation => l10n.dashboardReportDimensionVariation,
      ReportDimension.category => l10n.dashboardReportDimensionCategory,
      ReportDimension.brand => l10n.dashboardReportDimensionBrand,
      ReportDimension.customer => l10n.dashboardReportDimensionCustomer,
      ReportDimension.channel => l10n.dashboardReportDimensionChannel,
      ReportDimension.register => l10n.dashboardReportDimensionRegister,
      ReportDimension.operator => l10n.dashboardReportDimensionOperator,
      ReportDimension.paymentMethod =>
        l10n.dashboardReportDimensionPaymentMethod,
    };

String reportFilterKindLabel(AppLocalizations l10n, ReportFilterKind k) =>
    switch (k) {
      ReportFilterKind.product => l10n.dashboardReportDimensionProduct,
      ReportFilterKind.customer => l10n.dashboardReportDimensionCustomer,
      ReportFilterKind.category => l10n.dashboardReportDimensionCategory,
      ReportFilterKind.brand => l10n.dashboardReportDimensionBrand,
      ReportFilterKind.channel => l10n.dashboardReportDimensionChannel,
      ReportFilterKind.register => l10n.dashboardReportDimensionRegister,
      ReportFilterKind.operator => l10n.dashboardReportDimensionOperator,
      ReportFilterKind.paymentMethod =>
        l10n.dashboardReportDimensionPaymentMethod,
    };

/// Localized chart type name.
String dashboardChartLabel(AppLocalizations l10n, DashboardChartType type) =>
    switch (type) {
      DashboardChartType.number => l10n.dashboardWidgetChartNumber,
      DashboardChartType.gauge => l10n.dashboardWidgetChartGauge,
      DashboardChartType.bar => l10n.dashboardWidgetChartBar,
      DashboardChartType.horizontalBar =>
        l10n.dashboardWidgetChartHorizontalBar,
      DashboardChartType.line => l10n.dashboardWidgetChartLine,
      DashboardChartType.area => l10n.dashboardWidgetChartArea,
      DashboardChartType.pie => l10n.dashboardWidgetChartPie,
      DashboardChartType.donut => l10n.dashboardWidgetChartDonut,
      DashboardChartType.table => l10n.dashboardWidgetChartTable,
    };

IconData dashboardChartIcon(DashboardChartType type) => switch (type) {
  DashboardChartType.number => Icons.looks_one_outlined,
  DashboardChartType.gauge => Icons.speed,
  DashboardChartType.bar => Icons.bar_chart,
  DashboardChartType.horizontalBar => Icons.align_horizontal_left,
  DashboardChartType.line => Icons.show_chart,
  DashboardChartType.area => Icons.area_chart_outlined,
  DashboardChartType.pie => Icons.pie_chart_outline,
  DashboardChartType.donut => Icons.donut_large,
  DashboardChartType.table => Icons.table_rows_outlined,
};

/// Card of one widget: title row plus the chart.
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({
    super.key,
    required this.config,
    required this.dataset,
    this.leading,
    this.trailing,
    this.highlighted = false,
  });

  final DashboardWidgetConfig config;
  final DashboardDataset dataset;
  final Widget? leading;
  final Widget? trailing;

  /// Drawn with an accent border, e.g. while a widget is dropped on it.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = dashboardWidgetTitle(l10n, config);
    final subtitle = _subtitle(l10n);

    return Container(
      height: config.height.pixels,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: .7),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ?leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: config.shape == DashboardMetricShape.single
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  String? _subtitle(AppLocalizations l10n) {
    final reportFilters = config.report?.filters ?? const [];
    final parts = <String>[
      if (reportFilters.isNotEmpty)
        reportFilters.map((filter) => filter.label).join(', '),
      if (config.metric.hasStockThreshold)
        l10n.dashboardScorteBasse(config.stockThreshold),
      if (config.itemFilter.trim().isNotEmpty)
        l10n.dashboardWidgetFilteredBy(config.itemFilter.trim()),
      if (config.metric.ignoresPeriod &&
          config.metric.shape != DashboardMetricShape.single)
        l10n.dashboardWidgetNotPeriodBound,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    switch (dataset.status) {
      case DashboardDatasetStatus.loading:
        return const Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case DashboardDatasetStatus.unavailable:
        return _EmptyText(
          text: dataset.message ?? l10n.dashboardWidgetDataUnavailable,
        );
      case DashboardDatasetStatus.ready:
        break;
    }
    if (dataset.isEmpty) return _EmptyText(text: l10n.dashboardNessunDato);
    return switch (config.chartType) {
      DashboardChartType.number => _NumberView(dataset: dataset),
      DashboardChartType.gauge => _GaugeView(dataset: dataset),
      DashboardChartType.bar => _BarView(dataset: dataset),
      DashboardChartType.horizontalBar => _HorizontalBarView(dataset: dataset),
      DashboardChartType.line => _LineView(dataset: dataset, area: false),
      DashboardChartType.area => _LineView(dataset: dataset, area: true),
      DashboardChartType.pie => _PieView(dataset: dataset, donut: false),
      DashboardChartType.donut => _PieView(dataset: dataset, donut: true),
      DashboardChartType.table => _TableView(dataset: dataset),
    };
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

// =======================================================
// ==                  SINGLE VALUES                    ==
// =======================================================

class _NumberView extends StatelessWidget {
  const _NumberView({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DashboardFormat.of(context);
    final value = dataset.value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              format.value(value, dataset.format),
              maxLines: 1,
              style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _ReferenceLine(dataset: dataset),
      ],
    );
  }
}

/// Change against the previous period, or share of the total.
class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final value = dataset.value ?? 0;
    final reference = dataset.reference;
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);

    if (reference == null) return const SizedBox(height: 16);
    if (!dataset.referenceIsPrevious) {
      final share = reference > 0 ? value / reference : 0.0;
      return Text(
        l10n.dashboardWidgetShareOfTotal(
          format.percent(share),
          format.value(reference, dataset.format),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    if (reference <= 0) {
      return Text(
        l10n.dashboardNessunConfronto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final change = (value - reference) / reference;
    final (icon, color) = switch (change.sign) {
      > 0 => (Icons.arrow_upward, palette.deltaUp),
      < 0 => (Icons.arrow_downward, palette.deltaDown),
      _ => (Icons.remove, muted),
    };
    final changeText =
        '${change > 0 ? '+' : (change < 0 ? '−' : '')}'
        '${format.percent(change.abs())}';
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          changeText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            l10n.dashboardWidgetVersus(format.value(reference, dataset.format)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _GaugeView extends StatelessWidget {
  const _GaugeView({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final reference = dataset.reference;
    if (reference == null || reference <= 0) {
      return _NumberView(dataset: dataset);
    }
    final theme = Theme.of(context);
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final value = dataset.value ?? 0;
    final fraction = value / reference;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight * 2);
        return Center(
          child: SizedBox(
            width: size,
            height: size / 2,
            child: CustomPaint(
              painter: _GaugePainter(
                fraction: fraction,
                color: palette.series,
                track: palette.seriesWash,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        format.value(value, dataset.format),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      format.percent(fraction),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(8.0, size.height * 0.14);
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      (size.height - stroke / 2) * 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, math.pi, math.pi, false, paint..color = track);
    final sweep = math.pi * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, math.pi, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

// =======================================================
// ==                      SERIES                       ==
// =======================================================

/// "Clean" grid step: 1, 2 or 5 times a power of ten.
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  var magnitude = 1.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  while (magnitude > raw) {
    magnitude /= 10;
  }
  for (final multiple in const [1, 2, 5, 10]) {
    if (multiple * magnitude >= raw) return multiple * magnitude;
  }
  return 10 * magnitude;
}

class _Axis {
  _Axis(List<DashboardPoint> points) {
    final highest = points.fold<double>(0, (a, b) => math.max(a, b.value));
    step = _niceStep(highest / 4);
    maxY = math.max(step, (highest / step).ceil() * step);
  }

  late final double step;
  late final double maxY;
}

FlTitlesData _titles({
  required BuildContext context,
  required List<DashboardPoint> points,
  required DashboardDataset dataset,
  required double step,
  required int labelEvery,
}) {
  final format = DashboardFormat.of(context);
  final axisStyle = TextStyle(
    fontSize: 11,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 52,
        interval: step,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              format.compact(value, dataset.format),
              maxLines: 1,
              style: axisStyle,
            ),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (value != index.toDouble() ||
              index < 0 ||
              index >= points.length ||
              index % labelEvery != 0) {
            return const SizedBox.shrink();
          }
          final text = format.axisLabel(
            points[index],
            monthly: dataset.monthly,
          );
          return SideTitleWidget(
            meta: meta,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: axisStyle,
              ),
            ),
          );
        },
      ),
    ),
  );
}

TextStyle _tooltipLabelStyle(ColorScheme scheme) => TextStyle(
  color: scheme.onInverseSurface.withValues(alpha: .8),
  fontSize: 11,
);

TextStyle _tooltipValueStyle(ColorScheme scheme) => TextStyle(
  color: scheme.onInverseSurface,
  fontWeight: FontWeight.w600,
  fontSize: 13,
);

class _BarView extends StatelessWidget {
  const _BarView({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final points = dataset.points;
    final axis = _Axis(points);
    final timeSeries = points.first.date != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 52) / points.length;
        final barWidth = (slot * 0.6).clamp(2.0, 28.0);
        final labelEvery = ((timeSeries ? 56 : 72) / slot).ceil().clamp(
          1,
          points.length,
        );
        return BarChart(
          BarChartData(
            maxY: axis.maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            barGroups: [
              for (var index = 0; index < points.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: points[index].value,
                      width: barWidth,
                      color: palette.series,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: axis.step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: palette.grid, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: palette.baseline)),
            ),
            titlesData: _titles(
              context: context,
              points: points,
              dataset: dataset,
              step: axis.step,
              labelEvery: labelEvery,
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                tooltipBorderRadius: BorderRadius.circular(6),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                maxContentWidth: 220,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final point = points[group.x];
                  return BarTooltipItem(
                    '${format.pointLabel(point, monthly: dataset.monthly)}\n',
                    _tooltipLabelStyle(scheme),
                    children: [
                      TextSpan(
                        text: format.value(point.value, dataset.format),
                        style: _tooltipValueStyle(scheme),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}

class _LineView extends StatelessWidget {
  const _LineView({required this.dataset, required this.area});

  final DashboardDataset dataset;
  final bool area;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final points = dataset.points;
    final axis = _Axis(points);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 52) / math.max(1, points.length);
        final labelEvery = (56 / slot).ceil().clamp(1, points.length);
        return LineChart(
          LineChartData(
            minY: 0,
            maxY: axis.maxY,
            minX: 0,
            maxX: math.max(1, points.length - 1).toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var index = 0; index < points.length; index++)
                    FlSpot(index.toDouble(), points[index].value),
                ],
                color: palette.series,
                barWidth: 2,
                isCurved: false,
                dotData: FlDotData(show: points.length <= 31),
                belowBarData: BarAreaData(
                  show: area,
                  color: palette.series.withValues(alpha: .18),
                ),
              ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: axis.step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: palette.grid, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: palette.baseline)),
            ),
            titlesData: _titles(
              context: context,
              points: points,
              dataset: dataset,
              step: axis.step,
              labelEvery: labelEvery,
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                tooltipBorderRadius: BorderRadius.circular(6),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${format.pointLabel(points[spot.x.round()], monthly: dataset.monthly)}\n',
                      _tooltipLabelStyle(scheme),
                      children: [
                        TextSpan(
                          text: format.value(spot.y, dataset.format),
                          style: _tooltipValueStyle(scheme),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}

class _HorizontalBarView extends StatelessWidget {
  const _HorizontalBarView({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final points = dataset.points;
    final highest = points.fold<double>(0, (a, b) => math.max(a, b.value));

    return ListView.separated(
      itemCount: points.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final point = points[index];
        final label = format.pointLabel(point, monthly: dataset.monthly);
        return Tooltip(
          message: '$label: ${format.value(point.value, dataset.format)}',
          waitDuration: const Duration(milliseconds: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    format.value(point.value, dataset.format),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Bar(
                fraction: highest > 0 ? point.value / highest : 0,
                color: palette.series,
                track: palette.seriesWash,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => Container(
    height: 8,
    decoration: BoxDecoration(
      color: track,
      borderRadius: BorderRadius.circular(4),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0.0, 1.0),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );
}

class _PieView extends StatefulWidget {
  const _PieView({required this.dataset, required this.donut});

  final DashboardDataset dataset;
  final bool donut;

  @override
  State<_PieView> createState() => _PieViewState();
}

class _PieViewState extends State<_PieView> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = DashboardPalette.of(context);
    final format = DashboardFormat.of(context);
    final dataset = widget.dataset;
    final monthly = dataset.monthly;

    // Fixed hue order; anything past the palette folds into "Other".
    final maxSlices = palette.categorical.length;
    final source = dataset.points.where((point) => point.value > 0).toList();
    final slices = <(String, double, Color)>[
      for (var index = 0; index < source.length && index < maxSlices; index++)
        (
          format.pointLabel(source[index], monthly: monthly),
          source[index].value,
          palette.categorical[index],
        ),
    ];
    if (source.length > maxSlices) {
      // The last palette slot becomes "Other" so the total stays complete.
      final kept = slices.take(maxSlices - 1).toList();
      final rest = source
          .skip(maxSlices - 1)
          .fold<double>(0, (sum, point) => sum + point.value);
      slices
        ..clear()
        ..addAll(kept)
        ..add((l10n.dashboardWidgetOther, rest, palette.other));
    }
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.$2);
    if (total <= 0) return _EmptyText(text: l10n.dashboardNessunDato);

    final legend = ListView(
      shrinkWrap: true,
      children: [
        for (var index = 0; index < slices.length; index++)
          InkWell(
            onTap: () =>
                setState(() => _touched = _touched == index ? null : index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: slices[index].$3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slices[index].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: _touched == index
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    format.value(slices[index].$2, dataset.format),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      format.percent(slices[index].$2 / total),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 420;
        final chartSize = side
            ? math.min(constraints.maxHeight, constraints.maxWidth * 0.45)
            : math.min(constraints.maxWidth, constraints.maxHeight * 0.55);
        final radius = chartSize / 2;
        final chart = SizedBox.square(
          dimension: chartSize,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: widget.donut ? radius * 0.55 : 0,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) return;
                  final index = response?.touchedSection?.touchedSectionIndex;
                  if (index != _touched) setState(() => _touched = index);
                },
              ),
              sections: [
                for (var index = 0; index < slices.length; index++)
                  PieChartSectionData(
                    value: slices[index].$2,
                    color: slices[index].$3,
                    showTitle: false,
                    radius:
                        (widget.donut ? radius * 0.45 : radius) *
                        (_touched == index ? 1.0 : 0.94),
                  ),
              ],
            ),
            duration: Duration.zero,
          ),
        );
        if (side) {
          return Row(
            children: [
              chart,
              const SizedBox(width: 16),
              Expanded(child: Center(child: legend)),
            ],
          );
        }
        return Column(
          children: [
            chart,
            const SizedBox(height: 8),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.dataset});

  final DashboardDataset dataset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DashboardFormat.of(context);
    final points = dataset.points.first.date != null
        ? dataset.points.reversed
              .toList() // most recent first
        : dataset.points;
    const figures = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return ListView.separated(
      itemCount: points.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final point = points[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  format.pointLabel(point, monthly: dataset.monthly),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                format.value(point.value, dataset.format),
                style: theme.textTheme.bodyMedium
                    ?.merge(figures)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
