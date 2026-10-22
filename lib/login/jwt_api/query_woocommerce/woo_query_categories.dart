import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../products/class_products.dart';
import '../../../log_viewer/app_logger.dart';

/// Query class per la gestione delle categorie prodotti WooCommerce
/// Converte i dati WooCommerce in modelli globali multi-piattaforma
class WooQueryCategoria {
  // Singleton pattern
  static final WooQueryCategoria _instance = WooQueryCategoria._internal();
  factory WooQueryCategoria() => _instance;
  WooQueryCategoria._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  // =======================================================
  // == CONVERSIONE WOOCOMMERCE → MODELLO GLOBALE        ==
  // =======================================================

  /// Converte WooProductCategory in CategoriaProdotto (modello globale)
  /// Metodo sicuro che gestisce il problema del campo display come stringa
  CategoriaProdotto _convertToCategoriaProdotto(dynamic wooCategoryData) {
    try {
      // Se è già un WooProductCategory, estraiamo i dati manualmente
      if (wooCategoryData is WooProductCategory) {
        return CategoriaProdotto(
          id: wooCategoryData.id ?? 0,
          nome: wooCategoryData.name ?? '',
          slug: wooCategoryData.slug ?? '',
          descrizione: wooCategoryData.description,
          immagine: wooCategoryData.image?.src,
          parentId:
              (wooCategoryData.parent == null || wooCategoryData.parent == 0)
              ? null
              : wooCategoryData.parent,
          count: wooCategoryData.count ?? 0,
          visibile: true,
        );
      }

      // Se è un Map (da JSON), estraiamo i dati manualmente evitando il campo display
      if (wooCategoryData is Map<String, dynamic>) {
        return CategoriaProdotto(
          id: wooCategoryData['id'] ?? 0,
          nome: wooCategoryData['name'] ?? '',
          slug: wooCategoryData['slug'] ?? '',
          descrizione: wooCategoryData['description'],
          immagine: wooCategoryData['image']?['src'],
          parentId:
              (wooCategoryData['parent'] == null ||
                  wooCategoryData['parent'] == 0)
              ? null
              : wooCategoryData['parent'],
          count: wooCategoryData['count'] ?? 0,
          visibile: true,
        );
      }

      throw Exception('Unsupported data type: ${wooCategoryData.runtimeType}');
    } catch (e) {
      log.e('🔍 ERRORE CONVERSIONE CATEGORIA: $e');
      log.e('🔍 TIPO DATI: ${wooCategoryData.runtimeType}');

      // Fallback: crea categoria minima
      if (wooCategoryData is WooProductCategory) {
        return CategoriaProdotto(
          id: wooCategoryData.id ?? 0,
          nome: wooCategoryData.name ?? 'Unknown category',
          slug: wooCategoryData.slug ?? 'unknown-category',
          count: wooCategoryData.count ?? 0,
          visibile: true,
        );
      } else if (wooCategoryData is Map<String, dynamic>) {
        return CategoriaProdotto(
          id: wooCategoryData['id'] ?? 0,
          nome: wooCategoryData['name'] ?? 'Unknown category',
          slug: wooCategoryData['slug'] ?? 'unknown-category',
          count: wooCategoryData['count'] ?? 0,
          visibile: true,
        );
      }

      // Ultimo fallback
      return CategoriaProdotto(
        id: 0,
        nome: 'Category error',
        slug: 'category-error',
        count: 0,
        visibile: true,
      );
    }
  }

  // =======================================================
  // == METODI CATEGORIE (Restituiscono modello globale) ==
  // =======================================================

  /// Ottiene lista categorie con paginazione e filtri
  Future<List<CategoriaProdotto>> getCategories({
    int page = 1,
    int perPage = 20,
    String? search,
    int? parent,
    bool? hideEmpty,
    String orderBy = 'name',
    String order = 'asc',
  }) async {
    try {
      final woo = _woo;

      // Usa chiamata diretta per evitare problemi di deserializzazione
      final response = await woo.dio.get(
        '/products/categories',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null) 'search': search,
          if (parent != null) 'parent': parent,
          if (hideEmpty != null) 'hide_empty': hideEmpty,
          'orderby': orderBy,
          'order': order,
        },
      );

