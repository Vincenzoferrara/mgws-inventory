import 'package:flutter/foundation.dart';

import '../l10n/localized_text.dart';
import '../products/class_products.dart';
import '../products/product_barcode_lookup.dart';
import '../products/product_list/product_list.code.dart';
import 'inventory_quick_load.code.dart';

class InventoryQuickLoadCatalogController extends ChangeNotifier {
  InventoryQuickLoadCatalogController({
    ProdottiGestioneController? productsController,
  }) : _productsController = productsController ?? ProdottiGestioneController();

  final ProdottiGestioneController _productsController;
  bool _disposed = false;
  bool isLoading = false;
  int loadedProducts = 0;
  LocalizedText? errorMessage;

  List<ProdottoGlobal> get products => _productsController.prodotti;

  Future<void> load({bool forceRefresh = false}) async {
    if (_disposed || isLoading) return;
    isLoading = true;
    errorMessage = null;
    _notifyListeners();
    try {
      await _productsController.caricaProdotti(
        forceRefresh: forceRefresh,
        onProgress: (items) {
          if (_disposed) return;
          loadedProducts = items.length;
          _notifyListeners();
        },
      );
      if (_disposed) return;
      loadedProducts = products.length;
      errorMessage = _productsController.consumeLastLoadWarning();
    } catch (error) {
      if (_disposed) return;
      errorMessage = literalText(error.toString());
    } finally {
      if (!_disposed) {
        isLoading = false;
        _notifyListeners();
      }
    }
  }

  void search(String query) {
    if (_disposed) return;
    _productsController.setFiltroRicerca(query);
    _notifyListeners();
  }

  bool isVariable(ProdottoGlobal product) {
    return product.variations?.isNotEmpty ?? false;
  }

  Future<List<VarianteProductGlobal>> loadVariants(
    ProdottoGlobal product, {
    bool forceRefresh = false,
  }) async {
    if (_disposed || !isVariable(product)) {
      return const <VarianteProductGlobal>[];
    }
    if (!forceRefresh && (product.varianti?.isNotEmpty ?? false)) {
      return product.varianti!;
    }
    _productsController.selezionaProdottoLocal(product);
    await _productsController.caricaVariantiProdottoSelezionato(
      forceRefresh: forceRefresh,
    );
    if (_disposed) return const <VarianteProductGlobal>[];
    return _productsController.prodottoSelezionato?.varianti ??
        const <VarianteProductGlobal>[];
  }

  /// Trova prodotto o variante a partire da un barcode letto dallo scanner.
  ///
  /// Cerca prima sul catalogo gia caricato (veloce, nessuna rete). Se non
  /// trova nulla, interroga il backend con [cercaProdottoPerBarcode], la
  /// stessa ricerca della cassa. Restituisce
  /// `null` se il codice non e in catalogo: e il chiamante a decidere se
  /// avvisare l'operatore, senza creare righe con prodotti inesistenti.
  Future<InventoryQuickLoadMatch?> ricercaPerBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return null;

    // 1) Catalogo in memoria: rapido e senza rete.
    final inMemory = findByBarcode(code);
    if (inMemory != null) return inMemory;

    // 2) Fallback on-demand, con la stessa ricerca della cassa: le varianti
    //    non sono in memoria finche' non si aprono, quindi un EAN di variante
    //    si trova solo chiedendo al backend.
    return inventoryMatchFromBackend(code);
  }

  /// Trova prodotto o variante a partire da un barcode nel catalogo
  /// gia caricato. Non tocca la rete.
  InventoryQuickLoadMatch? findByBarcode(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) return null;
    for (final product in products) {
      if (_matches(product.barcodeInterno, code) ||
          _matches(product.barcodeProduttore, code)) {
        return InventoryQuickLoadMatch(product: product, barcode: code);
      }
    }
    for (final product in products) {
      for (final variation
          in product.varianti ?? const <VarianteProductGlobal>[]) {
        if (_matches(variation.barcodeInterno, code) ||
            _matches(variation.barcodeFornitore, code)) {
          return InventoryQuickLoadMatch(
            product: product,
            variation: variation,
            barcode: code,
          );
        }
      }
    }
    return null;
  }

  static bool _matches(String? value, String code) {
    final normalized = value?.trim();
    return normalized != null && normalized.isNotEmpty && normalized == code;
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _productsController.dispose();
    super.dispose();
  }
}

String inventoryVariationLabel(VarianteProductGlobal variant) {
  final attributes = variant.attributi
      .map((attribute) => attribute.opzione.trim())
      .where((value) => value.isNotEmpty)
      .join(' / ');
  if (attributes.isNotEmpty) return attributes;
  if (variant.nome.trim().isNotEmpty) return variant.nome.trim();
  return '#${variant.id}';
}

/// Cerca il barcode sul backend con la stessa ricerca della cassa, senza
/// passare dal catalogo in memoria: serve ai pannelli aperti senza catalogo.
Future<InventoryQuickLoadMatch?> inventoryMatchFromBackend(
  String rawCode,
) async {
  final code = rawCode.trim();
  final trovato = await cercaProdottoPerBarcode(code);
  if (trovato == null) return null;
  return InventoryQuickLoadMatch(
    product: trovato.prodotto,
    variation: trovato.variante,
    barcode: code,
  );
}

/// Prodotto o variante identificata tramite un barcode.
///
/// E il ponte fra la lettura dello scanner e la riga di carico: chi chiama
/// [toLine] ottiene una [InventoryQuickLoadLineDraft] gia valorizzata con
/// id, etichetta, barcode e immagine del prodotto trovato.
class InventoryQuickLoadMatch {
  const InventoryQuickLoadMatch({
    required this.product,
    required this.barcode,
    this.variation,
  });

  final ProdottoGlobal product;
  final VarianteProductGlobal? variation;
  final String barcode;

  bool get isVariant => variation != null;
  int get productId => product.id ?? 0;
  int get variationId => variation?.id ?? 0;

  String get productLabel {
    final name = product.nome?.trim();
    return name != null && name.isNotEmpty ? name : '#${product.id ?? 0}';
  }

  String get label {
    final value = variation;
    return value == null
        ? productLabel
        : '$productLabel · ${inventoryVariationLabel(value)}';
  }

  String get barcodeInterno {
    final value = variation?.barcodeInterno.trim() ?? '';
    if (value.isNotEmpty) return value;
    return product.barcodeInterno?.trim() ?? '';
  }

  String? get imageUrl => variation?.immagineUrl ?? product.immagineUrl;

  /// Barcode del produttore letto dai metadati, se il prodotto lo espone.
  String? get barcodeFornitore {
    final scanned =
        (variation?.metadatiCustom ?? product.metadatiCustom)?['barcode']
            ?.toString()
            .trim();
    if (scanned == null || scanned.isEmpty) return null;
    return scanned;
  }

  InventoryQuickLoadLineDraft toLine({required String idempotencyKey}) {
    return InventoryQuickLoadLineDraft(
      productId: productId,
      variationId: variationId,
      label: label,
      barcodeInterno: barcodeInterno.isEmpty ? null : barcodeInterno,
      barcode: barcodeFornitore ?? barcode,
      imageUrl: imageUrl,
      quantity: 1,
      idempotencyKey: idempotencyKey,
    );
  }
}
