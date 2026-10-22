// Report Code - Business Logic & Models
//
// Sistema di report per WooCommerce
// Gestisce la logica di business, modelli dati e coordinamento con WooQueryReport
//
// Struttura:
// - Modelli dati (Dashboard, Report vendite, Statistiche)
// - ReportService (coordinatore principale)
// - Helper per calcoli e formattazione

import 'package:intl/intl.dart';

import '../login/jwt_api/query_woocommerce/woo_query_report.dart';
import 'class_report.dart';
import '../log_viewer/app_logger.dart';
import '../l10n/extensions.dart';

/// Eccezione personalizzata per errori report
class ReportException implements Exception {
  final String message;
  final ReportErrorType type;
  final dynamic originalError;

  ReportException(this.message, this.type, [this.originalError]);

  @override
  String toString() => message;

  /// Messaggio utente-friendly
  String get userMessage {
    switch (type) {
      case ReportErrorType.network:
        return 'Errore di connessione. Verifica la tua connessione internet.';
      case ReportErrorType.authentication:
        return 'Sessione scaduta. Effettua nuovamente il login.';
      case ReportErrorType.serverError:
        return 'Il server non è disponibile. Riprova più tardi.';
      case ReportErrorType.timeout:
        return 'La richiesta ha impiegato troppo tempo. Riprova.';
      case ReportErrorType.noData:
        return 'Nessun dato disponibile per il periodo selezionato.';
      case ReportErrorType.unknown:
        return 'Si è verificato un errore imprevisto. Riprova.';
    }
  }
}

/// Tipi di errore per i report
enum ReportErrorType {
  network,
  authentication,
  serverError,
  timeout,
  noData,
  unknown,
}

// =======================================================
// ==                MODELLI DATI REPORT                ==
// =======================================================

/// Dashboard summary - Vista principale dei report
class DashboardData {
  final PeriodoReport periodo;
  final VenditeData vendite;
  final ProdottiData prodotti;
  final OrdiniData ordini;
  final ClientiData? clienti;
  final DateTime ultimoAggiornamento;

  DashboardData({
    required this.periodo,
    required this.vendite,
    required this.prodotti,
    required this.ordini,
    this.clienti,
    DateTime? ultimoAggiornamento,
  }) : ultimoAggiornamento = ultimoAggiornamento ?? DateTime.now();

  /// Verifica se i dati sono obsoleti (> 5 minuti)
  bool get isObsoleto {
    final diff = DateTime.now().difference(ultimoAggiornamento);
    return diff.inMinutes > 5;
  }
}

/// Periodo del report
class PeriodoReport {
  final DateTime dataInizio;
  final DateTime dataFine;
  final TipoPeriodo tipo;

  PeriodoReport({
    required this.dataInizio,
    required this.dataFine,
    this.tipo = TipoPeriodo.custom,
  });

  /// Factory per periodi predefiniti
  factory PeriodoReport.oggi() {
    final oggi = DateTime.now();
    final inizio = DateTime(oggi.year, oggi.month, oggi.day);
    return PeriodoReport(
      dataInizio: inizio,
      dataFine: oggi,
      tipo: TipoPeriodo.oggi,
    );
  }

  factory PeriodoReport.settimana() {
    final oggi = DateTime.now();
    final inizioSettimana = oggi.subtract(Duration(days: oggi.weekday - 1));
    return PeriodoReport(
      dataInizio: DateTime(
        inizioSettimana.year,
        inizioSettimana.month,
        inizioSettimana.day,
      ),
      dataFine: oggi,
      tipo: TipoPeriodo.settimana,
    );
  }

  factory PeriodoReport.mese() {
    final oggi = DateTime.now();
    return PeriodoReport(
      dataInizio: DateTime(oggi.year, oggi.month, 1),
      dataFine: oggi,
      tipo: TipoPeriodo.mese,
    );
  }

  factory PeriodoReport.anno() {
    final oggi = DateTime.now();
    return PeriodoReport(
      dataInizio: DateTime(oggi.year, 1, 1),
      dataFine: oggi,
      tipo: TipoPeriodo.anno,
    );
  }

