import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class StockResetException implements Exception {
  final int statusCode;
  final String message;

  StockResetException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per il reset massivo dello stock MGWS.
class QueryMgwsStockReset {
  QueryMgwsStockReset();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> reset({
    required int warehouseId,
    required int targetQty,
    List<int> productIds = const <int>[],
    bool dryRun = false,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/inventory/stock/reset',
        data: <String, dynamic>{
          'warehouse_id': warehouseId,
          'target_qty': targetQty,
          if (productIds.isNotEmpty) 'product_ids': productIds,
          if (dryRun) 'dry_run': true,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw StockResetException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'error';
  }
}