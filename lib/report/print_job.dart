import 'package:flutter/foundation.dart';

import '../prodotti/class_prodotti.dart';
import '../traduzioni/mappa_attributi.dart';

/// One product or variant to label. It always prints one label per piece in
/// stock: the number cannot be changed, only the whole line removed.
class PrintLabelItem {
  final ProdottoGlobal product;
  final VarianteProductGlobal? variant;

  const PrintLabelItem({required this.product, this.variant});

  /// Labels printed for this line: one per piece in stock.
  int get quantity => stock;

  String get key => '${product.id}-${variant?.id ?? 0}';

  /// Pieces available in stock: the default number of labels.
  int get stock => variant?.quantita ?? product.quantitaTotale ?? 0;

  String get name => product.nome ?? '';

  String get color => _attribute(AttributoCanonico.color);

  String get size => _attribute(AttributoCanonico.size);

  double get price {
    final variant = this.variant;
    if (variant != null) return variant.prezzoEffettivo;
    return product.prezzoEffettivo;
  }

  /// The full price, when the item is discounted.
  double? get oldPrice {
    final variant = this.variant;
    if (variant != null) {
      return variant.prezzoScontato != null &&
              variant.prezzoScontato! < variant.prezzo
          ? variant.prezzo
          : null;
    }
    final regular = product.prezzoNormale;
    final sale = product.prezzoScontato;
    return sale != null && regular != null && sale < regular ? regular : null;
  }

  int? get discountPercent {
    final original = oldPrice;
    if (original == null || original <= 0) return null;
    return ((1 - price / original) * 100).round();
  }

  String get sku {
    final variant = this.variant;
    if (variant != null && variant.codiceProdotto.isNotEmpty)
      return variant.codiceProdotto;
    return product.codiceProdotto ?? '';
  }

  String get barcode {
    final variant = this.variant;
    if (variant != null && variant.barcodeInterno.isNotEmpty)
      return variant.barcodeInterno;
    return product.barcodeInterno ?? '';
  }

  String get manufacturerBarcode {
    final variant = this.variant;
    if (variant != null && variant.barcodeFornitore.isNotEmpty)
      return variant.barcodeFornitore;
    return product.barcodeProduttore ?? '';
  }

  /// Option of the colour or size attribute of the variant. Catalogues may
  /// call the attributes `Color`/`Size` or `Colore`/`Taglia`: the same
  /// recognition used by the product screens finds either.
  String _attribute(AttributoCanonico canonical) {
    final attributes = variant?.attributi ?? const <AttributoVariante>[];
    final match = trovaAttributo(canonical, [
      for (var index = 0; index < attributes.length; index++)
        AttributoCatalogo(id: index, nome: attributes[index].nome),
    ]);
    return match == null ? '' : attributes[match.id].opzione;
  }
}

/// Labels requested from another section, e.g. the products list.
class PrintJob {
  final List<PrintLabelItem> items;

  const PrintJob(this.items);

  int get totalLabels => items.fold(0, (sum, item) => sum + item.quantity);

  /// One entry per label to print, in order.
  List<PrintLabelItem> get expanded => [
    for (final item in items)
      for (var copy = 0; copy < item.quantity; copy++) item,
  ];

  /// The job with the lines of [other] it does not have yet, appended at
  /// the end: a variant already in the job is never doubled.
  PrintJob merge(PrintJob other) {
    final known = items.map((item) => item.key).toSet();
    return PrintJob([
      ...items,
      for (final item in other.items)
        if (known.add(item.key)) item,
    ]);
  }

  /// The job without the line [key].
  PrintJob without(String key) => PrintJob([
    for (final item in items)
      if (item.key != key) item,
  ]);

  /// Builds the job from products and their selected variants: one line per
  /// variant (or per simple product) with pieces in stock. Variants and
  /// products with no pieces are left out.
  factory PrintJob.fromProducts(List<ProdottoGlobal> products) {
    final items = <PrintLabelItem>[];
    for (final product in products) {
      final variants = product.varianti ?? const <VarianteProductGlobal>[];
      final lines = variants.isEmpty
          ? [PrintLabelItem(product: product)]
          : [
              for (final variant in variants)
                PrintLabelItem(product: product, variant: variant),
            ];
      items.addAll(lines.where((item) => item.stock > 0));
    }
    return PrintJob(items);
  }
}

/// Id of the "Templates and print" section in the home. It stays `report`
/// so saved desktop layouts keep finding the section.
const String printSectionId = 'report';

/// Hands a print job from another section to the print section, which opens
/// its Print tab on it.
final ValueNotifier<PrintJob?> pendingPrintJob = ValueNotifier<PrintJob?>(null);
