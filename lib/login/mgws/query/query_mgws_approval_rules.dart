import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class ApprovalRulesException implements Exception {
  final int statusCode;
  final String message;

  ApprovalRulesException(this.statusCode, this.message);

  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per le regole di approvazione MGWS.
class QueryMgwsApprovalRules {
  QueryMgwsApprovalRules();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> list({String documentType = ''}) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.get(
        '/wp-json/mgws/v1/approval-rules',
        queryParameters: <String, dynamic>{
          if (documentType.isNotEmpty) 'document_type': documentType,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ApprovalRulesException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> create({
    required String documentType,
    required int thresholdCents,
    required String requiredCapability,
    String? note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/approval-rules',
        data: <String, dynamic>{
          'document_type': documentType,
          'threshold_cents': thresholdCents,
          'required_capability': requiredCapability,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ApprovalRulesException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String documentType,
    required int thresholdCents,
    required String requiredCapability,
    bool active = true,
    String? note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.patch(
        '/wp-json/mgws/v1/approval-rules/$id',
        data: <String, dynamic>{
          'document_type': documentType,
          'threshold_cents': thresholdCents,
          'required_capability': requiredCapability,
          'active': active,
          if (note != null) 'note': note,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ApprovalRulesException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<void> delete(int id) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
    try {
      await _base.delete('/wp-json/mgws/v1/approval-rules/$id');
    } on DioException catch (e) {
      throw ApprovalRulesException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  Future<Map<String, dynamic>> check({
    required String documentType,
    required int amountCents,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/approval-rules/check',
        data: <String, dynamic>{
          'document_type': documentType,
          'amount_cents': amountCents,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return const <String, dynamic>{'ok': false};
    } on DioException catch (e) {
      throw ApprovalRulesException(e.response?.statusCode ?? 0, _message(e));
    }
  }

  static String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return AppMessages.mgwsServerUnreachable;
  }
}
