import 'package:intl/intl.dart';

import '../products/class_products.dart';
import '../l10n/extensions.dart';
import 'print_job.dart';
import 'package:report_flutter/report_flutter.dart';

/// What data a template is bound to: a product (labels and shop signs) or
/// report figures. It is a setting of the template, stored under `kind`, the
/// key already saved with the templates; templates without it are product
/// labels.
enum ShopTemplateKind { productLabel, shopSign, report }

extension ShopTemplateKindOf on PrintTemplate {
  static const String settingKey = 'kind';

  ShopTemplateKind get shopKind =>
      ShopTemplateKind.values
          .where((kind) => kind.name == settings[settingKey])
          .firstOrNull ??
      ShopTemplateKind.productLabel;
}

/// Data the print templates are bound to.
///
/// Every key is a field the designer offers for drag and drop. Product keys
/// reuse `ProdottoGlobal.toMap()` (already used by the designer) and add the
/// variant and pre-formatted values a label needs. The keys are stored inside
/// saved templates, so they must not be renamed.
///
/// Labels printed from the products list use the real product and variant
/// data ([labelData]); previews, the designer and reports use realistic
/// example values, because sales and stock reports are not connected yet.
class PrintSampleData {
  PrintSampleData._();

  static Map<String, dynamic> forTemplate(
    PrintTemplate template,
    AppLocalizations l10n,
    String localeName,
  ) {
    switch (template.shopKind) {
      case ShopTemplateKind.productLabel:
      case ShopTemplateKind.shopSign:
        return labelData(
          sampleItem(l10n),
          localeName,
          separator: variantSeparatorOf(template),
        );
      case ShopTemplateKind.report:
        return report(l10n, localeName);
    }
  }

  /// Template setting that holds the colour/size separator; the key is the
  /// one already stored with the templates.
  static const String variantSeparatorKey = 'variant_separator';

  /// Separator printed between colour and size when none was chosen.
  static const String defaultVariantSeparator = ' - ';

  static String variantSeparatorOf(PrintTemplate template) =>
      template.settings[variantSeparatorKey]?.toString() ??
      defaultVariantSeparator;

  /// Colour first, then size: "Navy blue - M".
  static String colorAndSize(String color, String size, String separator) =>
      [color, size].where((part) => part.isNotEmpty).join(separator);

  /// Example product used by previews and the designer.
  static PrintLabelItem sampleItem(AppLocalizations l10n) {
    final product = ProdottoGlobal(
      id: 1001,
      nome: l10n.reportSampleProduct1,
      codiceProdotto: 'MAG-COT',
      marca: l10n.reportSampleBrand,
      inStock: true,
      quantitaTotale: 24,
      status: 'publish',
    );
    final variant = VarianteProductGlobal(
      id: 2001,
      nome: l10n.reportSampleProduct1,
      attributi: [
        AttributoVariante(nome: 'Color', opzione: l10n.reportSampleColorNavy),
        AttributoVariante(nome: 'Size', opzione: 'M'),
      ],
      codiceProdotto: 'MAG-COT-M-BLU',
      barcodeInterno: '8001234567890',
      barcodeFornitore: '8009876543210',
      prezzo: 39.90,
      prezzoScontato: 29.90,
      quantita: 24,
    );
    return PrintLabelItem(product: product, variant: variant);
  }

  /// Fields of one label. Product keys come from `ProdottoGlobal.toMap()`;
  /// variant values (code, barcode, prices) replace the product ones.
  static Map<String, dynamic> labelData(
    PrintLabelItem item,
    String localeName, {
    String separator = defaultVariantSeparator,
  }) {
    final money = NumberFormat.currency(locale: localeName, symbol: '€');
    final oldPrice = item.oldPrice;
    final discount = item.discountPercent;
    final colorAndSizeText = colorAndSize(item.color, item.size, separator);
    return {
      ...item.product.toMap(),
      'sku': item.sku,
      'global_unique_id': item.barcode,
      'barcode_manufacturer': item.manufacturerBarcode,
      'prezzoEffettivo': item.price,
      'quantitaTotale': item.stock,
      'taglia': item.size,
      'colore': item.color,
      'coloreTaglia': colorAndSizeText,
      // Older name of the same field, kept for templates saved with it.
      'tagliaColore': colorAndSizeText,
      'prezzoTesto': money.format(item.price),
      'prezzoPrecedenteTesto': oldPrice == null ? '' : money.format(oldPrice),
      'scontoTesto': discount == null || discount <= 0 ? '' : '-$discount%',
    };
  }

