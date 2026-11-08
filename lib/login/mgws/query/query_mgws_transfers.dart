import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class TransfersException implements Exception {
  final int statusCode;
  final String message;

  TransfersException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i trasferimenti con stato MGWS.
class QueryMgwsTransfers {
  QueryMgwsTransfers();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list({String status = ''}) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/transfers',
        queryParameters: <String, dynamic>{
          if (status.isNotEmpty) 'status': status,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
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
      final response = await _base.get('/wp-json/mgws/v1/transfers/$id');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required int fromWarehouseId,
    required int toWarehouseId,
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
        '/wp-json/mgws/v1/transfers',
        data: <String, dynamic>{
          'from_warehouse_id': fromWarehouseId,
          'to_warehouse_id': toWarehouseId,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> addLine({
    required int transferId,
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
        '/wp-json/mgws/v1/transfers/$transferId/lines',
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
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> removeLine(int transferId, int lineId) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/transfers/$transferId/lines/$lineId');
    } on DioException catch (e) {
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> send(int id) async {
    return _transition(id, 'send');
  }

  Future<Map<String, dynamic>> receive(int id) async {
    return _transition(id, 'receive');
  }

  Future<Map<String, dynamic>> cancel(int id) async {
    return _transition(id, 'cancel');
  }

  Future<Map<String, dynamic>> _transition(int id, String action) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post('/wp-json/mgws/v1/transfers/$id/$action');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw TransfersException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
