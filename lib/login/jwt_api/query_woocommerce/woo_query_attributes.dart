import '../woo_connect.dart';
import '../error_list.dart';
import '../../../log_viewer/app_logger.dart';

/// Model per attributo prodotto
class ProductAttribute {
  final int? id;
  final String? name;
  final String? slug;
  final String? type;
  final String? orderBy;
  final bool? hasArchives;

  ProductAttribute({
    this.id,
    this.name,
    this.slug,
    this.type,
    this.orderBy,
    this.hasArchives,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      type: json['type'],
      orderBy: json['order_by'],
      hasArchives: json['has_archives'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (type != null) 'type': type,
      if (orderBy != null) 'order_by': orderBy,
      if (hasArchives != null) 'has_archives': hasArchives,
    };
  }
}

/// Model per termine di attributo
class ProductAttributeTerm {
  final int? id;
  final String? name;
  final String? slug;
  final String? description;
  final int? menuOrder;
  final int? count;

  ProductAttributeTerm({
    this.id,
    this.name,
    this.slug,
    this.description,
    this.menuOrder,
    this.count,
  });

  factory ProductAttributeTerm.fromJson(Map<String, dynamic> json) {
    return ProductAttributeTerm(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'],
      menuOrder: json['menu_order'],
      count: json['count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (description != null) 'description': description,
      if (menuOrder != null) 'menu_order': menuOrder,
      if (count != null) 'count': count,
    };
  }
}

/// Query class per la gestione degli attributi prodotti WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
/// Nota: Gli attributi non sono nel package woocommerce_flutter_api, quindi usa Dio diretto
class WooQueryAttributi {
  // Singleton pattern
  static final WooQueryAttributi _instance = WooQueryAttributi._internal();
  factory WooQueryAttributi() => _instance;
  WooQueryAttributi._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  get _woo => _wooConnect.woo;

  /// Ottiene tutti gli attributi globali
  Future<List<ProductAttribute>> getAttributes() async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final response = await _woo.dio.get('/products/attributes');

    return (response.data as List)
        .map((json) => ProductAttribute.fromJson(json))
        .toList();
  }

  /// Ottiene un attributo per ID
  Future<ProductAttribute> getAttributeById(int attributeId) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final response = await _woo.dio.get('/products/attributes/$attributeId');

    return ProductAttribute.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trova un attributo per nome (case-insensitive)
  Future<ProductAttribute?> findAttributeByName(String name) async {
    try {
      final attributes = await getAttributes();
      // Cerca match esatto case-insensitive
      for (final attr in attributes) {
        if (attr.name?.toLowerCase() == name.toLowerCase()) {
          return attr;
        }
      }
      return null;
    } catch (e) {
      log.e('❌ Errore findAttributeByName: $e');
      return null;
    }
  }

