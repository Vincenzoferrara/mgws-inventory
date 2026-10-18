import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

/// Dashboards stored by MGWS.
///
/// Personal dashboards belong to the logged-in user; shared dashboards are
/// visible to every user (`everyone`) or only to shop managers (`admins`).
/// The server decides who may manage shared dashboards and reports it as
/// `can_manage_shared`.
class QueryMgwsDashboards {
  QueryMgwsDashboards();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<bool> isAvailable() => MgwsConnection.instance.ensureConnected();

  Future<Map<String, dynamic>> list() async {
    final response = await _base.get('/wp-json/mgws/v1/dashboards');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Unexpected MGWS dashboards response');
  }

  Future<Map<String, dynamic>> save({
    required String dashboardId,
    required String name,
    required String visibility,
    required Map<String, dynamic> layout,
  }) async {
    final response = await _base.put(
      '/wp-json/mgws/v1/dashboards/${Uri.encodeComponent(dashboardId)}',
      data: <String, dynamic>{
        'name': name,
        'visibility': visibility,
        'layout': layout,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Unexpected MGWS dashboard save response');
  }

  Future<void> delete(String dashboardId) async {
    await _base.delete(
      '/wp-json/mgws/v1/dashboards/${Uri.encodeComponent(dashboardId)}',
    );
  }
}
