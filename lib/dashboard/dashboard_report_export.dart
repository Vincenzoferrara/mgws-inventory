// Report Export - Funzionalità di esportazione report
//
// Gestisce l'esportazione dei report in formato CSV e PDF; il file viene
// salvato dove sceglie l'utente, con la finestra di salvataggio di sistema.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dashboard.code.dart';
import 'dashboard_widget_data.dart' show dashboardOrderStatusLabel;
import '../log_viewer/app_logger.dart';
import '../reuse_class/logic/save_file_dialog.dart';
import '../l10n/extensions.dart';
import '../theme/theme.dart';

/// Report pronto da salvare: nome proposto, contenuto e tipo MIME.
class DashboardExportFile {
  const DashboardExportFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
}

/// Contratto per l'export dei report dashboard
abstract interface class DashboardExportGateway {
  Future<DashboardExportFile> exportDashboardToCsv(
    DashboardData dashboard,
    AppLocalizations l10n,
  );

  Future<DashboardExportFile> exportVenditeToCsv(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  );

  Future<DashboardExportFile> exportDashboardToPdf(
    DashboardData dashboard,
    AppLocalizations l10n,
  );

  Future<DashboardExportFile> exportVenditeToPdf(
    ReportVenditeDettagliato report,
    AppLocalizations l10n,
  );

  /// Chiede dove salvare [file] e lo scrive. Restituisce il percorso (o il
  /// nome) del file salvato, null se l'utente annulla.
  Future<String?> saveFile(DashboardExportFile file, {String? dialogTitle});
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

  String title(AppLocalizations l10n) {
    return switch ((scope, format)) {
      (DashboardExportScope.dashboard, DashboardExportFormat.csv) =>
        l10n.dashboardExportChoiceDashboardCsv,
      (DashboardExportScope.dashboard, DashboardExportFormat.pdf) =>
        l10n.dashboardExportChoiceDashboardPdf,
      (DashboardExportScope.vendite, DashboardExportFormat.csv) =>
        l10n.dashboardExportChoiceSalesCsv,
      (DashboardExportScope.vendite, DashboardExportFormat.pdf) =>
        l10n.dashboardExportChoiceSalesPdf,
    };
  }

  String subtitle(AppLocalizations l10n) {
    return switch (scope) {
      DashboardExportScope.dashboard => l10n.dashboardExportChoiceDashboardHint,
      DashboardExportScope.vendite => l10n.dashboardExportChoiceSalesHint,
    };
  }

  String shareSubject(AppLocalizations l10n) =>
      l10n.dashboardExportShareSubject(title(l10n));

  IconData get icon {
    return switch (format) {
      DashboardExportFormat.csv => Icons.table_chart,
      DashboardExportFormat.pdf => Icons.picture_as_pdf,
    };
  }

