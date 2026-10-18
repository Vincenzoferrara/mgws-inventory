import '../login/mgws/query/query_mgws_print.dart';
import '../traduzioni/estensioni.dart';
import 'print_template.dart';

/// How the printer receives the media.
enum PaperFeed {
  /// A4 (or other) sheet with one or more labels/signs laid out in a grid.
  sheet,

  /// Thermal roll: one label per page, page size equals label size.
  roll,
}

/// Physical layout of the media a template prints on.
///
/// Every measure is in millimetres. A sheet holds [columns] x [rows] cells
/// of [cellWidthMm] x [cellHeightMm]; a roll holds a single cell per page.
/// Paper formats are stored by MGWS and can be created, changed and deleted
/// by shop managers.
class PaperFormat {
  final String id;
  final String name;
  final PrintTemplateKind kind;
  final PaperFeed feed;
  final double pageWidthMm;
  final double pageHeightMm;
  final int columns;
  final int rows;
  final double cellWidthMm;
  final double cellHeightMm;
  final double marginTopMm;
  final double marginLeftMm;
  final double gapXMm;
  final double gapYMm;

  const PaperFormat({
    required this.id,
    this.name = '',
    required this.kind,
    required this.feed,
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.columns,
    required this.rows,
    required this.cellWidthMm,
    required this.cellHeightMm,
    this.marginTopMm = 0,
    this.marginLeftMm = 0,
    this.gapXMm = 0,
    this.gapYMm = 0,
  });

  const PaperFormat.roll({
    required this.id,
    this.name = '',
    required double widthMm,
    required double heightMm,
  }) : kind = PrintTemplateKind.productLabel,
       feed = PaperFeed.roll,
       pageWidthMm = widthMm,
       pageHeightMm = heightMm,
       columns = 1,
       rows = 1,
       cellWidthMm = widthMm,
       cellHeightMm = heightMm,
       marginTopMm = 0,
       marginLeftMm = 0,
       gapXMm = 0,
       gapYMm = 0;

  /// A single page as big as [widthMm] x [heightMm], used when a template
  /// points to a paper format that no longer exists.
  const PaperFormat.single({
    required this.kind,
    required double widthMm,
    required double heightMm,
  }) : id = '',
       name = '',
       feed = PaperFeed.roll,
       pageWidthMm = widthMm,
       pageHeightMm = heightMm,
       columns = 1,
       rows = 1,
       cellWidthMm = widthMm,
       cellHeightMm = heightMm,
       marginTopMm = 0,
       marginLeftMm = 0,
       gapXMm = 0,
       gapYMm = 0;

  int get cellsPerPage => columns * rows;

  bool get isMultiCellSheet => feed == PaperFeed.sheet && cellsPerPage > 1;

  /// Top-left corner of the cell at [index] (0-based, row by row).
  ({double leftMm, double topMm}) cellOrigin(int index) {
    final column = index % columns;
    final row = (index ~/ columns) % rows;
    return (
      leftMm: marginLeftMm + column * (cellWidthMm + gapXMm),
      topMm: marginTopMm + row * (cellHeightMm + gapYMm),
    );
  }

  /// Positions skipped on each sheet needed to print [labels] labels.
  ///
  /// [requested] holds the positions already used at the start of each sheet
  /// (sheet 1 first); missing entries count as 0. The result has one entry
  /// per sheet that will be printed, so its length is the number of sheets.
  /// Only multi-label sheets skip positions: rolls and single-page formats
  /// always start from the first position.
  List<int> sheetSkips(int labels, List<int> requested) {
    if (labels <= 0) return const [];
    final perSheet = cellsPerPage;
    if (!isMultiCellSheet) {
      return List<int>.filled((labels / perSheet).ceil(), 0);
    }
    final skips = <int>[];
    var placed = 0;
    while (placed < labels) {
      final index = skips.length;
      final skip = index < requested.length
          ? requested[index].clamp(0, perSheet - 1)
          : 0;
      skips.add(skip);
      placed += perSheet - skip;
    }
    return skips;
  }

  /// Name chosen by the shop, or a description built from the measures.
  String displayName(AppLocalizations l10n) =>
      name.trim().isNotEmpty ? name : describe(l10n);

