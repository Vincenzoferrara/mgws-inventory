// Report Export - Funzionalità di esportazione report
//
// Gestisce l'esportazione dei report in formato CSV e PDF

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dashboard.code.dart';
import '../log_viewer/app_logger.dart';
import '../l10n/extensions.dart';

/// Contratto per l'export dei report dashboard
abstract interface class DashboardExportGateway {
  Future<File> exportDashboardToCsv(
    DashboardData dashboard,
    AppLocalizations l10n,
  );

  Future<File> exportVenditeToCsv(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  );

  Future<File> exportDashboardToPdf(
    DashboardData dashboard,
    AppLocalizations l10n,
  );

  Future<File> exportVenditeToPdf(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  );

  Future<void> shareFile(File file, {String? subject});
}

enum DashboardExportScope { dashboard, vendite }

enum DashboardExportFormat { csv, pdf }

class DashboardExportChoice {
  const DashboardExportChoice({required this.scope, required this.format});

  final DashboardExportScope scope;
  final DashboardExportFormat format;

  static const dashboardCsv = DashboardExportChoice(
    scope: DashboardExportScope.dashboard,
    format: DashboardExportFormat.csv,
  );
  static const dashboardPdf = DashboardExportChoice(
    scope: DashboardExportScope.dashboard,
    format: DashboardExportFormat.pdf,
  );
  static const venditeCsv = DashboardExportChoice(
    scope: DashboardExportScope.vendite,
    format: DashboardExportFormat.csv,
  );
  static const venditePdf = DashboardExportChoice(
    scope: DashboardExportScope.vendite,
    format: DashboardExportFormat.pdf,
  );

  static const values = [dashboardCsv, dashboardPdf, venditeCsv, venditePdf];

  String get title {
    return switch ((scope, format)) {
      (DashboardExportScope.dashboard, DashboardExportFormat.csv) =>
        'Dashboard CSV',
      (DashboardExportScope.dashboard, DashboardExportFormat.pdf) =>
        'Dashboard PDF',
      (DashboardExportScope.vendite, DashboardExportFormat.csv) =>
        'Vendite CSV',
      (DashboardExportScope.vendite, DashboardExportFormat.pdf) =>
        'Vendite PDF',
    };
  }

  String get subtitle {
    return switch (scope) {
      DashboardExportScope.dashboard =>
        'Riepilogo del periodo e dei dati correnti dashboard',
      DashboardExportScope.vendite =>
        'Dettaglio vendite, top prodotti e tendenze del periodo',
    };
  }

  String get shareSubject => 'Report $title';

  IconData get icon {
    return switch (format) {
      DashboardExportFormat.csv => Icons.table_chart,
      DashboardExportFormat.pdf => Icons.picture_as_pdf,
    };
  }

  Color get color {
    return switch (format) {
      DashboardExportFormat.csv => Colors.green,
      DashboardExportFormat.pdf => Colors.red,
    };
  }
}

