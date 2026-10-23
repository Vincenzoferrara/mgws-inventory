// product_barcode_lookup.dart
//
// Da un barcode letto dallo scanner al prodotto o alla variante a cui
// appartiene. E' la ricerca della cassa, messa qui perche' anche i moduli di
// magazzino la usino: un EAN di variante (global_unique_id) non e' un id di
// prodotto e non va mai mandato al backend come tale.

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import 'class_products.dart';

/// Prodotto trovato per barcode, con la variante quando il codice e' suo.
class ProdottoPerBarcode {
  const ProdottoPerBarcode(this.prodotto, [this.variante]);

  final ProdottoGlobal prodotto;
  final VarianteProductGlobal? variante;
}

/// Ricerca ON-DEMAND sul backend per barcode (scanner o testo).
///
/// Non carica mai il catalogo: interroga il backend e materializza solo
/// l'elemento che corrisponde al codice (variante se il barcode appartiene
/// a una variante, prodotto semplice altrimenti). Restituisce `null` se il
/// codice non e' di nessun prodotto.
Future<ProdottoPerBarcode?> cercaProdottoPerBarcode(String barcode) async {
  final codice = barcode.trim();
  if (codice.isEmpty) return null;
  try {
    // 1) Lookup esatto per barcode interno (global_unique_id).
    final prodotto = await PlatformManager.prodotti
        .findProductByBarcodeInternoExact(codice);
    if (prodotto != null) {
      return await _daProdottoPerBarcode(prodotto, codice);
    }
    // 2) Fallback: ricerca generica sul termine.
    final candidati = await PlatformManager.prodotti.searchProducts(
      codice,
      limit: 5,
    );
    if (candidati.isEmpty) return null;
    if (candidati.length == 1) {
      return await _daProdottoPerBarcode(candidati.first, codice);
    }
    for (final candidato in candidati) {
      final trovato = await _daProdottoPerBarcode(candidato, codice);
      if (trovato != null) return trovato;
    }
    return null;
  } catch (e) {
    AppLogger().w('🔍 Ricerca barcode "$codice" fallita: $e');
    return null;
  }
}

/// Da un prodotto trovato per barcode restituisce l'elemento corretto:
/// la variante che contiene il codice, oppure il prodotto se semplice.
Future<ProdottoPerBarcode?> _daProdottoPerBarcode(
  ProdottoGlobal prodotto,
  String barcode,
) async {
  final codice = barcode.trim().toLowerCase();
  final hasVariationIds =
      prodotto.variations != null && prodotto.variations!.isNotEmpty;
  if (!hasVariationIds) {
    return ProdottoPerBarcode(prodotto);
  }
  try {
    final varianti = await PlatformManager.varianti.getAllVariations(
      prodotto.id,
    );
    for (final variante in varianti) {
      if (codiceInVariante(variante, codice)) {
        return ProdottoPerBarcode(prodotto, variante);
      }
    }
  } catch (e) {
    AppLogger().w('⚠️ Varianti del prodotto ${prodotto.id} non caricate: $e');
  }
  return null;
}

/// Verifica se il codice (barcode) appartiene alla variante, confrontando
/// barcode interno, barcode fornitore e metadati custom.
bool codiceInVariante(VarianteProductGlobal variante, String codice) {
  final cercato = codice.trim().toLowerCase();
  final codici = <String>[
    variante.barcodeInterno,
    variante.barcodeFornitore,
    variante.metadatiCustom?['barcode_manufacturer']?.toString() ?? '',
    variante.metadatiCustom?['barcode_produttore']?.toString() ?? '',
    variante.metadatiCustom?['supplier_sku']?.toString() ?? '',
    variante.metadatiCustom?['barcode']?.toString() ?? '',
  ];
  return codici
      .map((c) => c.trim().toLowerCase())
      .where((c) => c.isNotEmpty)
      .any((c) => c.contains(cercato));
}