  /// Description built from the measures, e.g. "A4 sheet · 24 labels 70×37 mm".
  String describe(AppLocalizations l10n) {
    final cell = '${formatMm(cellWidthMm)}×${formatMm(cellHeightMm)}';
    if (feed == PaperFeed.roll) return l10n.reportPaperRoll(cell);
    final page = '${formatMm(pageWidthMm)}×${formatMm(pageHeightMm)}';
    return l10n.reportPaperSheetDescription(page, cellsPerPage, cell);
  }

  static String formatMm(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  PaperFormat copyWith({String? id, String? name}) => PaperFormat(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind,
    feed: feed,
    pageWidthMm: pageWidthMm,
    pageHeightMm: pageHeightMm,
    columns: columns,
    rows: rows,
    cellWidthMm: cellWidthMm,
    cellHeightMm: cellHeightMm,
    marginTopMm: marginTopMm,
    marginLeftMm: marginLeftMm,
    gapXMm: gapXMm,
    gapYMm: gapYMm,
  );

  MgwsPrintItem toItem() => MgwsPrintItem(
    id: id,
    name: name,
    data: {
      'kind': kind.name,
      'feed': feed.name,
      'page_width_mm': pageWidthMm,
      'page_height_mm': pageHeightMm,
      'columns': columns,
      'rows': rows,
      'cell_width_mm': cellWidthMm,
      'cell_height_mm': cellHeightMm,
      'margin_top_mm': marginTopMm,
      'margin_left_mm': marginLeftMm,
      'gap_x_mm': gapXMm,
      'gap_y_mm': gapYMm,
    },
  );

  /// Returns null when the stored data is incomplete or out of range.
  static PaperFormat? tryFromItem(MgwsPrintItem item) {
    final data = item.data;
    final kind = PrintTemplateKind.values
        .where((value) => value.name == data['kind'])
        .firstOrNull;
    final feed = PaperFeed.values
        .where((value) => value.name == data['feed'])
        .firstOrNull;
    double number(String key) => (data[key] as num?)?.toDouble() ?? 0;
    int count(String key) => (data[key] as num?)?.toInt() ?? 0;
    if (kind == null || feed == null) return null;
    final format = PaperFormat(
      id: item.id,
      name: item.name,
      kind: kind,
      feed: feed,
      pageWidthMm: number('page_width_mm'),
      pageHeightMm: number('page_height_mm'),
      columns: feed == PaperFeed.roll ? 1 : count('columns'),
      rows: feed == PaperFeed.roll ? 1 : count('rows'),
      cellWidthMm: number('cell_width_mm'),
      cellHeightMm: number('cell_height_mm'),
      marginTopMm: number('margin_top_mm'),
      marginLeftMm: number('margin_left_mm'),
      gapXMm: number('gap_x_mm'),
      gapYMm: number('gap_y_mm'),
    );
    return format.validationError == null ? format : null;
  }

  /// Why the measures cannot print, or null when they are valid.
  PaperFormatError? get validationError {
    if (pageWidthMm <= 0 ||
        pageHeightMm <= 0 ||
        cellWidthMm <= 0 ||
        cellHeightMm <= 0) {
      return PaperFormatError.sizeMissing;
    }
    if (columns < 1 || rows < 1 || columns > 20 || rows > 40) {
      return PaperFormatError.gridOutOfRange;
    }
    final usedWidth =
        marginLeftMm + columns * cellWidthMm + (columns - 1) * gapXMm;
    final usedHeight = marginTopMm + rows * cellHeightMm + (rows - 1) * gapYMm;
    if (usedWidth > pageWidthMm + 0.5 || usedHeight > pageHeightMm + 0.5) {
      return PaperFormatError.cellsOutsidePage;
    }
    return null;
  }
}

/// Reasons a paper format cannot be saved.
enum PaperFormatError { sizeMissing, gridOutOfRange, cellsOutsidePage }

/// Paper formats loaded the first time the print library is set up on a site.
/// After that they are ordinary items the shop can change or delete.
class PaperFormatDefaults {
  PaperFormatDefaults._();

