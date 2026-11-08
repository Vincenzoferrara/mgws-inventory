import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class LotsException implements Exception {
  final int statusCode;
  final String message;

  LotsException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i lotti di magazzino MGWS.
class QueryMgwsLots {
  QueryMgwsLots();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list({
    required int productId,
    int variationId = 0,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/lots',
        queryParameters: <String, dynamic>{
          'product_id': productId,
          'variation_id': variationId,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw LotsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required int productId,
    int variationId = 0,
    int supplierId = 0,
    String lotCode = '',
    String? expiresAtGmt,
    String? receivedAtGmt,
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
        '/wp-json/mgws/v1/lots',
        data: <String, dynamic>{
          'product_id': productId,
          'variation_id': variationId,
          'supplier_id': supplierId,
          'lot_code': lotCode,
          if (expiresAtGmt != null) 'expires_at_gmt': expiresAtGmt,
          if (receivedAtGmt != null) 'received_at_gmt': receivedAtGmt,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw LotsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    int supplierId = 0,
    String lotCode = '',
    String? expiresAtGmt,
    String? receivedAtGmt,
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
        '/wp-json/mgws/v1/lots/$id',
        data: <String, dynamic>{
          'supplier_id': supplierId,
          'lot_code': lotCode,
          if (expiresAtGmt != null) 'expires_at_gmt': expiresAtGmt,
          if (receivedAtGmt != null) 'received_at_gmt': receivedAtGmt,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw LotsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> delete(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/lots/$id');
    } on DioException catch (e) {
      throw LotsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> upsertLevel({
    required int lotId,
    required int warehouseId,
    String room = '',
    String rack = '',
    String shelf = '',
    required int qty,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.post(
        '/wp-json/mgws/v1/lots/$lotId/levels',
        data: <String, dynamic>{
          'warehouse_id': warehouseId,
          'room': room,
          'rack': rack,
          'shelf': shelf,
          'qty': qty,
        },
      );
    } on DioException catch (e) {
      throw LotsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
