import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

/// Errore contrattuale MGWS sulle rotte permission-sets.
class PermissionSetsException implements Exception {
  final int statusCode;
  final String message;

  PermissionSetsException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i set di permessi MGWS.
class QueryMgwsPermissionSets {
  QueryMgwsPermissionSets();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get('/wp-json/mgws/v1/permission-sets');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PermissionSetsException(
        e.response?.statusCode ?? 0,
        _message(e),
      );
    }
  }

  Future<Map<String, dynamic>> create({
    required String slug,
    required String label,
    required List<String> capabilities,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/permission-sets',
        data: <String, dynamic>{
          'slug': slug,
          'label': label,
          'capabilities': capabilities,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PermissionSetsException(
        e.response?.statusCode ?? 0,
        _message(e),
      );
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required List<String> capabilities,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.patch(
        '/wp-json/mgws/v1/permission-sets/$id',
        data: <String, dynamic>{'capabilities': capabilities},
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw PermissionSetsException(
        e.response?.statusCode ?? 0,
        _message(e),
      );
    }
  }

  Future<void> delete(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/permission-sets/$id');
    } on DioException catch (e) {
      throw PermissionSetsException(
        e.response?.statusCode ?? 0,
        _message(e),
      );
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