  Color color(AppColorExtension colors) {
    return switch (format) {
      DashboardExportFormat.csv => colors.spreadsheetExport,
      DashboardExportFormat.pdf => colors.pdfExport,
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
  Future<DashboardExportFile> exportDashboardToCsv(
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
        l10n.dashboardExportPeriod(
          _dateFormat.format(dashboard.periodo.dataInizio),
          _dateFormat.format(dashboard.periodo.dataFine),
        ),
      );
      buffer.writeln(
        l10n.dashboardExportGeneratedOn(_dateFormat.format(DateTime.now())),
      );
      buffer.writeln();

      // Vendite
      buffer.writeln('=== ${l10n.dashboardExportSectionSales} ===');
      buffer.writeln(
        '${l10n.dashboardExportTotalSales};${dashboard.vendite.totaleVendite}',
      );
      buffer.writeln(
        '${l10n.dashboardExportOrderCount};${dashboard.vendite.numeroOrdini}',
      );
      buffer.writeln(
        '${l10n.dashboardExportAverageTicket};${dashboard.vendite.ticketMedio}',
      );
      if (dashboard.vendite.variazionePrecedente != 0) {
        buffer.writeln(
          '${l10n.dashboardExportChangeVsPrevious};${dashboard.vendite.variazionePrecedente}%',
        );
      }
      buffer.writeln();

      // Prodotti
      buffer.writeln('=== ${l10n.dashboardExportSectionProducts} ===');
      buffer.writeln(
        '${l10n.dashboardExportTotalProducts};${dashboard.prodotti.totaleProdotti}',
      );
      buffer.writeln(
        '${l10n.dashboardExportInStock};${dashboard.prodotti.prodottiInStock}',
      );
      buffer.writeln(
        '${l10n.dashboardExportOutOfStock};${dashboard.prodotti.prodottiOutOfStock}',
      );
      buffer.writeln(
        '${l10n.dashboardExportLowStock};${dashboard.prodotti.prodottiPerEsaurimento}',
      );
      buffer.writeln(
        '${l10n.dashboardExportInventoryValue};${dashboard.prodotti.valoreInventario}',
      );
      buffer.writeln();

      // Ordini
      buffer.writeln('=== ${l10n.dashboardExportSectionOrders} ===');
      buffer.writeln(
        '${l10n.dashboardExportTotalOrders};${dashboard.ordini.totaleOrdini}',
      );
      buffer.writeln(
        '${l10n.dashboardExportCompleted};${dashboard.ordini.ordiniCompletati}',
      );
      buffer.writeln(
        '${l10n.dashboardExportProcessing};${dashboard.ordini.ordiniInElaborazione}',
      );
      buffer.writeln(
        '${l10n.dashboardExportPending};${dashboard.ordini.ordiniInAttesa}',
      );
      buffer.writeln();

      // Ordini per stato dettagliati
      buffer.writeln('=== ${l10n.dashboardExportSectionOrdersByStatus} ===');
      dashboard.ordini.ordiniPerStato.forEach((stato, count) {
        buffer.writeln('${dashboardOrderStatusLabel(l10n, stato)};$count');
      });
      buffer.writeln();

      // Clienti (se disponibili)
      if (dashboard.clienti != null) {
        buffer.writeln('=== ${l10n.dashboardExportSectionCustomers} ===');
        buffer.writeln(
          '${l10n.dashboardExportTotalCustomers};${dashboard.clienti!.totaleClienti}',
        );
        buffer.writeln(
          '${l10n.dashboardExportNewCustomers};${dashboard.clienti!.nuoviClienti}',
        );
        buffer.writeln(
          '${l10n.dashboardExportActiveCustomers};${dashboard.clienti!.clientiAttivi}',
        );
        buffer.writeln();
      }

      // Andamento giornaliero (se disponibile)
      if (dashboard.vendite.andamentoGiornaliero.isNotEmpty) {
        buffer.writeln('=== ${l10n.dashboardExportSectionDailyTrend} ===');
        buffer.writeln(
          '${l10n.dashboardExportColDate};${l10n.dashboardExportColTotal};${l10n.dashboardExportColOrders}',
        );
        for (final vendita in dashboard.vendite.andamentoGiornaliero) {
          buffer.writeln(
            '${_dateFormat.format(vendita.data)};${vendita.totale};${vendita.ordini}',
          );
        }
      }

      log.i('CSV Dashboard pronto');
      return _csvFile('dashboard', buffer);
    } catch (e) {
      log.e('Errore export CSV dashboard', e);
      rethrow;
    }
  }

  /// Esporta report vendite dettagliato in CSV
  Future<DashboardExportFile> exportVenditeToCsv(
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
        l10n.dashboardExportPeriod(
          _dateFormat.format(report.periodo.dataInizio),
          _dateFormat.format(report.periodo.dataFine),
        ),
      );
      buffer.writeln(
        l10n.dashboardExportGeneratedOn(_dateFormat.format(DateTime.now())),
      );
      buffer.writeln();

      // Riepilogo
      buffer.writeln('=== ${l10n.dashboardExportSectionSummary} ===');
      buffer.writeln(
        '${l10n.dashboardExportTotalSales};${report.vendite.totaleVendite}',
      );
      buffer.writeln(
        '${l10n.dashboardExportOrderCount};${report.vendite.numeroOrdini}',
      );
      buffer.writeln(
        '${l10n.dashboardExportAverageTicket};${report.vendite.ticketMedio}',
      );
      buffer.writeln();

