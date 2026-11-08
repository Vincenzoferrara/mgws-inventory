import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class KitDeductionException implements Exception {
  final int statusCode;
  final String message;
  KitDeductionException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class for kit stock deduction (components per physical site).
class QueryMgwsKits {
  QueryMgwsKits();

  final QueryMgwsBase _base = QueryMgwsBase();

  /// Per-site availability of a kit product: how many kits can be built from
  /// the component stock of each physical site.
  Future<Map<String, dynamic>> availability({
    required int productId,
    int variationId = 0,
    int qty = 1,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/inventory/kits/availability',
        queryParameters: <String, dynamic>{
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
      throw KitDeductionException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  /// Deduct component stock for [qty] kits from a single physical site.
  Future<Map<String, dynamic>> deduct({
    required int siteId,
    required int productId,
    int variationId = 0,
    int qty = 1,
    int refOrderId = 0,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/inventory/kits/deduct',
        data: <String, dynamic>{
          'site_id': siteId,
          'product_id': productId,
          'variation_id': variationId,
          'qty': qty,
          if (refOrderId > 0) 'ref_order_id': refOrderId,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw KitDeductionException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  /// Restore component stock for [qty] kits to a single physical site.
  Future<Map<String, dynamic>> restore({
    required int siteId,
    required int productId,
    int variationId = 0,
    int qty = 1,
    int refOrderId = 0,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/inventory/kits/restore',
        data: <String, dynamic>{
          'site_id': siteId,
          'product_id': productId,
          'variation_id': variationId,
          'qty': qty,
          if (refOrderId > 0) 'ref_order_id': refOrderId,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw KitDeductionException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  /// Kit definitions with their components.
  Future<List<Map<String, dynamic>>> list() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw KitDeductionException(0, AppMessages.mgwsUnavailable);
    }
    try {
      final response = await _base.get('/wp-json/mgws/v1/inventory/kits');
      final data = response.data;
      return data is List
          ? data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
    } on DioException catch (e) {
      throw KitDeductionException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  /// Declares which sold product is a kit.
  Future<Map<String, dynamic>> create({
    required String name,
    required int productId,
    int variationId = 0,
  }) =>
      _write(
        () => _base.post(
          '/wp-json/mgws/v1/inventory/kits',
          data: <String, dynamic>{
            'name': name,
            'product_id': productId,
            'variation_id': variationId,
          },
        ),
      );

  Future<Map<String, dynamic>> addComponent({
    required int kitId,
    required int productId,
    int variationId = 0,
    required int qty,
  }) =>
      _write(
        () => _base.post(
          '/wp-json/mgws/v1/inventory/kits/$kitId/components',
          data: <String, dynamic>{
            'product_id': productId,
            'variation_id': variationId,
            'qty': qty,
          },
        ),
      );

  Future<Map<String, dynamic>> removeComponent(int componentId) =>
      _write(() => _base.delete('/wp-json/mgws/v1/inventory/kits/components/$componentId'));

  Future<Map<String, dynamic>> delete(int kitId) =>
      _write(() => _base.delete('/wp-json/mgws/v1/inventory/kits/$kitId'));

  Future<Map<String, dynamic>> _write(Future<dynamic> Function() call) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw KitDeductionException(0, AppMessages.mgwsUnavailable);
    }
    try {
      final response = await call();
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{'ok': true};
    } on DioException catch (e) {
      throw KitDeductionException(e.response?.statusCode ?? 0, _message(e));
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