// inventory_movements_images.code.dart
//
// Le immagini dei prodotti toccati da un movimento.
//
// MGWS conserva il ledger: product_id e variation_id, quantita' e magazzini.
// Non conserva l'immagine, che invece vive nel catalogo WooCommerce. Qui si
// ricostruisce il collegamento partendo dagli id del movimento, senza toccare
// il gruppo ne' il ledger: se il catalogo non risponde, la tabella del dettaglio
// mostra il segnaposto invece di bloccare la lettura del movimento.

import '../login/jwt_api/adapter/platform_manager.dart';
import '../products/class_products.dart';
import '../products/product_cache.dart';
import 'inventory_movement_groups.code.dart';

/// Carica le immagini dei prodotti di un movimento, una sola volta.
///
/// Prima usa cio' che e' gia' in cache (la lista prodotti e le varianti aperte
/// in Gestione prodotti): e' il caso normale, perche' chi arriva dal ledger ha
/// quasi sempre il catalogo gia' caricato. Solo gli id mancanti vengono chiesti
/// a WooCommerce, con una richiesta per i prodotti e una per le varianti ancora
/// sconosciute. Un errore di rete non e' un errore del movimento: le immagini
/// restano facoltative e il chiamante mostra il segnaposto.
///
/// Le sorgenti sono parametri per poter provare il comportamento con dati
/// controllati; senza parametri usa la cache condivisa e le API del catalogo.
Future<Map<String, String?>> loadInventoryMovementImages(
  Iterable<InventoryMovementProduct> products, {
  Map<int, ProdottoGlobal>? cachedProducts,
  Map<int, List<VarianteProductGlobal>>? cachedVariants,
  Future<List<ProdottoGlobal>> Function(List<int> ids)? fetchProducts,
  Future<List<VarianteProductGlobal>> Function(int productId)? fetchVariants,
}) async {
  final items = products.toList(growable: false);
  if (items.isEmpty) return const <String, String?>{};

  final wantedProductIds = <int>[];
  final wantedVariationIds = <int, List<int>>{};
  for (final item in items) {
    if (!wantedProductIds.contains(item.productId)) {
      wantedProductIds.add(item.productId);
    }
    if (item.variationId > 0) {
      final ids = wantedVariationIds.putIfAbsent(
        item.productId,
        () => <int>[],
      );
      if (!ids.contains(item.variationId)) ids.add(item.variationId);
    }
  }

  final productsById = <int, ProdottoGlobal>{};
  if (cachedProducts != null) {
    productsById.addAll(cachedProducts);
  } else {
    for (final product
        in ProdottiCache.readProducts() ?? const <ProdottoGlobal>[]) {
      final id = product.id;
      if (id != null && wantedProductIds.contains(id)) {
        productsById[id] = product;
      }
    }
  }

  final missingProductIds = wantedProductIds
      .where((id) => !productsById.containsKey(id))
      .toList(growable: false);
  if (missingProductIds.isNotEmpty) {
    try {
      final fetched = await (fetchProducts ??
              PlatformManager.prodotti.getProductsByIds)(
        missingProductIds,
      );
      for (final product in fetched) {
        final id = product.id;
        if (id != null && wantedProductIds.contains(id)) {
          productsById[id] = product;
        }
      }
    } catch (_) {
      // Il ledger resta leggibile anche senza il catalogo.
    }
  }

  final variantsByProduct = <int, List<VarianteProductGlobal>>{};
  if (cachedVariants != null) {
    variantsByProduct.addAll(cachedVariants);
  } else {
    for (final entry in wantedVariationIds.entries) {
      final cached = ProdottiCache.readVariants(
        entry.key,
        const Duration(minutes: 10),
      );
      if (cached != null) variantsByProduct[entry.key] = cached;
    }
  }
  for (final entry in wantedVariationIds.entries) {
    final known = variantsByProduct[entry.key] ?? const <VarianteProductGlobal>[];
    final knownIds = known.map((variant) => variant.id).toSet();
    final missing = entry.value
        .where((id) => !knownIds.contains(id))
        .toList(growable: false);
    if (missing.isEmpty) continue;
    try {
      final fetched = await (fetchVariants ??
              PlatformManager.varianti.getAllVariations)(
        entry.key,
      );
      variantsByProduct[entry.key] = [...known, ...fetched];
    } catch (_) {
      // Senza la variante resta l'immagine del prodotto padre.
    }
  }

  return <String, String?>{
    for (final item in items)
      '${item.productId}:${item.variationId}':
          _imageUrlFor(item, productsById, variantsByProduct),
  };
}

/// La variante vince solo se ha davvero un URL: un campo vuoto non deve
/// nascondere la foto del prodotto, che e' cio' che l'operatore si aspetta di
/// vedere quando la variante non ha una foto propria.
String? _imageUrlFor(
  InventoryMovementProduct item,
  Map<int, ProdottoGlobal> productsById,
  Map<int, List<VarianteProductGlobal>> variantsByProduct,
) {
  if (item.variationId > 0) {
    for (final variant
        in variantsByProduct[item.productId] ?? const <VarianteProductGlobal>[]) {
      final url = variant.immagineUrl?.trim();
      if (variant.id == item.variationId && url != null && url.isNotEmpty) {
        return url;
      }
    }
  }
  final fallback = productsById[item.productId]?.immagineUrl?.trim();
  return fallback == null || fallback.isEmpty ? null : fallback;
}
