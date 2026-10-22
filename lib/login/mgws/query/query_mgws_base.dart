import '../../../l10n/known_messages.dart';
import '../../jwt_api/woo_connect.dart';

/// Query base autenticata per le rotte MGWS.
///
/// Il trasporto viene da `WooConnect`, che e' l'unico owner dei connettori:
/// base URL e credenziali arrivano dal connettore realmente in uso (JWT,
/// WordPress Basic Auth o Consumer Key/Secret). Non esiste un connettore
/// secondario ne un fallback: se non c'e' sessione, la richiesta non parte e
/// l'errore resta in chiaro.
class QueryMgwsBase {
  final WooConnect _woo = WooConnect();

  Future<String> ensureBaseUrl() async {
    final baseUrl = _woo.siteUrl ?? '';
    if (baseUrl.isEmpty) {
      throw Exception(AppMessages.noSiteConnected);
    }
    return baseUrl;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final baseUrl = await ensureBaseUrl();
    final dio = _woo.getAuthenticatedDio();
    return dio.get('$baseUrl$endpoint', queryParameters: queryParameters);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? data}) async {
    final baseUrl = await ensureBaseUrl();
    final dio = _woo.getAuthenticatedDio();
    return dio.post('$baseUrl$endpoint', data: data);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? data}) async {
    final baseUrl = await ensureBaseUrl();
    final dio = _woo.getAuthenticatedDio();
    return dio.put('$baseUrl$endpoint', data: data);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? data}) async {
    final baseUrl = await ensureBaseUrl();
    final dio = _woo.getAuthenticatedDio();
    return dio.patch('$baseUrl$endpoint', data: data);
  }

  Future<dynamic> delete(String endpoint) async {
    final baseUrl = await ensureBaseUrl();
    final dio = _woo.getAuthenticatedDio();
    return dio.delete('$baseUrl$endpoint');
  }
}
