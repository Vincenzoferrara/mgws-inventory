import '../../../l10n/known_messages.dart';
import '../woo_connect.dart';
import '../../mgws/connection/mgws_connection.dart';

/// Errore contrattuale MGWS sulle rotte permessi/credenziali.
///
/// Espone lo status HTTP cosi la UI puo distinguere il 403 dovuto alle capability
/// richieste dalla rotta (per esempio `mgws_manage_credentials`, riservata
/// all'amministratore) da un fallimento generico.
class PermessiUtenteException implements Exception {
  final int statusCode;
  final String message;

  PermessiUtenteException(this.statusCode, this.message);

  /// L'utente autenticato non ha la capability richiesta dalla rotta.
  bool get nonAutorizzato => statusCode == 403;

  @override
  String toString() => message;
}

/// Query class per i permessi WordPress/MGWS di un dipendente collegato.
///
/// Il client non espone una lista utenti generica: i permessi si leggono e si
/// modificano solo partendo da un dipendente MGWS con `wp_user_id` valorizzato.
/// Non genera credenziali: l'Application Password del dispositivo e gia
/// provisionata dal flusso di login wp-admin, quindi qui si leggono e revocano.
class QueryUserWordPress {
  // Singleton pattern
  static final QueryUserWordPress _instance = QueryUserWordPress._internal();
  factory QueryUserWordPress() => _instance;
  QueryUserWordPress._internal();

  /// Legge ruoli e capability dell'utente WordPress collegato al dipendente.
  Future<Map<String, dynamic>> getUserPermissions(int userId) async {
    final response = await _authorizedGet(
      '/wp-json/mgws/v1/users/$userId/permissions',
    );
    return _readMap(response, 200, AppMessages.employeePermissionsReadFailed);
  }

  /// Aggiorna ruoli e/o capability dell'utente WordPress collegato.
  Future<Map<String, dynamic>> updateUserPermissions({
    required int userId,
    List<String>? roles,
    Map<String, bool>? capabilities,
  }) async {
    final payload = <String, dynamic>{
      if (roles != null) 'roles': roles,
      if (capabilities != null) 'capabilities': capabilities,
    };

    if (payload.isEmpty) {
      throw Exception(AppMessages.nothingToSave);
    }

    final response = await _authorizedPatch(
      '/wp-json/mgws/v1/users/$userId/permissions',
      payload,
    );
    return _readMap(response, 200, AppMessages.employeePermissionsUpdateFailed);
  }

  /// Elenco delle Application Password attive dell'utente collegato.
  Future<Map<String, dynamic>> listApplicationPasswords(int userId) async {
    final response = await _authorizedGet(
      '/wp-json/mgws/v1/users/$userId/app-passwords',
    );
    return _readMap(response, 200, AppMessages.employeeAppPasswordsLoadFailed);
  }

  /// Revoca una Application Password dell'utente collegato.
  Future<void> deleteApplicationPassword({
    required int userId,
    required String uuid,
  }) async {
    final response = await _authorizedDelete(
      '/wp-json/mgws/v1/users/$userId/app-passwords/$uuid',
    );
    _readMap(response, 200, AppMessages.appPasswordRevokeFailed);
  }

  /// Elenco delle WooCommerce API key attive dell'utente collegato.
  Future<Map<String, dynamic>> listWooApiKeys(int userId) async {
    final response = await _authorizedGet(
      '/wp-json/mgws/v1/users/$userId/woo-keys',
    );
    return _readMap(response, 200, AppMessages.employeeWooKeysLoadFailed);
  }

  /// Revoca una WooCommerce API key dell'utente collegato.
  Future<void> deleteWooApiKey({
    required int userId,
    required int keyId,
  }) async {
    final response = await _authorizedDelete(
      '/wp-json/mgws/v1/users/$userId/woo-keys/$keyId',
    );
    _readMap(response, 200, AppMessages.wooKeyRevokeFailed);
  }

  Map<String, dynamic> _readMap(
    dynamic response,
    int expectedStatus,
    String failureMessage,
  ) {
    if (response.statusCode == expectedStatus &&
        response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw PermessiUtenteException(
      response.statusCode,
      '$failureMessage (HTTP ${response.statusCode})',
    );
  }

  Future<dynamic> _authorizedGet(String endpoint) async {
    await _ensureMgwsAvailable();
    final baseUrl = await _ensureBaseUrl();
    return WooConnect().getAuthenticatedDio().get('$baseUrl$endpoint');
  }

  Future<dynamic> _authorizedPatch(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    await _ensureMgwsAvailable();
    final baseUrl = await _ensureBaseUrl();
    return WooConnect().getAuthenticatedDio().patch(
      '$baseUrl$endpoint',
      data: payload,
    );
  }

  Future<dynamic> _authorizedDelete(String endpoint) async {
    await _ensureMgwsAvailable();
    final baseUrl = await _ensureBaseUrl();
    return WooConnect().getAuthenticatedDio().delete('$baseUrl$endpoint');
  }

  /// URL del sito dal connettore in uso, senza tentare connessioni alternative.
  ///
  /// Le rotte MGWS richiedono un utente WordPress: se la sessione attiva non
  /// espone un sito, non esiste un percorso secondario che funzioni.
  Future<String> _ensureBaseUrl() async {
    final baseUrl = WooConnect().siteUrl ?? '';
    if (baseUrl.isEmpty) {
      throw Exception(AppMessages.noSiteConnected);
    }
    return baseUrl;
  }

  /// Ogni operazione su permessi usa lo stato MGWS centralizzato.
  ///
  /// Usa `ensureConnected` e non una verifica forzata: leggere o scrivere un
  /// permesso non richiede di ricontattare il backend, e farlo a ogni
  /// operazione moltiplicherebbe le richieste senza motivo. Se il backend e'
  /// stato fermato a meta' sessione, la prossima verifica della catena di
  /// login o un'azione esplicita dell'utente lo segnalano.
  Future<void> _ensureMgwsAvailable() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      throw StateError(AppMessages.mgwsUnavailable);
    }
  }
}
