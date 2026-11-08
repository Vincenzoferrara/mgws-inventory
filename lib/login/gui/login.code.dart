import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../jwt_api/error_list.dart';
import '../jwt_api/woo_connect.dart';
import '../mgws/connection/mgws_connection.dart';
import '../wp_admin_api/browser_location.dart';
import '../wp_admin_api/wp_authorize_app.dart';
import '../../l10n/localized_text.dart';
import '../../log_viewer/app_logger.dart';
import '../../users/class_user_global.dart';
import '../../settings/user_settings_sync.dart';

class LoginCode {
  final WooConnect _woo = WooConnect();

  /// Error of the last return from the WordPress approval page, shown by the
  /// login form when it opens. Read once with [takeWpAuthorizeError].
  LocalizedText? _wpAuthorizeError;

  LocalizedText? takeWpAuthorizeError() {
    final error = _wpAuthorizeError;
    _wpAuthorizeError = null;
    return error;
  }

  /// Web login "WordPress admin": leaves the app for the WordPress approval
  /// page of [siteUrl]. The login ends in [completeWpAuthorizeReturn] when
  /// WordPress sends the browser back.
  Future<void> startWpAuthorize(String siteUrl) async {
    final normalizedUrl = _normalizeUrl(siteUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(wpAuthorizePendingSiteKey, normalizedUrl);
    browserGoTo(
      wpAuthorizeApplicationUrl(
        siteUrl: normalizedUrl,
        returnUrl: Uri.base,
      ).toString(),
    );
  }

  /// At start on the web: when the URL carries the WordPress answer, removes
  /// it from the address bar and finishes the login with the Application
  /// Password received. Returns true when the login succeeded.
  ///
  /// The answer counts only after [startWpAuthorize] on this browser, and the
  /// site is the one the user typed, not the `site_url` in the link: a link
  /// made by someone else cannot connect the app to another site.
  Future<bool> completeWpAuthorizeReturn() async {
    if (!kIsWeb) return false;
    final answer = wpAuthorizeAnswerFromUri(Uri.base);
    if (answer == null) return false;
    browserReplaceUrl(wpAuthorizeReturnUrl(Uri.base).toString());

    final prefs = await SharedPreferences.getInstance();
    final pendingSite = prefs.getString(wpAuthorizePendingSiteKey);
    await prefs.remove(wpAuthorizePendingSiteKey);

    switch (answer) {
      case WpAuthorizeRejected():
        _wpAuthorizeError = (l10n) => l10n.loginWpAuthorizeRejected;
        return false;
      case WpAuthorizeApproved():
        if (pendingSite == null) {
          log.w('WordPress (web): risposta di autorizzazione non richiesta');
          _wpAuthorizeError = (l10n) => l10n.loginWpAuthorizeUnexpected;
          return false;
        }
        try {
          await performWpLogin(
            siteUrl: pendingSite,
            username: answer.userLogin,
            password: answer.password,
          );
          return true;
        } on AppException catch (e) {
          _wpAuthorizeError = e.localizedMessage;
          return false;
        }
    }
  }

  /// Normalizza un URL convertendo 127.0.0.1 in localhost
  /// Necessario per compatibilità con JWT token
  String _normalizeUrl(String url) {
    return url.replaceAll('127.0.0.1', 'localhost');
  }

  /// Tenta il login automatico utilizzando le credenziali salvate
  Future<bool> tryAutoLogin() async {
    final ok = await _woo.tryAutoConnect();
    if (ok) await UserSettingsSync.instance.syncAfterLogin();
    return ok;
  }

  /// Testa la connessione al server
  Future<bool> testConnection() => _woo.testConnection();

  /// Esegue il login con JWT
  Future<void> performLogin({
    required String siteUrl,
    required String username,
    required String password,
    String? customJwtEndpoint,
  }) async {
    // Normalizza l'URL prima del login
    final normalizedUrl = _normalizeUrl(siteUrl);

    await _woo.connectWithJwt(
      siteUrl: normalizedUrl,
      username: username,
      password: password,
      customEndpoint: customJwtEndpoint,
    );
    await UserSettingsSync.instance.syncAfterLogin();
  }

  /// Esegue il login con WooCommerce API (Consumer Key/Secret)
  Future<void> performApiLogin({
    required String siteUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    // Normalizza l'URL prima del login
    final normalizedUrl = _normalizeUrl(siteUrl);

    await _woo.connectWithApi(
      siteUrl: normalizedUrl,
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
    );
    await UserSettingsSync.instance.syncAfterLogin();
  }

  /// Esegue il login con credenziali wp-admin (Application Passwords).
  ///
  /// NESSUN fallback JWT: se fallisce, fallisce con errore esplicito.
  Future<void> performWpLogin({
    required String siteUrl,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = _normalizeUrl(siteUrl);
    await _woo.connectWithWordPress(
      siteUrl: normalizedUrl,
      username: username,
      password: password,
    );
    await UserSettingsSync.instance.syncAfterLogin();
  }

  /// Disconnette l'utente
  Future<void> logout() => _woo.disconnect();

  /// Verifica se l'utente è attualmente connesso
  bool get isConnected => _woo.isAuthenticated;

  /// Indica se MGWS era disponibile nell'ultima verifica di connessione.
  bool get isMgwsAvailable => _woo.isMgwsAvailable;

  /// Stato MGWS centralizzato, lo stesso oggetto usato dai moduli.
  ///
  /// La home e i moduli che richiedono MGWS leggono lo stato da qui, cosi
  /// login e moduli condividono una sola fonte di verita'.
  MgwsConnection get mgwsConnection => MgwsConnection.instance;

  /// Garantisce che lo stato MGWS sia noto e restituisce se e' utilizzabile.
  Future<bool> ensureMgwsConnected() => mgwsConnection.ensureConnected();

  /// Riesegue la verifica centralizzata dei servizi MGWS.
  Future<bool> refreshMgwsAvailability() => _woo.refreshMgwsAvailability();

  /// Username dell'utente autenticato, se noto.
  Future<String?> loggedUsername() => _woo.loggedUsername();

  /// Profilo WP dell'utente corrente (nome + avatar), se leggibile.
  Future<UserGlobal?> currentUserProfile() => _woo.currentUserProfile();

  /// Ottiene l'URL del sito salvato in cache
  String? get cachedSiteUrl => _woo.siteUrl;
}

final loginCode = LoginCode();