/// Servizio per esportazione report
class ReportExporter implements DashboardExportGateway {
  static final ReportExporter _instance = ReportExporter._internal();
  factory ReportExporter() => _instance;
  ReportExporter._internal();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  /// Esporta dashboard in CSV
  Future<File> exportDashboardToCsv(
    DashboardData dashboard,
    AppLocalizations l10n,
  ) async {
    try {
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
        l10n.dashboardTitoloReportCsv(
          periodoReportLabel(l10n, dashboard.periodo),
        ),
      );
      buffer.writeln(
        'Periodo: ${_dateFormat.format(dashboard.periodo.dataInizio)} - ${_dateFormat.format(dashboard.periodo.dataFine)}',
      );
      buffer.writeln('Generato il: ${_dateFormat.format(DateTime.now())}');
      buffer.writeln();

      // Vendite
      buffer.writeln('=== VENDITE ===');
      buffer.writeln('Totale Vendite;${dashboard.vendite.totaleVendite}');
      buffer.writeln('Numero Ordini;${dashboard.vendite.numeroOrdini}');
      buffer.writeln('Ticket Medio;${dashboard.vendite.ticketMedio}');
      if (dashboard.vendite.variazionePrecedente != 0) {
        buffer.writeln(
          'Variazione vs Precedente;${dashboard.vendite.variazionePrecedente}%',
        );
      }
      buffer.writeln();

      // Prodotti
      buffer.writeln('=== PRODOTTI ===');
      buffer.writeln('Totale Prodotti;${dashboard.prodotti.totaleProdotti}');
      buffer.writeln('In Stock;${dashboard.prodotti.prodottiInStock}');
      buffer.writeln('Esauriti;${dashboard.prodotti.prodottiOutOfStock}');
      buffer.writeln(
        'Stock Basso;${dashboard.prodotti.prodottiPerEsaurimento}',
      );
      buffer.writeln(
        'Valore Inventario;${dashboard.prodotti.valoreInventario}',
      );
      buffer.writeln();

      // Ordini
      buffer.writeln('=== ORDINI ===');
      buffer.writeln('Totale Ordini;${dashboard.ordini.totaleOrdini}');
      buffer.writeln('Completati;${dashboard.ordini.ordiniCompletati}');
      buffer.writeln(
        'In Elaborazione;${dashboard.ordini.ordiniInElaborazione}',
      );
      buffer.writeln('In Attesa;${dashboard.ordini.ordiniInAttesa}');
      buffer.writeln();

      // Ordini per stato dettagliati
      buffer.writeln('=== ORDINI PER STATO ===');
      dashboard.ordini.ordiniPerStato.forEach((stato, count) {
        buffer.writeln('$stato;$count');
      });
      buffer.writeln();

      // Clienti (se disponibili)
      if (dashboard.clienti != null) {
        buffer.writeln('=== CLIENTI ===');
        buffer.writeln('Totale Clienti;${dashboard.clienti!.totaleClienti}');
        buffer.writeln('Nuovi Clienti;${dashboard.clienti!.nuoviClienti}');
        buffer.writeln('Clienti Attivi;${dashboard.clienti!.clientiAttivi}');
        buffer.writeln();
      }

      // Andamento giornaliero (se disponibile)
      if (dashboard.vendite.andamentoGiornaliero.isNotEmpty) {
        buffer.writeln('=== ANDAMENTO GIORNALIERO ===');
        buffer.writeln('Data;Totale;Ordini');
        for (final vendita in dashboard.vendite.andamentoGiornaliero) {
          buffer.writeln(
            '${_dateFormat.format(vendita.data)};${vendita.totale};${vendita.ordini}',
          );
        }
      }

      // Salva file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/report_dashboard_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      log.i('CSV Dashboard esportato: ${file.path}');
      return file;
    } catch (e) {
      log.e('Errore export CSV dashboard', e);
      rethrow;
    }
  }

  /// Esporta report vendite dettagliato in CSV
  Future<File> exportVenditeToCsv(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  ) async {
    try {
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
        l10n.dashboardTitoloReportVenditeCsv(
          periodoReportLabel(l10n, report.periodo),
        ),
      );
      buffer.writeln(
        'Periodo: ${_dateFormat.format(report.periodo.dataInizio)} - ${_dateFormat.format(report.periodo.dataFine)}',
      );
      buffer.writeln('Generato il: ${_dateFormat.format(DateTime.now())}');
      buffer.writeln();

      // Riepilogo
      buffer.writeln('=== RIEPILOGO ===');
      buffer.writeln('Totale Vendite;${report.vendite.totaleVendite}');
      buffer.writeln('Numero Ordini;${report.vendite.numeroOrdini}');
      buffer.writeln('Ticket Medio;${report.vendite.ticketMedio}');
      buffer.writeln();

      // Top Prodotti
      buffer.writeln('=== TOP PRODOTTI ===');
      buffer.writeln('Posizione;Prodotto;Quantita;Totale;Prezzo Medio');
      for (int i = 0; i < report.topProdotti.length; i++) {
        final p = report.topProdotti[i];
        buffer.writeln(
          '${i + 1};${p.titolo};${p.quantitaVenduta};${p.totaleVendite};${p.prezzoMedio}',
        );
      }
      buffer.writeln();

      // Vendite per categoria
      if (report.venditePerCategoria.isNotEmpty) {
        buffer.writeln('=== VENDITE PER CATEGORIA ===');
        buffer.writeln('Categoria;Totale');
        report.venditePerCategoria.forEach((cat, totale) {
          buffer.writeln('$cat;$totale');
        });
        buffer.writeln();
      }

      // Tendenze
      if (report.tendenze.isNotEmpty) {
        buffer.writeln('=== TENDENZE GIORNALIERE ===');
        buffer.writeln('Data;Vendite;Ordini;Ticket Medio');
        for (final t in report.tendenze) {
          buffer.writeln(
            '${_dateFormat.format(t.data)};${t.vendite};${t.ordini};${t.ticketMedio}',
          );
        }
      }

      // Salva file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/report_vendite_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      log.i('CSV Vendite esportato: ${file.path}');
      return file;
    } catch (e) {
      log.e('Errore export CSV vendite', e);
      rethrow;
    }
  }

  /// Esporta dashboard in PDF
  Future<File> exportDashboardToPdf(
    DashboardData dashboard,
    AppLocalizations l10n,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Titolo
            pw.Header(
              level: 0,
              child: pw.Text(
                'Report Dashboard',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              l10n.dashboardEtichettaPeriodo(
                periodoReportLabel(l10n, dashboard.periodo),
              ),
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              '${_dateFormat.format(dashboard.periodo.dataInizio)} - ${_dateFormat.format(dashboard.periodo.dataFine)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Vendite
            pw.Header(level: 1, child: pw.Text(l10n.dashboardVendite)),
            _buildPdfKeyValue(
              'Totale Vendite',
              _currencyFormat.format(dashboard.vendite.totaleVendite),
            ),
            _buildPdfKeyValue(
              'Numero Ordini',
              dashboard.vendite.numeroOrdini.toString(),
            ),
            _buildPdfKeyValue(
              'Ticket Medio',
              _currencyFormat.format(dashboard.vendite.ticketMedio),
            ),
            if (dashboard.vendite.variazionePrecedente != 0)
              _buildPdfKeyValue(
                'Variazione',
                '${dashboard.vendite.variazioneFormatted}',
              ),
            pw.SizedBox(height: 16),

            // Prodotti
            pw.Header(level: 1, child: pw.Text(l10n.prodottiTitolo)),
            _buildPdfKeyValue(
              'Totale Prodotti',
              dashboard.prodotti.totaleProdotti.toString(),
            ),
            _buildPdfKeyValue(
              'In Stock',
              dashboard.prodotti.prodottiInStock.toString(),
            ),
            _buildPdfKeyValue(
              'Esauriti',
              dashboard.prodotti.prodottiOutOfStock.toString(),
            ),
            _buildPdfKeyValue(
              'Stock Basso',
              dashboard.prodotti.prodottiPerEsaurimento.toString(),
            ),
            _buildPdfKeyValue(
              'Valore Inventario',
              _currencyFormat.format(dashboard.prodotti.valoreInventario),
            ),
            pw.SizedBox(height: 16),

            // Ordini
            pw.Header(level: 1, child: pw.Text(l10n.ordiniTitolo)),
            _buildPdfKeyValue(
              'Totale',
              dashboard.ordini.totaleOrdini.toString(),
            ),
            _buildPdfKeyValue(
              'Completati',
              dashboard.ordini.ordiniCompletati.toString(),
            ),
            _buildPdfKeyValue(
              'In Elaborazione',
              dashboard.ordini.ordiniInElaborazione.toString(),
            ),
            _buildPdfKeyValue(
              'In Attesa',
              dashboard.ordini.ordiniInAttesa.toString(),
            ),
            _buildPdfKeyValue(
              'Tasso Completamento',
              '${dashboard.ordini.tassoCompletamento.toStringAsFixed(1)}%',
            ),
            pw.SizedBox(height: 16),

            // Clienti
            if (dashboard.clienti != null) ...[
              pw.Header(level: 1, child: pw.Text(l10n.dashboardTitoloClienti)),
              _buildPdfKeyValue(
                'Totale Clienti',
                dashboard.clienti!.totaleClienti.toString(),
              ),
              _buildPdfKeyValue(
                'Nuovi Clienti',
                dashboard.clienti!.nuoviClienti.toString(),
              ),
              _buildPdfKeyValue(
                'Clienti Attivi',
                dashboard.clienti!.clientiAttivi.toString(),
              ),
              _buildPdfKeyValue(
                '% Attivi',
                '${dashboard.clienti!.percentualeClientiAttivi.toStringAsFixed(1)}%',
              ),
              pw.SizedBox(height: 16),
            ],

            // Tabella ordini per stato
            pw.Header(level: 1, child: pw.Text(l10n.dashboardOrdiniPerStato)),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Stato', 'Quantità'],
              data: dashboard.ordini.ordiniPerStato.entries
                  .map((e) => [_translateStatus(e.key), e.value.toString()])
                  .toList(),
            ),

            // Andamento giornaliero
            if (dashboard.vendite.andamentoGiornaliero.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Header(
                level: 1,
                child: pw.Text(l10n.dashboardAndamentoGiornaliero),
              ),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Data', 'Vendite', 'Ordini'],
                data: dashboard.vendite.andamentoGiornaliero
                    .map(
                      (v) => [
                        _dateFormat.format(v.data),
                        _currencyFormat.format(v.totale),
                        v.ordini.toString(),
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Generato il ${_dateFormat.format(DateTime.now())} - Pagina ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ),
      );

      // Salva file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/report_dashboard_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      log.i('PDF Dashboard esportato: ${file.path}');
      return file;
    } catch (e) {
      log.e('Errore export PDF dashboard', e);
      rethrow;
    }
  }

  /// Esporta report vendite in PDF
  Future<File> exportVenditeToPdf(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  ) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Titolo
            pw.Header(
              level: 0,
              child: pw.Text(
                'Report Vendite Dettagliato',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              l10n.dashboardEtichettaPeriodo(
                periodoReportLabel(l10n, report.periodo),
              ),
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              '${_dateFormat.format(report.periodo.dataInizio)} - ${_dateFormat.format(report.periodo.dataFine)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Riepilogo
            pw.Header(level: 1, child: pw.Text(l10n.dashboardRiepilogo)),
            _buildPdfKeyValue(
              'Totale Vendite',
              _currencyFormat.format(report.vendite.totaleVendite),
            ),
            _buildPdfKeyValue(
              'Numero Ordini',
              report.vendite.numeroOrdini.toString(),
            ),
            _buildPdfKeyValue(
              'Ticket Medio',
              _currencyFormat.format(report.vendite.ticketMedio),
            ),
            pw.SizedBox(height: 16),

            // Top Prodotti
            pw.Header(level: 1, child: pw.Text(l10n.dashboardTopProdotti)),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['#', 'Prodotto', 'Qtà', 'Totale', 'Prezzo Medio'],
              data: List.generate(report.topProdotti.length, (i) {
                final p = report.topProdotti[i];
                return [
                  (i + 1).toString(),
                  p.titolo.length > 25
                      ? '${p.titolo.substring(0, 22)}...'
                      : p.titolo,
                  p.quantitaVenduta.toString(),
                  _currencyFormat.format(p.totaleVendite),
                  _currencyFormat.format(p.prezzoMedio),
                ];
              }),
            ),
            pw.SizedBox(height: 16),

            // Vendite per categoria
            if (report.venditePerCategoria.isNotEmpty) ...[
              pw.Header(
                level: 1,
                child: pw.Text(l10n.dashboardVenditePerCategoria),
              ),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Categoria', 'Totale'],
                data: report.venditePerCategoria.entries
                    .map((e) => [e.key, _currencyFormat.format(e.value)])
                    .toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Tendenze
            if (report.tendenze.isNotEmpty) ...[
              pw.Header(
                level: 1,
                child: pw.Text(l10n.dashboardTendenzeGiornaliere),
              ),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Data', 'Vendite', 'Ordini', 'Ticket'],
                data: report.tendenze
                    .map(
                      (t) => [
                        _dateFormat.format(t.data),
                        _currencyFormat.format(t.vendite),
                        t.ordini.toString(),
                        _currencyFormat.format(t.ticketMedio),
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Generato il ${_dateFormat.format(DateTime.now())} - Pagina ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ),
      );

      // Salva file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/report_vendite_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      log.i('PDF Vendite esportato: ${file.path}');
      return file;
    } catch (e) {
      log.e('Errore export PDF vendite', e);
      rethrow;
    }
  }

  /// Condivide un file esportato
  Future<void> shareFile(File file, {String? subject}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject ?? 'Report Esportato',
        ),
      );
    } catch (e) {
      log.e('Errore condivisione file', e);
      rethrow;
    }
  }

  // Helper per creare riga key-value nel PDF
  pw.Widget _buildPdfKeyValue(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  // Traduce stati ordine
  String _translateStatus(String status) {
    const translations = {
      'pending': 'In Attesa',
      'processing': 'In Elaborazione',
      'completed': 'Completato',
      'on-hold': 'In Sospeso',
      'cancelled': 'Annullato',
      'refunded': 'Rimborsato',
      'failed': 'Fallito',
    };
    return translations[status] ?? status;
  }
}

/// Dialog per selezionare tipo di export
class ExportDialog extends StatelessWidget {
  final DashboardData? dashboardData;
  final ReportVenditeDettagliato? reportVendite;

  const ExportDialog({super.key, this.dashboardData, this.reportVendite});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.dashboardEsportaReport),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Scegli se generare un report dalla dashboard corrente o dal '
            'dettaglio vendite dello stesso periodo.',
          ),
          const SizedBox(height: 12),
          for (final choice in DashboardExportChoice.values)
            ListTile(
              leading: Icon(choice.icon, color: choice.color),
              title: Text(choice.title),
              subtitle: Text(choice.subtitle),
              onTap: () => Navigator.pop(context, choice),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonAnnulla),
        ),
      ],
    );
  }
}
