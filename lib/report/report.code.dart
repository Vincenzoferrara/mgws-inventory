import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_job.dart';
import 'print_library.dart';
import 'print_pdf_renderer.dart';
import 'print_sample_data.dart';
import 'print_template.dart';

/// State of the Print tab: the chosen template, the print settings and, when
/// labels were requested from the products list, the products to label.
///
/// Print settings (copies, used positions, paper) belong to one print only:
/// they never change the stored template.
class PrintCenterController extends ChangeNotifier {
  PrintCenterController({PrintLibrary? library})
    : library = library ?? printLibrary;

  final PrintLibrary library;

  PrintTemplate? _template;
  String? _paperOverrideId;
  int _copies = 1;
  List<int> _skippedPerSheet = const [];
  PrintJob? _job;

  PrintTemplate? get template => _template;
  int get copies => _job?.totalLabels ?? _copies;

  /// Positions skipped on each sheet that will be printed (one entry per
  /// sheet). Empty for rolls and single-page formats.
  List<int> get sheetSkips {
    final format = paper;
    if (format == null || _template?.kind == PrintTemplateKind.report)
      return const [];
    return format.sheetSkips(copies, _skippedPerSheet);
  }

  PrintJob? get job => _job;

  /// True while the chosen template is shown with its print settings.
  bool get isPrinting => _template != null;

  /// Templates the current job can use: product labels only when printing
  /// labels for real products.
  bool accepts(PrintTemplate template) =>
      _job == null || template.kind == PrintTemplateKind.productLabel;

  PaperFormat? get paper {
    final template = _template;
    if (template == null) return null;
    return library.paperFormatOf(template, overrideId: _paperOverrideId);
  }

  void chooseTemplate(PrintTemplate template) {
    _template = template;
    _paperOverrideId = null;
    _resetQuantities();
    notifyListeners();
  }

  /// Back to the template list.
  void closeTemplate() {
    _template = null;
    notifyListeners();
  }

  void setPaper(String formatId) {
    _paperOverrideId = formatId;
    _resetQuantities();
    notifyListeners();
  }

  void setCopies(int value) {
    _copies = value.clamp(1, 999);
    notifyListeners();
  }

  /// Sets how many positions are already used at the start of sheet
  /// [sheetIndex] (0-based).
  void setSkippedCells(int sheetIndex, int value) {
    final maxSkipped = (paper?.cellsPerPage ?? 1) - 1;
    final skips = List<int>.of(sheetSkips);
    while (skips.length <= sheetIndex) {
      skips.add(0);
    }
    skips[sheetIndex] = value.clamp(0, maxSkipped);
    _skippedPerSheet = skips;
    notifyListeners();
  }

  /// Starts printing labels for real products. A chosen template that is not
  /// a product label is dropped.
  void startJob(PrintJob job) {
    _job = job;
    if (_template != null && !accepts(_template!)) _template = null;
    _skippedPerSheet = const [];
    notifyListeners();
  }

  /// Adds the lines of [more] that are not in the labels yet and returns how
  /// many were added. Without a job yet, it starts one: the template stays
  /// when it is a product label.
  int addToJob(PrintJob more) {
    final current = _job;
    if (current == null) {
      startJob(more);
      return more.items.length;
    }
    final merged = current.merge(more);
    _job = merged;
    notifyListeners();
    return merged.items.length - current.items.length;
  }

  /// Removes one product or variant from the labels to print.
  void removeJobItem(String itemKey) {
    final job = _job;
    if (job == null) return;
    _job = job.without(itemKey);
    notifyListeners();
  }

  void clearJob() {
    _job = null;
    _resetQuantities();
    notifyListeners();
  }

  /// The templates were reloaded or changed: keep showing the stored version
  /// of the chosen one, or go back to the list if it was deleted.
  void syncWithLibrary() {
    final template = _template;
    if (template == null) return;
    _template = library.templates
        .where((entry) => entry.id == template.id)
        .firstOrNull;
    notifyListeners();
  }

  PrintRequest request(
    AppLocalizations l10n, {
    bool preview = false,
    bool singleCell = false,
  }) {
    final template = _template!;
    final job = _job;
    List<Map<String, dynamic>>? cells;
    if (job != null && template.kind == PrintTemplateKind.productLabel) {
      final labels = job.expanded;
      final source = singleCell && labels.isNotEmpty ? [labels.first] : labels;
      cells = [
        for (final item in source)
          PrintSampleData.labelData(
            item,
            l10n.localeName,
            separator: template.variantSeparator,
          ),
      ];
    }
    return PrintRequest(
      template: template,
      paper: paper!,
      l10n: l10n,
      localeName: l10n.localeName,
      copies: singleCell ? 1 : _copies,
      cellData: cells,
      skippedPerSheet: singleCell ? const [] : _skippedPerSheet,
      showCutGuides: preview,
      singleCellPage: singleCell,
    );
  }

  /// True when there is something to print (a job may have every quantity
  /// set to zero).
  bool get canPrint =>
      _template != null && (_job == null || _job!.totalLabels > 0);

  Future<void> printSelected(AppLocalizations l10n) async {
    final bytes = await PrintPdfRenderer.render(request(l10n));
    final format = paper!;
    await Printing.layoutPdf(
      name: _fileName,
      // Labels and signs carry their own page size: the document is not
      // re-laid out on the printer format, or labels drift off the sheet.
      format: PdfPageFormat(
        format.pageWidthMm * PdfPageFormat.mm,
        format.pageHeightMm * PdfPageFormat.mm,
      ),
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> shareSelected(AppLocalizations l10n) async {
    final bytes = await PrintPdfRenderer.render(request(l10n));
    await Printing.sharePdf(bytes: bytes, filename: '$_fileName.pdf');
  }

  String get _fileName {
    final name = (_template?.name ?? 'print')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return name.isEmpty ? 'print' : name;
  }

  void _resetQuantities() {
    final format = paper;
    _skippedPerSheet = const [];
    // Adhesive sheets default to a full sheet, everything else to one copy.
    _copies =
        format != null &&
            format.kind == PrintTemplateKind.productLabel &&
            format.isMultiCellSheet
        ? format.cellsPerPage
        : 1;
  }
}