  /// Numero di giorni di calendario nel periodo (estremi inclusi).
  int get giorniTotali =>
      DateTime(dataFine.year, dataFine.month, dataFine.day)
          .difference(
            DateTime(dataInizio.year, dataInizio.month, dataInizio.day),
          )
          .inDays +
      1;

  /// Stesso tratto del periodo precedente, per un confronto alla pari:
  /// oggi -> ieri, settimana -> stessi giorni della settimana scorsa,
  /// mese -> stessi giorni del mese scorso, anno -> stessi giorni dell'anno
  /// scorso. Un periodo custom si confronta con i giorni immediatamente prima.
  PeriodoReport get periodoPrecedente {
    DateTime giorno(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime clampMese(int anno, int mese, int giorno) {
      final ultimo = DateTime(anno, mese + 1, 0).day;
      return DateTime(anno, mese, giorno > ultimo ? ultimo : giorno);
    }

    final inizio = giorno(dataInizio);
    final fine = giorno(dataFine);
    switch (tipo) {
      case TipoPeriodo.oggi:
      case TipoPeriodo.settimana:
        final giorni = tipo == TipoPeriodo.oggi ? 1 : 7;
        return PeriodoReport(
          dataInizio: inizio.subtract(Duration(days: giorni)),
          dataFine: fine.subtract(Duration(days: giorni)),
        );
      case TipoPeriodo.mese:
        return PeriodoReport(
          dataInizio: DateTime(inizio.year, inizio.month - 1, 1),
          dataFine: clampMese(fine.year, fine.month - 1, fine.day),
        );
      case TipoPeriodo.anno:
        return PeriodoReport(
          dataInizio: DateTime(inizio.year - 1, 1, 1),
          dataFine: clampMese(fine.year - 1, fine.month, fine.day),
        );
      case TipoPeriodo.custom:
        return PeriodoReport(
          dataInizio: inizio.subtract(Duration(days: giorniTotali)),
          dataFine: inizio.subtract(const Duration(days: 1)),
        );
    }
  }
}

/// Etichetta tradotta del periodo.
///
/// Non puo' stare nella classe: la traduzione richiede le localizzazioni,
/// che la classe non puo' raggiungere da sola.
String periodoReportLabel(AppLocalizations l10n, PeriodoReport periodo) =>
    switch (periodo.tipo) {
      TipoPeriodo.oggi => l10n.dashboardPeriodoOggi,
      TipoPeriodo.settimana => l10n.dashboardPeriodoSettimana,
      TipoPeriodo.mese => l10n.dashboardPeriodoMese,
      TipoPeriodo.anno => l10n.dashboardPeriodoAnno,
      TipoPeriodo.custom => l10n.dashboardPeriodoCustom,
    };

enum TipoPeriodo { oggi, settimana, mese, anno, custom }

/// Filtro analisi dashboard basato solo sul periodo
class DashboardAnalysisFilter {
  final PeriodoReport periodo;

  const DashboardAnalysisFilter({required this.periodo});

