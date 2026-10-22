import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../products/class_products.dart';
import '../../../log_viewer/app_logger.dart';

/// Query class per la gestione dei tag prodotti WooCommerce
/// Converte i dati WooCommerce in modelli globali multi-piattaforma
class WooQueryTag {
  // Singleton pattern
  static final WooQueryTag _instance = WooQueryTag._internal();
  factory WooQueryTag() => _instance;
  WooQueryTag._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  // =======================================================
  // == UTILITY METHODS                                   ==
  // =======================================================

  /// Converte un valore dynamic a int, gestendo String e null
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // =======================================================
  // == CONVERSIONE WOOCOMMERCE → MODELLO GLOBALE        ==
  // =======================================================

  /// Converte WooProductTag in TagProdotto (modello globale)
  TagProdotto _convertToTagProdotto(WooProductTag wooTag) {
    return TagProdotto(
      id: _toInt(wooTag.id),
      nome: wooTag.name ?? '',
      slug: wooTag.slug ?? '',
      descrizione: wooTag.description,
      count: _toInt(wooTag.count),
    );
  }

  /// Converte TagProdotto (modello globale) in WooProductTag
  WooProductTag _convertTagProdottoToWoo(TagProdotto tag) {
    // Se slug è vuoto, genera automaticamente dal nome
    final slug = tag.slug.isNotEmpty
        ? tag.slug
        : tag.nome
              .toLowerCase()
              .replaceAll(' ', '-')
              .replaceAll(RegExp(r'[^\w\-]'), '');

    return WooProductTag(
      id: tag.id != 0 ? tag.id : null,
      name: tag.nome,
      slug: slug,
      description: tag.descrizione,
      count: tag.count,
    );
  }

  // =======================================================
  // == METODI TAG (Restituiscono modello globale)       ==
  // =======================================================

  /// Ottiene lista tag con paginazione e filtri
  Future<List<TagProdotto>> getTags({
    int page = 1,
    int perPage = 100,
    String? search,
    bool hideEmpty = false,
  }) async {
    try {
      final woo = _woo;

      final result = await woo.getProductTags(
        page: page,
        perPage: perPage,
        search: search,
        hideEmpty: hideEmpty,
      );
      return result.items.map((wt) => _convertToTagProdotto(wt)).toList();
    } catch (e) {
      log.e('❌ Errore getTags: $e');
      rethrow;
    }
  }

  /// Ottiene un tag per ID
  Future<TagProdotto> getTagById(int tagId) async {
    try {
      final woo = _woo;
      final wooTag = await woo.getProductTag(tagId);
      return _convertToTagProdotto(wooTag);
    } catch (e) {
      log.e('❌ Errore getTagById: $e');
      rethrow;
    }
  }

  /// Cerca tag per nome
  Future<List<TagProdotto>> searchTags(String searchTerm) async {
    try {
      final woo = _woo;
      final page = await woo.getProductTags(search: searchTerm, perPage: 100);
      return page.items.map((wt) => _convertToTagProdotto(wt)).toList();
    } catch (e) {
      log.e('❌ Errore searchTags: $e');
      rethrow;
    }
  }

  /// Crea un nuovo tag (VERIFICA ESISTENZA PRIMA)
  Future<TagProdotto> createTag({
    required String name,
    String? slug,
    String? description,
  }) async {
    try {
      // STEP 1: Verifica se il tag esiste già
      final existing = await findTagByName(name);
      if (existing != null) {
        log.e(
          'ℹ️ Tag "$name" già esistente (ID: ${existing.id}), uso quello esistente',
        );
        return existing;
      }

      // STEP 2: Crea il nuovo tag
      log.e('🔵 Creazione nuovo tag: $name');
      final woo = _woo;

      final tag = WooProductTag(
        id: null,
        name: name,
        slug: slug ?? name.toLowerCase().replaceAll(' ', '-'),
        description: description,
        count: 0,
      );

      final wooTag = await woo.createProductTag(tag);
      log.e('✅ Tag "$name" creato con successo (ID: ${wooTag.id})');
      return _convertToTagProdotto(wooTag);
    } catch (e) {
      log.e('❌ Errore createTag: $e');
      rethrow;
    }
  }

  /// Trova un tag per nome (case-insensitive)
  Future<TagProdotto?> findTagByName(String name) async {
    try {
      final tags = await searchTags(name);
      // Cerca match esatto case-insensitive
      for (final tag in tags) {
        if (tag.nome.toLowerCase() == name.toLowerCase()) {
          return tag;
        }
      }
      return null;
    } catch (e) {
      log.e('❌ Errore findTagByName: $e');
      return null;
    }
  }

