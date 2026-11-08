import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class DocumentException implements Exception {
  final int statusCode;
  final String message;
  DocumentException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class QueryMgwsDocuments {
  QueryMgwsDocuments();
  final QueryMgwsBase _base = QueryMgwsBase();

  Future<List<dynamic>> list({String documentType = '', String referenceType = '', int referenceId = 0}) async {
    if (!await MgwsConnection.instance.ensureConnected()) return [];
    try {
      final qp = <String, dynamic>{};
      if (documentType.isNotEmpty) qp['document_type'] = documentType;
      if (referenceType.isNotEmpty) qp['reference_type'] = referenceType;
      if (referenceId > 0) qp['reference_id'] = referenceId;
      final r = await _base.get('/wp-json/mgws/v1/inventory/documents', queryParameters: qp);
      final d = r.data;
      if (d is List) return d;
      if (d is Map && d['items'] is List) return d['items'] as List;
      return [];
    } on DioException catch (e) {
      throw DocumentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required String documentType,
    required String documentNumber,
    String referenceType = '',
    int referenceId = 0,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/documents', data: {
        'document_type': documentType,
        'document_number': documentNumber,
        if (referenceType.isNotEmpty) 'reference_type': referenceType,
        if (referenceId > 0) 'reference_id': referenceId,
      });
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw DocumentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  Future<Map<String, dynamic>> updateStatus(int documentId, String status) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const {'ok': false, 'message': AppMessages.mgwsUnavailable};
    }
    try {
      final r = await _base.post('/wp-json/mgws/v1/inventory/documents/$documentId/status', data: {'status': status});
      if (r.data is Map<String, dynamic>) return r.data as Map<String, dynamic>;
      return const {'ok': false};
    } on DioException catch (e) {
      throw DocumentException(e.response?.statusCode ?? 0, _msg(e));
    }
  }

  String _msg(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return e.message ?? 'error';
  }
}