  String get summaryText {
    return 'Analisi attiva per periodo: ${periodo.tipo.name} '
        '(${_formatDate(periodo.dataInizio)} - ${_formatDate(periodo.dataFine)})';
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Metadati delle capacita di analisi dashboard disponibili e mancanti
class DashboardAnalysisCapabilities {
  final List<String> available;
  final List<String> missing;

  const DashboardAnalysisCapabilities({
    required this.available,
    required this.missing,
  });

  bool get hasMissing => missing.isNotEmpty;

  String get availableSummary => available.join(', ');

  String get missingSummary => missing.join(', ');

  static const DashboardAnalysisCapabilities current =
      DashboardAnalysisCapabilities(
        available: [
          'Vendite',
          'Ordini',
          'Prodotti e stock',
          'Clienti',
          'Conteggi per categoria',
          'Trend vendite',
          'Top prodotti',
          'Export PDF/CSV',
        ],
        missing: [
          'Vendite per brand',
          'Vendite per varianti',
          'Vendite per attributi',
          'Filtri avanzati di analisi',
        ],
      );
}

/// Dati vendite per dashboard
class VenditeData {
  final double totaleVendite;
  final int numeroOrdini;
  final double ticketMedio;
  final double
  variazionePrecedente; // Percentuale rispetto al periodo precedente
  final List<VenditaGiornaliera> andamentoGiornaliero;

  /// true quando WooCommerce ha raggruppato l'andamento per mese
  /// (succede con intervalli lunghi, es. "Quest'anno").
  final bool andamentoMensile;

  /// Valori del periodo di confronto; null se non disponibili.
  final PeriodoReport? periodoPrecedente;
  final double? totalePrecedente;
  final int? ordiniPrecedenti;

  VenditeData({
    required this.totaleVendite,
    required this.numeroOrdini,
    required this.ticketMedio,
    this.variazionePrecedente = 0.0,
    this.andamentoGiornaliero = const [],
    this.andamentoMensile = false,
    this.periodoPrecedente,
    this.totalePrecedente,
    this.ordiniPrecedenti,
  });

  /// Il confronto ha senso solo se il periodo precedente ha venduto qualcosa.
  bool get haConfronto => (totalePrecedente ?? 0) > 0;

  double? get ticketMedioPrecedente {
    final ordini = ordiniPrecedenti ?? 0;
    return ordini > 0 ? totalePrecedente! / ordini : null;
  }

  bool get isInCrescita => variazionePrecedente > 0;
  bool get isInCalo => variazionePrecedente < 0;
  bool get isStabile => variazionePrecedente == 0.0;

  String get variazioneFormatted {
    if (variazionePrecedente == 0) return '0%';
    final segno = variazionePrecedente > 0 ? '+' : '';
    return '$segno${variazionePrecedente.toStringAsFixed(1)}%';
  }
}

/// Dati prodotti per dashboard
class ProdottiData {
  final int totaleProdotti;
  final int prodottiInStock;
  final int prodottiOutOfStock;
  final int prodottiPerEsaurimento; // Stock < 5
  final double valoreInventario;
  final Map<String, int>? prodottiPerCategoria;
  final List<Map<String, dynamic>>?
  prodottiStockBasso; // Lista prodotti con stock basso

  ProdottiData({
    required this.totaleProdotti,
    required this.prodottiInStock,
    required this.prodottiOutOfStock,
    this.prodottiPerEsaurimento = 0,
    this.valoreInventario = 0.0,
    this.prodottiPerCategoria,
    this.prodottiStockBasso,
  });

  double get percentualeInStock =>
      totaleProdotti > 0 ? (prodottiInStock / totaleProdotti) * 100 : 0;

  double get percentualeOutOfStock =>
      totaleProdotti > 0 ? (prodottiOutOfStock / totaleProdotti) * 100 : 0;

  bool get hasAllarmeStock =>
      prodottiOutOfStock > 0 || prodottiPerEsaurimento > 0;
}

/// Dati ordini per dashboard
class OrdiniData {
  /// Ordini creati nel periodo selezionato, per stato.
  final Map<String, int> ordiniPerStato;

  /// Ordini di sempre per stato: serve a sapere cosa resta da evadere oggi,
  /// indipendentemente da quando l'ordine e' arrivato.
  final Map<String, int> ordiniDiSempre;
  final int totaleOrdini;
  final int ordiniCompletati;
  final int ordiniInElaborazione;
  final int ordiniInAttesa;

  OrdiniData({required this.ordiniPerStato, Map<String, int>? ordiniDiSempre})
    : ordiniDiSempre = ordiniDiSempre ?? ordiniPerStato,
      totaleOrdini = ordiniPerStato.values.fold(0, (sum, count) => sum + count),
      ordiniCompletati = ordiniPerStato['completed'] ?? 0,
      ordiniInElaborazione = ordiniPerStato['processing'] ?? 0,
      ordiniInAttesa = ordiniPerStato['pending'] ?? 0;

  double get tassoCompletamento =>
      totaleOrdini > 0 ? (ordiniCompletati / totaleOrdini) * 100 : 0;

  /// Ordini ancora da evadere adesso: in lavorazione + in sospeso.
  /// I "pending" (pagamento non ricevuto) non richiedono azione del negozio.
  int get ordiniDaGestire =>
      (ordiniDiSempre['processing'] ?? 0) + (ordiniDiSempre['on-hold'] ?? 0);

  int get ordiniInAttesaPagamento => ordiniDiSempre['pending'] ?? 0;
}

/// Dati clienti per dashboard
class ClientiData {
  final int totaleClienti;
  final int nuoviClienti;
  final int clientiAttivi; // Con almeno un ordine
  final double valoreMedioCliente;

  ClientiData({
    required this.totaleClienti,
    required this.nuoviClienti,
    required this.clientiAttivi,
    this.valoreMedioCliente = 0.0,
  });

  double get percentualeClientiAttivi =>
      totaleClienti > 0 ? (clientiAttivi / totaleClienti) * 100 : 0;
}

/// Prodotto più venduto
class TopProdotto {
  final int productId;
  final String titolo;
  final int quantitaVenduta;
  final double totaleVendite;
  final String? immagineUrl;

  TopProdotto({
    required this.productId,
    required this.titolo,
    required this.quantitaVenduta,
    required this.totaleVendite,
    this.immagineUrl,
  });

  double get prezzoMedio =>
      quantitaVenduta > 0 ? totaleVendite / quantitaVenduta : 0.0;
}

/// Report vendite dettagliato
class ReportVenditeDettagliato {
  final PeriodoReport periodo;
  final VenditeData vendite;
  final List<TopProdotto> topProdotti;
  final Map<String, double> venditePerCategoria;
  final List<TendenzaVendite> tendenze;

  ReportVenditeDettagliato({
    required this.periodo,
    required this.vendite,
    required this.topProdotti,
    required this.venditePerCategoria,
    required this.tendenze,
  });
}

/// Contratto del servizio report usato dalla UI e dai test
abstract interface class DashboardReportGateway {
  Future<DashboardData> getDashboard({
    PeriodoReport? periodo,
    bool forceRefresh,
  });

  Future<ReportVenditeDettagliato> getReportVendite({PeriodoReport? periodo});

  Future<List<Map<String, dynamic>>> getProdottiStockBasso({int soglia});

  /// Published products per category name.
  Future<Map<String, int>> getProductsByCategory();

  Future<bool> isServiceAvailable();
}

/// Contratto del backend report sottostante al servizio dashboard
abstract interface class DashboardReportSource {
  Future<Map<String, dynamic>> getDashboardSummary({
    DateTime? dataInizio,
    DateTime? dataFine,
  });

  Future<Map<String, dynamic>> getStockStatistics({int lowStockThreshold});

  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold});

