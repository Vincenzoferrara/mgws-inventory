// Query WooCommerce - PRODOTTI
//
// Gestisce tutte le operazioni sui prodotti usando woocommerce_flutter_api
// L'autenticazione è gestita centralmente da WooConnect
// Converte i dati WooCommerce in modelli globali multi-piattaforma

import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import 'package:dio/dio.dart';
import '../woo_connect.dart';
import '../adapter/platform_manager.dart';
import '../../../prodotti/class_prodotti.dart';
import '../../../log_viewer/app_logger.dart';
import '../../../reuse_class/logic/global_pagination_controller.dart';
import 'woo_query_categoria.dart';
import 'woo_query_marchi.dart';
import 'woo_query_tag.dart';
import 'woo_query_varianti.dart';

/// Filtri per la ricerca prodotti
class ProductFilters {
  final String? search;
  final int? category;
  final String? tag;
  final String? barcodeInterno;
  final String? codiceProdotto;
  final WooProductStatus? status;
  final String? stockStatus;
  final bool? featured;
  final String? orderBy;
  final String? order;

  ProductFilters({
    this.search,
    this.category,
    this.tag,
    this.barcodeInterno,
    this.codiceProdotto,
    this.status,
    this.stockStatus,
    this.featured,
    this.orderBy,
    this.order,
  });
}

/// Prodotto o variante sotto la soglia scorte basse impostata sul prodotto.
class ProdottoSottoScorta {
  const ProdottoSottoScorta({
    required this.id,
    required this.parentId,
    required this.nome,
    required this.giacenza,
    required this.soglia,
  });

  final int id;

  /// Prodotto padre per le varianti, 0 per i prodotti semplici.
  final int parentId;
  final String nome;
  final int giacenza;
  final int soglia;
}

class _ResolvedProductRelations {
  final List<CategoriaProdotto>? categorie;
  final List<TagProdotto>? tag;
  final MarcaProdotto? marca;

  const _ResolvedProductRelations({
    required this.categorie,
    required this.tag,
    required this.marca,
  });
}

/// Service per gestire i prodotti WooCommerce
class WooQueryProdotti {
  static const bool _debugAttributeConversion = false;

  // Singleton
  static final WooQueryProdotti _instance = WooQueryProdotti._internal();
  factory WooQueryProdotti() => _instance;
  WooQueryProdotti._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  String? _mapWooProductStatusToApi(WooProductStatus? status) {
    if (status == null) return null;
    return status.toString().split('.').last;
  }

  Map<String, dynamic> _stripNullsDeep(Map<String, dynamic> input) {
    final out = <String, dynamic>{};

    for (final entry in input.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is Map<String, dynamic>) {
        final nested = _stripNullsDeep(value);
        if (nested.isNotEmpty) out[entry.key] = nested;
        continue;
      }

      if (value is List) {
        final cleaned = value
            .map((item) {
              if (item is Map<String, dynamic>) return _stripNullsDeep(item);
              return item;
            })
            .where((item) {
              if (item == null) return false;
              if (item is Map<String, dynamic>) return item.isNotEmpty;
              return true;
            })
            .toList();
        if (cleaned.isNotEmpty) out[entry.key] = cleaned;
        continue;
      }

      out[entry.key] = value;
    }

