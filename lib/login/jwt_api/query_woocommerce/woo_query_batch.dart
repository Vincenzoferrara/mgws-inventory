import 'package:dio/dio.dart';
import '../woo_connect.dart';

/// Query specifiche WooCommerce per operazioni batch (multiple)
class WooQueryBatch {
  // Singleton pattern
  static final WooQueryBatch _instance = WooQueryBatch._internal();
  factory WooQueryBatch() => _instance;
  WooQueryBatch._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza Dio dal plugin WooCommerce
  Dio get _dio => _wooConnect.woo.dio;

  /// Batch update prodotti (create, update, delete in una chiamata)
  Future<Map<String, dynamic>> batchUpdateProducts(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of products failed: $e');
    }
  }

  /// Batch update ordini
  Future<Map<String, dynamic>> batchUpdateOrders(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/orders/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of orders failed: $e');
    }
  }

  /// Batch update clienti
  Future<Map<String, dynamic>> batchUpdateCustomers(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/customers/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of customers failed: $e');
    }
  }

  /// Batch update coupon
  Future<Map<String, dynamic>> batchUpdateCoupons(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/coupons/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of coupons failed: $e');
    }
  }

  /// Batch update categorie prodotto
  Future<Map<String, dynamic>> batchUpdateCategories(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/categories/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of categories failed: $e');
    }
  }

  /// Batch update tag prodotto
  Future<Map<String, dynamic>> batchUpdateTags(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/tags/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of tags failed: $e');
    }
  }

  /// Batch update varianti prodotto
  Future<Map<String, dynamic>> batchUpdateVariations(
    int productId,
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/$productId/variations/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of variants failed: $e');
    }
  }

  /// Batch update attributi prodotto
  Future<Map<String, dynamic>> batchUpdateAttributes(
    Map<String, dynamic> batchData,
  ) async {
    try {
      final response = await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/attributes/batch',
        data: batchData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Batch update of attributes failed: $e');
    }
  }

  /// Helper: Crea batch data structure per prodotti
  Map<String, dynamic> createProductsBatchData({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) {
    final batch = <String, dynamic>{};

    if (create != null && create.isNotEmpty) {
      batch['create'] = create;
    }

    if (update != null && update.isNotEmpty) {
      batch['update'] = update;
    }

    if (delete != null && delete.isNotEmpty) {
      batch['delete'] = delete;
    }

    return batch;
  }

  /// Helper: Crea batch data structure per ordini
  Map<String, dynamic> createOrdersBatchData({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) {
    return createProductsBatchData(
      create: create,
      update: update,
      delete: delete,
    );
  }

  /// Batch delete massivo prodotti per IDs
  Future<Map<String, dynamic>> batchDeleteProducts(
    List<int> productIds, {
    bool force = false,
  }) async {
    final batchData = createProductsBatchData(delete: productIds);
    if (force) {
      // Aggiungi force a ogni delete
      batchData['delete'] = productIds
          .map((id) => {'id': id, 'force': true})
          .toList();
    }

    return await batchUpdateProducts(batchData);
  }

  /// Batch create multipli prodotti
  Future<Map<String, dynamic>> batchCreateProducts(
    List<Map<String, dynamic>> productsData,
  ) async {
    final batchData = createProductsBatchData(create: productsData);
    return await batchUpdateProducts(batchData);
  }

  /// Batch update prezzi prodotti
  Future<Map<String, dynamic>> batchUpdatePrices(
    List<Map<String, dynamic>> priceUpdates,
  ) async {
    // priceUpdates formato: [{id: 123, regular_price: "10.00", sale_price: "8.00"}, ...]
    final batchData = createProductsBatchData(update: priceUpdates);
    return await batchUpdateProducts(batchData);
  }

  /// Batch update stock quantità prodotti
  Future<Map<String, dynamic>> batchUpdateStock(
    List<Map<String, dynamic>> stockUpdates,
  ) async {
    // stockUpdates formato: [{id: 123, stock_quantity: 50, manage_stock: true}, ...]
    final batchData = createProductsBatchData(update: stockUpdates);
    return await batchUpdateProducts(batchData);
  }

  /// Batch update stati ordini
  Future<Map<String, dynamic>> batchUpdateOrderStatuses(
    List<Map<String, dynamic>> statusUpdates,
  ) async {
    // statusUpdates formato: [{id: 123, status: "completed"}, ...]
    final batchData = createOrdersBatchData(update: statusUpdates);
    return await batchUpdateOrders(batchData);
  }

  /// Importazione massiva prodotti da CSV/JSON
  Future<Map<String, dynamic>> importProducts(
    List<Map<String, dynamic>> productsData, {
    int batchSize = 100,
  }) async {
    final results = <String, dynamic>{
      'success': [],
      'errors': [],
      'total': productsData.length,
    };

    // Divide in batch per evitare timeout
    for (var i = 0; i < productsData.length; i += batchSize) {
      final end = (i + batchSize < productsData.length)
          ? i + batchSize
          : productsData.length;

      final batch = productsData.sublist(i, end);

      try {
        final batchResult = await batchCreateProducts(batch);

        if (batchResult['create'] != null) {
          for (var item in batchResult['create']) {
            if (item['error'] != null) {
              results['errors'].add(item);
            } else {
              results['success'].add(item);
            }
          }
        }
      } catch (e) {
        results['errors'].add({'batch': i, 'error': e.toString()});
      }
    }

    return results;
  }

  /// Verifica disponibilità servizio
  Future<bool> isServiceAvailable() async {
    try {
      // Test con batch vuoto
      await _dio.post(
        '${_wooConnect.siteUrl}/wp-json/wc/v3/products/batch',
        data: {'create': []},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
