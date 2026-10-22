import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import 'error_list.dart';
import '../../l10n/localized_text.dart';
import '../../log_viewer/app_logger.dart';
import '../auth_connector.dart';

/// Tipi di autenticazione supportati
enum AuthType { jwt, woocommerceApi, wordpress }

/// Configurazione WooCommerce
class WooConfig {
  final String baseUrl;
  final String consumerKey;
  final String consumerSecret;

  WooConfig({
    required this.baseUrl,
    required this.consumerKey,
    required this.consumerSecret,
  });
}

/// Un oggetto di sessione che contiene i dati necessari dopo un login riuscito.
class UserSession {
  final String token;
  final DateTime expiresAt;
  final AuthType authType;
  final WooConfig? wooConfig;

  UserSession({
    required this.token,
    required this.expiresAt,
    this.authType = AuthType.jwt,
    this.wooConfig,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory UserSession.fromJson(Map<String, dynamic> json) {
    WooConfig? parsedWooConfig;
    final rawWoo = json['woo_config'];
    if (rawWoo is Map<String, dynamic>) {
      final baseUrl = (rawWoo['base_url'] ?? '').toString();
      final consumerKey = (rawWoo['consumer_key'] ?? '').toString();
      final consumerSecret = (rawWoo['consumer_secret'] ?? '').toString();
      // Hardening compatibility: allow persisted sessions without Woo secrets.
      if (baseUrl.isNotEmpty &&
          consumerKey.isNotEmpty &&
          consumerSecret.isNotEmpty) {
        parsedWooConfig = WooConfig(
          baseUrl: baseUrl,
          consumerKey: consumerKey,
          consumerSecret: consumerSecret,
        );
      }
    }

    return UserSession(
      token: json['token'],
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expires_at']),
      authType: AuthType.values[json['auth_type'] ?? 0],
      wooConfig: parsedWooConfig,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'auth_type': authType.index,
      if (wooConfig != null)
        'woo_config': {
          'base_url': wooConfig!.baseUrl,
          'consumer_key': wooConfig!.consumerKey,
          'consumer_secret': wooConfig!.consumerSecret,
        },
    };
  }
}

/// Servizio centralizzato per l'autenticazione e la gestione della sessione JWT.
class JwtConnect implements AuthConnector {
  // Pattern Singleton per garantire una sola istanza del servizio nell'app.
  static final JwtConnect _instance = JwtConnect._internal();
  factory JwtConnect() => _instance;
  JwtConnect._internal();

  UserSession? _currentSession;
  String? _currentSiteUrl;
  // Username di login (identificativo non segreto): attribuisce l'operatore
  // di cassa all'utente autenticato senza esporre token o password.
  String? _currentUsername;
  Dio? _dioInstance;
  http.Client _httpClient = http.Client();
  bool _dioInitialized = false;

  // --- GETTERS PUBBLICI PER LO STATO ---
  @override
  bool get isConnected =>
      _currentSession != null && !_currentSession!.isExpired;
  @override
  String? get currentSiteUrl => _currentSiteUrl;
  UserSession? get session => isConnected ? _currentSession : null;

  /// Username dell'utente autenticato via JWT, se noto.
  String? get currentUsername => _currentUsername;

  /// Getter per l'istanza Dio (per compatibilità con codice esistente)
  Dio get dio {
    if (_dioInstance == null) {
      throw UnauthorizedException();
    }
    return _dioInstance!;
  }

  /// Crea e restituisce un'istanza Dio autenticata
  /// UNICA istanza Dio per tutta l'app - gestisce automaticamente il token JWT
  Dio getAuthenticatedDio() {
    if (!isConnected) {
      log.e('Attempt to use Dio without JWT authentication');
      throw UnauthorizedException();
    }

    // Crea l'istanza Dio UNA SOLA VOLTA
    if (_dioInstance == null || !_dioInitialized) {
      log.d('Creating Dio instance for JWT');

      // IMPORTANTE: baseUrl deve essere l'URL esatto senza modifiche
      final cleanBaseUrl = _currentSiteUrl!.endsWith('/')
          ? _currentSiteUrl!.substring(0, _currentSiteUrl!.length - 1)
          : _currentSiteUrl!;

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

      // Interceptor 1: Inserisce il token JWT DINAMICAMENTE ad ogni richiesta
      // In questo modo usa sempre il token corrente senza ricreare Dio
      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Inserisci sempre il token più recente
            if (_currentSession != null && !_currentSession!.isExpired) {
              options.headers['Authorization'] =
                  'Bearer ${_currentSession!.token}';
              log.d('Token JWT added to request');
            } else {
              log.e('JWT token expired or missing');
            }
            return handler.next(options);
          },
          onResponse: (response, handler) {
            log.d(
              'Response ${response.statusCode} from ${response.requestOptions.uri}',
            );
            return handler.next(response);
          },
          onError: (error, handler) async {
            log.e(
              'Error ${error.response?.statusCode} on ${error.requestOptions.uri}',
            );
            log.d('Server response: ${error.response?.data}');

            // Se ricevo 401 (Unauthorized), provo a refreshare il token
            // UNA SOLA VOLTA: senza guardia il retry rientra in questo
            // stesso handler e genera un loop infinito di refresh.
            if (error.response?.statusCode == 401) {
              if (error.requestOptions.extra['jwt_retried'] == true) {
                log.e(
                  '401 dopo retry con token refresh-ato, stop loop. Re-login necessario.',
                );
                return handler.next(error);
              }
              log.w('Token expired (401), attempting refresh');

              final refreshed = await refreshToken();
              if (refreshed) {
                log.d('Token refreshed, retrying original request');

                // Aggiorna il token nell'header della richiesta originale
                final newToken = _currentSession?.token;
                if (newToken == null) {
                  log.e('Token refresh succeeded but session is null');
                  return handler.next(error);
                }
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';
                error.requestOptions.extra['jwt_retried'] = true;

                // Ricrea l'istanza Dio se è stata resettata dal refresh
                final dio = getAuthenticatedDio();

                // Riprova la richiesta originale con il nuovo token
                try {
                  final response = await dio.fetch(error.requestOptions);
                  return handler.resolve(response);
                } catch (e) {
                  log.e('Request failed after token refresh', e);
                  return handler.next(error);
                }
              } else {
                log.e('Token refresh failed, user must login again');
              }
            }

            return handler.next(error);
          },
        ),
      );

      // Interceptor 2: Log delle richieste per debug (solo in modalità debug)
      if (kDebugMode) {
        _dioInstance!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              log.d('${options.method} ${options.uri}');
              return handler.next(options);
            },
          ),
        );
      }

      _dioInitialized = true;
      log.d('Dio initialized with baseUrl: $cleanBaseUrl');
    }

    return _dioInstance!;
  }

  /// Tenta di caricare una sessione salvata dallo storage sicuro all'avvio dell'app.
  @override
  Future<bool> tryAutoConnect() async {
    log.d('Attempting auto-connection');
    final storedData = await SecureStorageService.loadSession();
    if (storedData != null) {
      final session = storedData.$1;
      final siteUrl = storedData.$2;
      log.d('Session found for: $siteUrl');
      if (!session.isExpired) {
        _currentSession = session;
        _currentSiteUrl = siteUrl;
        _currentUsername = await SecureStorageService.loadLoginUsername();
        // Reset Dio per forzare la ricreazione con i nuovi parametri
        _dioInstance = null;
        _dioInitialized = false;
        log.d('Auto-connection successful: $siteUrl');
        return true;
      } else {
        log.w('Session expired, cleaning up');
        await disconnect(); // Pulisce i dati se la sessione è scaduta.
      }
    } else {
      log.d('No saved session found');
    }
    return false;
  }

  /// Esegue il processo di login.
  @override
  Future<UserSession> connect({
    required String siteUrl,
    required String username,
    required String password,
    String? customEndpoint,
  }) async {
    log.d('Login attempt for: $username @ $siteUrl');

    // 1. Determina gli endpoint da provare, dando priorità a quelli personalizzati/precedenti.
    final endpointsToTry = await _getEndpointsToTry(customEndpoint);
    log.d('Endpoints to try: ${endpointsToTry.join(", ")}');
    String? lastKnownError;
    LocalizedText? lastKnownLocalized;

    // 2. Prova ogni endpoint in sequenza.
    for (final endpoint in endpointsToTry) {
      try {
        log.d('Trying endpoint: $endpoint');
        final endpointExists = await _jwtEndpointExists(siteUrl, endpoint);
        if (!endpointExists) {
          lastKnownError = 'JWT plugin not installed or endpoint not active.';
          lastKnownLocalized = (l10n) => l10n.loginJwtPluginMissing;
          log.w('Endpoint JWT non disponibile: $endpoint');
          continue;
        }
        final uri = buildUri(siteUrl, endpoint);

        final response = await _httpClient
            .post(
              uri,
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode({'username': username, 'password': password}),
            )
            .timeout(const Duration(seconds: 20));

        log.d('HTTP Response ${response.statusCode}');

        // Se la richiesta ha successo, analizza la risposta.
        if (response.statusCode == 200) {
          log.d('Login successful with endpoint: $endpoint');
          final session = _parseSuccessResponse(response.body);
          await SecureStorageService.saveSession(session, siteUrl);
          await SecureStorageService.saveLastUsedEndpoint(endpoint);
          await SecureStorageService.saveLoginUsername(username);
          _currentSession = session;
          _currentSiteUrl = siteUrl;
          _currentUsername = username.trim();
          // Reset Dio per forzare la ricreazione con i nuovi parametri
          _dioInstance = null;
          _dioInitialized = false;
          log.d('Session saved and JWT token obtained');
          return session;
        }
        // Se l'errore è credenziali/permessi, interrompi subito.
        else if (response.statusCode == 403) {
          final body = jsonDecode(response.body);
          lastKnownError = body['message'];
          lastKnownLocalized = null;
          if (lastKnownError == null) {
            lastKnownError = 'Invalid credentials or insufficient permissions.';
            lastKnownLocalized = (l10n) =>
                l10n.loginInvalidCredentialsOrPermissions;
          }
          log.e('Error 403: $lastKnownError');
          break;
        } else {
          log.w('Endpoint $endpoint failed with status ${response.statusCode}');
        }
      } on SocketException catch (e) {
        log.e('Network error for $endpoint', e);
        throw ConnectionException.network();
      } on TimeoutException catch (e) {
        log.e('Timeout for $endpoint', e);
        throw ConnectionTimeoutException();
      } catch (e) {
        log.w('Error on $endpoint: $e');
        // Ignora gli errori 404 (NotFound) e continua con il prossimo endpoint.
        if (e is! NotFoundException) {
          lastKnownError = e.toString();
          lastKnownLocalized = null;
        }
      }
    }
    // 3. Se nessun endpoint ha funzionato, lancia un errore.
    log.e('All endpoints failed. Last error: $lastKnownError');
    throw InvalidCredentialsException(
      lastKnownError ?? 'No working JWT endpoint found.',
      localized: lastKnownError == null
          ? (l10n) => l10n.loginNoJwtEndpoint
          : lastKnownLocalized,
    );
  }

  /// Refresh del token JWT usando l'endpoint /auth/refresh
  @override
  Future<bool> refreshToken() async {
    if (_currentSession == null || _currentSiteUrl == null) {
      log.w('No active session to refresh');
      return false;
    }

    try {
      log.d('Attempting JWT token refresh');

      final uri = buildUri(
        _currentSiteUrl!,
        '/simple-jwt-login/v1/auth/refresh',
      );

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer ${_currentSession!.token}',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        log.d('Token refreshed successfully');
        final session = _parseSuccessResponse(response.body);
        await SecureStorageService.saveSession(session, _currentSiteUrl!);
        _currentSession = session;
        // Reset Dio per forzare la ricreazione con il nuovo token
        _dioInstance = null;
        _dioInitialized = false;
        log.d('New token saved');
        return true;
      } else {
        log.e('Refresh failed: ${response.statusCode}');
        return false;
      }
    } on TimeoutException {
      log.e('Timeout during token refresh');
      return false;
    } catch (e) {
      log.e('Error during token refresh', e);
      return false;
    }
  }

  /// Esegue una richiesta HTTP autenticata per conto di altri servizi.
  Future<http.Response> authenticatedRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    if (!isConnected) throw UnauthorizedException();

    final headers = {
      'Authorization': 'Bearer ${_currentSession!.token}',
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    try {
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await _httpClient
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw Exception('Unsupported HTTP method');
      }
      // Delega la gestione degli errori di risposta a un gestore centralizzato.
      if (response.statusCode >= 400) ErrorHandler.throwFromResponse(response);
      return response;
    } on SocketException {
      throw ConnectionException.network();
    } on TimeoutException {
      throw ConnectionTimeoutException();
    }
  }

  /// Costruisce un Uri sicuro, centralizzando la logica di formattazione.
  Uri buildUri(
    String siteUrl,
    String endpoint, {
    Map<String, String>? queryParams,
  }) {
    final cleanUrl = siteUrl.endsWith('/')
        ? siteUrl.substring(0, siteUrl.length - 1)
        : siteUrl;
    final cleanEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final routeWithParams = Uri(
      path: cleanEndpoint,
      queryParameters: queryParams,
    ).toString();
    return Uri.parse('$cleanUrl/?rest_route=/$routeWithParams');
  }

  /// Imposta l'URL del sito (usato per autenticazione API)
  void setSiteUrl(String siteUrl) {
    _currentSiteUrl = siteUrl;
  }

  @visibleForTesting
  void setHttpClientForTesting(http.Client client) {
    _httpClient = client;
  }

  /// Esegue il logout e pulisce tutti i dati di sessione.
  @override
  Future<void> disconnect() async {
    log.d('Disconnecting');
    await SecureStorageService.clearAll();
    _currentSession = null;
    _currentSiteUrl = null;
    _currentUsername = null;
    _dioInstance = null;
    _dioInitialized = false;
    log.d('Disconnection completed');
  }

  // --- Metodi Helper Privati ---

  Future<List<String>> _getEndpointsToTry(String? customEndpoint) async {
    const commonEndpoints = ['simple-jwt-login/v1/auth', 'jwt-auth/v1/token'];
    final lastUsedEndpoint = await SecureStorageService.getLastUsedEndpoint();
    // La logica toSet().toList() rimuove eventuali duplicati.
    return [
      if (customEndpoint != null && customEndpoint.isNotEmpty) customEndpoint,
      if (lastUsedEndpoint != null) lastUsedEndpoint,
      ...commonEndpoints,
    ].toSet().toList();
  }

  Future<bool> _jwtEndpointExists(String siteUrl, String endpoint) async {
    final uri = buildUri(siteUrl, endpoint);
    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 10));
    return response.statusCode != 404;
  }

  UserSession _parseSuccessResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>)
        throw InvalidResponseFormatException();

      final tokenData = decoded['data'];
      final String? token = tokenData?['jwt'] ?? tokenData?['token'];
      if (token == null) throw InvalidResponseFormatException();

      final int expiresIn =
          tokenData?['expires_in'] ?? 86400; // Default a 24 ore
      return UserSession(
        token: token,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
    } catch (_) {
      throw InvalidResponseFormatException();
    }
  }
}
