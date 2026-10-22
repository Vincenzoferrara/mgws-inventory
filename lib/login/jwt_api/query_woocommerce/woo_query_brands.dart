import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';

import '../woo_connect.dart';
import '../../../products/class_products.dart';
import '../../../log_viewer/app_logger.dart';

/// Query class per la gestione dei marchi prodotto WooCommerce.
/// Usa l'endpoint Woo `/products/brands` in modo analogo a categorie e tag.
class WooQueryMarchi {
  static final WooQueryMarchi _instance = WooQueryMarchi._internal();
  factory WooQueryMarchi() => _instance;
  WooQueryMarchi._internal();

  final WooConnect _wooConnect = WooConnect();

  WooCommerce get _woo => _wooConnect.woo;

  MarcaProdotto _convertToMarcaProdotto(dynamic brandData) {
    if (brandData is Map<String, dynamic>) {
      return MarcaProdotto(
        id: brandData['id'],
        nome: brandData['name'],
        slug: brandData['slug'],
        descrizione: brandData['description']?.toString(),
        count: brandData['count'],
      );
    }

    throw Exception('Tipo brand non supportato: ${brandData.runtimeType}');
  }

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^\w\-]'), '');
  }

  Future<List<MarcaProdotto>> getBrands({
    int page = 1,
    int perPage = 100,
    String? search,
    bool hideEmpty = false,
  }) async {
    try {
      final response = await _woo.dio.get(
        '/products/brands',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.trim().isNotEmpty) 'search': search,
          'hide_empty': hideEmpty,
        },
      );

      final List<dynamic> brandsData = response.data as List<dynamic>;
      return brandsData.map(_convertToMarcaProdotto).toList();
    } catch (e) {
      log.e('❌ Errore getBrands: $e');
      rethrow;
    }
  }

  Future<MarcaProdotto> getBrandById(int brandId) async {
    try {
      final response = await _woo.dio.get('/products/brands/$brandId');
      return _convertToMarcaProdotto(response.data as Map<String, dynamic>);
    } catch (e) {
      log.e('❌ Errore getBrandById: $e');
      rethrow;
    }
  }

  Future<List<MarcaProdotto>> searchBrands(String searchTerm) async {
    return getBrands(search: searchTerm, perPage: 100);
  }

  Future<MarcaProdotto?> findBrandByName(String name) async {
    try {
      final brands = await searchBrands(name);
      for (final brand in brands) {
        if (brand.nome.toLowerCase() == name.toLowerCase()) {
          return brand;
        }
      }
      return null;
    } catch (e) {
      log.e('❌ Errore findBrandByName: $e');
      return null;
    }
  }

  Future<MarcaProdotto> createBrand({
    required String name,
    String? slug,
    String? description,
  }) async {
    try {
      final existing = await findBrandByName(name);
      if (existing != null) {
        log.i('ℹ️ Marchio "$name" già esistente (ID: ${existing.id})');
        return existing;
      }

      final response = await _woo.dio.post(
        '/products/brands',
        data: {
          'name': name,
          'slug': slug ?? _generateSlug(name),
          if (description != null && description.trim().isNotEmpty)
            'description': description,
        },
      );

      return _convertToMarcaProdotto(response.data as Map<String, dynamic>);
    } catch (e) {
      log.e('❌ Errore createBrand: $e');
      rethrow;
    }
  }

  Future<MarcaProdotto?> createBrandIfNotExists(String? brandName) async {
    final normalized = brandName?.trim() ?? '';
    if (normalized.isEmpty) return null;

    try {
      final existing = await findBrandByName(normalized);
      if (existing != null) return existing;
      return await createBrand(name: normalized);
    } catch (e) {
      log.e('❌ Errore createBrandIfNotExists: $e');
      rethrow;
    }
  }
}