  Future<Map<String, int>> getProductsByCategory();

  Future<List<Map<String, dynamic>>> getSalesTrend({
    DateTime? dataInizio,
    DateTime? dataFine,
  });

  Future<ReportVendite> getSalesReport({
    DateTime? dataInizio,
    DateTime? dataFine,
  });

  Future<Statistiche> getProductStats();

  Future<Map<String, int>> getOrdersByStatus();

  Future<Map<String, int>> getReviewStats();

  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit,
    DateTime? dataInizio,
    DateTime? dataFine,
  });

  Future<bool> isServiceAvailable();
}

class _WooQueryReportSource implements DashboardReportSource {
  _WooQueryReportSource({WooQueryReport? query})
    : _query = query ?? WooQueryReport();

  final WooQueryReport _query;

  @override
  Future<Map<String, dynamic>> getDashboardSummary({
    DateTime? dataInizio,
    DateTime? dataFine,
  }) {
    return _query.getDashboardSummary(
      dataInizio: dataInizio,
      dataFine: dataFine,
    );
  }

  @override
  Future<Map<String, dynamic>> getStockStatistics({int lowStockThreshold = 5}) {
    return _query.getStockStatistics(lowStockThreshold: lowStockThreshold);
  }

  @override
  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 5}) {
    return _query.getLowStockProducts(threshold: threshold);
  }

  @override
  Future<Map<String, int>> getProductsByCategory() {
    return _query.getProductsByCategory();
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesTrend({
    DateTime? dataInizio,
    DateTime? dataFine,
  }) {
    return _query.getSalesTrend(dataInizio: dataInizio, dataFine: dataFine);
  }

  @override
  Future<ReportVendite> getSalesReport({
    DateTime? dataInizio,
    DateTime? dataFine,
  }) {
    return _query.getSalesReport(dataInizio: dataInizio, dataFine: dataFine);
  }

  @override
  Future<Statistiche> getProductStats() {
    return _query.getProductStats();
  }

  @override
  Future<Map<String, int>> getOrdersByStatus() {
    return _query.getOrdersByStatus();
  }

  @override
  Future<Map<String, int>> getReviewStats() {
    return _query.getReviewStats();
  }

  @override
  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit = 10,
    DateTime? dataInizio,
    DateTime? dataFine,
  }) {
    return _query.getTopSellingProducts(
      limit: limit,
      dataInizio: dataInizio,
      dataFine: dataFine,
    );
  }

  @override
  Future<bool> isServiceAvailable() {
    return _query.isServiceAvailable();
  }
}