  /// Crea tag SE NON ESISTONO, altrimenti ritorna quelli esistenti
  /// Questo è l'UNICO metodo da usare per creare tag
  /// Accetta List<TagProdotto> e restituisce List<TagProdotto> con ID
  Future<List<TagProdotto>> createTagIfNotExists(List<TagProdotto> tags) async {
    try {
      final List<TagProdotto> tagConId = [];

      for (final tag in tags) {
        // Se il tag ha già un ID valido, assumiamo che esista
        if (tag.id != 0) {
          log.e('✅ Tag con ID esistente: ${tag.nome} (ID ${tag.id})');
          tagConId.add(tag);
          continue;
        }

        // Cerca tag esistente con lo stesso nome
        final existingTag = await findTagByName(tag.nome);

        if (existingTag != null) {
          log.e(
            '✅ Tag esistente trovato: ${existingTag.nome} (ID ${existingTag.id})',
          );
          tagConId.add(existingTag);
        } else {
          // Se non esiste, crea il tag usando il convertitore diretto
          log.e('🔵 Creazione nuovo tag: ${tag.nome}');
          final wooTag = _convertTagProdottoToWoo(tag);
          final nuovoTag = await _woo.createProductTag(wooTag);
          final tagConvertito = _convertToTagProdotto(nuovoTag);
          tagConId.add(tagConvertito);
        }
      }

      return tagConId;
    } catch (e) {
      log.e('❌ Errore createTagIfNotExists: $e');
      rethrow;
    }
  }

  /// Aggiorna un tag esistente
  Future<TagProdotto> updateTag({
    required int tagId,
    String? name,
    String? slug,
    String? description,
  }) async {
    try {
      final woo = _woo;

      // Prima ottieni il tag esistente
      final existingTag = await woo.getProductTag(tagId);

      // Crea un nuovo tag con i campi aggiornati
      final updatedTag = WooProductTag(
        id: tagId,
        name: name ?? existingTag.name,
        slug: slug ?? existingTag.slug,
        description: description ?? existingTag.description,
        count: existingTag.count,
      );

      final wooTag = await woo.updateProductTag(tagId, updatedTag);
      return _convertToTagProdotto(wooTag);
    } catch (e) {
      log.e('❌ Errore updateTag: $e');
      rethrow;
    }
  }

  /// Elimina un tag
  Future<bool> deleteTag({required int tagId}) async {
    try {
      final woo = _woo;
      await woo.deleteProductTag(tagId);
      return true;
    } catch (e) {
      log.e('❌ Errore deleteTag: $e');
      rethrow;
    }
  }

  /// Ottiene tutti i tag (uso con cautela!)
  Future<List<TagProdotto>> getAllTags() async {
    try {
      final woo = _woo;
      final List<TagProdotto> allTags = [];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        final page = await woo.getProductTags(page: currentPage, perPage: 100);

        if (page.items.isEmpty) {
          hasMore = false;
        } else {
          allTags.addAll(page.items.map((wt) => _convertToTagProdotto(wt)));
          currentPage++;
        }
      }

      return allTags;
    } catch (e) {
      log.e('❌ Errore getAllTags: $e');
      rethrow;
    }
  }

  /// Batch update tag (usa Dio diretto)
  Future<Map<String, dynamic>> batchUpdateTags({
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
      '/products/tags/batch',
      data: batchData,
    );

    return response.data as Map<String, dynamic>;
  }

  /// Verifica se un tag esiste per nome
  Future<bool> tagExists(String name) async {
    try {
      final tags = await searchTags(name);
      return tags.any((tag) => tag.nome.toLowerCase() == name.toLowerCase());
    } catch (e) {
      log.e('❌ Errore tagExists: $e');
      return false;
    }
  }

  /// Ottiene tag per slug
  Future<TagProdotto?> getTagBySlug(String slug) async {
    try {
      final woo = _woo;
      final page = await woo.getProductTags(slug: slug, perPage: 1);

      return page.items.isNotEmpty
          ? _convertToTagProdotto(page.items.first)
          : null;
    } catch (e) {
      log.e('❌ Errore getTagBySlug: $e');
      return null;
    }
  }

  /// Ottiene statistiche tag
  Future<Map<String, dynamic>> getTagStats() async {
    final response = await _woo.dio.get(
      '/products/tags',
      queryParameters: {'per_page': 1, 'page': 1},
    );

    final totalTags =
        int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;

    return {'total_tags': totalTags};
  }

  /// Ottiene tag più usati
  Future<List<TagProdotto>> getTopTags({int limit = 10}) async {
    try {
      final woo = _woo;
      final page = await woo.getProductTags(
        perPage: limit,
        orderBy: WooOrderBy.count,
        order: WooSort.desc,
        hideEmpty: true,
      );
      return page.items.map((wt) => _convertToTagProdotto(wt)).toList();
    } catch (e) {
      log.e('❌ Errore getTopTags: $e');
      rethrow;
    }
  }
}
