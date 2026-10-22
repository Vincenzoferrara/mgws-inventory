import '../../../l10n/known_messages.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class QueryMgwsUserSettings {
  QueryMgwsUserSettings();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<Map<String, dynamic>> getMySettings() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
        'settings': <String, dynamic>{},
      };
    }
    final response = await _base.get('/wp-json/mgws/v1/me/settings');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return const <String, dynamic>{
      'ok': false,
      'settings': <String, dynamic>{},
    };
  }

  Future<Map<String, dynamic>> patchMySettings(
    Map<String, dynamic> settings,
  ) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'ok': false,
        'message': AppMessages.mgwsUnavailable,
      };
    }
    final response = await _base.patch(
      '/wp-json/mgws/v1/me/settings',
      data: <String, dynamic>{'settings': settings},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return const <String, dynamic>{'ok': false};
  }
}
