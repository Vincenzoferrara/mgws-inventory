import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

/// MGWS report engine.
///
/// A query is a measure (what to count), an optional dimension (what to split
/// by) and filters. MGWS aggregates POS receipts and WooCommerce online
/// orders server-side; the app never downloads every order.
class QueryMgwsReports {
  QueryMgwsReports();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<bool> isAvailable() => MgwsConnection.instance.ensureConnected();

  /// Measures, dimensions, filters and known values (registers, operators,
  /// payment methods).
  Future<Map<String, dynamic>> catalog() async {
    final response = await _base.get('/wp-json/mgws/v1/reports/catalog');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> query(Map<String, dynamic> request) async {
    final response = await _base.post(
      '/wp-json/mgws/v1/reports/query',
      data: request,
    );
    return _asMap(response.data);
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Unexpected MGWS reports response');
  }
}