/// Tendenza vendite per grafici
class TendenzaVendite {
  final DateTime data;
  final double vendite;
  final int ordini;
  final double ticketMedio;

  TendenzaVendite({
    required this.data,
    required this.vendite,
    required this.ordini,
  }) : ticketMedio = ordini > 0 ? vendite / ordini : 0.0;

  String get dataFormattata {
    return '${data.day}/${data.month}';
  }
}

// =======================================================
// ==            SERVIZIO PRINCIPALE REPORT             ==
// =======================================================

/// Servizio principale per gestire tutti i report
/// Coordina WooQueryReport e fornisce dati elaborati alla GUI
class ReportService implements DashboardReportGateway {
  // Singleton
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal({DashboardReportSource? reportSource})
    : _reportSource = reportSource ?? _WooQueryReportSource();

  ReportService.withDependencies({required DashboardReportSource reportSource})
    : _reportSource = reportSource;

  final DashboardReportSource _reportSource;

  /// Cache per dashboard data
  DashboardData? _cachedDashboard;
  PeriodoReport? _cachedPeriodo;

  /// Reset della cache (dopo logout o cambio periodo)
  void reset() {
    _cachedDashboard = null;
    _cachedPeriodo = null;
  }

  /// Ottiene dashboard completa con tutti i dati
  Future<DashboardData> getDashboard({
    PeriodoReport? periodo,
    bool forceRefresh = false,
  }) async {
    try {
      // Usa periodo corrente o mese di default
      periodo ??= PeriodoReport.mese();

      // Verifica cache
      if (!forceRefresh && _canReuseDashboardCache(periodo)) {
        log.d('📊 Dashboard cache HIT');
        return _cachedDashboard!;
      }

      log.d('📊 Caricamento dashboard per periodo: ${periodo.tipo.name}');

      // The landing dashboard must stay fast.  Stock details and inventory
      // valuation can require downloading every product, therefore they are
      // intentionally not part of this initial summary request.
      final summaryFuture = _reportSource.getDashboardSummary(
        dataInizio: periodo.dataInizio,
        dataFine: periodo.dataFine,
      );
      final trendsFuture = _reportSource.getSalesTrend(
        dataInizio: periodo.dataInizio,
        dataFine: periodo.dataFine,
      );

      final periodoPrecedente = periodo.periodoPrecedente;
      final reportPrecedenteFuture = _reportSource
          .getSalesReport(
            dataInizio: periodoPrecedente.dataInizio,
            dataFine: periodoPrecedente.dataFine,
          )
          .then<ReportVendite?>((r) => r)
          .catchError((Object e) {
            // Il confronto e' facoltativo: non deve bloccare la dashboard.
            log.w('Confronto periodo precedente non disponibile: $e');
            return null;
          });

      final summary = await summaryFuture;
      final reportPrecedente = await reportPrecedenteFuture;
      final trendsRaw = await trendsFuture;

      // Costruisci dati vendite
      final salesData = summary['sales'] as Map<String, dynamic>;

      final andamentoGiornaliero = <VenditaGiornaliera>[
        for (final t in trendsRaw)
          if (parseReportDate(t['date']) case final data?)
            VenditaGiornaliera(
              data: data,
              totale: _parseDouble(t['total_sales']),
              ordini: _parseInt(t['total_orders']),
            ),
      ]..sort((a, b) => a.data.compareTo(b.data));
      final andamentoMensile = trendsRaw.any((t) => t['monthly'] == true);

      final totaleCorrente = _parseDouble(salesData['total']);
      double variazionePrecedente = 0.0;
      if (reportPrecedente != null && reportPrecedente.totaleVendite > 0) {
        variazionePrecedente =
            ((totaleCorrente - reportPrecedente.totaleVendite) /
                reportPrecedente.totaleVendite) *
            100;
      }

      final vendite = VenditeData(
        totaleVendite: totaleCorrente,
        numeroOrdini: _parseInt(salesData['orders']),
        ticketMedio: _parseDouble(salesData['average_order']),
        variazionePrecedente: variazionePrecedente,
        andamentoGiornaliero: andamentoGiornaliero,
        andamentoMensile: andamentoMensile,
        periodoPrecedente: reportPrecedente == null ? null : periodoPrecedente,
        totalePrecedente: reportPrecedente?.totaleVendite,
        ordiniPrecedenti: reportPrecedente?.numeroOrdini,
      );

      // The summary source already returns the inexpensive product counters.
      // Detailed low-stock rows are loaded only by a future dedicated widget.
      final productsData = summary['products'] as Map<String, dynamic>? ?? {};
      final prodotti = ProdottiData(
        totaleProdotti: _parseInt(productsData['total']),
        prodottiInStock: _parseInt(productsData['in_stock']),
        prodottiOutOfStock: _parseInt(productsData['out_of_stock']),
      );

      // Costruisci dati ordini
      final ordersData = summary['orders_by_status'] as Map<String, dynamic>;
      final ordersAllTime =
          summary['orders_all_time'] as Map<String, dynamic>? ?? ordersData;
      final ordini = OrdiniData(
        ordiniPerStato: ordersData.map((k, v) => MapEntry(k, _parseInt(v))),
        ordiniDiSempre: ordersAllTime.map((k, v) => MapEntry(k, _parseInt(v))),
      );

      // Costruisci dati clienti (opzionali)
      ClientiData? clienti;
      if (summary.containsKey('customers')) {
        final customersData = summary['customers'] as Map<String, dynamic>;
        clienti = ClientiData(
          totaleClienti: _parseInt(customersData['customers_count']),
          nuoviClienti: _parseInt(customersData['new_customers']),
          clientiAttivi: _parseInt(customersData['paying_customers']),
        );
      }

      // Crea dashboard
      final dashboard = DashboardData(
        periodo: periodo,
        vendite: vendite,
        prodotti: prodotti,
        ordini: ordini,
        clienti: clienti,
      );

      // Salva in cache
      _cachedDashboard = dashboard;
      _cachedPeriodo = periodo;

      log.i('✅ Dashboard caricata con successo');
      return dashboard;
    } catch (e, stack) {
      log.e('❌ Errore caricamento dashboard', e);
      log.e('Stack trace:', stack);

      // Converti in ReportException con messaggio specifico
      final errorString = e.toString().toLowerCase();
      ReportErrorType errorType;

      if (errorString.contains('socketexception') ||
          errorString.contains('connection') ||
          errorString.contains('network')) {
        errorType = ReportErrorType.network;
      } else if (errorString.contains('401') ||
          errorString.contains('403') ||
          errorString.contains('unauthorized') ||
          errorString.contains('authentication')) {
        errorType = ReportErrorType.authentication;
      } else if (errorString.contains('500') ||
          errorString.contains('502') ||
          errorString.contains('503')) {
        errorType = ReportErrorType.serverError;
      } else if (errorString.contains('timeout')) {
        errorType = ReportErrorType.timeout;
      } else {
        errorType = ReportErrorType.unknown;
      }

      throw ReportException('Errore caricamento dashboard: $e', errorType, e);
    }
  }