    return out;
  }

  Future<_ResolvedProductRelations> _resolveProductRelations(
    ProdottoGlobal prodotto,
  ) async {
    List<CategoriaProdotto>? categorieConId;
    if (prodotto.categoria?.isNotEmpty ?? false) {
      log.d('📁 Verifica/Crea ${prodotto.categoria!.length} categorie...');
      final createdCategories = await WooQueryCategoria()
          .createCategoryIfNotExists(prodotto.categoria!);
      categorieConId = createdCategories.where((c) => c.id != 0).toList();
    }

    List<TagProdotto>? tagConId;
    if (prodotto.tag?.isNotEmpty ?? false) {
      log.d('🏷️ Verifica/Crea ${prodotto.tag!.length} tag...');
      tagConId = await WooQueryTag().createTagIfNotExists(prodotto.tag!);
    }

    MarcaProdotto? marcaConId;
    if (prodotto.marca?.trim().isNotEmpty ?? false) {
      log.d('🏭 Verifica/Crea marchio ${prodotto.marca}...');
      marcaConId = await WooQueryMarchi().createBrandIfNotExists(
        prodotto.marca,
      );
    }

    return _ResolvedProductRelations(
      categorie: categorieConId,
      tag: tagConId,
      marca: marcaConId,
    );
  }

  Map<String, dynamic> _buildProductPayload(
    ProdottoGlobal prodotto, {
    MarcaProdotto? brand,
    bool includeVariableAttributes = true,
  }) {
    final isVariable = prodotto.varianti?.isNotEmpty ?? false;
    final metaData = <Map<String, Object?>>[
      if ((prodotto.barcodeProduttore?.isNotEmpty ?? false))
        {'key': 'barcode_manufacturer', 'value': prodotto.barcodeProduttore},
      if (prodotto.costoAcquisto != null)
        {
          'key': '_purchase_cost',
          'value': prodotto.costoAcquisto!.toStringAsFixed(4),
        },
    ];

    final payload = <String, dynamic>{
      'name': prodotto.nome,
      'type': isVariable ? 'variable' : 'simple',
      'status': prodotto.status.isNotEmpty ? prodotto.status : 'draft',
      if ((prodotto.codiceProdotto?.isNotEmpty ?? false))
        'sku': prodotto.codiceProdotto,
      if ((prodotto.barcodeInterno?.isNotEmpty ?? false))
        'global_unique_id': prodotto.barcodeInterno,
      if (metaData.isNotEmpty) 'meta_data': metaData,
      if ((prodotto.descrizioneBreve?.isNotEmpty ?? false))
        'short_description': prodotto.descrizioneBreve,
      if ((prodotto.descrizioneCompleta?.isNotEmpty ?? false))
        'description': prodotto.descrizioneCompleta,
      if ((prodotto.peso?.isNotEmpty ?? false)) 'weight': prodotto.peso,
      if (prodotto.dimensioni != null)
        'dimensions': {
          'length': prodotto.dimensioni!.lunghezza.toString(),
          'width': prodotto.dimensioni!.larghezza.toString(),
          'height': prodotto.dimensioni!.altezza.toString(),
        },
      if (prodotto.categoria?.isNotEmpty ?? false)
        'categories': prodotto.categoria!
            .where((c) => (c.id) > 0)
            .map((c) => {'id': c.id})
            .toList(),
      if (prodotto.tag?.isNotEmpty ?? false)
        'tags': prodotto.tag!
            .where((t) => (t.id) > 0)
            .map((t) => {'id': t.id})
            .toList(),
      if (brand != null && brand.id > 0)
        'brands': [
          {'id': brand.id},
        ],
      if ((prodotto.immagineUrl?.isNotEmpty ?? false) ||
          (prodotto.immaginiAggiuntive?.isNotEmpty ?? false))
        'images': [
          if (prodotto.immagineUrl?.isNotEmpty ?? false)
            {'src': prodotto.immagineUrl},
          ...?prodotto.immaginiAggiuntive
              ?.where((url) => url.isNotEmpty)
              .map((url) => {'src': url}),
        ],
    };

    if (!isVariable) {
      payload['regular_price'] = (prodotto.prezzoNormale ?? 0.0).toString();
      payload['manage_stock'] = prodotto.quantitaTotale != null;
      if (prodotto.prezzoScontato != null && prodotto.prezzoScontato! > 0) {
        payload['sale_price'] = prodotto.prezzoScontato.toString();
      }
      if (prodotto.quantitaTotale != null) {
        payload['stock_quantity'] = prodotto.quantitaTotale;
      }
    } else {
      payload['manage_stock'] = false;

      final attributiMap = <String, Set<String>>{};
      for (final variante
          in prodotto.varianti ?? const <VarianteProductGlobal>[]) {
        for (final attr in variante.attributi) {
          final nome = attr.nome.trim();
          final opzione = attr.opzione.trim();
          if (nome.isEmpty || opzione.isEmpty) continue;
          attributiMap.putIfAbsent(nome, () => <String>{}).add(opzione);
        }
      }

      if (includeVariableAttributes && attributiMap.isNotEmpty) {
        payload['attributes'] = attributiMap.entries
            .map(
              (entry) => {
                'name': entry.key,
                'visible': true,
                'variation': true,
                'options': entry.value.toList(),
              },
            )
            .toList();
      }
    }

    return _stripNullsDeep(payload);
  }

  /// Prepara le immagini per un aggiornamento senza chiedere a WooCommerce di
  /// scaricare nuovamente quelle già presenti nel prodotto.
  ///
  /// L'API WooCommerce interpreta `src` come immagine remota da acquisire. In
  /// particolare, un URL `localhost` dell'app non è raggiungibile dal processo
  /// WordPress/Docker. Le immagini già collegate vengono quindi inviate con il
  /// loro attachment ID; gli URL rimangono riservati alle immagini nuove.
  Future<void> _replaceExistingImageUrlsWithIds(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    final requestedImages = payload['images'];
    if (requestedImages is! List || requestedImages.isEmpty) return;

    final response = await _woo.dio.get('/products/$productId');
    final productData = response.data;
    if (productData is! Map<String, dynamic>) return;

    final existingImages = productData['images'];
    if (existingImages is! List) return;

    final attachmentIdsByUrl = <String, int>{};
    for (final image in existingImages) {
      if (image is! Map) continue;
      final source = image['src']?.toString();
      final rawId = image['id'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (source != null && source.isNotEmpty && id != null && id > 0) {
        attachmentIdsByUrl[source] = id;
      }
    }

    if (attachmentIdsByUrl.isEmpty) return;

    payload['images'] = requestedImages.map((image) {
      if (image is! Map) return image;
      final source = image['src']?.toString();
      final attachmentId = source == null ? null : attachmentIdsByUrl[source];
      return attachmentId == null
          ? image
          : <String, dynamic>{'id': attachmentId};
    }).toList();
  }

  bool _isSkuDuplicateError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final code = (data['code'] ?? '').toString().toLowerCase();
      final message = (data['message'] ?? '').toString().toLowerCase();
      return code.contains('sku') || message.contains('sku');
    }
    return false;
  }

  // =======================================================
  // == CONVERSIONE WOOCOMMERCE → MODELLO GLOBALE        ==
  // =======================================================

  /// Estrae un valore specifico dai metadata di un prodotto WooCommerce
  String? _extractMetaData(WooProduct wooProduct, String key) {
    try {
      for (final meta in wooProduct.metaData ?? []) {
        if (meta.key == key) {
          return meta.value.toString();
        }
      }
      return null;
    } catch (e) {
      log.d('Errore estrazione metadata "$key": $e');
      return null;
    }
  }

  Map<String, dynamic> _extractAllMetaData(WooProduct wooProduct) {
    return <String, dynamic>{
      for (final meta in wooProduct.metaData ?? [])
        if (meta.key?.trim().isNotEmpty == true) meta.key!: meta.value,
    };
  }

  String? _stringFromProductData(
    Map<String, dynamic>? productData,
    String key,
  ) {
    final value = productData?[key];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _extractBrandNameFromProductData(Map<String, dynamic>? productData) {
    if (productData == null) return null;

    final brands = productData['brands'];
    if (brands is! List || brands.isEmpty) return null;

    final first = brands.first;
    if (first is Map<String, dynamic>) {
      final name = (first['name'] ?? '').toString().trim();
      return name.isEmpty ? null : name;
    }

    return null;
  }

  /// Converte WooProduct in Prodotto globale
  ///
  /// Le conversioni null → default sono gestite dal costruttore di ProdottoGlobal
  /// tramite le helper functions centralizzate (intNotNull, stringNotNull, doubleNotNull)
  ProdottoGlobal convert_wooproduct_To_ProdottoGlobal(
    WooProduct wooProduct, {
    Map<String, dynamic>? productData,
  }) {
    // Helper per gestire stringhe vuote e null (ritorna null se stringa vuota)
    String? handleEmptyString(String? value) {
      if (value == null || value.isEmpty) return null;
      return value;
    }

    // Helper per gestire double
    double? handleDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    List<int>? normalizeVariationIds(dynamic rawVariations) {
      if (rawVariations is! List || rawVariations.isEmpty) return null;

      final variationIds = <int>[];
      for (final value in rawVariations) {
        if (value is int) {
          variationIds.add(value);
          continue;
        }

        if (value is String) {
          final parsedValue = int.tryParse(value.trim());
          if (parsedValue != null) {
            variationIds.add(parsedValue);
          }
        }
      }

      return variationIds.isEmpty ? null : variationIds;
    }

    final variationIds =
        normalizeVariationIds(wooProduct.variations) ??
        normalizeVariationIds(productData?['variations']);

    return ProdottoGlobal(
      id: wooProduct.id,
      nome: wooProduct.name,
      codiceProdotto: wooProduct.sku,
      barcodeInterno: _stringFromProductData(productData, 'global_unique_id'),
      barcodeProduttore:
          handleEmptyString(
            _extractMetaData(wooProduct, 'barcode_manufacturer'),
          ) ??
          handleEmptyString(
            _extractMetaData(wooProduct, 'barcode_produttore'),
          ) ??
          handleEmptyString(_extractMetaData(wooProduct, 'supplier_sku')) ??
          handleEmptyString(_extractMetaData(wooProduct, 'barcode')),
      permalink: wooProduct.permalink,
      prezzoNormale: wooProduct.regularPrice ?? wooProduct.price,
      prezzoScontato:
          wooProduct.salePrice ??
          (wooProduct.onSale == true ? wooProduct.price : null),
      costoAcquisto: handleDouble(
        _extractMetaData(wooProduct, '_purchase_cost'),
      ),
      descrizioneBreve: wooProduct.shortDescription,
      descrizioneCompleta: handleEmptyString(wooProduct.description),
      immagineUrl: wooProduct.images?.isNotEmpty == true
          ? wooProduct.images?.first.src
          : null,
      immaginiAggiuntive: wooProduct.images!
          .skip(1)
          .map((img) => img.src ?? '')
          .toList(),
      attributi: () {
        if (_debugAttributeConversion) {
          log.d(
            'DEBUG attributi prodotto ${wooProduct.id} "${wooProduct.name}": count=${wooProduct.attributes?.length ?? 0}',
          );
        }

        final attributi = wooProduct.attributes!.expand((attr) {
          // Espandi ogni attributo in una lista di AttributoVariante, uno per ogni opzione
          // Questo permette al metodo getOpzioniFiltroDisponibili() di funzionare correttamente
          final options = attr.options ?? [];
          if (_debugAttributeConversion) {
            log.d(
              'DEBUG attributo: ${attr.name} opzioni=${options.length} (${options.join(", ")})',
            );
          }

          return options.map(
            (option) => AttributoVariante(
              id: attr.id ?? 0,
              nome: attr.name ?? '',
              opzione: option,
              slug: attr.name?.toLowerCase().replaceAll(' ', '-'),
              tipo: TipoAttributo
                  .select, // Default, potrebbe essere cambiato in seguito
            ),
          );
        }).toList();

        if (_debugAttributeConversion) {
          log.d('DEBUG attributi finali: ${attributi.length}');
        }
        return attributi;
      }(),
      categoria: wooProduct.categories?.isNotEmpty == true
          ? wooProduct.categories!
                .map(
                  (cat) => CategoriaProdotto(
                    id: cat.id ?? 0,
                    nome: cat.name ?? '',
                    slug: cat.slug ?? '',
                  ),
                )
                .toList()
          : [],
      peso: handleEmptyString(wooProduct.weight),
      marca:
          _extractBrandNameFromProductData(productData) ??
          handleEmptyString(_extractMetaData(wooProduct, 'brand')),
      dimensioni: wooProduct.dimensions != null
          ? DimensioniProdotto(
              lunghezza: handleDouble(wooProduct.dimensions?.length) ?? 0.0,
              larghezza: handleDouble(wooProduct.dimensions?.width) ?? 0.0,
              altezza: handleDouble(wooProduct.dimensions?.height) ?? 0.0,
            )
          : null,
      quantitaTotale: wooProduct.stockQuantity,
      inStock: wooProduct.stockStatus?.name == 'instock',
      // Le varianti vengono caricate separatamente, ma salviamo gli ID se presenti
      varianti: [],
      variations: variationIds,
      tipoProdotto: wooProduct.type?.name,
      tag: wooProduct.tags?.isNotEmpty == true
          ? wooProduct.tags!
                .map(
                  (tag) => TagProdotto(
                    id: tag.id ?? 0,
                    nome: tag.name ?? '',
                    slug: tag.slug ?? '',
                  ),
                )
                .toList()
          : [],
      status: handleEmptyString(wooProduct.status?.name) ?? 'draft',
      metadatiCustom: _extractAllMetaData(wooProduct),
      dataCreazione: wooProduct.dateCreated,
      dataModifica: wooProduct.dateModified,
    );
  }

  /// Converte ProdottoGlobal in Map per API WooCommerce
  ///
  /// Trasforma il modello interno ProdottoGlobal in un Map compatibile con l'API WooCommerce.
  /// Gestisce sia prodotti semplici che variabili, preparando i dati necessari per la creazione/aggiornamento.
  /* WooProduct _convert_prodotto_global_To_WooProduct(ProdottoGlobal prodotto/* , List<WooProductCategory> categoryId, List<WooProductTag> tagIds */) {
   
   
    final bool isVariable = prodotto.varianti.isNotEmpty;

    // Dati base del prodotto
    //final data = <String, dynamic>{

    final data = WooProduct(
      name: prodotto.nome,
      //type: isVariable ? 'variable' : 'simple',
      sku: prodotto.barcodeInterno.isNotEmpty ? prodotto.barcodeInterno : '',
      shortDescription: prodotto.descrizioneBreve,
      description: '',  // Verrà sovrascritto se presente descrizioneCompleta
      //status: prodotto.status.isNotEmpty ? prodotto.status : 'draft',
      //categories: categoryId,  // Verrà popolato dal chiamante con gli ID categoria
      //tags: tagIds,  // Verrà popolato dal chiamante con gli ID tag
      //images: [],  // Verrà popolato se ci sono immagini
    );

    /* // Per prodotti semplici, imposta prezzo e stock
    if (!isVariable) {
      data.regular_price = prodotto.prezzoNormale;
      data.manageStock= true;
      data.stockStatus = prodotto.inStock ? 'instock' : 'outofstock';

      // Prezzo scontato (opzionale)
      if (prodotto.prezzoScontato != null && prodotto.prezzoScontato! > 0) {
        data['sale_price'] = prodotto.prezzoScontato.toString();
      }

      // Quantità (opzionale)
      if (prodotto.quantitaTotale != null) {
        data['stock_quantity'] = prodotto.quantitaTotale;
      }
    } else {
      // Per prodotti variabili, NON impostare prezzo e stock a livello di prodotto
      // Questi vengono gestiti a livello di varianti
      data['manage_stock'] = false;
    }

    // Descrizione completa (opzionale)
    if (prodotto.descrizioneCompleta != null && prodotto.descrizioneCompleta!.isNotEmpty) {
      data['description'] = prodotto.descrizioneCompleta;
    }

    // Peso (opzionale)
    if (prodotto.peso != null && prodotto.peso!.isNotEmpty) {
      data['weight'] = prodotto.peso;
    }

    // Dimensioni (opzionali)
    if (prodotto.dimensioni != null) {
      data['dimensions'] = {
        'length': prodotto.dimensioni!.lunghezza.toString(),
        'width': prodotto.dimensioni!.larghezza.toString(),
        'height': prodotto.dimensioni!.altezza.toString(),
      };
    }

    // Immagini
    if (prodotto.immagineUrl.isNotEmpty) {
      final images = <Map<String, dynamic>>[];
      images.add({'src': prodotto.immagineUrl, 'position': 0});

      for (int i = 0; i < prodotto.immaginiAggiuntive.length; i++) {
        images.add({'src': prodotto.immaginiAggiuntive[i], 'position': i + 1});
      }

      data['images'] = images;
    } */

    /* // Attributi per prodotti variabili
    if (prodotto.varianti.isNotEmpty) {
      // Mappa: lowercase -> {nome originale, set di opzioni}
      final attributiMap = <String, Map<String, dynamic>>{};

      // Raccogli tutti gli attributi dalle varianti
      for (final variante in prodotto.varianti) {
        for (final attr in variante.attributi) {
          final nomeKey = attr.nome.toLowerCase();
          if (!attributiMap.containsKey(nomeKey)) {
            attributiMap[nomeKey] = {
              'nome': attr.nome, // Nome originale (case-sensitive)
              'opzioni': <String>{},
            };
          }
          (attributiMap[nomeKey]!['opzioni'] as Set<String>).add(attr.opzione);
        }
      }

      // Converti in formato WooCommerce
      data['attributes'] = attributiMap.values.map((attrData) {
        return {
          'name': attrData['nome'], // Usa il nome originale
          'visible': true,
          'variation': true,
          'options': (attrData['opzioni'] as Set<String>).toList(),
        };
      }).toList();
    } */

    return data;
  } */

  /// Crea WooProduct da ProdottoGlobal usando costruttore manuale (senza JSON)
  ///
  /// Questo approccio evita i bug di WooProduct.fromJson() creando l'oggetto
  /// direttamente con il costruttore. Le immagini includono DateTime.
  Future<WooProduct> convert_prodotto_global_To_WooProduct(
    ProdottoGlobal prodotto,
    //int? categoryId,
    //List<int>? tagIds,
  ) async {
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final bool isVariable = prodotto.varianti?.isNotEmpty ?? false;

    // DEBUG STEP 5: Durante la conversione
    log.d('🔍 DEBUG STEP 5: Conversione categorie');
    for (final cat in prodotto.categoria ?? []) {
      log.d('🔍 Categoria: ID=${cat.id}, Nome=${cat.nome}');
    }

    log.d('🔍 DEBUG STEP 6: Creazione WooProductCategory');
    List<WooProductCategory> wooCategories = [];

    if (prodotto.categoria?.isNotEmpty ?? false) {
      wooCategories = prodotto.categoria!.map((cat) {
        log.d('🔍 Mappatura categoria: ${cat.nome} -> WooProductCategory');
        try {
          final wooCat = WooProductCategory(
            id: cat.id,
            name: cat.nome,
            slug: cat.slug,
          );
          log.d('🔍 WooProductCategory creato con successo per: ${cat.nome}');
          return wooCat;
        } catch (e) {
          log.e('🔍 ERRORE creazione WooProductCategory per ${cat.nome}: $e');
          rethrow;
        }
      }).toList();
    }

    // STEP 1: Crea attributi per prodotto variable se necessario
    List<WooProductItemAttribute> wooAttributes = [];
    if (isVariable && (prodotto.varianti?.isNotEmpty ?? false)) {
      log.d('🔍 DEBUG: Creazione attributi per prodotto variable');

      // Estrai tutti gli attributi unici dalle varianti
      final Map<String, Set<String>> attributiUnici = {};

      for (final variante in prodotto.varianti!) {
        for (final attributo in variante.attributi) {
          final nomeAttributo = attributo.nome;
          final opzioneAttributo = attributo.opzione;

          attributiUnici.putIfAbsent(nomeAttributo, () => <String>{});
          attributiUnici[nomeAttributo]!.add(opzioneAttributo);
        }
      }

      // Ottieni gli attributi esistenti per avere i loro ID
      final attributiEsistenti = await PlatformManager.attributi
          .getAttributes();
      final attributiMap = {
        for (var attr in attributiEsistenti)
          if (attr.name != null) attr.name!.toLowerCase(): attr,
      };

      // Converti in WooProductItemAttribute
      int position = 0;
      for (final entry in attributiUnici.entries) {
        final nomeAttributo = entry.key;
        final opzioni = entry.value.toList();

        log.d('🔍 DEBUG: Attributo $nomeAttributo con opzioni: $opzioni');

        // Cerca l'ID dell'attributo esistente
        final attributoEsistente = attributiMap[nomeAttributo.toLowerCase()];
        final attributoId = attributoEsistente?.id;

        final wooAttribute = WooProductItemAttribute(
          id: attributoId,
          name: nomeAttributo,
          position: position++,
          visible: true,
          variation: true,
          options: opzioni,
        );

        wooAttributes.add(wooAttribute);
      }

      log.d(
        '🔍 DEBUG: Creati ${wooAttributes.length} attributi per prodotto variable',
      );
    }

    try {
      final result = WooProduct(
        name: prodotto.nome,
        type: isVariable ? WooProductType.variable : WooProductType.simple,
        status: _parseProductStatus(prodotto.status),
        sku: (prodotto.codiceProdotto?.isNotEmpty ?? false)
            ? prodotto.codiceProdotto
            : null,
        // Per prodotti variabili, NON impostare prezzo e stock a livello prodotto
        regularPrice: !isVariable ? (prodotto.prezzoNormale ?? 0.0) : null,
        salePrice: !isVariable ? prodotto.prezzoScontato : null,
        description: prodotto.descrizioneCompleta,
        shortDescription: prodotto.descrizioneBreve,
        manageStock: !isVariable && prodotto.quantitaTotale != null,
        stockQuantity: !isVariable ? prodotto.quantitaTotale : null,
        weight: prodotto.peso,
        dimensions: prodotto.dimensioni != null
            ? WooProductDimension(
                length: prodotto.dimensioni!.lunghezza.toString(),
                width: prodotto.dimensioni!.larghezza.toString(),
                height: prodotto.dimensioni!.altezza.toString(),
              )
            : null,
        categories: wooCategories,
        tags: prodotto.tag?.isNotEmpty ?? false
            ? prodotto.tag!
                  .map(
                    (tag) => WooProductTag(
                      id: tag.id,
                      name: tag.nome,
                      slug: tag.slug,
                    ),
                  )
                  .toList()
            : [],
        attributes: wooAttributes, // Aggiungi attributi per prodotti variabili
        images: [
          if (prodotto.immagineUrl?.isNotEmpty ?? false)
            WooProductImage(
              id: null,
              src: prodotto.immagineUrl,
              name: prodotto.nome,
              alt: null,
              dateCreated: now,
              dateCreatedGMT: nowUtc,
              dateModified: now,
              dateModifiedGMT: nowUtc,
            ),
          /* ...prodotto.immaginiAggiuntive.map((url) => WooProductImage(
                id: null,
                src: url,
                name: prodotto.nome,
                alt: null,
                dateCreated: now,
                dateCreatedGMT: nowUtc,
                dateModified: now,
                dateModifiedGMT: nowUtc,
              )), */
        ],
      );
      log.d('🔍 DEBUG: WooProduct creato con successo');
      return result;
    } catch (e) {
      log.e('🔍 ERRORE creazione WooProduct: $e');
      log.e('🔍 STACK TRACE: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Converte Map in WooProduct, assicurando compatibilità con WooProduct.fromJson
  ///
  /// Secondo la documentazione ufficiale WooCommerce REST API v3, solo 'name' è obbligatorio.
  /// Tuttavia, WooProduct.fromJson del package woocommerce_flutter_api ha problemi con:
  /// - DateTime fields che chiamano DateTime.parse() senza controllo null
  /// - Cast diretti su liste (cast int) che falliscono se null
  ///
  /// Questa funzione fornisce valori sicuri per questi campi problematici.
  /* WooProduct _convertToWooProductInput(Map<String, dynamic> data) {
    // Helper per normalizzare liste di oggetti (categories, tags)
    List<Map<String, dynamic>> normalizeList(dynamic list) {
      if (list == null || list is! List) return [];
      return list.whereType<Map>().map((item) => {
        'id': item['id'],
        'name': stringNotNull(item['name'] as String?),
        'slug': stringNotNull(item['slug'] as String?),
      }).toList();
    }

    // Prendi i dati come sono, sovrascrivi solo i campi problematici
    //final safeData = Map<String, dynamic>.from(data);

    // Fix per DateTime.parse() che crashano se null/empty (package bug)
    // Il package chiama DateTime.parse() anche su stringhe vuote, quindi usiamo una data valida
    /* const epochDate = '1970-01-01T00:00:00';

    safeData['date_created'] ??= DateTime.now().toIso8601String();
    safeData['date_created_gmt'] ??= DateTime.now().toUtc().toIso8601String();
    safeData['date_modified'] ??= DateTime.now().toIso8601String();
    safeData['date_modified_gmt'] ??= DateTime.now().toUtc().toIso8601String();

    // Per le date di vendita: usa epochDate invece di stringa vuota per evitare crash
    safeData['date_on_sale_from'] ??= epochDate;
    safeData['date_on_sale_from_gmt'] ??= epochDate;
    safeData['date_on_sale_to'] ??= epochDate;
    safeData['date_on_sale_to_gmt'] ??= epochDate;

    // Fix per campi String che non possono essere null
    safeData['slug'] ??= '';
    safeData['permalink'] ??= '';
    safeData['description'] ??= '';
    safeData['short_description'] ??= '';
    safeData['sku'] ??= '';
    safeData['price'] ??= '0';
    safeData['regular_price'] ??= '0';
    safeData['sale_price'] ??= '0';
    safeData['price_html'] ??= '';
    safeData['type'] ??= 'simple';
    safeData['status'] ??= 'publish';
    safeData['catalog_visibility'] ??= 'visible';
    safeData['tax_status'] ??= 'taxable';
    safeData['tax_class'] ??= '';
    safeData['stock_status'] ??= 'instock';
    safeData['backorders'] ??= 'no';
    safeData['weight'] ??= '';
    safeData['shipping_class'] ??= '';
    safeData['average_rating'] ??= '0';
    safeData['external_url'] ??= '';
    safeData['button_text'] ??= '';

    // Fix per .cast<int>() che fallisce se null (package bug)
    safeData['related_ids'] ??= [];
    safeData['upsell_ids'] ??= [];
    safeData['cross_sell_ids'] ??= [];
    safeData['variations'] ??= [];
    safeData['grouped_products'] ??= [];

    // Fix per liste di oggetti
    safeData['downloads'] ??= [];
    safeData['categories'] = normalizeList(safeData['categories']);
    safeData['tags'] = normalizeList(safeData['tags']);
    safeData['images'] ??= [];
    safeData['attributes'] ??= [];
    safeData['default_attributes'] ??= [];
    safeData['meta_data'] ??= [];

    // Fix per dimensions
    safeData['dimensions'] ??= {'length': '', 'width': '', 'height': ''};  */

    //return WooProduct.fromJson(safeData);
  }  */

  // =======================================================
  // == METODI PRODOTTI (Restituiscono modello globale)  ==
  // =======================================================

  /// Ottiene lista prodotti con paginazione e filtri
  Future<List<ProdottoGlobal>> getProducts({
    int page = 1,
    int perPage = 20,
    ProductFilters? filters,
    bool includeAllStatus = false,
  }) async {
    try {
      final woo = _woo;

      // Usa chiamata diretta quando servono filtri non supportati dal package
      // o quando dobbiamo includere tutti gli status prodotto.
      if (includeAllStatus ||
          (filters?.barcodeInterno?.trim().isNotEmpty ?? false) ||
          (filters?.codiceProdotto?.trim().isNotEmpty ?? false)) {
        final response = await woo.dio.get(
          '/products',
          queryParameters: {
            'page': page,
            'per_page': perPage,
            if (filters?.search != null) 'search': filters!.search,
            if (filters?.category != null) 'category': filters!.category,
            if (filters?.codiceProdotto?.trim().isNotEmpty ?? false)
              'sku': filters!.codiceProdotto,
            if (filters?.barcodeInterno?.trim().isNotEmpty ?? false) ...{
              'search': filters!.barcodeInterno,
              'search_fields': ['global_unique_id'],
            },
            if (_mapWooProductStatusToApi(filters?.status) != null)
              'status': _mapWooProductStatusToApi(filters?.status),
          },
        );

        final List<dynamic> productsData = response.data;
        final converted = <ProdottoGlobal>[];
        for (final productData in productsData) {
          try {
            // Convert JSON to WooProduct first, then to ProdottoGlobal
            final wooProduct = WooProduct.fromJson(productData);
            converted.add(
              convert_wooproduct_To_ProdottoGlobal(
                wooProduct,
                productData: productData as Map<String, dynamic>,
              ),
            );
          } catch (e, stack) {
            log.e('❌ Errore conversione prodotto da JSON: $e');
            log.e('   Stack trace:', stack);
          }
        }
        return converted;
      }

      final wooProducts = await woo.getProducts(
        page: page,
        perPage: perPage,
        search: filters?.search,
        category: filters?.category,
        status: filters?.status ?? WooProductStatus.publish,
      );

      // Converti in modello globale
      final converted = <ProdottoGlobal>[];
      for (final wp in wooProducts.items) {
        try {
          converted.add(convert_wooproduct_To_ProdottoGlobal(wp));
        } catch (e, stack) {
          log.e('❌ Errore conversione prodotto ID ${wp.id} "${wp.name}"', e);
          log.e('   Stack trace:', stack);
          rethrow;
        }
      }
      return converted;
    } catch (e) {
      log.e('❌ Errore getProducts', e);
      rethrow;
    }
  }

  /// Riscarica i prodotti indicati in una sola richiesta (`include`), con
  /// qualunque stato. Serve a mostrare l'ultima versione della pagina
  /// visibile: un prodotto eliminato sul server semplicemente non torna.
  Future<List<ProdottoGlobal>> getProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return const <ProdottoGlobal>[];
    final response = await _woo.dio.get(
      '/products',
      queryParameters: {
        'include': ids.join(','),
        'per_page': ids.length,
        'status': 'any',
      },
    );
    final converted = <ProdottoGlobal>[];
    for (final productData in response.data as List<dynamic>) {
      try {
        converted.add(
          convert_wooproduct_To_ProdottoGlobal(
            WooProduct.fromJson(productData),
            productData: productData as Map<String, dynamic>,
          ),
        );
      } catch (e) {
        log.e('❌ Errore conversione prodotto da JSON: $e');
      }
    }
    return converted;
  }

  /// Prodotti e varianti sotto la propria soglia "scorte basse".
  ///
  /// Usa `wc-analytics/products/low-in-stock`, lo stesso elenco del pannello
  /// WooCommerce, tramite il client del pacchetto (stesse credenziali). Il
  /// modello `WooProduct` non ha `low_stock_amount`, quindi si legge il JSON.
  /// Restano solo gli elementi con soglia impostata sul prodotto: quelli che
  /// ricadono sulla soglia generale del negozio vengono scartati.
  Future<List<ProdottoSottoScorta>> getProdottiSottoScorta({
    int maxPagine = 5,
  }) async {
    final siteUrl = _woo.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = '$siteUrl/wp-json/wc-analytics/products/low-in-stock';
    final risultato = <ProdottoSottoScorta>[];
    for (var pagina = 1; pagina <= maxPagine; pagina++) {
      final response = await _woo.dio.get(
        url,
        queryParameters: {'page': pagina, 'per_page': 100},
      );
      final items = response.data as List<dynamic>;
      for (final item in items.cast<Map<String, dynamic>>()) {
        final soglia = item['low_stock_amount'];
        if (soglia is! num) continue;
        risultato.add(
          ProdottoSottoScorta(
            id: (item['id'] as num?)?.toInt() ?? 0,
            parentId: (item['parent_id'] as num?)?.toInt() ?? 0,
            nome: (item['name'] as String?) ?? '',
            giacenza: (item['stock_quantity'] as num?)?.toInt() ?? 0,
            soglia: soglia.toInt(),
          ),
        );
      }
      final pagine =
          int.tryParse(response.headers.value('x-wp-totalpages') ?? '') ?? 1;
      if (pagina >= pagine) break;
    }
    return risultato;
  }

  Future<PaginatedResult<ProdottoGlobal>> getProductsPaginated({
    int page = 1,
    int perPage = 20,
    ProductFilters? filters,
    bool includeAllStatus = false,
  }) async {
    try {
      final response = await _woo.dio.get(
        '/products',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (filters?.search != null) 'search': filters!.search,
          if (filters?.category != null) 'category': filters!.category,
          if (filters?.codiceProdotto?.trim().isNotEmpty ?? false)
            'sku': filters!.codiceProdotto,
          if (filters?.barcodeInterno?.trim().isNotEmpty ?? false) ...{
            'search': filters!.barcodeInterno,
            'search_fields': ['global_unique_id'],
          },
          if (!includeAllStatus &&
              _mapWooProductStatusToApi(filters?.status) != null)
            'status': _mapWooProductStatusToApi(filters?.status),
        },
      );

      final List<dynamic> productsData = response.data as List<dynamic>;
      final converted = <ProdottoGlobal>[];
      for (final productData in productsData) {
        try {
          final wooProduct = WooProduct.fromJson(productData);
          converted.add(
            convert_wooproduct_To_ProdottoGlobal(
              wooProduct,
              productData: productData as Map<String, dynamic>,
            ),
          );
        } catch (e, stack) {
          log.e('❌ Errore conversione prodotto da JSON: $e');
          log.e('   Stack trace:', stack);
        }
      }

      final totalItems = int.tryParse(
        response.headers.value('x-wp-total') ?? '',
      );
      final totalPages = int.tryParse(
        response.headers.value('x-wp-totalpages') ?? '',
      );

      return PaginatedResult<ProdottoGlobal>(
        items: converted,
        page: page,
        perPage: perPage,
        totalItems: totalItems,
        totalPages: totalPages,
        hasMore: totalPages != null
            ? page < totalPages
            : converted.length >= perPage,
      );
    } catch (e) {
      log.e('❌ Errore getProductsPaginated', e);
      rethrow;
    }
  }

  /// Ottiene un singolo prodotto per ID
  Future<ProdottoGlobal> getProductById(int productId) async {
    try {
      final response = await _woo.dio.get('/products/$productId');
      final productData = response.data as Map<String, dynamic>;
      final wooProduct = WooProduct.fromJson(productData);
      return convert_wooproduct_To_ProdottoGlobal(
        wooProduct,
        productData: productData,
      );
    } catch (e) {
      log.e('❌ Errore getProductById: $productId', e);
      rethrow;
    }
  }

  /// Cerca prodotti per termine
  Future<List<ProdottoGlobal>> searchProducts(
    String searchTerm, {
    int limit = 20,
  }) async {
    return await getProducts(
      perPage: limit,
      filters: ProductFilters(search: searchTerm),
    );
  }

  Future<ProdottoGlobal?> findProductByBarcodeInternoExact(
    String barcodeInterno, {
    int? excludeProductId,
  }) async {
    final barcodeNormalizzato = barcodeInterno.trim();
    if (barcodeNormalizzato.isEmpty) return null;

    final products = await getProducts(
      perPage: 5,
      includeAllStatus: true,
      filters: ProductFilters(barcodeInterno: barcodeNormalizzato),
    );

    for (final product in products) {
      if ((product.id ?? 0) == excludeProductId) continue;
      if ((product.barcodeInterno ?? '').trim().toLowerCase() ==
          barcodeNormalizzato.toLowerCase()) {
        return product;
      }
    }

    return null;
  }

  Future<ProdottoGlobal?> findProductByCodiceProdottoExact(
    String codiceProdotto, {
    int? excludeProductId,
  }) async {
    final codiceNormalizzato = codiceProdotto.trim();
    if (codiceNormalizzato.isEmpty) return null;

    final products = await getProducts(
      perPage: 5,
      includeAllStatus: true,
      filters: ProductFilters(codiceProdotto: codiceNormalizzato),
    );

    for (final product in products) {
      if ((product.id ?? 0) == excludeProductId) continue;
      if ((product.codiceProdotto ?? '').trim().toLowerCase() ==
          codiceNormalizzato.toLowerCase()) {
        return product;
      }
    }

    return null;
  }

  /// Ottiene prodotti per categoria
  Future<List<ProdottoGlobal>> getProductsByCategory(
    int categoryId, {
    int limit = 50,
  }) async {
    return await getProducts(
      perPage: limit,
      filters: ProductFilters(category: categoryId),
    );
  }

  /// Ottiene prodotti in esaurimento
  Future<List<ProdottoGlobal>> getOutOfStockProducts({int limit = 100}) async {
    return await getProducts(
      perPage: limit,
      filters: ProductFilters(stockStatus: 'outofstock'),
    );
  }

  /// Crea un nuovo prodotto (accetta ProdottoGlobal)
  ///
  /// Gestisce automaticamente:
  /// - Creazione di categorie se non esistono
  /// - Creazione di tag se non esistono
  /// - Conversione type-safe usando mapper diretto (evita bug di WooProduct.fromJson)
  Future<ProdottoGlobal> createProduct(ProdottoGlobal prodotto) async {
    final woo = _woo;

    try {
      log.i('🔵 Creazione prodotto: ${prodotto.nome}');

      // DEBUG STEP 1: Analisi dati iniziali
      log.d('🔍 DEBUG STEP 1: Inizio creazione prodotto');
      log.d('🔍 Prodotto nome: ${prodotto.nome}');
      log.d(
        '🔍 Prodotto categorie: ${prodotto.categoria?.map((c) => "ID:${c.id}, Nome:${c.nome}").toList()}',
      );
      log.d(
        '🔍 Prodotto tag: ${prodotto.tag?.map((t) => "ID:${t.id}, Nome:${t.nome}").toList()}',
      );
      log.d('🔍 Prodotto varianti: ${prodotto.varianti?.length ?? 0}');

      final barcodeNormalizzato = (prodotto.barcodeInterno ?? '').trim();
      if (barcodeNormalizzato.isNotEmpty) {
        final existingProduct = await findProductByBarcodeInternoExact(
          barcodeNormalizzato,
        );
        if (existingProduct != null) {
          throw Exception(
            'Barcode interno già esistente in WooCommerce: $barcodeNormalizzato (prodotto ID ${existingProduct.id})',
          );
        }
      }

      final codiceProdottoNormalizzato = (prodotto.codiceProdotto ?? '').trim();
      if (codiceProdottoNormalizzato.isNotEmpty) {
        final existingProduct = await findProductByCodiceProdottoExact(
          codiceProdottoNormalizzato,
        );
        if (existingProduct != null) {
          throw Exception(
            'Codice prodotto già esistente in WooCommerce: $codiceProdottoNormalizzato (prodotto ID ${existingProduct.id})',
          );
        }
      }

      final resolved = await _resolveProductRelations(prodotto);
      final categorieConId = resolved.categorie;
      final tagConId = resolved.tag;
      final marcaConId = resolved.marca;

      // STEP 3: Crea una nuova istanza del prodotto con categorie e tag aggiornati
      final prodottoConId = prodotto.copyWith(
        categoria: categorieConId,
        tag: tagConId,
      );

      // DEBUG STEP 4: Prima della conversione
      log.d('🔍 DEBUG STEP 4: Inizio conversione WooProduct');
      if (prodottoConId.categoria?.isNotEmpty ?? false) {
        log.d(
          '🔍 Prodotto con ID categoria: ${prodottoConId.categoria!.first.id}',
        );
      } else {
        log.d('🔍 Prodotto senza categorie valide');
      }

      final createPayload = _buildProductPayload(
        prodottoConId,
        brand: marcaConId,
        includeVariableAttributes: true,
      );
      log.d('🔍 DEBUG: Payload create prodotto preparato');

      // DEBUG STEP 7: Prima della chiamata API
      log.d('🔍 DEBUG STEP 7: Prima chiamata API');
      try {
        log.d('🔍 DEBUG: Serializzazione JSON completata');
        log.d('📤 Dati da inviare: $createPayload');
      } on TypeError catch (e) {
        log.e('🔍 ERRORE SERIALIZZAZIONE JSON: $e');
        log.e('🔍 STACK TRACE: ${StackTrace.current}');
        rethrow;
      } catch (e) {
        log.e('🔍 ERRORE GENERICO SERIALIZZAZIONE: $e');
        rethrow;
      }

      Map<String, dynamic> finalPayload = Map<String, dynamic>.from(
        createPayload,
      );
      dynamic response;

      try {
        response = await woo.dio.post('/products', data: finalPayload);
      } on DioException catch (e) {
        if (_isSkuDuplicateError(e) && (finalPayload['sku'] is String)) {
          final currentSku = (finalPayload['sku'] as String).trim();
          throw Exception(
            'SKU gia esistente in WooCommerce: $currentSku. Usa uno SKU diverso.',
          );
        } else {
          rethrow;
        }
      }

      final wooProduct = WooProduct.fromJson(
        response.data as Map<String, dynamic>,
      );

      log.i('✅ CREATE PRODUCT - Success: ${wooProduct.id}');

      // STEP 4: Gestione varianti - crea le varianti se presenti
      if (prodotto.varianti?.isNotEmpty ?? false) {
        log.i(
          '🔧 STEP 4: Creazione ${prodotto.varianti!.length} varianti per prodotto ${wooProduct.id}...',
        );
        log.d('🔍 Dettaglio varianti:');
        for (final variante in prodotto.varianti!) {
          log.d(
            '  - Variante: ${variante.nome}, Barcode interno: ${variante.barcodeInterno}, Prezzo: ${variante.prezzo}',
          );
          log.d(
            '    Attributi: ${variante.attributi.map((a) => "${a.nome}:${a.opzione}").toList()}',
          );
        }

        try {
          final variantiCreate = await WooQueryVarianti()
              .createVariationsIfNotExists(
                productId: wooProduct.id!,
                varianti: prodotto.varianti!,
                forcedStatus: prodotto.status,
              );
          log.i(
            '✅ STEP 4: ${variantiCreate.length} varianti create con successo',
          );
        } catch (e) {
          log.e('❌ ERRORE STEP 4: Creazione varianti fallita: $e');
          log.e('🔍 STACK TRACE: ${StackTrace.current}');
          // Non fare rethrow per non bloccare la creazione del prodotto base
        }
      } else {
        log.i('ℹ️ STEP 4: Nessuna variante da creare');
      }

      // Salva i metadata custom del prodotto
      if (prodottoConId.stanza != null ||
          prodottoConId.scaffale != null ||
          prodottoConId.mensola != null) {
        final metadata = <String, dynamic>{};
        if (prodottoConId.stanza?.isNotEmpty ?? false)
          metadata['stanza'] = prodottoConId.stanza!;
        if (prodottoConId.scaffale?.isNotEmpty ?? false)
          metadata['scaffale'] = prodottoConId.scaffale!;
        if (prodottoConId.mensola?.isNotEmpty ?? false)
          metadata['mensola'] = prodottoConId.mensola!;

        if (prodottoConId.barcodeProduttore?.isNotEmpty ?? false) {
          metadata['barcode_manufacturer'] = prodottoConId.barcodeProduttore!;
        }

        // Aggiungi altri metadata custom se presenti
        if (prodotto.metadatiCustom != null) {
          prodotto.metadatiCustom!.forEach((key, value) {
            metadata[key] = value;
          });
        }

        await updateProductMetadata(wooProduct.id!, metadata);
      }

      // Converte il WooProduct ricevuto dal server nel modello ProdottoGlobal
      return convert_wooproduct_To_ProdottoGlobal(
        wooProduct,
        productData: response.data as Map<String, dynamic>,
      );
    } on TypeError catch (e) {
      log.e('🔍 ERRORE TYPE in createProduct: $e');
      log.e('🔍 STACK TRACE: ${StackTrace.current}');
      rethrow;
    } on DioException catch (e) {
      log.e('❌ Errore createProduct', e);
      log.e('❌ createProduct statusCode: ${e.response?.statusCode}');
      log.e('❌ createProduct response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      log.e('❌ Errore createProduct', e);
      rethrow;
    }
  }

  /// Aggiorna un prodotto esistente (accetta ProdottoGlobal)
  Future<ProdottoGlobal> updateProduct(ProdottoGlobal prodotto) async {
    try {
      if ((prodotto.id ?? 0) == 0) {
        throw Exception('Product ID is required for update');
      }

      log.d('🔵 UPDATE PRODUCT ${prodotto.id}');

      final resolved = await _resolveProductRelations(prodotto);
      final prodottoConId = prodotto.copyWith(
        categoria: resolved.categorie,
        tag: resolved.tag,
      );
      final payload = _buildProductPayload(
        prodottoConId,
        brand: resolved.marca,
        includeVariableAttributes: false,
      );
      await _replaceExistingImageUrlsWithIds(prodotto.id!, payload);
      log.d('📤 UPDATE PRODUCT ${prodotto.id} - payload: $payload');
      final response = await _woo.dio.post(
        '/products/${prodotto.id}',
        data: payload,
      );
      final productData = response.data as Map<String, dynamic>;
      final wooProduct = WooProduct.fromJson(productData);

      log.i('✅ UPDATE PRODUCT - Success: ${wooProduct.id}');

      return convert_wooproduct_To_ProdottoGlobal(
        wooProduct,
        productData: productData,
      );
    } on DioException catch (e) {
      log.e('❌ Errore updateProduct: ${prodotto.id}', e);
      log.e('❌ updateProduct statusCode: ${e.response?.statusCode}');
      log.e('❌ updateProduct response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      log.e('❌ Errore updateProduct: ${prodotto.id}', e);
      rethrow;
    }
  }

  /// Elimina un prodotto
  Future<bool> deleteProduct(int productId, {bool force = false}) async {
    try {
      final woo = _woo;

      log.d('🔵 DELETE PRODUCT $productId (force: $force)');

      // Usa il metodo deleteProduct del plugin
      await woo.deleteProduct(productId, force: force);

      log.i('✅ DELETE PRODUCT - Success: $productId');

      return true;
    } catch (e) {
      log.e('❌ Errore deleteProduct: $e');
      rethrow;
    }
  }

  /// Aggiorna lo stock di un prodotto
  Future<ProdottoGlobal> updateProductStock(
    int productId, {
    required int stockQuantity,
    String? stockStatus,
  }) async {
    try {
      final woo = _woo;

      log.d(
        '🔵 UPDATE STOCK - Product $productId: qty=$stockQuantity, status=$stockStatus',
      );

      // Crea WooProduct minimo solo con dati stock
      final wooProductInput = WooProduct(
        stockQuantity: stockQuantity,
        manageStock: true,
        stockStatus: stockStatus != null
            ? _parseStockStatus(stockStatus)
            : null,
      );

      final wooProduct = await woo.updateProduct(productId, wooProductInput);

      log.i('✅ UPDATE STOCK - Success: ${wooProduct.id}');

      return convert_wooproduct_To_ProdottoGlobal(wooProduct);
    } catch (e) {
      log.e('❌ Errore updateProductStock: $e');
      rethrow;
    }
  }

  /// Operazioni batch sui prodotti (usa Dio del plugin per endpoint non disponibili)
  Future<Map<String, dynamic>> batchUpdateProducts({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    try {
      final woo = _woo;

      final batchData = <String, dynamic>{};
      if (create != null && create.isNotEmpty) batchData['create'] = create;
      if (update != null && update.isNotEmpty) batchData['update'] = update;
      if (delete != null && delete.isNotEmpty) batchData['delete'] = delete;

      if (batchData.isEmpty) {
        throw Exception('Nessuna operazione batch specificata');
      }

      log.d('🔵 BATCH UPDATE - ${batchData.length} operations');

      // Usa il Dio del plugin (ha già JWT configurato)
      final response = await woo.dio.post('/products/batch', data: batchData);

      log.i('✅ BATCH UPDATE - Success');

      return response.data as Map<String, dynamic>;
    } catch (e) {
      log.e('❌ Errore batchUpdateProducts: $e');
      rethrow;
    }
  }

  /// Ottiene statistiche rapide sui prodotti
  Future<Map<String, int>> getProductStats() async {
    try {
      final woo = _woo;

      // Chiamate parallele per ottenere conteggi
      final futures = await Future.wait([
        _getProductCount(woo, WooProductStatus.publish),
        _getProductCount(woo, WooProductStatus.draft),
        _getProductCountByStock(woo, 'outofstock'),
      ]);

      return {
        'total_published': futures[0],
        'total_drafts': futures[1],
        'out_of_stock': futures[2],
      };
    } catch (e) {
      log.d('❌ Errore getProductStats: $e');
      return {'total_published': 0, 'total_drafts': 0, 'out_of_stock': 0};
    }
  }

  /// Helper: ottiene il conteggio prodotti per stato
  Future<int> _getProductCount(WooCommerce woo, WooProductStatus status) async {
    /* try {
      // Usa il Dio del plugin (ha già JWT configurato)
      final response = await woo.dio.get(
        '/products',wooProductInput
        queryParameters: {
          'per_page': 1,
          'status': status.toString().split('.').last,
        },
      );

      return int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (e) { */
    return 0;
    //}
  }

  /// Helper: ottiene il conteggio prodotti per stock status
  Future<int> _getProductCountByStock(
    WooCommerce woo,
    String stockStatus,
  ) async {
    try {
      // Usa il Dio del plugin (ha già JWT configurato)
      final response = await woo.dio.get(
        '/products',
        queryParameters: {'per_page': 1, 'stock_status': stockStatus},
      );

      return int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Verifica disponibilità del servizio
  Future<bool> isServiceAvailable() async {
    try {
      await getProducts(perPage: 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Aggiorna i metadata di un prodotto esistente
  Future<bool> updateProductMetadata(
    int productId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      log.d('🔧 Aggiornamento metadata per prodotto $productId');

      // Prepara i metadata per WooCommerce
      final metaDataList = metadata.entries
          .map(
            (entry) => {
              'key': entry.key,
              'value': entry.value?.toString() ?? '',
            },
          )
          .toList();

      // Usa woo.dio per chiamata diretta all'API
      final response = await _woo.dio.post(
        '/products/$productId',
        data: {'meta_data': metaDataList},
      );

      if (response.statusCode == 200) {
        log.i('✅ Metadata aggiornati con successo per prodotto $productId');
        return true;
      } else {
        log.e('❌ Errore aggiornamento metadata: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      log.e('❌ Errore aggiornamento metadata prodotto $productId: $e');
      return false;
    }
  }

  /// Recupera i metadata di un prodotto
  Future<Map<String, String>> getProductMetadata(int productId) async {
    try {
      log.d('🔍 Recupero metadata per prodotto $productId');

      final response = await _woo.dio.get('/products/$productId');

      if (response.statusCode == 200) {
        final productData = response.data as Map<String, dynamic>;
        final metaData = productData['meta_data'] as List<dynamic>? ?? [];

        final metadataMap = <String, String>{};
        for (final meta in metaData) {
          if (meta['key'] != null) {
            metadataMap[meta['key'].toString()] =
                meta['value']?.toString() ?? '';
          }
        }

        log.d(
          '✅ Recuperati ${metadataMap.length} metadata per prodotto $productId',
        );
        return metadataMap;
      } else {
        log.e('❌ Errore recupero metadata: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      log.e('❌ Errore recupero metadata prodotto $productId: $e');
      return {};
    }
  }

  /// Converte uno string status in WooProductStatus (v2 non ha fromString)
  static WooProductStatus _parseProductStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return WooProductStatus.draft;
      case 'pending':
        return WooProductStatus.pending;
      case 'private':
        return WooProductStatus.private;
      case 'publish':
        return WooProductStatus.publish;
      case 'future':
        return WooProductStatus.future;
      default:
        return WooProductStatus.unknown;
    }
  }

  /// Converte uno string stock status in WooProductStockStatus (v2 non ha fromString)
  static WooProductStockStatus _parseStockStatus(String status) {
    switch (status.toLowerCase()) {
      case 'instock':
        return WooProductStockStatus.instock;
      case 'outofstock':
        return WooProductStockStatus.outofstock;
      case 'onbackorder':
        return WooProductStockStatus.onbackorder;
      default:
        return WooProductStockStatus.unknown;
    }
  }
}