      // Top Prodotti
      buffer.writeln('=== ${l10n.dashboardExportSectionTopProducts} ===');
      buffer.writeln(
        '${l10n.dashboardExportColPosition};${l10n.dashboardExportColProduct};${l10n.dashboardExportColQuantity};${l10n.dashboardExportColTotal};${l10n.dashboardExportColAveragePrice}',
      );
      for (int i = 0; i < report.topProdotti.length; i++) {
        final p = report.topProdotti[i];
        buffer.writeln(
          '${i + 1};${p.titolo};${p.quantitaVenduta};${p.totaleVendite};${p.prezzoMedio}',
        );
      }
      buffer.writeln();

      // Vendite per categoria
      if (report.venditePerCategoria.isNotEmpty) {
        buffer.writeln('=== ${l10n.dashboardExportSectionSalesByCategory} ===');
        buffer.writeln(
          '${l10n.dashboardExportColCategory};${l10n.dashboardExportColTotal}',
        );
        report.venditePerCategoria.forEach((cat, totale) {
          buffer.writeln('$cat;$totale');
        });
        buffer.writeln();
      }

      // Tendenze
      if (report.tendenze.isNotEmpty) {
        buffer.writeln('=== ${l10n.dashboardExportSectionDailyTrends} ===');
        buffer.writeln(
          '${l10n.dashboardExportColDate};${l10n.dashboardExportColSales};${l10n.dashboardExportColOrders};${l10n.dashboardExportAverageTicket}',
        );
        for (final t in report.tendenze) {
          buffer.writeln(
            '${_dateFormat.format(t.data)};${t.vendite};${t.ordini};${t.ticketMedio}',
          );
        }
      }