  /// Ottiene report vendite dettagliato
  Future<ReportVenditeDettagliato> getReportVendite({
    PeriodoReport? periodo,
  }) async {
    try {
      periodo ??= PeriodoReport.mese();

      log.d('📈 Caricamento report vendite per: ${periodo.tipo.name}');

      // Carica dati in parallelo
      final results = await Future.wait([
        _reportSource.getSalesReport(
          dataInizio: periodo.dataInizio,
          dataFine: periodo.dataFine,
        ),
        _reportSource.getTopSellingProducts(
          limit: 20,
          dataInizio: periodo.dataInizio,
          dataFine: periodo.dataFine,
        ),
        _reportSource.getSalesTrend(
          dataInizio: periodo.dataInizio,
          dataFine: periodo.dataFine,
        ),
      ]);

      final reportVendite = results[0] as ReportVendite;
      final topProductsRaw = results[1] as List<Map<String, dynamic>>;
      final trendsRaw = results[2] as List<Map<String, dynamic>>;

      // Converti top prodotti
      final topProdotti = topProductsRaw.map((p) {
        return TopProdotto(
          productId: _parseInt(p['product_id']),
          titolo: p['title']?.toString() ?? 'Sconosciuto',
          quantitaVenduta: _parseInt(p['quantity']),
          totaleVendite: _parseDouble(p['total']),
        );
      }).toList();

      // Converti tendenze
      final tendenze = <TendenzaVendite>[
        for (final t in trendsRaw)
          if (parseReportDate(t['date']) case final data?)
            TendenzaVendite(
              data: data,
              vendite: _parseDouble(t['total_sales']),
              ordini: _parseInt(t['total_orders']),
            ),
      ];

      // Costruisci VenditeData
      final vendite = VenditeData(
        totaleVendite: reportVendite.totaleVendite,
        numeroOrdini: reportVendite.numeroOrdini,
        ticketMedio: reportVendite.ticketMedio,
        andamentoGiornaliero: reportVendite.venditeGiornaliere,
      );

      log.i('✅ Report vendite caricato: ${topProdotti.length} top prodotti');

      return ReportVenditeDettagliato(
        periodo: periodo,
        vendite: vendite,
        topProdotti: topProdotti,
        venditePerCategoria: reportVendite.venditePerCategoria,
        tendenze: tendenze,
      );
    } catch (e, stack) {
      log.e('❌ Errore caricamento report vendite', e);
      log.e('Stack trace:', stack);
      rethrow;
    }
  }

