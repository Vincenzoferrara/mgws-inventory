import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class CountScheduleException implements Exception {
  final int statusCode;
  final String message;
  CountScheduleException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class QueryMgwsCountSchedules {
  QueryMgwsCountSchedules();
  final QueryMgwsBase _base = QueryMgwsBase();

  Future<List<dynamic>> list({bool? active}) async {
    if (!await MgwsConnection.instance.ensureConnected()) return [];
    try {
      final r = await _base.get('/wp-json/mgws/v1/inventory/count-schedules', queryParameters: {
        if (active != null) 'active': active,
      });
      final d = r.data;
      if (d is List) return d;
      return [];
    } on DioException catch (e) {
      throw CountScheduleException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required int siteId,
    required int warehouseId,
    int frequencyDays = 30,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/count-schedules', data: {
        'site_id': siteId,
        'warehouse_id': warehouseId,
        'frequency_days': frequencyDays,
      });
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw CountScheduleException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> runDue() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/count-schedules/run-due');
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw CountScheduleException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return e.message ?? 'error';
  }
}