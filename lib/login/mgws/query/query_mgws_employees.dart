import 'package:dio/dio.dart';

import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

/// Error of an employee route, with the server's code (`mgws_shift_overlap`,
/// `mgws_email_exists`, ...) so the app can say it in the operator's language.
class MgwsEmployeeException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  /// `data` of the WordPress error, minus `status`.
  final Map<String, dynamic> data;

  MgwsEmployeeException(
    this.statusCode,
    this.code,
    this.message, {
    this.data = const <String, dynamic>{},
  });

  @override
  String toString() => message;
}

/// [QueryMgwsBase] that turns an HTTP error into [MgwsEmployeeException]
/// instead of Dio's own description of the status code.
class _EmployeesBase extends QueryMgwsBase {
  Future<dynamic> _guard(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      final map = data is Map ? data : const <String, dynamic>{};
      throw MgwsEmployeeException(
        e.response?.statusCode ?? 0,
        (map['code'] ?? '').toString(),
        map['message'] is String
            ? map['message'] as String
            : (e.message ?? 'error'),
        data: map['data'] is Map
            ? Map<String, dynamic>.from(map['data'] as Map)
            : const <String, dynamic>{},
      );
    }
  }

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) => _guard(() => super.get(endpoint, queryParameters: queryParameters));

  @override
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? data}) =>
      _guard(() => super.post(endpoint, data: data));

  @override
  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? data}) =>
      _guard(() => super.patch(endpoint, data: data));

  @override
  Future<dynamic> delete(String endpoint) =>
      _guard(() => super.delete(endpoint));
}

class QueryMgwsEmployees {
  QueryMgwsEmployees();

  final QueryMgwsBase _base = _EmployeesBase();

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

  /// Utenti WordPress non ancora collegati a un dipendente, per nome, login o
  /// email. Sotto i due caratteri il server non cerca.
  Future<List<Map<String, dynamic>>> linkableUsers(String search) async {
    if (!await MgwsConnection.instance.ensureConnected())
      return const <Map<String, dynamic>>[];
    final response = await _base.get(
      '/wp-json/mgws/v1/employees/linkable-users',
      queryParameters: <String, dynamic>{'search': search.trim()},
    );
    final data = response.data;
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
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

  Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};

  Future<void> _connesso() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw Exception(AppMessages.mgwsUnavailable);
    }
  }

  /// Turni di un periodo (`from`/`to` YYYY-MM-DD) con il riepilogo ore.
  Future<Map<String, dynamic>> shifts(
    int employeeId,
    String from,
    String to,
  ) async {
    await _connesso();
    final response = await _base.get(
      '/wp-json/mgws/v1/employees/$employeeId/shifts',
      queryParameters: <String, dynamic>{'from': from, 'to': to},
    );
    return _map(response.data);
  }

  Future<Map<String, dynamic>> createShift(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    await _connesso();
    final response = await _base.post(
      '/wp-json/mgws/v1/employees/$employeeId/shifts',
      data: payload,
    );
    return _map(response.data);
  }

  Future<Map<String, dynamic>> updateShift(
    int employeeId,
    int shiftId,
    Map<String, dynamic> payload,
  ) async {
    await _connesso();
    final response = await _base.patch(
      '/wp-json/mgws/v1/employees/$employeeId/shifts/$shiftId',
      data: payload,
    );
    return _map(response.data);
  }

  Future<void> deleteShift(int employeeId, int shiftId) async {
    await _connesso();
    await _base.delete(
      '/wp-json/mgws/v1/employees/$employeeId/shifts/$shiftId',
    );
  }

  /// Copia la settimana tipo sul periodo; con [replace] sostituisce i turni
  /// gia' presenti invece di saltare quei giorni.
  Future<Map<String, dynamic>> generateShifts(
    int employeeId,
    String from,
    String to, {
    bool replace = false,
  }) async {
    await _connesso();
    final response = await _base.post(
      '/wp-json/mgws/v1/employees/$employeeId/shifts/generate',
      data: <String, dynamic>{'from': from, 'to': to, 'replace': replace},
    );
    return _map(response.data);
  }

  Future<List<Map<String, dynamic>>> documents(int employeeId) async {
    await _connesso();
    final response = await _base.get(
      '/wp-json/mgws/v1/employees/$employeeId/documents',
    );
    final items = _map(response.data)['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
  }

  /// Carica un documento: il file viaggia in base64 (`content_base64`).
  Future<Map<String, dynamic>> uploadDocument(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    await _connesso();
    final response = await _base.post(
      '/wp-json/mgws/v1/employees/$employeeId/documents',
      data: payload,
    );
    return _map(response.data);
  }

  Future<Map<String, dynamic>> downloadDocument(
    int employeeId,
    int documentId,
  ) async {
    await _connesso();
    final response = await _base.get(
      '/wp-json/mgws/v1/employees/$employeeId/documents/$documentId',
    );
    return _map(response.data);
  }

  Future<void> deleteDocument(int employeeId, int documentId) async {
    await _connesso();
    await _base.delete(
      '/wp-json/mgws/v1/employees/$employeeId/documents/$documentId',
    );
  }
}
