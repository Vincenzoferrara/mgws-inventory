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
    // 2) Codice articolo esatto: in negozio il codice si digita spesso a
    //    mano al posto del barcode. Solo per i prodotti semplici: il padre di
    //    un prodotto variabile non ha stock suo.
    final perCodice = await PlatformManager.prodotti
        .findProductByCodiceProdottoExact(codice);
    if (perCodice != null &&
        (perCodice.variations == null || perCodice.variations!.isEmpty)) {
      return ProdottoPerBarcode(perCodice);
    }
    // 3) Fallback: ricerca generica sul termine. La ricerca per testo trova
    //    anche nomi e codici che contengono il termine: vale solo il prodotto
    //    (o la variante) con un codice identico, altrimenti un codice
    //    sconosciuto metterebbe in cassa il primo articolo trovato.
    final candidati = await PlatformManager.prodotti.searchProducts(
      codice,
      limit: 5,
    );
    for (final candidato in candidati) {
      final trovato = await _daProdottoPerBarcode(
        candidato,
        codice,
        verificaCodice: true,
      );
      if (trovato != null) return trovato;
    }
    return null;
  } catch (e) {
    AppLogger().w('🔍 Ricerca barcode "$codice" fallita: $e');
    return null;
  }
}

/// Da un prodotto trovato per barcode restituisce l'elemento corretto:
/// la variante che ha il codice, oppure il prodotto se semplice.
///
/// Con [verificaCodice] il prodotto semplice vale solo se uno dei suoi codici
/// e' identico a [barcode]: serve quando il prodotto arriva da una ricerca
/// per testo e non da un lookup esatto.
Future<ProdottoPerBarcode?> _daProdottoPerBarcode(
  ProdottoGlobal prodotto,
  String barcode, {
  bool verificaCodice = false,
}) async {
  final codice = barcode.trim().toLowerCase();
  final hasVariationIds =
      prodotto.variations != null && prodotto.variations!.isNotEmpty;
  if (!hasVariationIds) {
    if (verificaCodice && !codiceInProdotto(prodotto, codice)) return null;
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
/// codice articolo, barcode interno, barcode fornitore e metadati custom.
bool codiceInVariante(VarianteProductGlobal variante, String codice) {
  return _unoUguale([
    variante.codiceProdotto,
    variante.barcodeInterno,
    variante.barcodeFornitore,
    ..._codiciMetadati(variante.metadatiCustom),
  ], codice);
}

/// Verifica se il codice appartiene al prodotto semplice: codice articolo,
/// barcode interno, barcode produttore e metadati custom.
bool codiceInProdotto(ProdottoGlobal prodotto, String codice) {
  return _unoUguale([
    prodotto.codiceProdotto,
    prodotto.barcodeInterno,
    prodotto.barcodeProduttore,
    ..._codiciMetadati(prodotto.metadatiCustom),
  ], codice);
}

/// Due codici sono lo stesso codice se coincidono a meno di maiuscole e
/// spazi, oppure se sono numerici e coincidono senza gli zeri iniziali (un
/// UPC-A letto come EAN-13 ha uno zero in piu'). Un pezzo di codice non
/// basta: "1" non e' "MGWS-T-1".
bool codiciUguali(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final numerico = RegExp(r'^\d+$');
  if (!numerico.hasMatch(x) || !numerico.hasMatch(y)) return false;
  final zeri = RegExp(r'^0+');
  return x.replaceFirst(zeri, '') == y.replaceFirst(zeri, '');
}

bool _unoUguale(List<String?> codici, String cercato) =>
    codici.any((c) => c != null && codiciUguali(c, cercato));

List<String?> _codiciMetadati(Map<String, dynamic>? metadati) => [
  for (final chiave in const [
    'barcode_manufacturer',
    'barcode_produttore',
    'supplier_sku',
    'barcode',
  ])
    metadati?[chiave]?.toString(),
];
