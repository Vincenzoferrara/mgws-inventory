// Report Detailed - Pagine di report dettagliati
//
// Visualizzazioni dettagliate per diverse metriche:
// - Report Top Prodotti
// - Analisi Performance Temporale
// - Report Ordini Dettagliato

import 'package:flutter/material.dart';
import 'dashboard.code.dart';
import 'dashboard_charts.dart';
import '../log_viewer/app_logger.dart';
import '../l10n/extensions.dart';

// =======================================================
// ==        REPORT TOP PRODOTTI DETTAGLIATO            ==
// =======================================================

/// Pagina di report dettagliato sui prodotti più venduti
class TopProductsReportPage extends StatefulWidget {
  final PeriodoReport periodo;

  const TopProductsReportPage({super.key, required this.periodo});

  @override
  State<TopProductsReportPage> createState() => _TopProductsReportPageState();
}

class _TopProductsReportPageState extends State<TopProductsReportPage> {
  final ReportService _reportService = ReportService();
  ReportVenditeDettagliato? _reportVendite;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService.getReportVendite(
        periodo: widget.periodo,
      );

      if (mounted) {
        setState(() {
          _reportVendite = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('❌ Errore caricamento report top prodotti', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dashboardTopProdotti),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.dashboardCaricamentoReport),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_reportVendite == null || _reportVendite!.topProdotti.isEmpty) {
      return Center(child: Text(context.l10n.dashboardNessunDato));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con periodo
            _buildPeriodHeader(),
            const SizedBox(height: 24),

            // Grafico top prodotti
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                child: TopProductsBarChart(
                  topProducts: _reportVendite!.topProdotti,
                  maxItems: 10,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Lista dettagliata prodotti
            _buildProductsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodoReportLabel(context.l10n, widget.periodo),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${ReportFormatter.formatDateFull(widget.periodo.dataInizio)} - ${ReportFormatter.formatDateFull(widget.periodo.dataFine)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            'Dettaglio Prodotti',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ..._reportVendite!.topProdotti.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return _buildProductCard(product, index + 1);
        }),
      ],
    );
  }

  Widget _buildProductCard(TopProdotto product, int position) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Posizione
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getPositionColor(position),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '#$position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info prodotto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.titolo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildProductMetric(
                        Icons.shopping_cart,
                        '${product.quantitaVenduta} unità',
                        ReportColors.info,
                      ),
                      const SizedBox(width: 16),
                      _buildProductMetric(
                        Icons.attach_money,
                        ReportFormatter.formatCurrency(product.prezzoMedio),
                        ReportColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Totale vendite
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Totale',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  ReportFormatter.formatCurrency(product.totaleVendite),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(ReportColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductMetric(IconData icon, String value, int colorValue) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Color(colorValue)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getPositionColor(int position) {
    if (position == 1) return const Color(0xFFFFD700); // Oro
    if (position == 2) return const Color(0xFFC0C0C0); // Argento
    if (position == 3) return const Color(0xFFCD7F32); // Bronzo
    return Color(ReportColors.primary);
  }
}

// =======================================================
// ==      REPORT PERFORMANCE TEMPORALE                 ==
// =======================================================

/// Pagina di analisi delle performance nel tempo
class PerformanceTimelineReportPage extends StatefulWidget {
  final PeriodoReport periodo;

  const PerformanceTimelineReportPage({super.key, required this.periodo});

  @override
  State<PerformanceTimelineReportPage> createState() =>
      _PerformanceTimelineReportPageState();
}

