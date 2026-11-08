import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class PaymentException implements Exception {
  final int statusCode;
  final String message;
  PaymentException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class QueryMgwsPayments {
  QueryMgwsPayments();
  final QueryMgwsBase _base = QueryMgwsBase();

  Future<List<dynamic>> list() async {
    if (!await MgwsConnection.instance.ensureConnected()) return [];
    try {
      final r = await _base.get('/wp-json/mgws/v1/inventory/payments');
      final d = r.data;
      if (d is List) return d;
      if (d is Map && d['items'] is List) return d['items'] as List;
      return [];
    } on DioException catch (e) {
      throw PaymentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> aging() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.get('/wp-json/mgws/v1/inventory/payments/aging');
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw PaymentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required String referenceType,
    required int referenceId,
    required int amountCents,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/payments', data: {
        'reference_type': referenceType,
        'reference_id': referenceId,
        'amount_cents': amountCents,
      });
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw PaymentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return e.message ?? 'error';
  }
}