  /// Crea un nuovo attributo globale (VERIFICA ESISTENZA PRIMA)
  Future<ProductAttribute> createAttribute({
    required String name,
    String? slug,
    String? type,
    String? orderBy,
    bool? hasArchives,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    try {
      // STEP 1: Verifica se l'attributo esiste già
      final existing = await findAttributeByName(name);
      if (existing != null) {
        log.e(
          'ℹ️ Attributo "$name" già esistente (ID: ${existing.id}), uso quello esistente',
        );
        return existing;
      }

      // STEP 2: Crea il nuovo attributo
      log.e('🔵 Creazione nuovo attributo: $name');
      final attributeData = {
        'name': name,
        'slug': slug ?? name.toLowerCase().replaceAll(' ', '-'),
        'type': type ?? 'select',
        'order_by': orderBy ?? 'menu_order',
        'has_archives': hasArchives ?? true,
      };

      final response = await _woo.dio.post(
        '/products/attributes',
        data: attributeData,
      );

      final newAttribute = ProductAttribute.fromJson(
        response.data as Map<String, dynamic>,
      );
      log.e('✅ Attributo "$name" creato con successo (ID: ${newAttribute.id})');
      return newAttribute;
    } catch (e) {
      log.e('❌ Errore createAttribute: $e');
      rethrow;
    }
  }

  /// Crea attributo SE NON ESISTE, altrimenti ritorna quello esistente
  Future<ProductAttribute> createAttributeIfNotExists({
    required String name,
    String? slug,
    String? type,
    String? orderBy,
    bool? hasArchives,
  }) async {
    return await createAttribute(
      name: name,
      slug: slug,
      type: type,
      orderBy: orderBy,
      hasArchives: hasArchives,
    );
  }

  /// Aggiorna un attributo esistente
  Future<ProductAttribute> updateAttribute({
    required int attributeId,
    String? name,
    String? slug,
    String? type,
    String? orderBy,
    bool? hasArchives,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final attributeData = {
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (type != null) 'type': type,
      if (orderBy != null) 'order_by': orderBy,
      if (hasArchives != null) 'has_archives': hasArchives,
    };

    final response = await _woo.dio.put(
      '/products/attributes/$attributeId',
      data: attributeData,
    );

    return ProductAttribute.fromJson(response.data as Map<String, dynamic>);
  }

  /// Elimina un attributo
  Future<bool> deleteAttribute({
    required int attributeId,
    bool force = false,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    await _woo.dio.delete(
      '/products/attributes/$attributeId',
      queryParameters: {'force': force},
    );

    return true;
  }

  /// Ottiene i termini di un attributo specifico
  Future<List<ProductAttributeTerm>> getAttributeTerms(
    int attributeId, {
    int page = 1,
    int perPage = 100,
    String? search,
    bool hideEmpty = false,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final queryParams = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search != null) 'search': search,
      'hide_empty': hideEmpty,
    };

    final response = await _woo.dio.get(
      '/products/attributes/$attributeId/terms',
      queryParameters: queryParams,
    );

    return (response.data as List)
        .map((json) => ProductAttributeTerm.fromJson(json))
        .toList();
  }

  /// Ottiene un termine specifico di un attributo
  Future<ProductAttributeTerm> getAttributeTermById(
    int attributeId,
    int termId,
  ) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final response = await _woo.dio.get(
      '/products/attributes/$attributeId/terms/$termId',
    );

    return ProductAttributeTerm.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trova un termine di attributo per nome (case-insensitive)
  Future<ProductAttributeTerm?> findAttributeTermByName(
    int attributeId,
    String name,
  ) async {
    try {
      final terms = await getAttributeTerms(attributeId, search: name);
      // Cerca match esatto case-insensitive
      for (final term in terms) {
        if (term.name?.toLowerCase() == name.toLowerCase()) {
          return term;
        }
      }
      return null;
    } catch (e) {
      log.e('❌ Errore findAttributeTermByName: $e');
      return null;
    }
  }

  /// Crea un nuovo termine per un attributo (VERIFICA ESISTENZA PRIMA)
  Future<ProductAttributeTerm> createAttributeTerm({
    required int attributeId,
    required String name,
    String? slug,
    String? description,
    int? menuOrder,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    try {
      // STEP 1: Verifica se l'attributo esiste
      try {
        await getAttributeById(attributeId);
      } catch (e) {
        throw Exception(
          'Attributo con ID $attributeId non trovato. Impossibile creare il termine.',
        );
      }

      // STEP 2: Verifica se il termine esiste già
      final existing = await findAttributeTermByName(attributeId, name);
      if (existing != null) {
        log.e(
          'ℹ️ Termine "$name" già esistente per attributo $attributeId (ID: ${existing.id}), uso quello esistente',
        );
        return existing;
      }

      // STEP 3: Crea il nuovo termine
      log.e('🔵 Creazione nuovo termine "$name" per attributo $attributeId');
      final termData = {
        'name': name,
        'slug': slug ?? name.toLowerCase().replaceAll(' ', '-'),
        if (description != null) 'description': description,
        if (menuOrder != null) 'menu_order': menuOrder,
      };

      final response = await _woo.dio.post(
        '/products/attributes/$attributeId/terms',
        data: termData,
      );

      final newTerm = ProductAttributeTerm.fromJson(
        response.data as Map<String, dynamic>,
      );
      log.e('✅ Termine "$name" creato con successo (ID: ${newTerm.id})');
      return newTerm;
    } catch (e) {
      log.e('❌ Errore createAttributeTerm: $e');
      rethrow;
    }
  }

  /// Crea termine SE NON ESISTE, altrimenti ritorna quello esistente
  Future<ProductAttributeTerm> createAttributeTermIfNotExists({
    required int attributeId,
    required String name,
    String? slug,
    String? description,
    int? menuOrder,
  }) async {
    return await createAttributeTerm(
      attributeId: attributeId,
      name: name,
      slug: slug,
      description: description,
      menuOrder: menuOrder,
    );
  }

  /// Aggiorna un termine esistente
  Future<ProductAttributeTerm> updateAttributeTerm({
    required int attributeId,
    required int termId,
    String? name,
    String? slug,
    String? description,
    int? menuOrder,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final termData = {
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (description != null) 'description': description,
      if (menuOrder != null) 'menu_order': menuOrder,
    };

    final response = await _woo.dio.put(
      '/products/attributes/$attributeId/terms/$termId',
      data: termData,
    );

    return ProductAttributeTerm.fromJson(response.data as Map<String, dynamic>);
  }

  /// Elimina un termine
  Future<bool> deleteAttributeTerm({
    required int attributeId,
    required int termId,
    bool force = false,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    await _woo.dio.delete(
      '/products/attributes/$attributeId/terms/$termId',
      queryParameters: {'force': force},
    );

    return true;
  }

  /// Ottiene attributi usati per variazioni (colore, taglia, etc.)
  Future<List<ProductAttribute>> getVariationAttributes() async {
    final allAttributes = await getAttributes();
    return allAttributes.where((attr) => attr.hasArchives == true).toList();
  }

  /// Cerca attributi per nome (autocompletamento)
  Future<List<String>> searchAttributeNames(String searchTerm) async {
    if (searchTerm.length < 2) return [];

    final attributes = await getAttributes();
    return attributes
        .map((attr) => attr.name ?? '')
        .where((name) => name.toLowerCase().contains(searchTerm.toLowerCase()))
        .toList();
  }

  /// Ottiene tutti i termini disponibili per un attributo specifico (per autocompletamento)
  Future<List<String>> getAttributeTermNames(
    int attributeId, {
    String? search,
  }) async {
    final terms = await getAttributeTerms(
      attributeId,
      search: search,
      perPage: 100,
    );
    return terms
        .map((term) => term.name ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Crea attributo "Colore" se non esiste
  Future<ProductAttribute> ensureColorAttribute() async {
    final attributes = await getAttributes();

    // Cerca attributo colore esistente
    final colorAttr = attributes.firstWhere(
      (attr) =>
          (attr.name?.toLowerCase() ?? '').contains('color') ||
          (attr.name?.toLowerCase() ?? '').contains('colore'),
      orElse: () => ProductAttribute(),
    );

    if (colorAttr.id != null) {
      return colorAttr;
    }

    // Crea nuovo attributo colore
    return await createAttribute(
      name: 'Colore',
      slug: 'colore',
      type: 'select',
      orderBy: 'menu_order',
      hasArchives: true,
    );
  }

  /// Crea attributo "Taglia" se non esiste
  Future<ProductAttribute> ensureSizeAttribute() async {
    final attributes = await getAttributes();

    final sizeAttr = attributes.firstWhere(
      (attr) =>
          (attr.name?.toLowerCase() ?? '').contains('size') ||
          (attr.name?.toLowerCase() ?? '').contains('taglia'),
      orElse: () => ProductAttribute(),
    );

    if (sizeAttr.id != null) {
      return sizeAttr;
    }

    return await createAttribute(
      name: 'Taglia',
      slug: 'taglia',
      type: 'select',
      orderBy: 'menu_order',
      hasArchives: true,
    );
  }

  /// Ottiene mappa completa attributo → termini per autocompletamento
  Future<Map<String, List<String>>> getAttributeTermsMap() async {
    final attributes = await getAttributes();
    final termsMap = <String, List<String>>{};

    for (final attr in attributes) {
      final attributeId = attr.id;
      final attributeName = attr.name ?? '';

      if (attributeId != null && attributeName.isNotEmpty) {
        try {
          final terms = await getAttributeTermNames(attributeId);
          termsMap[attributeName] = terms;
        } catch (e) {
          termsMap[attributeName] = [];
        }
      }
    }

    return termsMap;
  }

  /// Batch update termini di un attributo
  Future<Map<String, dynamic>> batchUpdateAttributeTerms({
    required int attributeId,
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    if (!_wooConnect.isAuthenticated) {
      throw UnauthorizedException();
    }

    final batchData = {
      if (create != null && create.isNotEmpty) 'create': create,
      if (update != null && update.isNotEmpty) 'update': update,
      if (delete != null && delete.isNotEmpty) 'delete': delete,
    };

    final response = await _woo.dio.post(
      '/products/attributes/$attributeId/terms/batch',
      data: batchData,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Cerca termini di un attributo
  Future<List<ProductAttributeTerm>> searchAttributeTerms({
    required int attributeId,
    required String searchTerm,
  }) async {
    if (searchTerm.length < 2) return [];

    return await getAttributeTerms(
      attributeId,
      search: searchTerm,
      perPage: 50,
    );
  }

  /// Ottiene tutti i termini di un attributo (senza paginazione)
  Future<List<ProductAttributeTerm>> getAllAttributeTerms(
    int attributeId,
  ) async {
    final List<ProductAttributeTerm> allTerms = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      final terms = await getAttributeTerms(
        attributeId,
        page: currentPage,
        perPage: 100,
      );

      if (terms.isEmpty) {
        hasMore = false;
      } else {
        allTerms.addAll(terms);
        currentPage++;
      }
    }

    return allTerms;
  }

  /// Ottiene statistiche attributi
  Future<Map<String, dynamic>> getAttributeStats() async {
    final attributes = await getAttributes();
    int totalTerms = 0;

    for (final attr in attributes) {
      if (attr.id != null) {
        try {
          final terms = await getAttributeTerms(attr.id!);
          totalTerms += terms.length;
        } catch (e) {
          // Continua con il prossimo attributo
        }
      }
    }

    return {
      'total_attributes': attributes.length,
      'total_terms': totalTerms,
      'variation_attributes': attributes
          .where((a) => a.hasArchives == true)
          .length,
    };
  }
}
