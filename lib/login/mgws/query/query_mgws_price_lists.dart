import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class PriceListsException implements Exception {
  final int statusCode;
  final String message;

  PriceListsException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i listini prezzi B2B MGWS.
class QueryMgwsPriceLists {
  QueryMgwsPriceLists();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list({
    int customerId = 0,
    int supplierId = 0,
    bool? active,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/price-lists',
        queryParameters: <String, dynamic>{
          if (customerId > 0) 'customer_id': customerId,
          if (supplierId > 0) 'supplier_id': supplierId,
          if (active != null) 'active': active,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> get(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get('/wp-json/mgws/v1/price-lists/$id');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required String name,
    int customerId = 0,
    int supplierId = 0,
    String currency = 'EUR',
    String? validFromGmt,
    String? validToGmt,
    String? note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/price-lists',
        data: <String, dynamic>{
          'name': name,
          'customer_id': customerId,
          'supplier_id': supplierId,
          'currency': currency,
          if (validFromGmt != null) 'valid_from_gmt': validFromGmt,
          if (validToGmt != null) 'valid_to_gmt': validToGmt,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String name,
    int customerId = 0,
    int supplierId = 0,
    String currency = 'EUR',
    String? validFromGmt,
    String? validToGmt,
    bool active = true,
    String? note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.patch(
        '/wp-json/mgws/v1/price-lists/$id',
        data: <String, dynamic>{
          'name': name,
          'customer_id': customerId,
          'supplier_id': supplierId,
          'currency': currency,
          if (validFromGmt != null) 'valid_from_gmt': validFromGmt,
          if (validToGmt != null) 'valid_to_gmt': validToGmt,
          'active': active,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> delete(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/price-lists/$id');
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> upsertItem({
    required int listId,
    required int productId,
    int variationId = 0,
    required int priceCents,
    int minQty = 1,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/price-lists/$listId/items',
        data: <String, dynamic>{
          'product_id': productId,
          'variation_id': variationId,
          'price_cents': priceCents,
          'min_qty': minQty,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> removeItem(int listId, int itemId) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.delete(
        '/wp-json/mgws/v1/price-lists/$listId/items/$itemId',
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PriceListsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