  static Map<String, dynamic> report(AppLocalizations l10n, String localeName) {
    final money = NumberFormat.currency(locale: localeName, symbol: '€');
    final number = NumberFormat.decimalPattern(localeName);
    final dates = DateFormat.yMd(localeName);
    final today = DateTime.now();
    final products = [
      l10n.reportSampleProduct1,
      l10n.reportSampleProduct2,
      l10n.reportSampleProduct3,
      l10n.reportSampleProduct4,
      l10n.reportSampleProduct5,
      l10n.reportSampleProduct6,
    ];
    const separator = defaultVariantSeparator;
    final variants = [
      colorAndSize(l10n.reportSampleColorNavy, 'M', separator),
      colorAndSize(l10n.reportSampleColorBlack, 'L', separator),
      colorAndSize(l10n.reportSampleColorGrey, 'S', separator),
      colorAndSize(l10n.reportSampleColorWhite, '40', separator),
      colorAndSize(l10n.reportSampleColorBeige, 'M', separator),
      colorAndSize(l10n.reportSampleColorWhite, '42', separator),
    ];
    const soldPieces = [42, 31, 27, 18, 12, 9];
    const soldRevenue = [1255.80, 1859.00, 1293.30, 989.10, 828.00, 711.00];
    const stockPieces = [24, 3, 15, 8, 2, 11];
    const stockValue = [717.60, 179.70, 673.50, 359.20, 138.00, 869.00];
    const movedPieces = ['+24', '-2', '-1', '+12', '-5', '-1'];
    final movementTypes = [
      l10n.reportSampleMovementLoad,
      l10n.reportSampleMovementSale,
      l10n.reportSampleMovementAdjustment,
      l10n.reportSampleMovementLoad,
      l10n.reportSampleMovementTransfer,
      l10n.reportSampleMovementSale,
    ];

    return {
      'dataStampa': DateFormat.yMd(localeName).add_Hm().format(today),
      'giornata': dates.format(today),
      'cassa': l10n.reportSampleRegister,
      'periodo': DateFormat.yMMMM(localeName).format(today),
      'periodoDal': dates.format(today.subtract(const Duration(days: 6))),
      'periodoAl': dates.format(today),
      // Daily closing
      'incassoTotale': money.format(1686.60),
      'numeroScontrini': number.format(38),
      'scontrinoMedio': money.format(44.38),
      'differenzaCassa': money.format(-2.50),
      'pagamenti': [
        {
          'metodo': l10n.reportSamplePaymentCash,
          'importo': money.format(412.50),
        },
        {
          'metodo': l10n.reportSamplePaymentCard,
          'importo': money.format(1289.00),
        },
        {
          'metodo': l10n.reportSamplePaymentVoucher,
          'importo': money.format(45.00),
        },
        {
          'metodo': l10n.reportSamplePaymentReturns,
          'importo': money.format(-59.90),
        },
      ],
      'contanti': [
        {
          'voce': l10n.reportSampleOpeningFloat,
          'importo': money.format(150.00),
        },
        {
          'voce': l10n.reportSampleExpectedCash,
          'importo': money.format(562.50),
        },
        {'voce': l10n.reportSampleCountedCash, 'importo': money.format(560.00)},
        {'voce': l10n.reportSampleDifference, 'importo': money.format(-2.50)},
      ],
      // Sales
      'fatturato': money.format(6936.20),
      'pezziVenduti': number.format(139),
      'scontriniPeriodo': number.format(96),
      'resi': number.format(4),
      'prodottiVenduti': [
        for (var index = 0; index < products.length; index++)
          {
            'prodotto': products[index],
            'pezzi': number.format(soldPieces[index]),
            'incasso': money.format(soldRevenue[index]),
          },
      ],
      // Stock
      'articoli': number.format(6),
      'pezziMagazzino': number.format(63),
      'valoreMagazzino': money.format(2937.00),
      'sottoScorta': number.format(2),
      'giacenze': [
        for (var index = 0; index < products.length; index++)
          {
            'prodotto': products[index],
            'variante': variants[index],
            'codice': 'SKU-${1001 + index}',
            'quantita': number.format(stockPieces[index]),
            'valore': money.format(stockValue[index]),
          },
      ],
      // Stock movements
      'carichi': number.format(36),
      'scarichi': number.format(9),
      'rettifiche': number.format(1),
      'movimenti': [
        for (var index = 0; index < products.length; index++)
          {
            'data': dates.format(today.subtract(Duration(days: 5 - index))),
            'prodotto': products[index],
            'tipo': movementTypes[index],
            'quantita': movedPieces[index],
          },
      ],
    };
  }
}