  /// Prodotti con stock basso, ordinati per quantita' crescente.
  ///
  /// Separato da [getDashboard] perche' scarica le schede prodotto: la
  /// dashboard lo carica dopo aver mostrato i numeri principali.
  @override
  Future<List<Map<String, dynamic>>> getProdottiStockBasso({int soglia = 5}) =>
      _reportSource.getLowStockProducts(threshold: soglia);

  @override
  Future<Map<String, int>> getProductsByCategory() =>
      _reportSource.getProductsByCategory();

  /// Ottiene statistiche prodotti
  Future<Statistiche> getStatisticheProdotti() async {
    try {
      log.d('📦 Caricamento statistiche prodotti');
      final stats = await _reportSource.getProductStats();
      log.i('✅ Statistiche prodotti caricate');
      return stats;
    } catch (e) {
      log.e('❌ Errore caricamento statistiche prodotti', e);
      rethrow;
    }
  }

  /// Ottiene ordini per stato
  Future<Map<String, int>> getOrdiniPerStato() async {
    try {
      log.d('📋 Caricamento ordini per stato');
      final ordini = await _reportSource.getOrdersByStatus();
      log.i('✅ Ordini per stato caricati: ${ordini.length} stati');
      return ordini;
    } catch (e) {
      log.e('❌ Errore caricamento ordini per stato', e);
      rethrow;
    }
  }

