import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../jwt_api/secure_storage_service.dart';
import '../jwt_api/url_validator.dart';
import '../auth_connector.dart';
import '../../log_viewer/app_logger.dart';
import '../jwt_api/error_list.dart';
import 'wordpress_session.dart';

/// Connettore per autenticazione WordPress nativa (wp-admin credentials).
///
/// Flusso:
/// 1. Login via /wp-login.php (cookie-based)
/// 2. Provisioning Application Password via REST API
/// 3. Basic Auth per tutte le richieste successive
///
/// NESSUN fallback JWT: se fallisce, fallisce.
class WordPressConnect implements AuthConnector {
  static final WordPressConnect _instance = WordPressConnect._internal();
  factory WordPressConnect() => _instance;
  WordPressConnect._internal();

  WordPressSession? _currentSession;
  Dio? _dioInstance;
  bool _dioInitialized = false;

  // --- GETTERS PUBBLICI ---

  @override
  bool get isConnected => _currentSession != null;

  @override
  String? get currentSiteUrl => _currentSession?.siteUrl;

  WordPressSession? get session => _currentSession;

  /// Crea Dio con Basic Auth interceptor
  @override
  Dio getAuthenticatedDio() {
    if (!isConnected) {
      log.e('WordPress: tentativo di usare Dio senza autenticazione');
      throw UnauthorizedException();
    }

    if (_dioInstance == null || !_dioInitialized) {
      log.d('WordPress: creazione istanza Dio con Basic Auth');

      final cleanBaseUrl = _currentSession!.siteUrl.endsWith('/')
          ? _currentSession!.siteUrl.substring(
              0,
              _currentSession!.siteUrl.length - 1,
            )
          : _currentSession!.siteUrl;

      _dioInstance = Dio(
        BaseOptions(
          baseUrl: cleanBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      // Interceptor: Basic Auth + gestione 401
      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (_currentSession != null) {
              final credentials =
                  '${_currentSession!.username}:${_currentSession!.appPassword}';
              final encoded = base64Encode(utf8.encode(credentials));
              options.headers['Authorization'] = 'Basic $encoded';
              log.d('WordPress: Basic Auth aggiunto alla richiesta');
            } else {
              log.e('WordPress: sessione mancante');
            }
            return handler.next(options);
          },
          onResponse: (response, handler) {
            log.d(
              'WordPress: risposta ${response.statusCode} da ${response.requestOptions.uri}',
            );
            return handler.next(response);
          },
          onError: (error, handler) async {
            log.e(
              'WordPress: errore ${error.response?.statusCode} su ${error.requestOptions.uri}',
            );

            // 401 = sessione invalida → re-login, NESSUN retry/fallback
            if (error.response?.statusCode == 401) {
              log.e(
                'WordPress: 401 ricevuto, sessione invalida. Re-login necessario.',
              );
              await disconnect();
            }

            return handler.next(error);
          },
        ),
      );

      // Log debug
      if (kDebugMode) {
        _dioInstance!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              log.d('WordPress: ${options.method} ${options.uri}');
              return handler.next(options);
            },
          ),
        );
      }

      _dioInitialized = true;
      log.d('WordPress: Dio inizializzato con baseUrl: $cleanBaseUrl');
    }

    return _dioInstance!;
  }

  // --- AUTHENTICATOR METHODS ---

  // Limite tentativi auto-connect per sessione app
  static int _autoConnectAttempts = 0;
  static const int _maxAutoConnectAttempts = 3;

  @override
  Future<bool> tryAutoConnect() async {
    // Protezione anti-loop: massimo N tentativi per sessione app
    _autoConnectAttempts++;
    if (_autoConnectAttempts > _maxAutoConnectAttempts) {
      log.w(
        '⚠️ WordPress: auto-connect limit raggiunto '
        '($_autoConnectAttempts/$_maxAutoConnectAttempts). '
        'Login manuale richiesto.',
      );
      return false;
    }

    log.d(
      '🔄 WordPress: tentativo auto-connect '
      '$_autoConnectAttempts/$_maxAutoConnectAttempts',
    );

    final storedData = await SecureStorageService.loadWpSession();
    if (storedData != null) {
      _currentSession = storedData;
      log.d('WordPress: sessione trovata per ${storedData.siteUrl}');

      // Verifica che la sessione sia ancora valida
      try {
        final dio = getAuthenticatedDio();
        final response = await dio.get('/wp-json/wp/v2/users/me');
        if (response.statusCode == 200) {
          log.d('WordPress: auto-connect riuscito');
          _autoConnectAttempts = 0; // Auto-connect riuscito: reset limite
          return true;
        }
      } catch (e) {
        log.w('WordPress: sessione invalida, pulizia');
        await disconnect();
      }
    } else {
      log.d('WordPress: nessuna sessione salvata');
    }
    return false;
  }

  @override
  Future<void> connect({
    required String siteUrl,
    required String username,
    required String password,
    String? customEndpoint,
  }) async {
    log.d(
      'WordPress: login per ${username.length > 3 ? '${username.substring(0, 3)}***' : '***'} @ $siteUrl',
    );

    // Validazione HTTPS: obbligatorio salvo rete locale/sviluppo
    // (stessa regola del form login: UrlValidator + checkbox "sviluppo locale").
    // Permette http://localhost e IP riservati LAN (192.168.x.x, 10.x.x.x,
    // 172.16-31.x.x, 127.x.x.x) e 10.0.2.2 dell'emulatore Android.
    final siteUri = Uri.tryParse(siteUrl);
    final isHttps = siteUri?.scheme == 'https';
    final isLocalHttp =
        siteUri != null &&
        siteUri.scheme == 'http' &&
        UrlValidator.isLocalOrReservedIp(siteUri.host);
    if (!isHttps && !isLocalHttp) {
      throw Exception('HTTPS obbligatorio per l\'autenticazione WordPress');
    }
    if (isLocalHttp) {
      log.w(
        'WordPress: connessione HTTP verso host locale/RFC1918 '
        '(${siteUri.host}): credenziali in chiaro, solo sviluppo.',
      );
    }

    try {
      // Nel browser il login via cookie non e' possibile (niente dart:io,
      // cookie cross-origin non leggibili): la build web, usata solo per lo
      // sviluppo, accetta direttamente un'Application Password.
      if (kIsWeb) {
        await _connectWithApplicationPassword(siteUrl, username, password);
        return;
      }

      // Step 1: Login via /wp-login.php (cookie-based)
      final cookies = await _loginWithCookies(siteUrl, username, password);

      // Step 2: Verifica Application Passwords abilitate + estrai nonce
      final nonce = await _checkApplicationPasswordsEnabled(siteUrl, cookies);

      // Step 3: Provisioning Application Password
      final appPassword = await _provisionApplicationPassword(
        siteUrl,
        username,
        cookies,
        nonce,
      );

      // Step 4: Salva sessione
      final session = WordPressSession(
        username: username,
        appPassword: appPassword,
        siteUrl: siteUrl,
        deviceId: await _getDeviceId(),
      );

      await SecureStorageService.saveWpSession(session);
      _currentSession = session;
      _autoConnectAttempts = 0; // Login esplicito riuscito: reset limite

      // Reset Dio
      _dioInstance = null;
      _dioInitialized = false;

      log.i('WordPress: login completato con successo');
    } on SocketException {
      throw ConnectionException('di rete');
    } on TimeoutException {
      throw ConnectionTimeoutException();
    } catch (e) {
      log.e('WordPress: login fallito', e);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    log.d('WordPress: disconnessione');
    await SecureStorageService.clearWpSession();
    _currentSession = null;
    _dioInstance = null;
    _dioInitialized = false;
    // NOTA: il contatore _autoConnectAttempts NON si resetta qui.
    // Resettarlo nel disconnect automatico vanifica il limite anti-loop.
    // Reset solo a login esplicito o auto-connect riuscito.
    log.d('WordPress: disconnessione completata');
  }

  /// Le Application Passwords non scadono. 401 = re-login.
  @override
  Future<bool> refreshToken() async {
    log.d('WordPress: le application password non necessitano di refresh');
    return false;
  }

  // --- METODI PRIVATI ---

  /// Login solo web: la password inserita e' un'Application Password creata
  /// dal profilo WordPress, verificata con una chiamata REST in Basic Auth.
  Future<void> _connectWithApplicationPassword(
    String siteUrl,
    String username,
    String appPassword,
  ) async {
    log.d('WordPress (web): verifica Application Password');
    final base = siteUrl.endsWith('/')
        ? siteUrl.substring(0, siteUrl.length - 1)
        : siteUrl;
    final credentials = base64Encode(utf8.encode('$username:$appPassword'));
    try {
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Authorization': 'Basic $credentials'},
        ),
      ).get('$base/wp-json/wp/v2/users/me');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw InvalidCredentialsException(
          'Sul web serve un\'Application Password (WordPress > Utenti > '
          'Profilo > Password applicazione), non la password di accesso.',
        );
      }
      throw ConnectionException('di rete');
    }

    final session = WordPressSession(
      username: username,
      appPassword: appPassword,
      siteUrl: siteUrl,
      deviceId: await _getDeviceId(),
    );
    await SecureStorageService.saveWpSession(session);
    _currentSession = session;
    _autoConnectAttempts = 0;
    _dioInstance = null;
    _dioInitialized = false;
    log.i('WordPress (web): login completato con Application Password');
  }

  /// Login via /wp-login.php e estrazione cookie
  Future<Map<String, String>> _loginWithCookies(
    String siteUrl,
    String username,
    String password,
  ) async {
    log.d('WordPress: login via /wp-login.php');

    final uri = Uri.parse('$siteUrl/wp-login.php');
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      // Imposta il cookie test manualmente via header raw (il valore contiene spazi che
      // Dart's Cookie class non accetta).
      request.headers.add(
        'Cookie',
        'wordpress_test_cookie=WP%20Cookie%20check',
      );

      final body = Uri(
        queryParameters: {
          'log': username,
          'pwd': password,
          'wp-submit': 'Accedi',
          'redirect_to': '/wp-admin/',
          'testcookie': '1',
        },
      ).query;

      request.write(body);

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );

      // Raccolta cookie — URL-decodifica i valori (%7C → |) perché WordPress
      // splitta il cookie su | e se inviamo %7C lo split fallisce.
      final cookies = <String, String>{};
      for (final cookie in response.cookies) {
        cookies[cookie.name] = Uri.decodeComponent(cookie.value);
      }

      // Verifica login riuscito (presenza cookie wordpress_logged_in_*)
      final loggedInCookie = cookies.keys.firstWhere(
        (name) => name.startsWith('wordpress_logged_in_'),
        orElse: () => '',
      );

      if (loggedInCookie.isEmpty) {
        log.e('WordPress: login fallito, cookie non trovato');
        throw InvalidCredentialsException(
          'Credenziali non valide o errore del server.',
        );
      }

      log.d('WordPress: login cookie ottenuto');
      return cookies;
    } finally {
      client.close();
    }
  }

  /// Verifica che Application Passwords siano abilitati e restituisce il nonce
  Future<String> _checkApplicationPasswordsEnabled(
    String siteUrl,
    Map<String, String> cookies,
  ) async {
    log.d('WordPress: verifica Application Passwords abilitati');

    final cookieHeader = cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    // Step 2a: Verifica che AP siano abilitati via /wp-json/
    final discoveryResponse = await HttpClient()
        .getUrl(Uri.parse('$siteUrl/wp-json/'))
        .then((request) {
          request.headers.set('Cookie', cookieHeader);
          return request.close();
        })
        .timeout(const Duration(seconds: 10));

    final discoveryBody = await discoveryResponse
        .transform(utf8.decoder)
        .join();

    if (!discoveryBody.contains('application-passwords')) {
      throw Exception(
        'Application Passwords non abilitati sul sito. '
        'Abilitarli da WordPress > Profilo > Application Passwords.',
      );
    }

    log.d('WordPress: Application Passwords abilitati');

    // Step 2b: Estrai il REST nonce dalla pagina wp-admin.
    // Il nonce NON è nel /wp-json/ discovery — va estratto da wp-admin/profile.php
    // cercando il pattern createNonceMiddleware() usato da wp-api-fetch.
    final adminResponse = await HttpClient()
        .getUrl(Uri.parse('$siteUrl/wp-admin/profile.php'))
        .then((request) {
          request.headers.set('Cookie', cookieHeader);
          request.followRedirects = true;
          return request.close();
        })
        .timeout(const Duration(seconds: 15));

    final adminBody = await adminResponse.transform(utf8.decoder).join();

    // Pattern: wp-api-fetch.createNonceMiddleware( "abc123" )
    final nonceMatch = RegExp(
      r'createNonceMiddleware\(\s*"([a-f0-9]+)"\s*\)',
    ).firstMatch(adminBody);

    if (nonceMatch == null) {
      throw Exception(
        'Nonce REST API non trovato nella pagina wp-admin. '
        'Verificare che l\'utente sia autenticato.',
      );
    }

    final nonce = nonceMatch.group(1)!;
    log.d('WordPress: REST nonce estratto da wp-admin');
    return nonce;
  }

  /// Crea una Application Password per questo dispositivo
  Future<String> _provisionApplicationPassword(
    String siteUrl,
    String username,
    Map<String, String> cookies,
    String nonce,
  ) async {
    log.d('WordPress: provisioning Application Password');

    final cookieHeader = cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final deviceId = await _getDeviceId();
    final appName = 'gestione-negozio-$deviceId';

    final uri = Uri.parse(
      '$siteUrl/wp-json/wp/v2/users/me/application-passwords',
    );
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Cookie', cookieHeader);
      request.headers.set('X-WP-Nonce', nonce);

      final body = jsonEncode({'name': appName});
      request.write(body);

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );

      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        final appPassword = json['password'] as String;
        log.d('WordPress: Application Password creata');
        return appPassword;
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        // App password già esistente → prova a recuperarla
        log.w('WordPress: app password già esistente, tentativo recupero');
        return await _getExistingApplicationPassword(
          siteUrl,
          username,
          cookies,
        );
      } else {
        throw Exception(
          'Impossibile creare Application Password: ${json['message'] ?? 'errore sconosciuto'}',
        );
      }
    } finally {
      client.close();
    }
  }

  /// Recupera un'Application Password esistente con lo stesso nome
  Future<String> _getExistingApplicationPassword(
    String siteUrl,
    String username,
    Map<String, String> cookies,
  ) async {
    final cookieHeader = cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final response = await HttpClient()
        .getUrl(
          Uri.parse('$siteUrl/wp-json/wp/v2/users/me/application-passwords'),
        )
        .then((request) {
          request.headers.set('Cookie', cookieHeader);
          return request.close();
        })
        .timeout(const Duration(seconds: 10));

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as List<dynamic>;

    final deviceId = await _getDeviceId();
    final appName = 'gestione-negozio-$deviceId';

    for (final app in json) {
      if (app['name'] == appName) {
        log.d('WordPress: Application Password esistente trovata');
        // Le API REST non restituiscono la password in chiaro
        // L'utente deve riviverla o usarne una esistente
        throw Exception(
          'Application Password già esistente. '
          'Rivolgersi al profilo WordPress per recuperarla o revocarla.',
        );
      }
    }

    throw Exception('Impossibile creare o recuperare Application Password');
  }

  /// Ottiene un ID univoco per questo dispositivo
  Future<String> _getDeviceId() async {
    // Usa un identificatore basato sul platform
    final platform = kIsWeb ? 'web' : Platform.operatingSystem;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$platform-$timestamp';
  }
}