      log.i('CSV Vendite pronto');
      return _csvFile('vendite', buffer);
    } catch (e) {
      log.e('Errore export CSV vendite', e);
      rethrow;
    }
  }

  /// Esporta dashboard in PDF
  Future<DashboardExportFile> exportDashboardToPdf(
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
                l10n.dashboardExportDashboardTitle,
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
              l10n.dashboardExportTotalSales,
              _currencyFormat.format(dashboard.vendite.totaleVendite),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportOrderCount,
              dashboard.vendite.numeroOrdini.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportAverageTicket,
              _currencyFormat.format(dashboard.vendite.ticketMedio),
            ),
            if (dashboard.vendite.variazionePrecedente != 0)
              _buildPdfKeyValue(
                l10n.dashboardExportChange,
                '${dashboard.vendite.variazioneFormatted}',
              ),
            pw.SizedBox(height: 16),

            // Prodotti
            pw.Header(level: 1, child: pw.Text(l10n.prodottiTitolo)),
            _buildPdfKeyValue(
              l10n.dashboardExportTotalProducts,
              dashboard.prodotti.totaleProdotti.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportInStock,
              dashboard.prodotti.prodottiInStock.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportOutOfStock,
              dashboard.prodotti.prodottiOutOfStock.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportLowStock,
              dashboard.prodotti.prodottiPerEsaurimento.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportInventoryValue,
              _currencyFormat.format(dashboard.prodotti.valoreInventario),
            ),
            pw.SizedBox(height: 16),

            // Ordini
            pw.Header(level: 1, child: pw.Text(l10n.ordiniTitolo)),
            _buildPdfKeyValue(
              l10n.dashboardExportColTotal,
              dashboard.ordini.totaleOrdini.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportCompleted,
              dashboard.ordini.ordiniCompletati.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportProcessing,
              dashboard.ordini.ordiniInElaborazione.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportPending,
              dashboard.ordini.ordiniInAttesa.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportCompletionRate,
              '${dashboard.ordini.tassoCompletamento.toStringAsFixed(1)}%',
            ),
            pw.SizedBox(height: 16),

            // Clienti
            if (dashboard.clienti != null) ...[
              pw.Header(level: 1, child: pw.Text(l10n.dashboardTitoloClienti)),
              _buildPdfKeyValue(
                l10n.dashboardExportTotalCustomers,
                dashboard.clienti!.totaleClienti.toString(),
              ),
              _buildPdfKeyValue(
                l10n.dashboardExportNewCustomers,
                dashboard.clienti!.nuoviClienti.toString(),
              ),
              _buildPdfKeyValue(
                l10n.dashboardExportActiveCustomers,
                dashboard.clienti!.clientiAttivi.toString(),
              ),
              _buildPdfKeyValue(
                l10n.dashboardExportActivePercent,
                '${dashboard.clienti!.percentualeClientiAttivi.toStringAsFixed(1)}%',
              ),
              pw.SizedBox(height: 16),
            ],

            // Tabella ordini per stato
            pw.Header(level: 1, child: pw.Text(l10n.dashboardOrdiniPerStato)),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: [
                l10n.dashboardExportColStatus,
                l10n.dashboardExportColQuantity,
              ],
              data: dashboard.ordini.ordiniPerStato.entries
                  .map(
                    (e) => [
                      dashboardOrderStatusLabel(l10n, e.key),
                      e.value.toString(),
                    ],
                  )
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
                headers: [
                  l10n.dashboardExportColDate,
                  l10n.dashboardExportColSales,
                  l10n.dashboardExportColOrders,
                ],
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
              l10n.dashboardExportFooter(
                _dateFormat.format(DateTime.now()),
                context.pageNumber,
                context.pagesCount,
              ),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ),
      );

      log.i('PDF Dashboard pronto');
      return await _pdfFile('dashboard', pdf);
    } catch (e) {
      log.e('Errore export PDF dashboard', e);
      rethrow;
    }
  }

  /// Esporta report vendite in PDF
  Future<DashboardExportFile> exportVenditeToPdf(
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
                l10n.dashboardExportSalesTitle,
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
              l10n.dashboardExportTotalSales,
              _currencyFormat.format(report.vendite.totaleVendite),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportOrderCount,
              report.vendite.numeroOrdini.toString(),
            ),
            _buildPdfKeyValue(
              l10n.dashboardExportAverageTicket,
              _currencyFormat.format(report.vendite.ticketMedio),
            ),
            pw.SizedBox(height: 16),

            // Top Prodotti
            pw.Header(level: 1, child: pw.Text(l10n.dashboardTopProdotti)),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: [
                '#',
                l10n.dashboardExportColProduct,
                l10n.dashboardExportColQty,
                l10n.dashboardExportColTotal,
                l10n.dashboardExportColAveragePrice,
              ],
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
                headers: [
                  l10n.dashboardExportColCategory,
                  l10n.dashboardExportColTotal,
                ],
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
                headers: [
                  l10n.dashboardExportColDate,
                  l10n.dashboardExportColSales,
                  l10n.dashboardExportColOrders,
                  l10n.dashboardExportColTicket,
                ],
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
              l10n.dashboardExportFooter(
                _dateFormat.format(DateTime.now()),
                context.pageNumber,
                context.pagesCount,
              ),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ),
      );

      log.i('PDF Vendite pronto');
      return await _pdfFile('vendite', pdf);
    } catch (e) {
      log.e('Errore export PDF vendite', e);
      rethrow;
    }
  }

  /// Salva un report con la finestra di sistema (portale XDG su Linux).
  Future<String?> saveFile(
    DashboardExportFile file, {
    String? dialogTitle,
  }) async {
    try {
      final saved = await saveFileWithDialog(
        dialogTitle: dialogTitle,
        fileName: file.fileName,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
      if (saved != null) log.i('Report salvato: $saved');
      return saved;
    } catch (e) {
      log.e('Errore salvataggio report', e);
      rethrow;
    }
  }

  /// Nome proposto, per esempio `report-dashboard-2026-10-26.pdf`.
  String _fileName(String kind, String extension) =>
      'report-$kind-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.$extension';

  DashboardExportFile _csvFile(String kind, StringBuffer buffer) =>
      DashboardExportFile(
        fileName: _fileName(kind, 'csv'),
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
        mimeType: 'text/csv',
      );

  Future<DashboardExportFile> _pdfFile(String kind, pw.Document pdf) async =>
      DashboardExportFile(
        fileName: _fileName(kind, 'pdf'),
        bytes: await pdf.save(),
        mimeType: 'application/pdf',
      );

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
          Text(context.l10n.dashboardExportDialogHint),
          const SizedBox(height: 12),
          for (final choice in DashboardExportChoice.values)
            ListTile(
              leading: Icon(choice.icon, color: choice.color(context.colors)),
              title: Text(choice.title(context.l10n)),
              subtitle: Text(choice.subtitle(context.l10n)),
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