  /// Ottiene statistiche recensioni
  Future<Map<String, int>> getStatisticheRecensioni() async {
    try {
      log.d('⭐ Caricamento statistiche recensioni');
      final reviews = await _reportSource.getReviewStats();
      log.i('✅ Statistiche recensioni caricate');
      return reviews;
    } catch (e) {
      log.e('❌ Errore caricamento statistiche recensioni', e);
      rethrow;
    }
  }

  /// Verifica disponibilità servizio report
  Future<bool> isServiceAvailable() async {
    try {
      return await _reportSource.isServiceAvailable();
    } catch (e) {
      log.e('❌ Servizio report non disponibile', e);
      return false;
    }
  }

  bool _canReuseDashboardCache(PeriodoReport periodo) {
    final cachedDashboard = _cachedDashboard;
    final cachedPeriodo = _cachedPeriodo;

    if (cachedDashboard == null ||
        cachedPeriodo == null ||
        cachedDashboard.isObsoleto) {
      return false;
    }

    if (cachedPeriodo.tipo != periodo.tipo) {
      return false;
    }

    if (periodo.tipo == TipoPeriodo.custom) {
      return cachedPeriodo.dataInizio == periodo.dataInizio &&
          cachedPeriodo.dataFine == periodo.dataFine;
    }

    return true;
  }

  // Helper per parsing sicuro
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// =======================================================
// ==              HELPER E UTILITY                     ==
// =======================================================

/// Data di una riga di `/reports/sales`: "2026-10-17" se raggruppata per
/// giorno, "2026-10" se raggruppata per mese. Prima le chiavi mensili
/// finivano tutte su `DateTime.now()`, schiacciando il grafico annuale.
DateTime? parseReportDate(Object? raw) {
  final text = raw?.toString() ?? '';
  final mese = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(text);
  if (mese != null) {
    return DateTime(int.parse(mese[1]!), int.parse(mese[2]!));
  }
  return DateTime.tryParse(text);
}

/// Formatter per valori report
class ReportFormatter {
  static final _euro = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  static final _intero = NumberFormat.decimalPattern('it_IT');

  /// Formatta valuta in euro (1.234,50 €)
  static String formatCurrency(double value) => _euro.format(value);

  /// Formatta un intero con separatore delle migliaia (1.234)
  static String formatInt(int value) => _intero.format(value);

  /// Formatta valuta compatta (es. 1.5K, 2.3M)
  static String formatCurrencyCompact(double value) {
    if (value >= 1000000) {
      return '€${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '€${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '€${value.toStringAsFixed(0)}';
    }
  }

  /// Formatta percentuale
  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  /// Formatta numero intero compatto
  static String formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  /// Formatta data per grafici
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  /// Formatta data completa
  static String formatDateFull(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Colori per i report
class ReportColors {
  // Colori principali
  static const primary = 0xFF2196F3;
  static const success = 0xFF4CAF50;
  static const warning = 0xFFFF9800;
  static const danger = 0xFFF44336;
  static const info = 0xFF00BCD4;

  // Colori per trend
  static const trendUp = success;
  static const trendDown = danger;
  static const trendStable = 0xFF9E9E9E;

  // Colori per stati ordine
  static const statusPending = warning;
  static const statusProcessing = info;
  static const statusCompleted = success;
  static const statusCancelled = danger;

  // Colori per grafici
  static const chartColors = [
    0xFF2196F3,
    0xFFF44336,
    0xFF4CAF50,
    0xFFFF9800,
    0xFF9C27B0,
    0xFF00BCD4,
    0xFFFFEB3B,
    0xFF795548,
  ];
}
