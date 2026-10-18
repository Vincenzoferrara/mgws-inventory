// Dashboard GUI - Interfaccia Utente per Dashboard
//
// Dashboard e visualizzazione statistiche WooCommerce
// Mostra vendite, prodotti, ordini e statistiche

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.code.dart';
import 'dashboard_charts.dart';
import '../theme/theme.dart';
import 'dashboard_detailed.dart';
import 'dashboard_customization.dart';
import 'dashboard_report_export.dart';
import 'dashboard_report_panel.gui.dart';
import 'ads_dashboard.code.dart';
import '../log_viewer/app_logger.dart';
import '../login/gui/login.code.dart';
import '../notification/notification_service.dart';
import '../traduzioni/estensioni.dart';

/// Pagina principale della dashboard con statistiche
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.reportGateway, this.exportGateway});

  final DashboardReportGateway? reportGateway;
  final DashboardExportGateway? exportGateway;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardReportGateway _reportService;
  late final DashboardExportGateway _exportGateway;
  final AdsPlatformService _adsService = AdsPlatformService();

  DashboardData? _dashboard;
  AdsPlatformData? _adsData;
  PeriodoReport _periodo = PeriodoReport.mese();
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Verifica se l'utente è autenticato
  bool get _isAuthenticated => loginCode.isConnected;

  @override
  void initState() {
    super.initState();
    _reportService = widget.reportGateway ?? ReportService();
    _exportGateway = widget.exportGateway ?? ReportExporter();
    // Carica i dati solo se autenticato
    if (_isAuthenticated) {
      _loadDashboard();
      _initializeAdsService();
    }
  }

  Future<void> _initializeAdsService() async {
    try {
      await _adsService.initialize();
      // Carica dati ads se disponibili
      if (_adsService.isConnected("meta") ||
          _adsService.isConnected("google") ||
          _adsService.isConnected("tiktok")) {
        _loadAdsData();
      }
    } catch (e) {
      log.w('⚠️ Ads service non disponibile: $e');
    }
  }

  Future<void> _loadAdsData() async {
    try {
      // Carica gli Account IDs salvati
      final prefs = await SharedPreferences.getInstance();
      final metaAdAccountId = prefs.getString('ads_meta_account_id');
      final googleCustomerId = prefs.getString('ads_google_customer_id');
      final tiktokAdvertiserId = prefs.getString('ads_tiktok_advertiser_id');
      final instagramUserId = prefs.getString('ads_instagram_user_id');

      final data = await _adsService.fetchAllData(
        metaAdAccountId: metaAdAccountId?.isEmpty == true
            ? null
            : metaAdAccountId,
        googleCustomerId: googleCustomerId?.isEmpty == true
            ? null
            : googleCustomerId,
        tiktokAdvertiserId: tiktokAdvertiserId?.isEmpty == true
            ? null
            : tiktokAdvertiserId,
        instagramUserId: instagramUserId?.isEmpty == true
            ? null
            : instagramUserId,
      );
      if (mounted) {
        setState(() => _adsData = data);
      }
    } catch (e) {
      log.w('⚠️ Errore caricamento dati ads: $e');
    }
  }

  @override
  void dispose() {
    _adsService.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    // Verifica autenticazione prima di caricare
    if (!_isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dashboard = await _reportService.getDashboard(
        periodo: _periodo,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('❌ Errore caricamento dashboard', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _changePeriod(PeriodoReport newPeriod) {
    setState(() {
      _periodo = newPeriod;
    });
    _loadDashboard(forceRefresh: true);
  }

  Future<void> _generateReport() async {
    final dashboard = _dashboard;
    if (_isExporting || dashboard == null) {
      return;
    }

    final choice = await showDialog<DashboardExportChoice>(
      context: context,
      builder: (context) => ExportDialog(dashboardData: dashboard),
    );
    if (choice == null || !mounted) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      final file = await _exportReport(choice, dashboard);
      await _exportGateway.shareFile(file, subject: choice.shareSubject);
      if (!mounted) {
        return;
      }
      NotificationService.instance.messageBar(
        'successo',
        'dashboard',
        'Report generato: ${file.path}',
      );
    } catch (e) {
      log.e('❌ Errore generazione report dashboard', e);
      if (!mounted) {
        return;
      }
      NotificationService.instance.messageBar(
        'errore',
        'dashboard',
        'Export non riuscito: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<File> _exportReport(
    DashboardExportChoice choice,
    DashboardData dashboard,
  ) async {
    switch (choice.scope) {
      case DashboardExportScope.dashboard:
        return switch (choice.format) {
          DashboardExportFormat.csv => _exportGateway.exportDashboardToCsv(
            dashboard,
            context.l10n,
          ),
          DashboardExportFormat.pdf => _exportGateway.exportDashboardToPdf(
            dashboard,
            context.l10n,
          ),
        };
      case DashboardExportScope.vendite:
        final salesReport = await _reportService.getReportVendite(
          periodo: _periodo,
        );
        return switch (choice.format) {
          DashboardExportFormat.csv => _exportGateway.exportVenditeToCsv(
            salesReport,
            context.l10n,
          ),
          DashboardExportFormat.pdf => _exportGateway.exportVenditeToPdf(
            salesReport,
            context.l10n,
          ),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsante personalizzazione
          FloatingActionButton.small(
            heroTag: 'customize',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomizableDashboardPage(),
                ),
              );
            },
            child: const Icon(Icons.dashboard_customize),
          ),
          const SizedBox(height: 8),
          // Pulsante refresh
          FloatingActionButton.small(
            heroTag: 'refresh',
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () => _loadDashboard(forceRefresh: true),
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          // Pulsante periodo
          PopupMenuButton<PeriodoReport>(
            onSelected: _changePeriod,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: PeriodoReport.oggi(),
                child: Text(context.l10n.dashboardOggi),
              ),
              PopupMenuItem(
                value: PeriodoReport.settimana(),
                child: Text(context.l10n.dashboardQuestaSettimana),
              ),
              PopupMenuItem(
                value: PeriodoReport.mese(),
                child: Text(context.l10n.dashboardQuestoMese),
              ),
              PopupMenuItem(
                value: PeriodoReport.anno(),
                child: Text(context.l10n.dashboardQuestAnno),
              ),
            ],
            child: FloatingActionButton.small(
              heroTag: 'period',
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: null,
              child: const Icon(Icons.date_range),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Se non autenticato, mostra messaggio di login
    if (!_isAuthenticated) {
      return _buildLoginRequired();
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.dashboardCaricamento),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colors.errorColorStatus,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: context.colors.errorColorStatus),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_dashboard == null) {
      return Center(child: Text(context.l10n.dashboardNessunDato));
    }

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(forceRefresh: true),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con periodo
            _buildPeriodHeader(),
            const SizedBox(height: 24),

            // Card vendite
            _buildVenditeCard(),
            const SizedBox(height: 16),

            // Row con prodotti e ordini
            Row(
              children: [
                Expanded(child: _buildProdottiCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildOrdiniCard()),
              ],
            ),
            const SizedBox(height: 16),

            // Card clienti (se disponibile)
            if (_dashboard!.clienti != null) ...[
              _buildClientiCard(),
              const SizedBox(height: 16),
            ],

            // Card Ads Platform (se connesse)
            if (_adsService.isConnected("meta") ||
                _adsService.isConnected("google") ||
                _adsService.isConnected("tiktok")) ...[
              _buildAdsPlatformCard(),
              const SizedBox(height: 16),
            ],

            // Grafico andamento vendite (se disponibile)
            if (_dashboard!.vendite.andamentoGiornaliero.isNotEmpty) ...[
              _buildAndamentoVenditeCard(),
              const SizedBox(height: 16),
            ],

            DashboardReportPanel(
              dashboardData: _dashboard!,
              filter: DashboardAnalysisFilter(periodo: _periodo),
              availableCapabilities:
                  DashboardAnalysisCapabilities.current.available,
              missingCapabilities:
                  DashboardAnalysisCapabilities.current.missing,
              onGenerateReport: _generateReport,
              isExporting: _isExporting,
            ),
            const SizedBox(height: 16),

            // Quick access ai report dettagliati
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                'Report Dettagliati',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            _buildQuickAccessReports(),
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
                  periodoReportLabel(context.l10n, _periodo),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${ReportFormatter.formatDateFull(_periodo.dataInizio)} - ${ReportFormatter.formatDateFull(_periodo.dataFine)}',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.subtitleColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${_periodo.giorniTotali} giorni',
              style: context.text.titleSmall?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenditeCard() {
    final vendite = _dashboard!.vendite;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(ReportColors.primary).withValues(alpha: 0.15),
            Color(ReportColors.primary).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(ReportColors.primary).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(ReportColors.primary),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(
                            ReportColors.primary,
                          ).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.euro,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Vendite',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Totale vendite
              Text(
                ReportFormatter.formatCurrency(vendite.totaleVendite),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(ReportColors.primary),
                  shadows: [
                    Shadow(
                      color: Color(ReportColors.primary).withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info aggiuntive con design migliorato
              Row(
                children: [
                  Expanded(
                    child: _buildEnhancedMetric(
                      'Ordini',
                      vendite.numeroOrdini.toString(),
                      Icons.shopping_cart,
                      ReportColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEnhancedMetric(
                      'Ticket Medio',
                      ReportFormatter.formatCurrency(vendite.ticketMedio),
                      Icons.receipt,
                      ReportColors.success,
                    ),
                  ),
                ],
              ),

              // Variazione (se disponibile)
              if (vendite.variazionePrecedente != 0.0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (vendite.isInCrescita
                                ? Color(ReportColors.success)
                                : Color(ReportColors.danger))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (vendite.isInCrescita
                                  ? Color(ReportColors.success)
                                  : Color(ReportColors.danger))
                              .withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        vendite.isInCrescita
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: vendite.isInCrescita
                            ? Color(ReportColors.success)
                            : Color(ReportColors.danger),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        vendite.variazioneFormatted,
                        style: TextStyle(
                          color: vendite.isInCrescita
                              ? Color(ReportColors.success)
                              : Color(ReportColors.danger),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'vs periodo precedente',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.subtitleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProdottiCard() {
    final prodotti = _dashboard!.prodotti;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Color(ReportColors.info)),
                const SizedBox(width: 8),
                const Text(
                  'Prodotti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildMetric(
              'Totale',
              prodotti.totaleProdotti.toString(),
              Icons.apps,
            ),
            const SizedBox(height: 8),
            _buildMetric(
              'In Stock',
              prodotti.prodottiInStock.toString(),
              Icons.check_circle,
              color: ReportColors.success,
            ),
            const SizedBox(height: 8),
            _buildMetric(
              'Esauriti',
              prodotti.prodottiOutOfStock.toString(),
              Icons.warning,
              color: ReportColors.danger,
            ),

            if (prodotti.hasAllarmeStock) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(ReportColors.warning).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Color(ReportColors.warning),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Attenzione allo stock!',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdiniCard() {
    final ordini = _dashboard!.ordini;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Color(ReportColors.success)),
                const SizedBox(width: 8),
                const Text(
                  'Ordini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildMetric(
              'Totale',
              ordini.totaleOrdini.toString(),
              Icons.shopping_bag,
            ),
            const SizedBox(height: 8),
            _buildMetric(
              'Completati',
              ordini.ordiniCompletati.toString(),
              Icons.check,
              color: ReportColors.success,
            ),
            const SizedBox(height: 8),
            _buildMetric(
              'In elaborazione',
              ordini.ordiniInElaborazione.toString(),
              Icons.hourglass_empty,
              color: ReportColors.info,
            ),

            if (ordini.ordiniDaGestire > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(ReportColors.info).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Color(ReportColors.info), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ordini.ordiniDaGestire} ordini da gestire',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientiCard() {
    final clienti = _dashboard!.clienti!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Color(ReportColors.primary)),
                const SizedBox(width: 8),
                const Text(
                  'Clienti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Totale',
                    clienti.totaleClienti.toString(),
                    Icons.person,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Nuovi',
                    clienti.nuoviClienti.toString(),
                    Icons.person_add,
                    color: ReportColors.success,
                  ),
                ),
                Expanded(
                  child: _buildMetric(
                    'Attivi',
                    clienti.clientiAttivi.toString(),
                    Icons.person_outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndamentoVenditeCard() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        child: SalesLineChart(
          vendite: _dashboard!.vendite.andamentoGiornaliero,
          title: context.l10n.dashboardAndamentoVendite,
          lineColor: Color(ReportColors.primary),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, {int? color}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color != null ? Color(color) : context.colors.subtitleColor,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.subtitleColor,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedMetric(
    String label,
    String value,
    IconData icon,
    int colorValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(colorValue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Color(colorValue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessReports() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildReportAccessCard(
                'Top Prodotti',
                'Analizza i prodotti più venduti',
                Icons.star,
                ReportColors.warning,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TopProductsReportPage(periodo: _periodo),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReportAccessCard(
                'Performance',
                'Analisi temporale vendite',
                Icons.trending_up,
                ReportColors.success,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PerformanceTimelineReportPage(periodo: _periodo),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildReportAccessCard(
                'Analisi Ordini',
                'Distribuzione e statistiche',
                Icons.assessment,
                ReportColors.info,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrdersDetailedReportPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReportAccessCard(
                'Export Report',
                'Esporta dati in CSV/PDF',
                Icons.file_download,
                ReportColors.primary,
                _generateReport,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportAccessCard(
    String title,
    String subtitle,
    IconData icon,
    int colorValue,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          border: Border.all(
            color: Color(colorValue).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(colorValue).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(colorValue),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Color(colorValue).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(colorValue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.subtitleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsPlatformCard() {
    final metrics = _adsData?.getAggregateMetrics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con controlli
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.infoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.ads_click,
                    color: context.colors.infoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Piattaforme Pubblicitarie',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Meta, Google, TikTok Ads',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pulsante refresh
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadAdsData,
                  tooltip: context.l10n.dashboardRicaricaDatiAds,
                ),
                // Auto-refresh toggle
                IconButton(
                  icon: Icon(
                    _adsService.isSchedulerRunning
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 20,
                  ),
                  onPressed: _toggleAdsAutoRefresh,
                  tooltip: _adsService.isSchedulerRunning
                      ? 'Disattiva auto-refresh'
                      : 'Attiva auto-refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stato connessioni
            Row(
              children: [
                _buildPlatformBadge(
                  'Meta',
                  _adsService.isConnected("meta"),
                  context.colors.infoColor,
                ),
                const SizedBox(width: 8),
                _buildPlatformBadge(
                  'Google',
                  _adsService.isConnected("google"),
                  context.colors.errorColorStatus,
                ),
                const SizedBox(width: 8),
                _buildPlatformBadge(
                  'TikTok',
                  _adsService.isConnected("tiktok"),
                  context.colors.neutralColor,
                ),
              ],
            ),

            // Metriche aggregate (se disponibili)
            if (metrics != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Metriche Aggregate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.subtitleColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAdMetricCard(
                    'Spesa Totale',
                    '€${metrics.totalSpend.toStringAsFixed(2)}',
                    Icons.euro,
                    context.colors.errorColorStatus,
                  ),
                  _buildAdMetricCard(
                    'Impressioni',
                    '${metrics.totalImpressions}',
                    Icons.visibility,
                    context.colors.infoColor,
                  ),
                  _buildAdMetricCard(
                    'Click',
                    '${metrics.totalClicks}',
                    Icons.touch_app,
                    context.colors.successColor,
                  ),
                  _buildAdMetricCard(
                    'Conversioni',
                    '${metrics.totalConversions}',
                    Icons.shopping_cart,
                    context.colors.warningColor,
                  ),
                  _buildAdMetricCard(
                    'CTR',
                    '${metrics.ctr.toStringAsFixed(2)}%',
                    Icons.percent,
                    context.colors.infoColor,
                  ),
                  _buildAdMetricCard(
                    'CPC',
                    '€${metrics.cpc.toStringAsFixed(2)}',
                    Icons.monetization_on,
                    context.colors.successColor,
                  ),
                ],
              ),
            ],

            // Dettagli per piattaforma
            if (_adsData != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Meta Ads
              if (_adsService.isConnected("meta")) ...[
                _buildPlatformDetailsSection(
                  'Meta Ads',
                  Icons.facebook,
                  context.colors.infoColor,
                  [
                    if (_adsData!.metaCampaigns != null)
                      'Campagne: ${_adsData!.metaCampaigns['data']?.length ?? 0}',
                    if (_adsData!.instagramMedia != null)
                      'Instagram Media: ${_adsData!.instagramMedia['data']?.length ?? 0}',
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Google Ads
              if (_adsService.isConnected("google")) ...[
                _buildPlatformDetailsSection(
                  'Google Ads',
                  Icons.g_mobiledata,
                  context.colors.errorColorStatus,
                  ['Dati disponibili'],
                ),
                const SizedBox(height: 12),
              ],

              // TikTok Ads
              if (_adsService.isConnected("tiktok")) ...[
                _buildPlatformDetailsSection(
                  'TikTok Ads',
                  Icons.tiktok_outlined,
                  context.colors.neutralColor,
                  [
                    if (_adsData!.tiktokCampaigns != null)
                      'Campagne: ${_adsData!.tiktokCampaigns['data']?.length ?? 0}',
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _toggleAdsAutoRefresh() {
    if (_adsService.isSchedulerRunning) {
      _adsService.stopAutoRefresh();
      NotificationService.instance.messageBar(
        'info',
        'dashboard',
        'Auto-refresh ads disattivato',
      );
    } else {
      _adsService.startAutoRefresh(interval: const Duration(minutes: 5));
      NotificationService.instance.messageBar(
        'successo',
        'dashboard',
        'Auto-refresh ads attivato (ogni 5 min)',
      );
    }
    setState(() {});
  }

  Widget _buildPlatformDetailsSection(
    String name,
    IconData icon,
    Color color,
    List<String> details,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  detail,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.subtitleColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.subtitleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(String name, bool isConnected, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? color.withValues(alpha: 0.1)
            : context.colors.neutralColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? color : context.colors.neutralColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: isConnected ? color : context.colors.neutralColor,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              color: isConnected ? color : context.colors.neutralColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Per visualizzare i dati devi fare il login',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'La dashboard contiene informazioni riservate che richiedono l\'autenticazione',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.subtitleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Naviga alla pagina di login o mostra dialog
                  Navigator.of(context).pushNamed('/login');
                },
                icon: const Icon(Icons.login),
                label: Text(context.l10n.loginAccedi),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
