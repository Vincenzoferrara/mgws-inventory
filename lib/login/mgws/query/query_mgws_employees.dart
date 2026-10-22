import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class QueryMgwsEmployees {
  QueryMgwsEmployees();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<List<Map<String, dynamic>>> listEmployees({
    String search = '',
    bool includeInactive = false,
    int limit = 100,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected())
      return const <Map<String, dynamic>>[];
    final response = await _base.get(
      '/wp-json/mgws/v1/employees',
      queryParameters: <String, dynamic>{
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'include_inactive': includeInactive,
        'limit': limit,
      },
    );
    if (response.data is List) {
      return (response.data as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> payload,
  ) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    final response = await _base.post(
      '/wp-json/mgws/v1/employees',
      data: payload,
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return const <String, dynamic>{'ok': false};
  }

  Future<Map<String, dynamic>> updateEmployee(
    int id,
    Map<String, dynamic> payload,
  ) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    final response = await _base.patch(
      '/wp-json/mgws/v1/employees/$id',
      data: payload,
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return const <String, dynamic>{'ok': false};
  }

  Future<Map<String, dynamic>> deleteEmployee(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    final response = await _base.delete('/wp-json/mgws/v1/employees/$id');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return const <String, dynamic>{'ok': false};
  }
}