class _PerformanceTimelineReportPageState
    extends State<PerformanceTimelineReportPage> {
  final ReportService _reportService = ReportService();
  ReportVenditeDettagliato? _reportVendite;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService.getReportVendite(
        periodo: widget.periodo,
      );

      if (mounted) {
        setState(() {
          _reportVendite = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('❌ Errore caricamento report performance', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dashboardPerformanceTemporale),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.dashboardCaricamentoReport),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_reportVendite == null) {
      return Center(child: Text(context.l10n.dashboardNessunDato));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // Grafico vendite nel tempo
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                child: SalesLineChart(
                  vendite: _reportVendite!.vendite.andamentoGiornaliero,
                  title: context.l10n.dashboardAndamentoVendite,
                  lineColor: Color(ReportColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Grafico ordini nel tempo
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                child: OrdersBarChart(
                  vendite: _reportVendite!.vendite.andamentoGiornaliero,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistiche dettagliate
            _buildDetailedStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final vendite = _reportVendite!.vendite;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Totale Vendite',
            ReportFormatter.formatCurrency(vendite.totaleVendite),
            Icons.euro,
            ReportColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Totale Ordini',
            vendite.numeroOrdini.toString(),
            Icons.shopping_cart,
            ReportColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Ticket Medio',
            ReportFormatter.formatCurrency(vendite.ticketMedio),
            Icons.receipt,
            ReportColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    int colorValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(colorValue).withValues(alpha: 0.1),
            Color(colorValue).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(colorValue).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Color(colorValue), size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(colorValue),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    final vendite = _reportVendite!.vendite.andamentoGiornaliero;
    if (vendite.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcola statistiche
    final totaleVendite = vendite.fold<double>(0, (sum, v) => sum + v.totale);
    final totaleOrdini = vendite.fold<int>(0, (sum, v) => sum + v.ordini);
    final mediaGiornaliera = totaleVendite / vendite.length;
    final giornoMigliore = vendite.reduce(
      (a, b) => a.totale > b.totale ? a : b,
    );
    final giornoPeggiore = vendite.reduce(
      (a, b) => a.totale < b.totale ? a : b,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiche Dettagliate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Media Giornaliera',
              ReportFormatter.formatCurrency(mediaGiornaliera),
            ),
            const Divider(),
            _buildStatRow(
              'Giorno Migliore',
              '${ReportFormatter.formatDateFull(giornoMigliore.data)} - ${ReportFormatter.formatCurrency(giornoMigliore.totale)}',
            ),
            const Divider(),
            _buildStatRow(
              'Giorno Peggiore',
              '${ReportFormatter.formatDateFull(giornoPeggiore.data)} - ${ReportFormatter.formatCurrency(giornoPeggiore.totale)}',
            ),
            const Divider(),
            _buildStatRow(
              'Media Ordini/Giorno',
              (totaleOrdini / vendite.length).toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// ==         REPORT ORDINI DETTAGLIATO                 ==
// =======================================================

/// Pagina di analisi dettagliata degli ordini
class OrdersDetailedReportPage extends StatefulWidget {
  const OrdersDetailedReportPage({super.key});

  @override
  State<OrdersDetailedReportPage> createState() =>
      _OrdersDetailedReportPageState();
}

class _OrdersDetailedReportPageState extends State<OrdersDetailedReportPage> {
  final ReportService _reportService = ReportService();
  Map<String, int>? _ordersByStatus;
  Map<String, int>? _reviewStats;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _reportService.getOrdiniPerStato(),
        _reportService.getStatisticheRecensioni(),
      ]);

      if (mounted) {
        setState(() {
          _ordersByStatus = results[0];
          _reviewStats = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('❌ Errore caricamento report ordini', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dashboardAnalisiOrdini),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.dashboardCaricamentoReport),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_ordersByStatus == null) {
      return Center(child: Text(context.l10n.dashboardNessunDato));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grafico distribuzione ordini
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                child: OrderStatusPieChart(ordersByStatus: _ordersByStatus!),
              ),
            ),
            const SizedBox(height: 24),

            // Statistiche recensioni (se disponibili)
            if (_reviewStats != null && _reviewStats!.isNotEmpty) ...[
              _buildReviewStats(),
              const SizedBox(height: 24),
            ],

            // Lista dettagliata ordini per stato
            _buildOrdersStatusList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStats() {
    final totalReviews = _reviewStats!.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalReviews == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recensioni Prodotti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._reviewStats!.entries.map((entry) {
              final stars = int.tryParse(entry.key) ?? 0;
              final count = entry.value;
              final percentage = (count / totalReviews) * 100;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < stars ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(ReportColors.warning),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$count (${percentage.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersStatusList() {
    final totalOrders = _ordersByStatus!.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dettaglio Stati Ordini',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Totale: $totalOrders',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._ordersByStatus!.entries.map((entry) {
              return _buildOrderStatusItem(entry.key, entry.value, totalOrders);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusItem(String status, int count, int total) {
    final percentage = (count / total) * 100;
    final statusLabel = _getStatusLabel(status);
    final color = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    const labels = {
      'pending': 'In Attesa',
      'processing': 'In Elaborazione',
      'completed': 'Completati',
      'on-hold': 'In Sospeso',
      'cancelled': 'Annullati',
      'refunded': 'Rimborsati',
      'failed': 'Falliti',
    };
    return labels[status] ?? status;
  }

  Color _getStatusColor(String status) {
    const colors = {
      'pending': 0xFFFF9800,
      'processing': 0xFF00BCD4,
      'completed': 0xFF4CAF50,
      'on-hold': 0xFFFFEB3B,
      'cancelled': 0xFFF44336,
      'refunded': 0xFF9C27B0,
      'failed': 0xFF795548,
    };
    return Color(colors[status] ?? ReportColors.primary);
  }
}
