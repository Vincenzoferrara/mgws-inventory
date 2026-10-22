import '../error_list.dart';
import '../../../l10n/known_messages.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../products/class_products.dart';
import 'woo_query_attributes.dart';
import 'woo_query_media.dart';
import '../../../log_viewer/app_logger.dart';
import '../../../settings/app_settings.dart';

/// Normalizza il JSON di una variazione WooCommerce v2.
///
/// La v2 di woocommerce_flutter_api parsea gli attributi con
/// WooProductItemAttribute.fromJson che gestisce solo json['options']
/// (array per attributi prodotto) ma NON json['option'] (stringa
/// singola per attributi variante). Questa funzione mappa
/// "option" → "options: [option]" per uniformare il formato.
Map<String, dynamic> _normalizeVariationJson(Map<String, dynamic> json) {
  final attributes = json['attributes'];
  if (attributes is List) {
    final normalizedAttrs = attributes.map((attr) {
      if (attr is Map<String, dynamic>) {
        if (attr.containsKey('option') && !attr.containsKey('options')) {
          return {
            ...attr,
            'options': [attr['option']],
          };
        }
      }
      return attr;
    }).toList();
    return {...json, 'attributes': normalizedAttrs};
  }
  return json;
}

/// Crea un WooProductVariation dal JSON, normalizzando gli attributi
/// della variante (option → options) per compatibilità con la v2 della libreria.
WooProductVariation _wooProductVariationFromJson(Map<String, dynamic> json) {
  final normalized = _normalizeVariationJson(json);
  return WooProductVariation.fromJson(normalized);
}

/// Query class per la gestione delle varianti prodotti WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
/// Converte i dati WooCommerce in modelli globali multi-piattaforma
class WooQueryVarianti {
  // Singleton pattern
  static final WooQueryVarianti _instance = WooQueryVarianti._internal();
  factory WooQueryVarianti() => _instance;
  WooQueryVarianti._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  static const String _nativeGalleryIdsMetaKey = '_woo_gallery_image_ids';
  static const String _nativeImageIdsByUrlMetaKey = '_woo_image_ids_by_url';

  final Map<int, String> _mediaUrlByIdCache = <int, String>{};

  // =======================================================
  // == CONVERSIONE WOOCOMMERCE → MODELLO GLOBALE        ==
  // =======================================================

  /// Recupera lo SKU del prodotto genitore (serve per distinguere lo SKU
  /// proprio della variante da quello ereditato e mostrato da WooCommerce).
  Future<String?> _fetchParentSku(int productId) async {
    try {
      final response = await _woo.dio.get('/products/$productId');
      final data = response.data;
      if (data is Map<String, dynamic>) return data['sku']?.toString();
      return null;
    } catch (e) {
      log.w('SKU genitore non recuperato per prodotto $productId: $e');
      return null;
    }
  }