      final List<dynamic> categoriesData = response.data;
      return categoriesData
          .map((data) => _convertToCategoriaProdotto(data))
          .toList();
    } catch (e) {
      log.e('❌ Errore getCategories: $e');
      rethrow;
    }
  }

  /// Ottiene una categoria specifica per ID
  Future<CategoriaProdotto> getCategoryById(int categoryId) async {
    try {
      final woo = _woo;
      final response = await woo.dio.get('/products/categories/$categoryId');
      return _convertToCategoriaProdotto(response.data);
    } catch (e) {
      log.e('❌ Errore getCategoryById: $e');
      rethrow;
    }
  }

  /// Ottiene categorie principali (senza parent)
  Future<List<CategoriaProdotto>> getMainCategories({
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final woo = _woo;
      final response = await woo.dio.get(
        '/products/categories',
        queryParameters: {'parent': 0, 'page': page, 'per_page': perPage},
      );
      final List<dynamic> categoriesData = response.data;
      return categoriesData
          .map((data) => _convertToCategoriaProdotto(data))
          .toList();
    } catch (e) {
      log.e('❌ Errore getMainCategories: $e');
      rethrow;
    }
  }

  /// Ottiene sottocategorie di una categoria
  Future<List<CategoriaProdotto>> getSubcategories(
    int parentId, {
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final woo = _woo;
      final response = await woo.dio.get(
        '/products/categories',
        queryParameters: {
          'parent': parentId,
          'page': page,
          'per_page': perPage,
        },
      );
      final List<dynamic> categoriesData = response.data;
      return categoriesData
          .map((data) => _convertToCategoriaProdotto(data))
          .toList();
    } catch (e) {
      log.e('❌ Errore getSubcategories: $e');
      rethrow;
    }
  }

  /// Cerca categorie per nome
  Future<List<CategoriaProdotto>> searchCategories(String searchTerm) async {
    try {
      log.d('🔍 DEBUG: Ricerca categorie con termine: "$searchTerm"');
      final woo = _woo;
      final response = await woo.dio.get(
        '/products/categories',
        queryParameters: {'search': searchTerm, 'per_page': 100},
      );
      final List<dynamic> categoriesData = response.data;
      log.d(
        '🔍 DEBUG: Trovate ${categoriesData.length} categorie per "$searchTerm"',
      );
      for (final cat in categoriesData) {
        log.d('🔍 DEBUG: Categoria trovata: ${cat['name']} (ID: ${cat['id']})');
      }
      return categoriesData
          .map((data) => _convertToCategoriaProdotto(data))
          .toList();
    } catch (e) {
      log.e('❌ Errore searchCategories: $e');
      rethrow;
    }
  }

  /// Crea categorie se non esistono, altrimenti restituisce quelle esistenti
  /// Questo è l'UNICO metodo da usare per creare categorie
  /// Accetta List<CategoriaProdotto> e restituisce List<CategoriaProdotto> con ID
  Future<List<CategoriaProdotto>> createCategoryIfNotExists(
    List<CategoriaProdotto> categorie,
  ) async {
    try {
      final List<CategoriaProdotto> categorieConId = [];

      for (final categoria in categorie) {
        // Se la categoria ha già un ID valido, assumiamo che esista
        if (categoria.id != 0) {
          log.i(
            '✅ Categoria con ID esistente: ${categoria.nome} (ID ${categoria.id})',
          );
          categorieConId.add(categoria);
          continue;
        }

        // Cerca categorie esistenti con lo stesso nome
        log.d('🔍 DEBUG: Ricerca categoria esistente: "${categoria.nome}"');
        final existingCategories = await searchCategories(categoria.nome);
        log.d(
          '🔍 DEBUG: Trovate ${existingCategories.length} categorie corrispondenti',
        );
        for (final cat in existingCategories) {
          log.d(
            '🔍 DEBUG: Categoria trovata - ID:${cat.id}, Nome:"${cat.nome}"',
          );
        }

        // Verifica se esiste una categoria con nome esatto (case-insensitive)
        CategoriaProdotto? exactMatch;
        for (final cat in existingCategories) {
          if (cat.nome.toLowerCase() == categoria.nome.toLowerCase()) {
            exactMatch = cat;
            break;
          }
        }

        if (exactMatch != null) {
          log.i(
            '✅ Categoria esistente trovata: ${exactMatch.nome} (ID ${exactMatch.id})',
          );
          categorieConId.add(exactMatch);
        } else {
          // Se non esiste, crea la categoria
          log.i('🔵 Creazione nuova categoria: ${categoria.nome}');

          try {
            log.d(
              '🔍 DEBUG CAT: Preparazione creazione categoria per: ${categoria.nome}',
            );
            log.d(
              '🔍 DEBUG CAT: Dati categoria - nome: ${categoria.nome}, slug: ${categoria.slug}',
            );

            // Usa chiamata diretta per evitare problemi del costruttore
            final response = await _woo.dio.post(
              '/products/categories',
              data: {
                'name': categoria.nome,
                'slug': categoria.slug.isNotEmpty
                    ? categoria.slug
                    : categoria.nome.toLowerCase().replaceAll(' ', '-'),
                if (categoria.descrizione?.isNotEmpty ?? false)
                  'description': categoria.descrizione,
              },
            );

            // Converte dalla risposta JSON diretta
            final categoriaConvertita = _convertToCategoriaProdotto(
              response.data,
            );
            categorieConId.add(categoriaConvertita);
          } catch (e) {
            // Se fallisce la creazione, NON aggiungere la categoria con ID 0
            // Il prodotto verrà creato senza categoria e potrà essere associato dopo
            log.e(
              '❌ Errore dettagliato creazione categoria "${categoria.nome}": $e',
            );
            log.e('❌ Stack trace: ${StackTrace.current}');
            log.w(
              '⚠️ Impossibile creare categoria "${categoria.nome}", prodotto creato senza categoria',
            );
            // Non aggiungere nulla a categorieConId
          }
        }
      }

      return categorieConId;
    } catch (e) {
      log.e('❌ Errore createCategoryIfNotExists: $e');
      rethrow;
    }
  }

  /// Crea una nuova categoria
  Future<CategoriaProdotto> createCategory({
    required String name,
    String? slug,
    int? parent,
    String? description,
    int? image,
    int? menuOrder,
  }) async {
    try {
      final woo = _woo;

      // Prova a creare la categoria senza specificare il campo display
      final newCategory = WooProductCategory(
        name: name,
        slug: slug,
        parent: parent,
        description: description,
        image: image != null ? WooProductCategoryImage(id: image) : null,
        menuOrder: menuOrder,
      );

      log.d('📤 Creazione categoria senza campo display');
      final wooCategory = await woo.createCategory(newCategory);
      return _convertToCategoriaProdotto(wooCategory);
    } catch (e) {
      // Gestione errore categoria esistente tramite WooConnect
      try {
        final errorData = e.toString();
        if (errorData.contains('term_exists') || errorData.contains('400')) {
          // Prova a recuperare la categoria esistente per nome
          final categoriesPage = await _woo.getCategories(search: name);

          if (categoriesPage.items.isNotEmpty) {
            final existingCategory = categoriesPage.items.first;
            log.w('⚠️ Categoria già esistente con ID: ${existingCategory.id}');
            return _convertToCategoriaProdotto(existingCategory);
          }
        }
      } catch (searchError) {
        log.e('❌ Errore ricerca categoria esistente: $searchError');
      }

      log.e('❌ Errore createCategory: $e');
      rethrow;
    }
  }

  /// Aggiorna una categoria esistente
  Future<CategoriaProdotto> updateCategory({
    required int categoryId,
    String? name,
    String? slug,
    int? parent,
    String? description,
    String? display,
    int? image,
    int? menuOrder,
  }) async {
    try {
      final woo = _woo;

      // Prima ottieni la categoria esistente
      final existingCategory = await woo.getCategory(categoryId);

      // Crea una nuova categoria con i campi aggiornati
      final updatedCategory = WooProductCategory(
        id: categoryId,
        name: name ?? existingCategory.name,
        slug: slug ?? existingCategory.slug,
        parent: parent ?? existingCategory.parent,
        description: description ?? existingCategory.description,
        // display: display != null ? WooCategoryDisplay.fromString(display) : existingCategory.display, // Commentato per evitare errore serializzazione
        image: image != null
            ? WooProductCategoryImage(id: image)
            : existingCategory.image,
        menuOrder: menuOrder ?? existingCategory.menuOrder,
        count: existingCategory.count,
      );

      final wooCategory = await woo.updateCategory(
        updatedCategory.id ?? 0,
        updatedCategory,
      );
      return _convertToCategoriaProdotto(wooCategory);
    } catch (e) {
      log.e('❌ Errore updateCategory: $e');
      rethrow;
    }
  }

  /// Elimina una categoria
  Future<bool> deleteCategory({
    required int categoryId,
    bool force = false,
  }) async {
    final woo = _woo;
    final r = await woo.deleteCategory(categoryId, force: force);
    return r.deleted;
  }

  /// Ottiene tutte le categorie (uso con cautela!)
  Future<List<CategoriaProdotto>> getAllCategories() async {
    try {
      final woo = _woo;
      final List<CategoriaProdotto> allCategories = [];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        final wooCategories = await woo.getCategories(
          page: currentPage,
          perPage: 100,
        );

        if (wooCategories.items.isEmpty) {
          hasMore = false;
        } else {
          allCategories.addAll(
            wooCategories.items.map((wc) => _convertToCategoriaProdotto(wc)),
          );
          currentPage++;
        }
      }

      return allCategories;
    } catch (e) {
      log.e('❌ Errore getAllCategories: $e');
      rethrow;
    }
  }

  /// Batch update categorie
  Future<Map<String, dynamic>> batchUpdateCategories({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    final batchData = {
      if (create != null && create.isNotEmpty) 'create': create,
      if (update != null && update.isNotEmpty) 'update': update,
      if (delete != null && delete.isNotEmpty) 'delete': delete,
    };

    // Usa l'istanza Dio del plugin che ha già l'autenticazione JWT
    final response = await _woo.dio.post(
      '/products/categories/batch',
      data: batchData,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Ottiene l'albero delle categorie (gerarchico)
  Future<List<Map<String, dynamic>>> getCategoryTree() async {
    try {
      final mainCategories = await getMainCategories(perPage: 100);
      final List<Map<String, dynamic>> tree = [];

      for (var category in mainCategories) {
        final subcategories = await getSubcategories(category.id);
        tree.add({'category': category, 'subcategories': subcategories});
      }

      return tree;
    } catch (e) {
      log.e('❌ Errore getCategoryTree: $e');
      rethrow;
    }
  }

  /// Conta i prodotti in una categoria
  Future<int> countProductsInCategory(int categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      return category.count;
    } catch (e) {
      log.e('❌ Errore countProductsInCategory: $e');
      return 0;
    }
  }

  /// Verifica se una categoria ha sottocategorie
  Future<bool> hasSubcategories(int categoryId) async {
    final subcategories = await getSubcategories(categoryId, perPage: 1);
    return subcategories.isNotEmpty;
  }

  /// Ottiene categorie vuote
  Future<List<CategoriaProdotto>> getEmptyCategories() async {
    try {
      final woo = _woo;
      final wooCategories = await woo.getCategories(
        hideEmpty: true,
        perPage: 100,
      );
      return wooCategories.items
          .map((wc) => _convertToCategoriaProdotto(wc))
          .toList();
    } catch (e) {
      log.e('❌ Errore getEmptyCategories: $e');
      rethrow;
    }
  }

  /// Riordina le categorie
  Future<List<CategoriaProdotto>> reorderCategories(
    List<Map<String, dynamic>> categoriesWithOrder,
  ) async {
    try {
      final updates = categoriesWithOrder.map((item) {
        return {'id': item['id'], 'menu_order': item['menu_order']};
      }).toList();

      await batchUpdateCategories(update: updates);
      return await getCategories(perPage: 100);
    } catch (e) {
      log.e('❌ Errore reorderCategories: $e');
      rethrow;
    }
  }

  /// Sposta una categoria sotto un nuovo parent
  Future<CategoriaProdotto> moveCategory({
    required int categoryId,
    required int newParentId,
  }) async {
    return await updateCategory(categoryId: categoryId, parent: newParentId);
  }

  /// Ottiene il percorso (breadcrumb) di una categoria
  Future<List<CategoriaProdotto>> getCategoryPath(int categoryId) async {
    try {
      final List<CategoriaProdotto> path = [];
      CategoriaProdotto? currentCategory = await getCategoryById(categoryId);

      while (currentCategory != null) {
        path.insert(0, currentCategory);
        if (currentCategory.parentId != null && currentCategory.parentId! > 0) {
          currentCategory = await getCategoryById(currentCategory.parentId!);
        } else {
          currentCategory = null;
        }
      }

      return path;
    } catch (e) {
      log.e('❌ Errore getCategoryPath: $e');
      rethrow;
    }
  }

  /// Ottiene statistiche categorie
  Future<Map<String, dynamic>> getCategoryStats() async {
    final response = await _woo.dio.get(
      '/products/categories',
      queryParameters: {'per_page': 1, 'page': 1},
    );

    final totalCategories =
        int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;

    final mainCategories = await getMainCategories(perPage: 1);
    final emptyCategories = await getEmptyCategories();

    return {
      'total_categories': totalCategories,
      'main_categories_count': mainCategories.length,
      'empty_categories_count': emptyCategories.length,
    };
  }

  /// Ottiene categorie più popolari (con più prodotti)
  Future<List<CategoriaProdotto>> getPopularCategories({int limit = 10}) async {
    try {
      final categories = await getCategories(hideEmpty: true, perPage: 100);

      // Ordina per count (numero di prodotti) decrescente
      categories.sort((a, b) => b.count.compareTo(a.count));

      return categories.take(limit).toList();
    } catch (e) {
      log.e('❌ Errore getPopularCategories: $e');
      rethrow;
    }
  }

  /// Conta i prodotti in una categoria (ricorsivo per sottocategorie)
  Future<int> getTotalProductsInCategory(
    int categoryId, {
    bool includeSubcategories = true,
  }) async {
    try {
      var total = 0;

      // Conta prodotti nella categoria corrente
      final category = await getCategoryById(categoryId);
      total += category.count;

      // Se richiesto, conta anche nelle sottocategorie
      if (includeSubcategories) {
        final subCategories = await getSubcategories(categoryId);
        for (final subCategory in subCategories) {
          total += await getTotalProductsInCategory(
            subCategory.id,
            includeSubcategories: true,
          );
        }
      }

      return total;
    } catch (e) {
      log.e('❌ Errore getTotalProductsInCategory: $e');
      return 0;
    }
  }

  /// Verifica se una categoria può essere eliminata (non ha prodotti né sottocategorie)
  Future<bool> canDeleteCategory(int categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      final hasProducts = category.count > 0;
      final hasSubcategoriesResult = await hasSubcategories(categoryId);

      return !hasProducts && !hasSubcategoriesResult;
    } catch (e) {
      log.e('❌ Errore canDeleteCategory: $e');
      return false;
    }
  }

  /// Ottiene statistiche categoria dettagliate
  Future<Map<String, dynamic>> getCategoryDetailedStats(int categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      final subCategories = await getSubcategories(categoryId);
      final totalProducts = await getTotalProductsInCategory(categoryId);
      final path = await getCategoryPath(categoryId);

      return {
        'nome': category.nome,
        'slug': category.slug,
        'prodotti_diretti': category.count,
        'prodotti_totali': totalProducts,
        'sottocategorie': subCategories.length,
        'livello_profondita': path.length,
        'path': path.map((c) => c.nome).join(' > '),
      };
    } catch (e) {
      log.e('❌ Errore getCategoryDetailedStats: $e');
      rethrow;
    }
  }
}
