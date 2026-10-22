import 'package:report_flutter/report_flutter.dart';

import '../l10n/extensions.dart';
import 'print_sample_data.dart';

/// Default print library: the templates and categories loaded on MGWS the
/// first time the print section is set up on a site. After that they are
/// ordinary items the shop can change or delete.
///
/// Each template is a designer layout (`ReportTemplate`) built with the
/// library `PrintDesign`, measured in millimetres: font sizes, stroke widths
/// and positions use the same unit the designer shows on its rulers. Dynamic
/// fields are bound to the keys of `PrintSampleData`.
///
/// Names and default texts use the language of the manager who loads them.
class PrintTemplateCatalog {
  PrintTemplateCatalog._();

  static const String labelsCategory = 'labels';
  static const String saleCategory = 'sale';
  static const String signsCategory = 'signs';
  static const String reportsCategory = 'reports';

  static List<PrintCategory> defaultCategories(AppLocalizations l10n) => [
    PrintCategory(
      id: labelsCategory,
      name: l10n.reportCategoryLabels,
      position: 0,
    ),
    PrintCategory(id: saleCategory, name: l10n.reportCategorySale, position: 1),
    PrintCategory(
      id: signsCategory,
      name: l10n.reportCategorySigns,
      position: 2,
    ),
    PrintCategory(
      id: reportsCategory,
      name: l10n.reportCategoryReports,
      position: 3,
    ),
  ];

  static const String _ink = '#1F2937';
  static const String _grey = '#6B7280';
  static const String _red = '#C62828';
  static const String _teal = '#00796B';
  static const String _navy = '#1E3A8A';
  static const String _gold = '#9A7B4F';
  static const String _purple = '#6A1B9A';
  static const String _white = '#FFFFFF';

  static List<PrintTemplate> defaultTemplates(AppLocalizations l10n) => [
    ..._labels(l10n),
    ..._signs(l10n),
    ..._reports(l10n),
  ];

  static PrintTemplate _builtIn({
    required String id,
    required String name,
    required ShopTemplateKind kind,
    required String paperFormatId,
    required PrintDesign design,
    String? category,
  }) {
    return PrintTemplate(
      id: id,
      name: name,
      categoryId: category ?? _defaultCategory(kind),
      paperFormatId: paperFormatId,
      design: design.build(
        id: id,
        name: name,
        reportType: kind == ShopTemplateKind.report
            ? ReportType.document
            : ReportType.label,
      ),
      settings: {ShopTemplateKindOf.settingKey: kind.name},
    );
  }

  static String _defaultCategory(ShopTemplateKind kind) => switch (kind) {
    ShopTemplateKind.productLabel => labelsCategory,
    ShopTemplateKind.shopSign => signsCategory,
    ShopTemplateKind.report => reportsCategory,
  };

  // ---------------------------------------------------------------------------
  // Product labels
  // ---------------------------------------------------------------------------