  List<String> _parseVariantImageGallery(dynamic rawValue) {
    dynamic parsed = rawValue;
    if (rawValue is String) {
      try {
        parsed = jsonDecode(rawValue);
      } catch (_) {
        parsed = rawValue
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
    }
    if (parsed is! Iterable) return const <String>[];
    final urls = <String>[];
    for (final value in parsed) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  List<int> _parseGalleryImageIds(dynamic rawValue) {
    if (rawValue is! Iterable) return const <int>[];
    final ids = <int>[];
    for (final value in rawValue) {
      final id = value is int ? value : int.tryParse(value?.toString() ?? '');
      if (id != null && id > 0 && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  Future<String?> _mediaUrlById(int mediaId) async {
    if (mediaId <= 0) return null;
    if (_mediaUrlByIdCache.containsKey(mediaId)) {
      return _mediaUrlByIdCache[mediaId];
    }
    try {
      final media = await WooQueryMedia().getMediaById(mediaId);
      final url = media.url.trim();
      if (url.isNotEmpty) {
        _mediaUrlByIdCache[mediaId] = url;
        return url;
      }
    } catch (e) {
      log.w('Media $mediaId non risolto per gallery variante: $e');
    }
    return null;
  }

  Future<VarianteProductGlobal> _applyNativeVariationGallery(
    VarianteProductGlobal variante,
    Map<String, dynamic>? variationData,
  ) async {
    if (variationData == null) return variante;

    final imageIdsByUrl = <String, int>{};
    final image = variationData['image'];
    if (image is Map) {
      final id = image['id'] is int
          ? image['id'] as int
          : int.tryParse(image['id']?.toString() ?? '');
      final src = image['src']?.toString().trim() ?? '';
      if (id != null && id > 0 && src.isNotEmpty) imageIdsByUrl[src] = id;
    }

    final galleryIds = _parseGalleryImageIds(
      variationData['gallery_image_ids'],
    );
    if (galleryIds.isEmpty) {
      final metadata = <String, dynamic>{...?variante.metadatiCustom}
        ..[_nativeGalleryIdsMetaKey] = <int>[];
      if (imageIdsByUrl.isNotEmpty) {
        metadata[_nativeImageIdsByUrlMetaKey] = imageIdsByUrl;
      }
      return variante.copyWith(metadatiCustom: metadata);
    }

    final galleryUrls = <String>[];
    for (final id in galleryIds) {
      final url = await _mediaUrlById(id);
      if (url == null || url.isEmpty) continue;
      if (!galleryUrls.contains(url)) galleryUrls.add(url);
      imageIdsByUrl[url] = id;
    }

    if (galleryUrls.isEmpty) return variante;

    final metadata = <String, dynamic>{...?variante.metadatiCustom}
      ..[_nativeGalleryIdsMetaKey] = galleryIds
      ..[_nativeImageIdsByUrlMetaKey] = imageIdsByUrl;

    return variante.copyWith(
      immaginiAggiuntive: galleryUrls,
      metadatiCustom: metadata,
    );
  }

  Map<String, int> _nativeImageIdsByUrl(Map<String, dynamic>? metadata) {
    final raw = metadata?[_nativeImageIdsByUrlMetaKey];
    if (raw is! Map) return const <String, int>{};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final url = entry.key?.toString().trim() ?? '';
      final id = entry.value is int
          ? entry.value as int
          : int.tryParse(entry.value?.toString() ?? '');
      if (url.isNotEmpty && id != null && id > 0) result[url] = id;
    }
    return result;
  }

  int? _nativeImageIdForUrl(Map<String, int> idsByUrl, String? url) {
    final clean = url?.trim() ?? '';
    if (clean.isEmpty) return null;
    return idsByUrl[clean];
  }

  /// Converte WooProductVariation in VarianteWoo (modello globale)
  VarianteProductGlobal _convertToVarianteWoo(
    WooProductVariation wooVariation, {
    List<AttributoVariante>? attributiProdotto,
    Map<String, dynamic>? variationData,
    String? parentSku,
  }) {
    // Converte attributi
    List<AttributoVariante> attributi = [];

    if (wooVariation.attributes?.isNotEmpty == true) {
      attributi = wooVariation.attributes!.map((attr) {
        // WooProductItemAttribute ha 'options' che è una lista
        final opzione = attr.options?.isNotEmpty == true
            ? attr.options!.first
            : '';
        final nomeAttr = attr.name ?? '';

        // Cerca l'attributo corrispondente nel prodotto per ottenere il tipo
        AttributoVariante? attrProdotto;
        if (attributiProdotto != null) {
          attrProdotto = attributiProdotto
              .where((a) => a.nome == nomeAttr && a.opzione == opzione)
              .firstOrNull;
        }

        final attributoConvertito = AttributoVariante(
          id: attr.id,
          nome: nomeAttr,
          opzione: opzione,
          slug: attr.name?.toLowerCase().replaceAll(' ', '-'),
          tipo: attrProdotto?.tipo ?? TipoAttributo.select,
          valore: attrProdotto?.valore,
        );
        return attributoConvertito;
      }).toList();
    } else if (attributiProdotto != null) {
      // Se la variante non ha attributi specifici, non mostrare attributi generici
      // Evita di mostrare tutti gli attributi del prodotto su ogni variante
      attributi = [];
    } else {
      attributi = [];
    }

    final metadatiCustom = <String, dynamic>{
      for (final meta in wooVariation.metaData ?? [])
        if (meta.key?.trim().isNotEmpty == true) meta.key!: meta.value,
    };
    final globalUniqueId = variationData?['global_unique_id']
        ?.toString()
        .trim();
    // Compatibilità: il vecchio gestionale salvava il barcode produttore in
    // chiavi diverse; il nuovo campo ufficiale è `barcode_manufacturer`.
    final barcodeProduttore =
        (metadatiCustom['barcode_manufacturer'] ??
                metadatiCustom['barcode_produttore'] ??
                metadatiCustom['supplier_sku'] ??
                metadatiCustom['barcode'])
            ?.toString()
            .trim();
    final immaginiVarianteLegacy = _parseVariantImageGallery(
      metadatiCustom['immagini_variante'],
    );

    // WooCommerce mostra lo SKU del genitore quando la variante non ne ha
    // uno proprio: in quel caso il codice prodotto resta vuoto e non viene
    // mai rispedito alla variante.
    final rawSku = (wooVariation.sku ?? '').trim();
    final parent = (parentSku ?? '').trim();
    final codiceProdotto =
        (parent.isNotEmpty && rawSku.toLowerCase() == parent.toLowerCase())
        ? ''
        : rawSku;

    return VarianteProductGlobal(
      id: wooVariation.id ?? 0,
      nome: wooVariation.description ?? '',
      attributi: attributi,
      codiceProdotto: codiceProdotto,
      barcodeInterno: globalUniqueId ?? '',
      barcodeFornitore: barcodeProduttore?.isNotEmpty == true
          ? barcodeProduttore!
          : '',
      prezzo: wooVariation.regularPrice ?? wooVariation.price ?? 0.0,
      prezzoScontato:
          wooVariation.salePrice ??
          (wooVariation.onSale == true ? wooVariation.price : null),
      quantita: wooVariation.stockQuantity ?? 0,
      immagineUrl: wooVariation.image?.src,
      immaginiAggiuntive: immaginiVarianteLegacy,
      peso: wooVariation.weight?.toString(),
      dimensioni: DimensioniProdotto(
        lunghezza:
            double.tryParse(wooVariation.dimensions?.length ?? '0') ?? 0.0,
        larghezza:
            double.tryParse(wooVariation.dimensions?.width ?? '0') ?? 0.0,
        altezza: double.tryParse(wooVariation.dimensions?.height ?? '0') ?? 0.0,
      ),
      attiva: wooVariation.status == WooProductStatus.publish,
      metadatiCustom: metadatiCustom,
    );
  }

  /// Converte VarianteWoo in Map per API WooCommerce
  Map<String, dynamic> _convertToWooVariationData(
    VarianteProductGlobal variante, {
    String? forcedStatus,
  }) {
    final normalizedForcedStatus = _normalizeStatus(forcedStatus);
    final data = <String, dynamic>{
      'regular_price': variante.prezzo.toString(),
      // Se la variante non ha un codice prodotto proprio, lo SKU non viene
      // inviato: WooCommerce usa il riferimento del prodotto genitore.
      if (variante.codiceProdotto.trim().isNotEmpty)
        'sku': variante.codiceProdotto.trim(),
      if (variante.barcodeInterno.trim().isNotEmpty)
        'global_unique_id': variante.barcodeInterno.trim(),
      'manage_stock': true,
      'stock_quantity': variante.quantita,
      'status':
          normalizedForcedStatus ?? (variante.attiva ? 'publish' : 'private'),
    };

    // Prezzo scontato
    if (variante.prezzoScontato != null && variante.prezzoScontato! > 0) {
      data['sale_price'] = variante.prezzoScontato.toString();
    }

    // Peso
    if (variante.peso != null && variante.peso!.isNotEmpty) {
      data['weight'] = variante.peso;
    }

    // Dimensioni
    if (variante.dimensioni != null) {
      data['dimensions'] = {
        'length': variante.dimensioni!.lunghezza.toString(),
        'width': variante.dimensioni!.larghezza.toString(),
        'height': variante.dimensioni!.altezza.toString(),
      };
    }

    // Attributi
    data['attributes'] = variante.attributi
        .map((attr) => {'name': attr.nome, 'option': attr.opzione})
        .toList();

    final idsByUrl = _nativeImageIdsByUrl(variante.metadatiCustom);

    // Immagine principale variante (copertina variante).
    if (variante.immagineUrl != null && variante.immagineUrl!.isNotEmpty) {
      final imageId = _nativeImageIdForUrl(idsByUrl, variante.immagineUrl);
      data['image'] = imageId == null
          ? {'src': variante.immagineUrl}
          : {'id': imageId};
    }

    // Galleria variante nativa WooCommerce 11.1+: contiene solo le immagini
    // aggiuntive, mentre la copertina resta in `image`. Inviamo anche lista
    // vuota per permettere di svuotare la gallery variante.
    final galleryIds = <int>[];
    for (final url in variante.immaginiAggiuntive) {
      final id = _nativeImageIdForUrl(idsByUrl, url);
      if (id != null && !galleryIds.contains(id)) galleryIds.add(id);
    }
    data['gallery_image_ids'] = galleryIds;

    final metadata = <String, dynamic>{
      ...?variante.metadatiCustom,
      'immagini_variante': jsonEncode(variante.immaginiAggiuntive),
      if (variante.barcodeFornitore.trim().isNotEmpty)
        'barcode_manufacturer': variante.barcodeFornitore.trim(),
    };
    // Consolidamento sul nuovo campo ufficiale: evita di riscrivere i
    // vecchi nomi del gestionale precedente.
    metadata.remove('barcode_produttore');
    metadata.remove('supplier_sku');
    metadata.remove(_nativeGalleryIdsMetaKey);
    metadata.remove(_nativeImageIdsByUrlMetaKey);
    if (variante.barcodeFornitore.trim().isNotEmpty) {
      metadata.remove('barcode');
    }
    if (metadata.isNotEmpty) {
      data['meta_data'] = metadata.entries
          .map((entry) => {'key': entry.key, 'value': entry.value})
          .toList(growable: false);
    }

    return data;
  }

  // =======================================================
  // == METODI VARIANTI (Restituiscono modello globale)  ==
  // =======================================================

  /// Ottiene tutte le varianti di un prodotto
  Future<List<VarianteProductGlobal>> getProductVariations(
    int productId, {
    int page = 1,
    int perPage = 100,
    String? search,
    String? includeStatus,
    List<AttributoVariante>? attributiProdotto,
    bool logRawAttributeMapping = false,
    String debugLogSource = 'VARIANTS',
    String? parentSku,
  }) async {
    try {
      final woo = _woo;
      final response = await woo.dio.get(
        '/products/$productId/variations',
        queryParameters: <String, dynamic>{
          'context': 'view',
          'page': page,
          'per_page': perPage,
          if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        },
      );
      final rawVariations = response.data;
      if (rawVariations is! List) {
        throw StateError(
          'Invalid variations response: expected a list, got ${rawVariations.runtimeType}',
        );
      }

      if (kDebugMode && logRawAttributeMapping) {
        log.d(
          '${debugLogSource}_VARIANTS_RAW_JSON productId=$productId page=$page '
          'json=${jsonEncode(rawVariations)}',
        );
      }

      final result = <VarianteProductGlobal>[];
      for (final rawVariation in rawVariations) {
        if (rawVariation is! Map) {
          throw StateError(
            'Invalid variation item: ${rawVariation.runtimeType}',
          );
        }
        final rawMap = Map<String, dynamic>.from(rawVariation);
        final wooVariation = _wooProductVariationFromJson(rawMap);
        final mappedVariation = await _applyNativeVariationGallery(
          _convertToVarianteWoo(
            wooVariation,
            attributiProdotto: attributiProdotto,
            variationData: rawMap,
            parentSku: parentSku,
          ),
          rawMap,
        );
        result.add(mappedVariation);

        if (kDebugMode && logRawAttributeMapping) {
          final mappedAttributes = mappedVariation.attributi
              .map(
                (attribute) => <String, dynamic>{
                  'id': attribute.id,
                  'nome': attribute.nome,
                  'opzione': attribute.opzione,
                  'slug': attribute.slug,
                  'tipo': attribute.tipo.value,
                  'valore': attribute.valore,
                },
              )
              .toList(growable: false);
          log.d(
            '${debugLogSource}_VARIANT_ATTRIBUTES_MAP productId=$productId '
            'variationId=${rawMap['id']} '
            'raw=${jsonEncode(rawMap['attributes'])} '
            'mapped=${jsonEncode(mappedAttributes)}',
          );
        }
      }
      return result;
    } catch (e) {
      log.e('Errore caricamento varianti per prodotto $productId: $e');
      rethrow;
    }
  }

  /// Ottiene una singola variante per ID
  Future<VarianteProductGlobal> getVariationById(
    int productId,
    int variationId,
  ) async {
    final response = await _woo.dio.get(
      '/products/$productId/variations/$variationId',
    );
    final variationData = Map<String, dynamic>.from(response.data as Map);
    final wooVariation = _wooProductVariationFromJson(variationData);
    return await _applyNativeVariationGallery(
      _convertToVarianteWoo(
        wooVariation,
        variationData: variationData,
        parentSku: await _fetchParentSku(productId),
      ),
      variationData,
    );
  }

  /// Verifica che tutti gli attributi e termini di una variante esistano
  Future<void> _verificaECreaAttributiVariante(
    VarianteProductGlobal variante,
    String attributeCaseMode,
  ) async {
    if (variante.attributi.isEmpty) {
      throw Exception(AppMessages.variantNeedsAttribute);
    }

    log.e('🔍 Verifica attributi per variante ${variante.barcodeInterno}...');

    // Importa WooQueryAttributi per accedere ai metodi
    final attributiQuery = WooQueryAttributi();

    for (final attr in variante.attributi) {
      final rawAttributeName = attr.nome;
      final rawTermName = attr.opzione;
      final attributeName = rawAttributeName.trim();
      final termName = rawTermName.trim();

      if (attributeName.isEmpty && termName.isEmpty) {
        throw LocalizedException(
          'Invalid variant attribute: empty name and value (${variante.barcodeInterno})',
          (l10n) => l10n.productsVariantAttributeEmpty(variante.barcodeInterno),
        );
      }

      if (attributeName.isEmpty && termName.isNotEmpty) {
        throw LocalizedException(
          'Invalid variant attribute: value without name (${variante.barcodeInterno})',
          (l10n) =>
              l10n.productsVariantAttributeNoName(variante.barcodeInterno),
        );
      }

      if (attributeName.isNotEmpty && termName.isEmpty) {
        throw LocalizedException(
          'Invalid variant attribute: name without value (${variante.barcodeInterno}, $attributeName)',
          (l10n) => l10n.productsVariantAttributeNoValue(
            variante.barcodeInterno,
            attributeName,
          ),
        );
      }

      // STEP 1: Verifica/crea l'attributo globale
      log.e('  → Verifica attributo: $attributeName');
      ProductAttribute attributo;
      final existingAttribute = await attributiQuery.findAttributeByName(
        attributeName,
      );
      if (existingAttribute != null) {
        attributo = existingAttribute;
      } else {
        final normalizedAttributeName =
            AppSettings.normalizeAttributeParameterWithMode(
              attributeName,
              attributeCaseMode,
            );
        if (normalizedAttributeName.isEmpty) {
          throw LocalizedException(
            'Invalid variant attribute after normalisation (${variante.barcodeInterno})',
            (l10n) =>
                l10n.productsVariantAttributeInvalid(variante.barcodeInterno),
          );
        }
        log.d(
          'PCREA_PARAM_CREATE_ATTR raw="$attributeName" normalized="$normalizedAttributeName" mode=$attributeCaseMode',
        );
        attributo = await attributiQuery.createAttributeIfNotExists(
          name: normalizedAttributeName,
          type: attr.tipo.value,
          hasArchives: true,
        );
      }

      if (attributo.id == null) {
        throw LocalizedException(
          'Could not create or find the attribute: $attributeName',
          (l10n) => l10n.productsAttributeCreateFailed(attributeName),
        );
      }

      // STEP 2: Verifica/crea il termine dell'attributo
      log.e('  → Verifica termine: $termName');
      final existingTerm = await attributiQuery.findAttributeTermByName(
        attributo.id!,
        termName,
      );
      if (existingTerm == null) {
        final normalizedTermName =
            AppSettings.normalizeAttributeParameterWithMode(
              termName,
              attributeCaseMode,
            );
        if (normalizedTermName.isEmpty) {
          throw LocalizedException(
            'Invalid attribute value after normalisation (${variante.barcodeInterno}, $attributeName)',
            (l10n) => l10n.productsVariantValueInvalid(
              variante.barcodeInterno,
              attributeName,
            ),
          );
        }
        log.d(
          'PCREA_PARAM_CREATE_TERM raw="$termName" normalized="$normalizedTermName" mode=$attributeCaseMode',
        );
        await attributiQuery.createAttributeTermIfNotExists(
          attributeId: attributo.id!,
          name: normalizedTermName,
        );
      }
    }

    log.e('✅ Tutti gli attributi della variante sono stati verificati');
  }

  /// Crea varianti per un prodotto se non esistono
  /// Questo è l'UNICO metodo da usare per creare varianti
  /// Accetta List<VarianteProductGlobal> e gestisce la creazione/aggiornamento
  Future<List<VarianteProductGlobal>> createVariationsIfNotExists({
    required int productId,
    required List<VarianteProductGlobal> varianti,
    String? forcedStatus,
  }) async {
    try {
      final List<VarianteProductGlobal> variantiCreate = [];
      final settings = AppSettings();
      await settings.init();
      final attributeCaseMode = settings.attributeCaseMode;

      log.i(
        '🔵 VARIANTE: Gestione ${varianti.length} varianti per prodotto $productId...',
      );
      log.d('PCREA_PARAM_CASE_MODE mode=$attributeCaseMode');
      final parentSku = await _fetchParentSku(productId);
      log.d('🔍 VARIANTE: Dettaglio varianti da creare:');
      for (final variante in varianti) {
        log.d(
          '  - ${variante.nome} (SKU: ${variante.barcodeInterno}, Prezzo: ${variante.prezzo})',
        );
        log.d(
          '    Attributi: ${variante.attributi.map((a) => "${a.nome}:${a.opzione}").toList()}',
        );
      }

      for (final variante in varianti) {
        try {
          log.i(
            '🔧 VARIANTE: Inizio creazione variante ${variante.barcodeInterno}...',
          );

          // STEP 1: Verifica che tutti gli attributi e termini esistano
          log.d(
            '🔍 VARIANTE: STEP 1 - Verifica attributi per ${variante.barcodeInterno}',
          );
          await _verificaECreaAttributiVariante(variante, attributeCaseMode);
          log.d('✅ VARIANTE: STEP 1 completato - Attributi verificati');

          // STEP 2: Crea la variante
          log.d('🔍 VARIANTE: STEP 2 - Conversione dati variante');
          final variationData = _convertToWooVariationData(
            variante,
            forcedStatus: forcedStatus,
          );
          log.d('🔍 VARIANTE: Dati variante: $variationData');

          log.d('🔍 VARIANTE: STEP 3 - Chiamata API POST');
          Map<String, dynamic> finalVariationData = Map<String, dynamic>.from(
            variationData,
          );
          dynamic response;

          try {
            response = await _wooConnect.woo.dio.post(
              '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations',
              data: finalVariationData,
            );
          } catch (e) {
            if (_isSkuDuplicateError(e) &&
                (finalVariationData['sku'] is String)) {
              final currentSku = (finalVariationData['sku'] as String).trim();
              final retrySku =
                  _extractSuggestedSku(e) ?? _fallbackSku(currentSku);
              log.w(
                '⚠️ SKU variante duplicato: $currentSku -> retry con $retrySku',
              );
              finalVariationData = Map<String, dynamic>.from(finalVariationData)
                ..['sku'] = retrySku;
              response = await _wooConnect.woo.dio.post(
                '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations',
                data: finalVariationData,
              );
            } else {
              rethrow;
            }
          }

          log.d('🔍 VARIANTE: STEP 4 - Parsing response');
          final nuovaVariante = await _parseVariationResponse(
            response.data as Map<String, dynamic>,
            attributiProdotto: variante.attributi,
            parentSku: parentSku,
          );

          log.i(
            '✅ VARIANTE: ${variante.barcodeInterno} creata con successo (ID: ${nuovaVariante.id})',
          );
          variantiCreate.add(nuovaVariante);
        } catch (e) {
          final errorMessage = e is Exception
              ? (e as dynamic).response?.toString() ?? '$e'
              : '$e';
          log.e(
            '❌ VARIANTE: Errore API creazione variante ${variante.barcodeInterno}: $errorMessage',
          );
          log.e('🔍 VARIANTE: STACK TRACE: ${StackTrace.current}');
          // Continua con le altre varianti anche se una fallisce
        }
      }

      if (varianti.isNotEmpty && variantiCreate.isEmpty) {
        throw LocalizedException(
          'No variant created for product $productId (attempted: ${varianti.length}).',
          (l10n) =>
              l10n.productsNoVariantCreated('$productId', varianti.length),
        );
      }

      return variantiCreate;
    } catch (e) {
      log.e('❌ Errore createVariationsIfNotExists: $e');
      rethrow;
    }
  }

  /// Crea una nuova variante (accetta VarianteWoo) - VERIFICA ATTRIBUTI PRIMA
  Future<VarianteProductGlobal> createVariation({
    required int productId,
    required VarianteProductGlobal variante,
    String? forcedStatus,
  }) async {
    try {
      final settings = AppSettings();
      await settings.init();

      // STEP 1: Verifica che tutti gli attributi e termini esistano
      await _verificaECreaAttributiVariante(
        variante,
        settings.attributeCaseMode,
      );

      // STEP 2: Crea la variante
      log.e(
        '🔵 Creazione variante ${variante.barcodeInterno} per prodotto $productId',
      );
      final variationData = _convertToWooVariationData(
        variante,
        forcedStatus: forcedStatus,
      );

      final response = await _wooConnect.woo.dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations',
        data: variationData,
      );

      final nuovaVariante = await _parseVariationResponse(
        response.data as Map<String, dynamic>,
        attributiProdotto: variante.attributi,
        parentSku: await _fetchParentSku(productId),
      );

      log.e(
        '✅ Variante ${variante.barcodeInterno} creata con successo (ID: ${nuovaVariante.id})',
      );
      return nuovaVariante;
    } catch (e) {
      log.e('❌ Errore createVariation: $e');
      rethrow;
    }
  }

  /// Aggiorna una variante esistente (accetta VarianteWoo)
  Future<VarianteProductGlobal> updateVariation({
    required int productId,
    required VarianteProductGlobal variante,
  }) async {
    final variationData = _convertToWooVariationData(variante);

    final response = await _wooConnect.woo.dio.put(
      '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations/${variante.id}',
      data: variationData,
    );

    return await _parseVariationResponse(
      response.data as Map<String, dynamic>,
      attributiProdotto: variante.attributi,
      parentSku: await _fetchParentSku(productId),
    );
  }

  /// Elimina una variante (usa Dio diretto)
  Future<bool> deleteVariation({
    required int productId,
    required int variationId,
    bool force = false,
  }) async {
    await _wooConnect.woo.dio.delete(
      '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations/$variationId',
      queryParameters: {'force': force},
    );

    return true;
  }

  /// Aggiorna solo lo stock di una variante
  Future<VarianteProductGlobal> updateVariationStock({
    required int productId,
    required int variationId,
    int? stockQuantity,
    String? stockStatus,
    bool? manageStock,
  }) async {
    // Prima ottieni la variante esistente
    final variante = await getVariationById(productId, variationId);

    // Aggiorna solo i campi stock
    final varianteAggiornata = VarianteProductGlobal(
      id: variante.id,
      nome: variante.nome,
      attributi: variante.attributi,
      codiceProdotto: variante.codiceProdotto,
      barcodeInterno: variante.barcodeInterno,
      barcodeFornitore: variante.barcodeFornitore,
      prezzo: variante.prezzo,
      prezzoScontato: variante.prezzoScontato,
      quantita: stockQuantity ?? variante.quantita,
      immagineUrl: variante.immagineUrl,
      immaginiAggiuntive: variante.immaginiAggiuntive,
      peso: variante.peso,
      dimensioni: variante.dimensioni,
      attiva: variante.attiva,
      metadatiCustom: variante.metadatiCustom,
    );

    return await updateVariation(
      productId: productId,
      variante: varianteAggiornata,
    );
  }

  /// Ottiene tutte le varianti di un prodotto (senza paginazione)
  Future<List<VarianteProductGlobal>> getAllVariations(
    int productId, {
    String? includeStatus,
    List<AttributoVariante>? attributiProdotto,
    bool logRawAttributeMapping = false,
    String debugLogSource = 'VARIANTS',
  }) async {
    final List<VarianteProductGlobal> allVariations = [];
    int currentPage = 1;
    bool hasMore = true;
    final parentSku = await _fetchParentSku(productId);

    while (hasMore) {
      final variations = await getProductVariations(
        productId,
        page: currentPage,
        perPage: 100,
        includeStatus: includeStatus,
        attributiProdotto: attributiProdotto,
        logRawAttributeMapping: logRawAttributeMapping,
        debugLogSource: debugLogSource,
        parentSku: parentSku,
      );

      allVariations.addAll(variations);
      // WooCommerce restituisce al massimo `perPage` elementi per pagina:
      // una pagina corta (o vuota) è necessariamente l'ultima. Fermarsi qui
      // evita la richiesta «di controllo» a `page=N+1` che raddoppiava le
      // chiamate (una per ogni prodotto) senza mai aggiungere elementi.
      if (variations.length < 100) {
        hasMore = false;
      } else {
        currentPage++;
      }
    }

    return allVariations;
  }

  /// Batch update varianti (usa Dio diretto)
  Future<Map<String, dynamic>> batchUpdateVariations({
    required int productId,
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    final batchData = {
      if (create != null && create.isNotEmpty) 'create': create,
      if (update != null && update.isNotEmpty) 'update': update,
      if (delete != null && delete.isNotEmpty) 'delete': delete,
    };

    final response = await _wooConnect.woo.dio.post(
      '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations/batch',
      data: batchData,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Ottiene varianti disponibili (in stock)
  Future<List<VarianteProductGlobal>> getAvailableVariations(
    int productId,
  ) async {
    final allVariations = await getAllVariations(productId);
    return allVariations.where((v) => v.quantita > 0).toList();
  }

  String? _normalizeStatus(String? status) {
    if (status == null || status.trim().isEmpty) return null;
    final normalized = status.trim().toLowerCase();
    const allowed = {'publish', 'draft', 'private', 'pending'};
    if (!allowed.contains(normalized)) {
      log.d('Status variante non supportato ignorato: $status');
      return null;
    }
    return normalized;
  }

  bool _isSkuDuplicateError(Object e) {
    final data = (e as dynamic).response?.data;
    if (data is Map<String, dynamic>) {
      final code = (data['code'] ?? '').toString().toLowerCase();
      final message = (data['message'] ?? '').toString().toLowerCase();
      return code.contains('sku') || message.contains('sku');
    }
    return false;
  }

  String _fallbackSku(String originalSku) {
    final suffix = DateTime.now().millisecondsSinceEpoch % 100000;
    return '$originalSku-$suffix';
  }

  String? _extractSuggestedSku(Object e) {
    final data = (e as dynamic).response?.data;
    if (data is! Map<String, dynamic>) return null;

    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final unique = nested['unique_sku'];
      if (unique is String && unique.trim().isNotEmpty) {
        return unique.trim();
      }
    }

    final top = data['unique_sku'];
    if (top is String && top.trim().isNotEmpty) {
      return top.trim();
    }

    return null;
  }

  Future<VarianteProductGlobal> _parseVariationResponse(
    Map<String, dynamic> variationData, {
    List<AttributoVariante>? attributiProdotto,
    String? parentSku,
  }) async {
    final wooVariation = _wooProductVariationFromJson(variationData);
    return await _applyNativeVariationGallery(
      _convertToVarianteWoo(
        wooVariation,
        attributiProdotto: attributiProdotto,
        variationData: variationData,
        parentSku: parentSku,
      ),
      variationData,
    );
  }

  /// Ottiene varianti esaurite
  Future<List<VarianteProductGlobal>> getOutOfStockVariations(
    int productId,
  ) async {
    final allVariations = await getAllVariations(productId);
    return allVariations.where((v) => v.quantita == 0).toList();
  }

  /// Trova variante per attributi specifici
  Future<VarianteProductGlobal?> findVariationByAttributes({
    required int productId,
    required Map<String, String> attributes,
  }) async {
    final allVariations = await getAllVariations(productId);

    for (final variation in allVariations) {
      bool matches = true;

      if (variation.attributi.isNotEmpty) {
        for (final attr in attributes.entries) {
          final varAttr = variation.attributi
              .where((a) => a.nome.toLowerCase() == attr.key.toLowerCase())
              .firstOrNull;

          if (varAttr == null ||
              varAttr.opzione.toLowerCase() != attr.value.toLowerCase()) {
            matches = false;
            break;
          }
        }
      } else {
        matches = false;
      }

      if (matches) return variation;
    }

    return null;
  }

  /// Ottiene statistiche varianti di un prodotto
  Future<Map<String, dynamic>> getVariationStats(int productId) async {
    final variations = await getAllVariations(productId);

    int totalStock = 0;
    int inStock = 0;
    int outOfStock = 0;
    double minPrice = double.infinity;
    double maxPrice = 0;

    for (final variation in variations) {
      if (variation.quantita > 0) {
        inStock++;
      } else {
        outOfStock++;
      }

      totalStock += variation.quantita;

      if (variation.prezzo < minPrice) minPrice = variation.prezzo;
      if (variation.prezzo > maxPrice) maxPrice = variation.prezzo;
    }

    return {
      'total_variations': variations.length,
      'in_stock': inStock,
      'out_of_stock': outOfStock,
      'total_stock_quantity': totalStock,
      'min_price': minPrice == double.infinity ? 0 : minPrice,
      'max_price': maxPrice,
    };
  }

  /// Aggiorna prezzo di una variante
  Future<VarianteProductGlobal> updateVariationPrice({
    required int productId,
    required int variationId,
    double? regularPrice,
    double? salePrice,
  }) async {
    final variante = await getVariationById(productId, variationId);

    final varianteAggiornata = VarianteProductGlobal(
      id: variante.id,
      nome: variante.nome,
      attributi: variante.attributi,
      codiceProdotto: variante.codiceProdotto,
      barcodeInterno: variante.barcodeInterno,
      barcodeFornitore: variante.barcodeFornitore,
      prezzo: regularPrice ?? variante.prezzo,
      prezzoScontato: salePrice ?? variante.prezzoScontato,
      quantita: variante.quantita,
      immagineUrl: variante.immagineUrl,
      immaginiAggiuntive: variante.immaginiAggiuntive,
      peso: variante.peso,
      dimensioni: variante.dimensioni,
      attiva: variante.attiva,
      metadatiCustom: variante.metadatiCustom,
    );

    return await updateVariation(
      productId: productId,
      variante: varianteAggiornata,
    );
  }

  /// Abilita/disabilita una variante
  Future<VarianteProductGlobal> toggleVariationStatus({
    required int productId,
    required int variationId,
    required bool enabled,
  }) async {
    final variante = await getVariationById(productId, variationId);

    final varianteAggiornata = VarianteProductGlobal(
      id: variante.id,
      nome: variante.nome,
      attributi: variante.attributi,
      codiceProdotto: variante.codiceProdotto,
      barcodeInterno: variante.barcodeInterno,
      barcodeFornitore: variante.barcodeFornitore,
      prezzo: variante.prezzo,
      prezzoScontato: variante.prezzoScontato,
      quantita: variante.quantita,
      immagineUrl: variante.immagineUrl,
      immaginiAggiuntive: variante.immaginiAggiuntive,
      peso: variante.peso,
      dimensioni: variante.dimensioni,
      attiva: enabled,
      metadatiCustom: variante.metadatiCustom,
    );

    return await updateVariation(
      productId: productId,
      variante: varianteAggiornata,
    );
  }

  /// Recupera i metadata custom di una variante prodotto
  Future<Map<String, String>> getProductVariationMetadata(
    int productId,
    int variationId,
  ) async {
    try {
      log.d(
        '🔍 Recupero metadata per variante $variationId del prodotto $productId',
      );

      final response = await _woo.dio.get(
        '/products/$productId/variations/$variationId',
      );

      if (response.statusCode == 200) {
        final variationData = response.data as Map<String, dynamic>;
        final metaData = variationData['meta_data'] as List<dynamic>? ?? [];

        final metadataMap = <String, String>{};
        for (final meta in metaData) {
          if (meta['key'] != null) {
            metadataMap[meta['key'].toString()] =
                meta['value']?.toString() ?? '';
          }
        }

        log.d(
          '✅ Recuperati ${metadataMap.length} metadata per variante $variationId',
        );
        return metadataMap;
      } else {
        log.e('❌ Errore recupero metadata variante: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      log.e('❌ Errore recupero metadata variante: $e');
      return {};
    }
  }
}
