import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class ProductBarcodeException implements Exception {
  final int statusCode;
  final String message;
  ProductBarcodeException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class QueryMgwsProductBarcodes {
  QueryMgwsProductBarcodes();
  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>?> get(int productId) async {
    if (!await MgwsConnection.instance.ensureConnected()) return null;
    try {
      final r = await _base.get('/wp-json/mgws/v1/inventory/product-barcodes/$productId');
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return null;
    } on DioException catch (e) {
      throw ProductBarcodeException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> upsert({required int productId, required String barcode, int variationId = 0}) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/product-barcodes', data: {
        'product_id': productId,
        'variation_id': variationId,
        'barcode': barcode,
      });
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw ProductBarcodeException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return e.message ?? 'error';
  }
}