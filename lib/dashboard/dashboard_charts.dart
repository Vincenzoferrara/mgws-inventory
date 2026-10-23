// Report Charts - Widget per grafici interattivi
//
// Collezione di widget di grafici per i report WooCommerce
// Utilizza fl_chart per visualizzazioni professionali e animate

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dashboard.code.dart';
import 'class_report.dart';
import 'dashboard_widget_data.dart' show dashboardOrderStatusLabel;
import '../l10n/extensions.dart';
import '../theme/theme.dart';

// =======================================================
// ==         GRAFICO A LINEE - VENDITE NEL TEMPO       ==
// =======================================================

/// Grafico a linee per mostrare l'andamento delle vendite nel tempo
class SalesLineChart extends StatefulWidget {
  final List<VenditaGiornaliera> vendite;
  final String? title;
  final Color? lineColor;
  final bool showGrid;
  final bool animate;
  final bool showArea;
  final bool showOrders;

  const SalesLineChart({
    super.key,
    required this.vendite,
    this.title,
    this.lineColor,
    this.showGrid = true,
    this.animate = true,
    this.showArea = false,
    this.showOrders = false,
  });

  @override
  State<SalesLineChart> createState() => _SalesLineChartState();
}

class _SalesLineChartState extends State<SalesLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      _animation = CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      );
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vendite.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.l10n.dashboardNoDataForPeriod,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    if (widget.animate) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => _buildChart(),
      );
    }

    return _buildChart();
  }

  Widget _buildChart() {
    final lineColor = widget.lineColor ?? Theme.of(context).primaryColor;
    final spots = _createSpots();
    final maxY = _calculateMaxY();
    final minY = _calculateMinY();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title ?? context.l10n.dashboardAndamentoVendite,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.lineBarSpots != null &&
                          response!.lineBarSpots!.isNotEmpty) {
                        _touchedIndex = response.lineBarSpots!.first.spotIndex;
                      } else {
                        _touchedIndex = null;
                      }
                    });
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        context.charts.tooltipBackground,
                    //tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final vendita = widget.vendite[spot.spotIndex];
                        return LineTooltipItem(
                          '${ReportFormatter.formatDate(vendita.data)}\n',
                          TextStyle(
                            color: context.charts.tooltipText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: ReportFormatter.formatCurrency(
                                vendita.totale,
                              ),
                              style: TextStyle(
                                color: context.charts.tooltipValue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '\n${context.l10n.dashboardOrdersCount(vendita.ordini)}',
                              style: TextStyle(
                                color: context.charts.tooltipMutedText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: widget.showGrid,
                  drawVerticalLine: true,
                  horizontalInterval: maxY > minY ? (maxY - minY) / 5 : 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: context.colors.neutralColor.withValues(alpha: 0.2),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: context.colors.neutralColor.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          ReportFormatter.formatCurrencyCompact(value),
                          style: TextStyle(
                            color: context.colors.subtitleColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _calculateBottomInterval(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < widget.vendite.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              ReportFormatter.formatDate(
                                widget.vendite[index].data,
                              ),
                              style: TextStyle(
                                color: context.colors.subtitleColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: context.colors.dividerColor,
                      width: 1,
                    ),
                    left: BorderSide(
                      color: context.colors.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: _touchedIndex == index ? 6 : 4,
                          color: context.charts.tooltipText,
                          strokeWidth: _touchedIndex == index ? 3 : 2,
                          strokeColor: lineColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: widget.showArea,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          lineColor.withValues(alpha: 0.3),
                          lineColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: widget.animate
                  ? const Duration(milliseconds: 150)
                  : Duration.zero,
            ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createSpots() {
    if (widget.animate) {
      final progress = _animation.value;
      final visibleCount = (widget.vendite.length * progress).ceil();
      return List.generate(
        visibleCount,
        (index) => FlSpot(
          index.toDouble(),
          widget.showOrders
              ? widget.vendite[index].ordini.toDouble()
              : widget.vendite[index].totale,
        ),
      );
    }

    return List.generate(
      widget.vendite.length,
      (index) => FlSpot(
        index.toDouble(),
        widget.showOrders
            ? widget.vendite[index].ordini.toDouble()
            : widget.vendite[index].totale,
      ),
    );
  }

  double _calculateMaxY() {
    if (widget.vendite.isEmpty) return 100;
    final values = widget.showOrders
        ? widget.vendite.map((e) => e.ordini.toDouble())
        : widget.vendite.map((e) => e.totale);
    final max = values.reduce((a, b) => a > b ? a : b);
    return max * 1.2; // +20% padding
  }

  double _calculateMinY() {
    if (widget.vendite.isEmpty) return 0;
    final values = widget.showOrders
        ? widget.vendite.map((e) => e.ordini.toDouble())
        : widget.vendite.map((e) => e.totale);
    final min = values.reduce((a, b) => a < b ? a : b);
    return (min * 0.8).clamp(0, double.infinity); // -20% padding, min 0
  }

  double _calculateBottomInterval() {
    final count = widget.vendite.length;
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 7;
  }
}

// =======================================================
// ==      GRAFICO A BARRE - TOP PRODOTTI VENDUTI       ==
// =======================================================

/// Grafico a barre orizzontali per i prodotti più venduti
class TopProductsBarChart extends StatefulWidget {
  final List<TopProdotto> topProducts;
  final int maxItems;
  final bool showQuantity;

  const TopProductsBarChart({
    super.key,
    required this.topProducts,
    this.maxItems = 10,
    this.showQuantity = true,
  });

  @override
  State<TopProductsBarChart> createState() => _TopProductsBarChartState();
}

class _TopProductsBarChartState extends State<TopProductsBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.l10n.dashboardNoProductData,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final products = widget.topProducts.take(widget.maxItems).toList();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.dashboardTopProductsSold,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          if (response?.spot != null) {
                            _touchedIndex =
                                response!.spot!.touchedBarGroupIndex;
                          } else {
                            _touchedIndex = null;
                          }
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            context.charts.tooltipBackground,
                        //tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final product = products[groupIndex];
                          return BarTooltipItem(
                            '${product.titolo}\n',
                            TextStyle(
                              color: context.charts.tooltipText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: ReportFormatter.formatCurrency(
                                  product.totaleVendite,
                                ),
                                style: TextStyle(
                                  color: context.charts.tooltipValue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '\n${context.l10n.dashboardQuantitaUnita('${product.quantitaVenduta}')}',
                                style: TextStyle(
                                  color: context.charts.tooltipMutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < products.length) {
                              final product = products[index];
                              String label = product.titolo;
                              if (label.length > 15) {
                                label = '${label.substring(0, 12)}...';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: context.colors.onSurfaceVariantColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              ReportFormatter.formatCurrencyCompact(value),
                              style: TextStyle(
                                color: context.colors.subtitleColor,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: context.colors.dividerColor,
                          width: 1,
                        ),
                        left: BorderSide(
                          color: context.colors.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _calculateHorizontalInterval(
                        products,
                      ),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: context.colors.neutralColor.withValues(
                            alpha: 0.2,
                          ),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    barGroups: _createBarGroups(products),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<BarChartGroupData> _createBarGroups(List<TopProdotto> products) {
    final progress = _animation.value;

    return List.generate(products.length, (index) {
      final product = products[index];
      final isTouched = _touchedIndex == index;
      final animatedValue = product.totaleVendite * progress;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: animatedValue,
            color: _getBarColor(index, isTouched),
            width: isTouched ? 24 : 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: product.totaleVendite,
              color: context.colors.neutralColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    });
  }

  Color _getBarColor(int index, bool isTouched) {
    final colors = context.charts.palette;
    final baseColor = colors[index % colors.length];
    return isTouched ? baseColor : baseColor.withValues(alpha: 0.85);
  }

  double _calculateHorizontalInterval(List<TopProdotto> products) {
    if (products.isEmpty) return 100;
    final max = products
        .map((e) => e.totaleVendite)
        .reduce((a, b) => a > b ? a : b);
    return max / 4;
  }
}

// =======================================================
// ==      GRAFICO A TORTA - STATO ORDINI               ==
// =======================================================

/// Grafico a torta per visualizzare la distribuzione degli ordini per stato
class OrderStatusPieChart extends StatefulWidget {
  final Map<String, int> ordersByStatus;
  final bool animate;

  const OrderStatusPieChart({
    super.key,
    required this.ordersByStatus,
    this.animate = true,
  });

  @override
  State<OrderStatusPieChart> createState() => _OrderStatusPieChartState();
}

class _OrderStatusPieChartState extends State<OrderStatusPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      _animation = CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCirc,
      );
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ordersByStatus.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.l10n.dashboardNoOrders,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    if (widget.animate) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => _buildChart(),
      );
    }

    return _buildChart();
  }

  Widget _buildChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.l10n.dashboardOrdersByStatusDistribution,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (response?.touchedSection != null) {
                              _touchedIndex =
                                  response!.touchedSection!.touchedSectionIndex;
                            } else {
                              _touchedIndex = -1;
                            }
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _createSections(),
                    ),
                  ),
                ),
              ),
              Expanded(flex: 2, child: _buildLegend()),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _createSections() {
    final total = widget.ordersByStatus.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (total == 0) return [];

    int index = 0;
    final progress = widget.animate ? _animation.value : 1.0;

    return widget.ordersByStatus.entries.map((entry) {
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 65.0 : 55.0;
      final fontSize = isTouched ? 16.0 : 14.0;
      final percentage = (entry.value / total) * 100;
      final animatedPercentage = percentage * progress;

      final palette = context.charts.palette;
      final color =
          context.charts.orderStatus(entry.key) ??
          palette[index % palette.length];

      final section = PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${animatedPercentage.toStringAsFixed(1)}%',
        radius: radius,
        color: color,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: context.charts.tooltipText,
          shadows: [
            Shadow(
              color: context.theme.colorScheme.shadow.withValues(alpha: 0.26),
              blurRadius: 2,
            ),
          ],
        ),
      );

      index++;
      return section;
    }).toList();
  }

  Widget _buildLegend() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: widget.ordersByStatus.entries.map((entry) {
        final color =
            context.charts.orderStatus(entry.key) ??
            context.theme.colorScheme.primary;
        final label = dashboardOrderStatusLabel(context.l10n, entry.key);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                entry.value.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// =======================================================
// ==    GRAFICO A BARRE - ORDINI NEL TEMPO             ==
// =======================================================

/// Grafico a barre per mostrare il numero di ordini nel tempo
class OrdersBarChart extends StatefulWidget {
  final List<VenditaGiornaliera> vendite;

  const OrdersBarChart({super.key, required this.vendite});

  @override
  State<OrdersBarChart> createState() => _OrdersBarChartState();
}

class _OrdersBarChartState extends State<OrdersBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vendite.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            context.l10n.dashboardNoData,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.dashboardOrdersOverTime,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          if (response?.spot != null) {
                            _touchedIndex =
                                response!.spot!.touchedBarGroupIndex;
                          } else {
                            _touchedIndex = null;
                          }
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            context.charts.tooltipBackground,
                        //tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final vendita = widget.vendite[groupIndex];
                          return BarTooltipItem(
                            '${ReportFormatter.formatDate(vendita.data)}\n',
                            TextStyle(
                              color: context.charts.tooltipText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: context.l10n.dashboardOrdersCount(
                                  vendita.ordini,
                                ),
                                style: TextStyle(
                                  color: context.charts.tooltipHighlight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: _calculateBottomInterval(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < widget.vendite.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  ReportFormatter.formatDate(
                                    widget.vendite[index].data,
                                  ),
                                  style: TextStyle(
                                    color: context.colors.subtitleColor,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: context.colors.subtitleColor,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: context.colors.dividerColor,
                          width: 1,
                        ),
                        left: BorderSide(
                          color: context.colors.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: context.colors.neutralColor.withValues(
                            alpha: 0.2,
                          ),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    barGroups: _createBarGroups(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<BarChartGroupData> _createBarGroups() {
    final progress = _animation.value;
    final maxOrders = widget.vendite
        .map((e) => e.ordini)
        .reduce((a, b) => a > b ? a : b);

    return List.generate(widget.vendite.length, (index) {
      final vendita = widget.vendite[index];
      final isTouched = _touchedIndex == index;
      final animatedValue = vendita.ordini * progress;

      // Calcola l'intensità del colore in base al numero di ordini
      final intensity = maxOrders > 0 ? vendita.ordini / maxOrders : 0.5;
      final baseColor = context.colors.infoColor;
      final color = Color.lerp(
        baseColor.withValues(alpha: 0.4),
        baseColor,
        intensity,
      )!;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: animatedValue.toDouble(),
            color: isTouched ? baseColor : color,
            width: isTouched ? 18 : 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  double _calculateBottomInterval() {
    final count = widget.vendite.length;
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 7;
  }
}
