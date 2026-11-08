import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class ReturnsException implements Exception {
  final int statusCode;
  final String message;

  ReturnsException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i resi (RMA) MGWS.
class QueryMgwsReturns {
  QueryMgwsReturns();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list({
    String status = '',
    int orderId = 0,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/returns',
        queryParameters: <String, dynamic>{
          if (status.isNotEmpty) 'status': status,
          if (orderId > 0) 'order_id': orderId,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
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
      final response = await _base.get('/wp-json/mgws/v1/returns/$id');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> create({
    int orderId = 0,
    int customerId = 0,
    int warehouseId = 0,
    String? reason,
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
        '/wp-json/mgws/v1/returns',
        data: <String, dynamic>{
          'order_id': orderId,
          'customer_id': customerId,
          'warehouse_id': warehouseId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> addLine({
    required int returnId,
    required int productId,
    int variationId = 0,
    required int qty,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/returns/$returnId/lines',
        data: <String, dynamic>{
          'product_id': productId,
          'variation_id': variationId,
          'qty': qty,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> removeLine(int returnId, int lineId) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/returns/$returnId/lines/$lineId');
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> delete(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/returns/$id');
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> approve(int id) async {
    return _transition(id, 'approve');
  }

  Future<Map<String, dynamic>> receive(int id) async {
    return _transition(id, 'receive');
  }

  Future<Map<String, dynamic>> reject(int id) async {
    return _transition(id, 'reject');
  }

  Future<Map<String, dynamic>> close(int id) async {
    return _transition(id, 'close');
  }

  Future<Map<String, dynamic>> _transition(int id, String action) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post('/wp-json/mgws/v1/returns/$id/$action');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ReturnsException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
