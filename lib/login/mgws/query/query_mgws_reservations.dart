import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class ReservationException implements Exception {
  final int statusCode;
  final String message;
  ReservationException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class QueryMgwsReservations {
  QueryMgwsReservations();
  final QueryMgwsBase _base = QueryMgwsBase();

  Future<List<dynamic>> list() async {
    if (!await MgwsConnection.instance.ensureConnected()) return [];
    try {
      final r = await _base.get('/wp-json/mgws/v1/inventory/reservations');
      final d = r.data;
      if (d is List) return d;
      if (d is Map && d['items'] is List) return d['items'] as List;
      return [];
    } on DioException catch (e) {
      throw ReservationException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> create({required int productId, int variationId = 0, required int qty}) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/reservations', data: {
        'product_id': productId,
        'variation_id': variationId,
        'qty': qty,
      });
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw ReservationException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> release(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/reservations/$id/release');
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw ReservationException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> consume(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/reservations/$id/consume');
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw ReservationException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return e.message ?? 'error';
  }
}