  static List<PrintTemplate> _labels(AppLocalizations l10n) {
    const kind = ShopTemplateKind.productLabel;

    // Designed by the shop in the app designer: barcode on top, then name and
    // colour/size, with old price, discount and price on the bottom row.
    final shopLabel = PrintDesign(70, 37)
      ..barcode('global_unique_id', 2.42, 2.25, 65.03, 13.5)
      ..field('nome', 2.5, 15.75, 65, 5.5, size: 3.2, bold: true)
      ..field('coloreTaglia', 2.42, 22.5, 65, 4.5, size: 2.4)
      ..field(
        'prezzoPrecedenteTesto',
        2.42,
        27,
        22.47,
        10,
        size: 5,
        align: 'center',
      )
      ..field('scontoTesto', 24.92, 27, 20, 10, size: 5, align: 'center')
      ..field(
        'prezzoTesto',
        44.92,
        27,
        22.94,
        10,
        size: 5.6,
        bold: true,
        align: 'center',
      );

    final classic = PrintDesign(70, 37)
      ..field('nome', 2.5, 2.5, 65, 5.5, size: 3.2, bold: true)
      ..field('coloreTaglia', 2.5, 8.5, 65, 4.5, size: 2.4)
      ..field(
        'prezzoTesto',
        2.5,
        24,
        33,
        10,
        size: 5.6,
        bold: true,
        verticalAlign: 'bottom',
      )
      ..barcode('global_unique_id', 37, 21, 30.5, 13.5);

    final bigPrice = PrintDesign(50, 30)
      ..field('nome', 2, 1.5, 46, 4.5, size: 2.6, bold: true, align: 'center')
      ..field(
        'prezzoTesto',
        2,
        7,
        46,
        13,
        size: 8.5,
        bold: true,
        align: 'center',
        color: _navy,
      )
      ..field('coloreTaglia', 2, 24.5, 28, 4, size: 2.1)
      ..field('sku', 28, 24.5, 20, 4, size: 1.8, align: 'right', color: _grey);

    final sale = PrintDesign(70, 37)
      ..rectangle(0, 0, 70, 7, fill: _red, strokeWidth: 0)
      ..text(
        l10n.reportDefaultSaleTitle.toUpperCase(),
        2.5,
        0.5,
        40,
        6,
        size: 2.8,
        bold: true,
        color: _white,
      )
      ..field(
        'scontoTesto',
        45,
        0.5,
        22.5,
        6,
        size: 3.2,
        bold: true,
        color: _white,
        align: 'right',
      )
      ..field('nome', 2.5, 8.5, 65, 5, size: 2.8, bold: true)
      ..field('coloreTaglia', 2.5, 13.5, 65, 4, size: 2.2)
      ..field(
        'prezzoPrecedenteTesto',
        2.5,
        21,
        32,
        4.5,
        size: 2.6,
        color: _grey,
        strike: true,
      )
      ..field(
        'prezzoTesto',
        2.5,
        25.5,
        33,
        9,
        size: 5.2,
        bold: true,
        color: _red,
      )
      ..barcode('global_unique_id', 38, 20, 29.5, 14);

    final minimal = PrintDesign(40, 30)
      ..field('nome', 2, 2.5, 36, 8, size: 2.6, align: 'center', maxLines: 2)
      ..field(
        'coloreTaglia',
        2,
        11,
        36,
        3.5,
        size: 2,
        align: 'center',
        color: _grey,
      )
      ..line(14, 16, 12, color: _ink, strokeWidth: 0.3)
      ..field(
        'prezzoTesto',
        2,
        18,
        36,
        9,
        size: 4.6,
        bold: true,
        align: 'center',
      );

    final boutique = PrintDesign(70, 42.4)
      ..rectangle(2, 2, 66, 38.4, stroke: _gold, strokeWidth: 0.3)
      ..text(
        l10n.reportDefaultShopName.toUpperCase(),
        4,
        4,
        62,
        4.5,
        size: 2,
        color: _gold,
        align: 'center',
        serif: true,
      )
      ..line(25, 9.5, 20, color: _gold, strokeWidth: 0.2)
      ..field('nome', 4, 11, 62, 6, size: 2.8, align: 'center', serif: true)
      ..field(
        'coloreTaglia',
        4,
        17,
        62,
        4,
        size: 2.1,
        align: 'center',
        color: _grey,
      )
      ..field(
        'prezzoTesto',
        5,
        28,
        40,
        9,
        size: 4.4,
        bold: true,
        serif: true,
        verticalAlign: 'bottom',
      )
      ..qrCode('global_unique_id', 52, 24.5, 13, 13);

    final barcode = PrintDesign(48.5, 25.4)
      ..field('nome', 1.5, 1, 45.5, 3.5, size: 2.2, bold: true, align: 'center')
      ..field('coloreTaglia', 1.5, 4.3, 45.5, 3, size: 1.9, align: 'center')
      ..barcode('global_unique_id', 3, 7.8, 42.5, 11)
      ..field('sku', 1.5, 20, 26, 4, size: 1.7, color: _grey)
      ..field(
        'prezzoTesto',
        27,
        19.5,
        20,
        5,
        size: 3.2,
        bold: true,
        align: 'right',
      );

    return [
      _builtIn(
        id: 'builtin_label_shop',
        name: l10n.reportTemplateLabelShop,
        kind: kind,
        paperFormatId: 'a4_3x8',
        design: shopLabel,
      ),
      _builtIn(
        id: 'builtin_label_classic',
        name: l10n.reportTemplateLabelClassic,
        kind: kind,
        paperFormatId: 'a4_3x8',
        design: classic,
      ),
      _builtIn(
        id: 'builtin_label_big_price',
        name: l10n.reportTemplateLabelBigPrice,
        kind: kind,
        paperFormatId: 'roll_50x30',
        design: bigPrice,
      ),
      _builtIn(
        id: 'builtin_label_sale',
        name: l10n.reportTemplateLabelSale,
        kind: kind,
        paperFormatId: 'a4_3x8',
        category: saleCategory,
        design: sale,
      ),
      _builtIn(
        id: 'builtin_label_minimal',
        name: l10n.reportTemplateLabelMinimal,
        kind: kind,
        paperFormatId: 'roll_40x30',
        design: minimal,
      ),
      _builtIn(
        id: 'builtin_label_boutique',
        name: l10n.reportTemplateLabelBoutique,
        kind: kind,
        paperFormatId: 'a4_3x7',
        design: boutique,
      ),
      _builtIn(
        id: 'builtin_label_barcode',
        name: l10n.reportTemplateLabelBarcode,
        kind: kind,
        paperFormatId: 'a4_4x10',
        design: barcode,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Shop signs
  // ---------------------------------------------------------------------------

  static List<PrintTemplate> _signs(AppLocalizations l10n) {
    const kind = ShopTemplateKind.shopSign;
    final shop = l10n.reportDefaultShopName.toUpperCase();

    final sale = PrintDesign(210, 297)
      ..rectangle(0, 0, 210, 297, fill: _red, strokeWidth: 0)
      ..text(shop, 15, 15, 180, 12, size: 7, color: _white, align: 'center')
      ..text(
        l10n.reportDefaultSaleTitle.toUpperCase(),
        10,
        70,
        190,
        45,
        size: 34,
        bold: true,
        color: _white,
        align: 'center',
      )
      ..text(
        '-30%',
        10,
        118,
        190,
        72,
        size: 64,
        bold: true,
        color: _white,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultSaleSubtitle,
        15,
        195,
        180,
        15,
        size: 10.5,
        color: _white,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultSaleFooter,
        15,
        262,
        180,
        12,
        size: 6.3,
        color: _white,
        align: 'center',
      );

    final newArrivals = PrintDesign(297, 210)
      ..rectangle(12, 12, 273, 186, stroke: _teal, strokeWidth: 2.2)
      ..rectangle(128, 28, 41, 2, fill: _teal, strokeWidth: 0)
      ..text(
        l10n.reportDefaultNewArrivalsTitle.toUpperCase(),
        25,
        58,
        247,
        38,
        size: 29,
        bold: true,
        color: _teal,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultNewArrivalsSubtitle,
        25,
        100,
        247,
        16,
        size: 11,
        color: _ink,
        align: 'center',
      )
      ..text(
        shop,
        25,
        158,
        247,
        11,
        size: 7.7,
        bold: true,
        color: _teal,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultNewArrivalsFooter,
        25,
        172,
        247,
        9,
        size: 5.6,
        color: _grey,
        align: 'center',
      );

    final shelfPrice = PrintDesign(105, 148.5)
      ..rectangle(0, 0, 105, 26, fill: _navy, strokeWidth: 0)
      ..text(
        l10n.reportDefaultShelfTitle.toUpperCase(),
        4,
        4,
        97,
        11,
        size: 7,
        bold: true,
        color: _white,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultShopName,
        4,
        16,
        97,
        7,
        size: 3.2,
        color: _white,
        align: 'center',
      )
      ..field(
        'nome',
        5,
        32,
        95,
        16,
        size: 6,
        bold: true,
        align: 'center',
        maxLines: 2,
      )
      ..text(
        l10n.reportDefaultShelfSubtitle,
        5,
        50,
        95,
        8,
        size: 4,
        color: _grey,
        align: 'center',
      )
      ..field(
        'prezzoPrecedenteTesto',
        5,
        70,
        95,
        11,
        size: 7,
        color: _grey,
        align: 'center',
        strike: true,
      )
      ..field(
        'prezzoTesto',
        5,
        83,
        95,
        26,
        size: 19,
        bold: true,
        color: _navy,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultShelfFooter,
        5,
        132,
        95,
        8,
        size: 3,
        color: _grey,
        align: 'center',
      );

    final promo = PrintDesign(210, 148.5)
      ..rectangle(
        5,
        5,
        200,
        138.5,
        fill: '#F3E5F5',
        stroke: _purple,
        strokeWidth: 1.4,
        radius: 6,
      )
      ..text(
        shop,
        15,
        13,
        180,
        9,
        size: 5.5,
        bold: true,
        color: _purple,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultPromoTitle,
        15,
        30,
        180,
        58,
        size: 42,
        bold: true,
        color: _purple,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultPromoSubtitle,
        15,
        92,
        180,
        16,
        size: 10,
        bold: true,
        color: _ink,
        align: 'center',
      )
      ..text(
        l10n.reportDefaultPromoFooter,
        15,
        122,
        180,
        9,
        size: 5,
        color: _grey,
        align: 'center',
      );

    return [
      _builtIn(
        id: 'builtin_sign_sale',
        name: l10n.reportTemplateSignSale,
        kind: kind,
        paperFormatId: 'a4_portrait',
        category: saleCategory,
        design: sale,
      ),
      _builtIn(
        id: 'builtin_sign_new_arrivals',
        name: l10n.reportTemplateSignNewArrivals,
        kind: kind,
        paperFormatId: 'a4_landscape',
        design: newArrivals,
      ),
      _builtIn(
        id: 'builtin_sign_shelf_price',
        name: l10n.reportTemplateSignShelfPrice,
        kind: kind,
        paperFormatId: 'sign_a6',
        design: shelfPrice,
      ),
      _builtIn(
        id: 'builtin_sign_promo',
        name: l10n.reportTemplateSignPromo,
        kind: kind,
        paperFormatId: 'sign_a5',
        category: saleCategory,
        design: promo,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Reports (A4 portrait)
  // ---------------------------------------------------------------------------

  static List<PrintTemplate> _reports(AppLocalizations l10n) {
    const kind = ShopTemplateKind.report;

    PrintDesign page(String title, String accent) => PrintDesign(210, 297)
      ..text(title, 14, 14, 128, 10, size: 6.5, bold: true, color: _ink)
      ..text(
        l10n.reportDefaultShopName,
        140,
        14,
        56,
        10,
        size: 4,
        bold: true,
        color: accent,
        align: 'right',
      )
      ..rectangle(14, 25.5, 182, 0.7, fill: accent, strokeWidth: 0)
      ..field(
        'dataStampa',
        14,
        284,
        120,
        5,
        size: 2.5,
        color: _grey,
        prefix: '${l10n.reportPrefixPrintedOn} ',
      );

    void figures(
      PrintDesign design,
      String accent,
      List<(String, String)> items,
    ) {
      const top = 34.0;
      const gap = 4.0;
      final width = (182 - gap * (items.length - 1)) / items.length;
      for (var index = 0; index < items.length; index++) {
        final left = 14 + index * (width + gap);
        design
          ..rectangle(
            left,
            top,
            width,
            18,
            fill: _tint(accent),
            strokeWidth: 0,
            radius: 1.5,
          )
          ..rectangle(left, top, 1, 18, fill: accent, strokeWidth: 0)
          ..text(
            items[index].$1,
            left + 3,
            top + 2,
            width - 4,
            5,
            size: 2.7,
            color: _grey,
          )
          ..field(
            items[index].$2,
            left + 3,
            top + 8,
            width - 4,
            8,
            size: 4.8,
            bold: true,
          );
      }
    }

    void signatures(PrintDesign design, List<String> labels) {
      for (var index = 0; index < labels.length; index++) {
        final left = 14 + index * 100.0;
        design
          ..line(left, 262, 80, color: _grey, strokeWidth: 0.2)
          ..text(labels[index], left, 264, 80, 5, size: 2.8, color: _grey);
      }
    }

    void notes(PrintDesign design, double top, double height) {
      design
        ..rectangle(
          14,
          top,
          182,
          height,
          stroke: '#BDBDBD',
          strokeWidth: 0.2,
          radius: 1.5,
        )
        ..text(
          l10n.reportNotesTitle,
          17,
          top + 2,
          60,
          5,
          size: 3,
          bold: true,
          color: _grey,
          verticalAlign: 'top',
        );
    }

    final closing = page(l10n.reportTemplateDailyClosing, _ink)
      ..field(
        'giornata',
        14,
        27.5,
        120,
        5,
        size: 3.4,
        color: _grey,
        prefix: '${l10n.reportPrefixBusinessDay} ',
      )
      ..field(
        'cassa',
        134,
        27.5,
        62,
        5,
        size: 3.4,
        color: _grey,
        align: 'right',
      );
    figures(closing, _ink, [
      (l10n.reportFigureTakings, 'incassoTotale'),
      (l10n.reportFigureReceipts, 'numeroScontrini'),
      (l10n.reportFigureAverageReceipt, 'scontrinoMedio'),
      (l10n.reportFigureCashDifference, 'differenzaCassa'),
    ]);
    closing
      ..text(
        l10n.reportTablePaymentMethods,
        14,
        60,
        182,
        7,
        size: 3.9,
        bold: true,
        color: _ink,
      )
      ..table(
        'pagamenti',
        14,
        68,
        182,
        40,
        accent: _ink,
        columns: [
          PrintColumn('metodo', l10n.reportColumnPaymentMethod, 122),
          PrintColumn('importo', l10n.reportColumnAmount, 60, alignRight: true),
        ],
      )
      ..text(
        l10n.reportTableCashCount,
        14,
        114,
        182,
        7,
        size: 3.9,
        bold: true,
        color: _ink,
      )
      ..table(
        'contanti',
        14,
        122,
        182,
        40,
        accent: _ink,
        columns: [
          PrintColumn('voce', l10n.reportColumnItem, 122),
          PrintColumn('importo', l10n.reportColumnAmount, 60, alignRight: true),
        ],
      );
    notes(closing, 172, 70);
    signatures(closing, [
      l10n.reportSignatureOperator,
      l10n.reportSignatureManager,
    ]);

    final sales = page(l10n.reportTemplateSales, _navy)
      ..field(
        'periodo',
        14,
        27.5,
        182,
        5,
        size: 3.4,
        color: _grey,
        prefix: '${l10n.reportPrefixPeriod} ',
      );
    figures(sales, _navy, [
      (l10n.reportFigureRevenue, 'fatturato'),
      (l10n.reportFigureItemsSold, 'pezziVenduti'),
      (l10n.reportFigureReceipts, 'scontriniPeriodo'),
      (l10n.reportFigureReturns, 'resi'),
    ]);
    sales
      ..text(
        l10n.reportTableTopProducts,
        14,
        60,
        182,
        7,
        size: 3.9,
        bold: true,
        color: _navy,
      )
      ..table(
        'prodottiVenduti',
        14,
        68,
        182,
        120,
        accent: _navy,
        columns: [
          PrintColumn('prodotto', l10n.reportColumnProduct, 112),
          PrintColumn('pezzi', l10n.reportColumnQuantity, 30, alignRight: true),
          PrintColumn(
            'incasso',
            l10n.reportColumnRevenue,
            40,
            alignRight: true,
          ),
        ],
      );
    notes(sales, 200, 70);

    final inventory = page(l10n.reportTemplateInventory, _teal)
      ..field(
        'giornata',
        14,
        27.5,
        182,
        5,
        size: 3.4,
        color: _grey,
        prefix: '${l10n.reportPrefixStockOn} ',
      );
    figures(inventory, _teal, [
      (l10n.reportFigureArticles, 'articoli'),
      (l10n.reportFigurePieces, 'pezziMagazzino'),
      (l10n.reportFigureStockValue, 'valoreMagazzino'),
      (l10n.reportFigureLowStock, 'sottoScorta'),
    ]);
    inventory
      ..text(
        l10n.reportTableStock,
        14,
        60,
        182,
        7,
        size: 3.9,
        bold: true,
        color: _teal,
      )
      ..table(
        'giacenze',
        14,
        68,
        182,
        120,
        accent: _teal,
        columns: [
          PrintColumn('prodotto', l10n.reportColumnProduct, 60),
          PrintColumn('variante', l10n.reportColumnVariant, 40),
          PrintColumn('codice', l10n.reportColumnCode, 28),
          PrintColumn(
            'quantita',
            l10n.reportColumnQuantity,
            20,
            alignRight: true,
          ),
          PrintColumn('valore', l10n.reportColumnValue, 34, alignRight: true),
        ],
      );
    notes(inventory, 196, 56);
    signatures(inventory, [
      l10n.reportSignatureCountedBy,
      l10n.reportSignatureManager,
    ]);

    final movements = page(l10n.reportTemplateStockMovements, _purple)
      ..field(
        'periodoDal',
        14,
        27.5,
        60,
        5,
        size: 3.4,
        color: _grey,
        prefix: '${l10n.reportPrefixFrom} ',
      )
      ..field(
        'periodoAl',
        74,
        27.5,
        60,
        5,
        size: 3.4,
        color: _grey,
        prefix: '${l10n.reportPrefixTo} ',
      );
    figures(movements, _purple, [
      (l10n.reportFigureLoads, 'carichi'),
      (l10n.reportFigureUnloads, 'scarichi'),
      (l10n.reportFigureAdjustments, 'rettifiche'),
    ]);
    movements
      ..text(
        l10n.reportTableMovements,
        14,
        60,
        182,
        7,
        size: 3.9,
        bold: true,
        color: _purple,
      )
      ..table(
        'movimenti',
        14,
        68,
        182,
        150,
        accent: _purple,
        columns: [
          PrintColumn('data', l10n.reportColumnDate, 30),
          PrintColumn('prodotto', l10n.reportColumnProduct, 82),
          PrintColumn('tipo', l10n.reportColumnMovementType, 44),
          PrintColumn(
            'quantita',
            l10n.reportColumnQuantity,
            26,
            alignRight: true,
          ),
        ],
      );
    notes(movements, 226, 50);

    return [
      _builtIn(
        id: 'builtin_report_daily_closing',
        name: l10n.reportTemplateDailyClosing,
        kind: kind,
        paperFormatId: 'a4_portrait',
        design: closing,
      ),
      _builtIn(
        id: 'builtin_report_sales',
        name: l10n.reportTemplateSales,
        kind: kind,
        paperFormatId: 'a4_portrait',
        design: sales,
      ),
      _builtIn(
        id: 'builtin_report_inventory',
        name: l10n.reportTemplateInventory,
        kind: kind,
        paperFormatId: 'a4_portrait',
        design: inventory,
      ),
      _builtIn(
        id: 'builtin_report_stock_movements',
        name: l10n.reportTemplateStockMovements,
        kind: kind,
        paperFormatId: 'a4_portrait',
        design: movements,
      ),
    ];
  }

  /// Very light version of [hex] for summary box backgrounds.
  static String _tint(String hex) {
    final value = int.parse(hex.substring(1), radix: 16);
    String channel(int shift) {
      final base = (value >> shift) & 0xFF;
      final light = (base + (255 - base) * 0.9).round();
      return light.toRadixString(16).padLeft(2, '0');
    }

    return '#${channel(16)}${channel(8)}${channel(0)}'.toUpperCase();
  }
}