  static List<PaperFormat> all(AppLocalizations l10n) {
    final formats = <PaperFormat>[
      // Adhesive A4 sheets, common office-supply layouts.
      const PaperFormat(
        id: 'a4_3x8',
        kind: PrintTemplateKind.productLabel,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 3,
        rows: 8,
        cellWidthMm: 70,
        cellHeightMm: 37,
        marginTopMm: 0.5,
      ),
      const PaperFormat(
        id: 'a4_3x7',
        kind: PrintTemplateKind.productLabel,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 3,
        rows: 7,
        cellWidthMm: 70,
        cellHeightMm: 42.4,
      ),
      const PaperFormat(
        id: 'a4_4x10',
        kind: PrintTemplateKind.productLabel,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 4,
        rows: 10,
        cellWidthMm: 48.5,
        cellHeightMm: 25.4,
        marginTopMm: 21.5,
        marginLeftMm: 8,
      ),
      const PaperFormat(
        id: 'a4_5x13',
        kind: PrintTemplateKind.productLabel,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 5,
        rows: 13,
        cellWidthMm: 38.1,
        cellHeightMm: 21.2,
        marginTopMm: 10.7,
        marginLeftMm: 4.75,
        gapXMm: 2.5,
      ),
      // Thermal label rolls.
      const PaperFormat.roll(id: 'roll_50x30', widthMm: 50, heightMm: 30),
      const PaperFormat.roll(id: 'roll_40x30', widthMm: 40, heightMm: 30),
      const PaperFormat.roll(id: 'roll_58x40', widthMm: 58, heightMm: 40),
      const PaperFormat.roll(id: 'roll_62x29', widthMm: 62, heightMm: 29),
      // Shop signs.
      const PaperFormat(
        id: 'sign_a4_portrait',
        kind: PrintTemplateKind.shopSign,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 1,
        rows: 1,
        cellWidthMm: 210,
        cellHeightMm: 297,
      ),
      const PaperFormat(
        id: 'sign_a4_landscape',
        kind: PrintTemplateKind.shopSign,
        feed: PaperFeed.sheet,
        pageWidthMm: 297,
        pageHeightMm: 210,
        columns: 1,
        rows: 1,
        cellWidthMm: 297,
        cellHeightMm: 210,
      ),
      const PaperFormat(
        id: 'sign_a5',
        kind: PrintTemplateKind.shopSign,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 1,
        rows: 2,
        cellWidthMm: 210,
        cellHeightMm: 148.5,
      ),
      const PaperFormat(
        id: 'sign_a6',
        kind: PrintTemplateKind.shopSign,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 2,
        rows: 2,
        cellWidthMm: 105,
        cellHeightMm: 148.5,
      ),
      // Reports.
      const PaperFormat(
        id: 'report_a4_portrait',
        kind: PrintTemplateKind.report,
        feed: PaperFeed.sheet,
        pageWidthMm: 210,
        pageHeightMm: 297,
        columns: 1,
        rows: 1,
        cellWidthMm: 210,
        cellHeightMm: 297,
      ),
      const PaperFormat(
        id: 'report_a4_landscape',
        kind: PrintTemplateKind.report,
        feed: PaperFeed.sheet,
        pageWidthMm: 297,
        pageHeightMm: 210,
        columns: 1,
        rows: 1,
        cellWidthMm: 297,
        cellHeightMm: 210,
      ),
    ];
    return [
      for (final format in formats)
        format.copyWith(name: _defaultName(l10n, format)),
    ];
  }

  static String _defaultName(AppLocalizations l10n, PaperFormat format) {
    switch (format.id) {
      case 'sign_a4_portrait':
        return l10n.reportPaperSignA4Portrait;
      case 'sign_a4_landscape':
        return l10n.reportPaperSignA4Landscape;
      case 'sign_a5':
        return l10n.reportPaperSignA5;
      case 'sign_a6':
        return l10n.reportPaperSignA6;
      case 'report_a4_portrait':
        return l10n.reportPaperReportPortrait;
      case 'report_a4_landscape':
        return l10n.reportPaperReportLandscape;
    }
    final cell =
        '${PaperFormat.formatMm(format.cellWidthMm)}×${PaperFormat.formatMm(format.cellHeightMm)}';
    return format.feed == PaperFeed.roll
        ? l10n.reportPaperRoll(cell)
        : l10n.reportPaperLabelSheet(format.cellsPerPage, cell);
  }
}
