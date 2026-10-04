import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import 'package:mgws_inventory/log_viewer/app_logger.dart';
import 'jwt_connect.dart';
import 'secure_storage_service.dart';
import '../wp_admin_api/wordpress_connect.dart';
import 'error_list.dart';
import '../mgws/connection/mgws_auth.dart';
import '../mgws/connection/mgws_connection.dart';
import '../../utenti/class_user_global.dart';

/// Classe singleton per gestire la connessione WooCommerce
///
/// COME USARE:
/// ```dart
/// // Ottieni l'istanza WooCommerce autenticata (usa SEMPRE questa!)
/// final woo = WooConnect().woo;
///
/// // Usa l'istanza per le query
/// final products = await woo.getProducts();
/// final orders = await woo.getOrders();
///
/// // Dopo logout, resetta l'istanza
/// WooConnect().reset();
/// ```
///
/// IMPORTANTE: NON creare nuove istanze WooCommerce manualmente!
/// Usa sempre WooConnect().woo per ottenere l'istanza autenticata.
class WooConnect {
  // Singleton pattern
  static final WooConnect _instance = WooConnect._internal();
  factory WooConnect() => _instance;
  WooConnect._internal();

  final JwtConnect _auth = JwtConnect();
  final WordPressConnect _wpAuth = WordPressConnect();
  WooCommerce? _woo;
  Dio? _apiDioInstance;
  bool _isJWT = true;
  bool _isWordPress = false;
  String? _consumerKey;
  String? _consumerSecret;

  // Limite tentativi auto-connect per sessione app
  static int _autoConnectAttempts = 0;
  static const int _maxAutoConnectAttempts = 3;

  /// Ottiene l'istanza WooCommerce autenticata (JWT, API o WordPress Basic Auth)
  ///
  /// Questa è l'UNICA istanza WooCommerce per tutta l'app.
  /// L'autenticazione avviene tramite JWT Bearer token, WooCommerce API,
  /// o WordPress Basic Auth (Application Password).
  ///
  /// Throws [UnauthorizedException] se non autenticato
  WooCommerce get woo {
    log.d('🛒 WooConnect: Richiesta istanza WooCommerce');

    // Se già esiste un'istanza, riutilizzala
    if (_woo != null) {
      log.v('♻️ Riuso istanza WooCommerce esistente');
      return _woo!;
    }

    if (_isWordPress) {
      // Autenticazione WordPress Basic Auth (Application Password)
      if (!_wpAuth.isConnected) {
        log.e(
          '❌ Tentativo di accesso WooCommerce senza autenticazione WordPress',
        );
        throw UnauthorizedException();
      }

      log.d(
        '🔧 Creazione nuova istanza WooCommerce con WordPress Basic Auth per: ${_wpAuth.currentSiteUrl}',
      );

      // Crea WooCommerce — le credenziali Basic Auth vengono aggiunte via interceptor
      // NOTA: v2 richiede consumerKey/consumerSecret anche con interceptor
      _woo = WooCommerce(
        baseUrl: _wpAuth.currentSiteUrl!,
        consumerKey: '', // Compilato dall'interceptor Basic Auth
        consumerSecret: '', // Compilato dall'interceptor Basic Auth
        useFaker: false,
        // isDebug: false → niente PrettyDioLogger: i body JSON completi (180+
        // righe per pagina) allagavano console e log. Il logging applicativo
        // ([perf-trace], errori) resta gestito da AppLogger.
        isDebug: false,
        interceptors: [
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final credentials =
                  '${_wpAuth.session!.username}:${_wpAuth.session!.appPassword}';
              final encoded = base64Encode(utf8.encode(credentials));
              options.headers['Authorization'] = 'Basic $encoded';
              log.v(
                '🔑 WordPress Basic Auth aggiunto alla richiesta WooCommerce',
              );
              return handler.next(options);
            },
          ),
        ],
      );

      log.i('✅ WooCommerce inizializzato con WordPress Basic Auth');
    } else if (_isJWT) {
      // Autenticazione JWT
      if (!_auth.isConnected) {
        log.e('❌ Tentativo di accesso WooCommerce senza autenticazione JWT');
        throw UnauthorizedException();
      }

      log.d(
        '🔧 Creazione nuova istanza WooCommerce con JWT per: ${_auth.currentSiteUrl}',
      );

      // Crea WooCommerce con JWT Bearer token tramite interceptor
      _woo = WooCommerce(
        baseUrl: _auth.currentSiteUrl!,
        consumerKey: '', // Compilato dall'interceptor JWT
        consumerSecret: '', // Compilato dall'interceptor JWT
        useFaker: false,
        // isDebug: false → niente PrettyDioLogger (body JSON completi nei log).
        isDebug: false,
        interceptors: [
          InterceptorsWrapper(
            onRequest: (options, handler) {
              // Sostituisci SEMPRE l'header Authorization con JWT Bearer token
              // (la libreria WooCommerce aggiunge Basic Auth vuoto di default)
              log.d('🔍 [WooInterceptor] onRequest triggered');
              log.d(
                '🔍 [WooInterceptor] _auth.isConnected: ${_auth.isConnected}',
              );
              log.d(
                '🔍 [WooInterceptor] _auth.session: ${_auth.session != null ? "present" : "NULL"}',
              );
              final hdr = options.headers["Authorization"]?.toString();
              log.d(
                '🔍 [WooInterceptor] headers prima: ${hdr != null ? "${hdr.length} chars" : "nessuno"}',
              );

              final token = _auth.session?.token;
              if (token != null) {
                // Token lungo solo i primi 20 char per log
                log.d(
                  '🔑 [WooInterceptor] Impostando Bearer token (${token.length} chars)',
                );
                options.headers['Authorization'] = 'Bearer $token';
              } else {
                // Rimuovi Basic Auth vuoto se il token non è disponibile
                log.w(
                  '⚠️ [WooInterceptor] JWT token NULL, rimuovo Authorization',
                );
                options.headers.remove('Authorization');
              }

              final hdrAfter = options.headers["Authorization"]?.toString();
              log.d(
                '🔍 [WooInterceptor] headers dopo: ${hdrAfter != null ? "${hdrAfter.length} chars" : "RIMOSSO"}',
              );
              return handler.next(options);
            },
            onError: (error, handler) async {
              // Gestione 401 (token scaduto/invalido) → refresh JWT + retry
              // Solo UNA VOLTA per richiesta: la guardia evita il loop infinito
              // (senza guardia, il retry rientrerebbe in questo stesso handler).
              if (error.response?.statusCode == 401) {
                if (error.requestOptions.extra['jwt_retried'] == true) {
                  log.e(
                    '❌ [WooInterceptor] 401 dopo retry con token refresh-ato, '
                    'stop loop. Re-login necessario.',
                  );
                  return handler.next(error);
                }

                log.w(
                  '⚠️ [WooInterceptor] 401 ricevuto, tenta refresh token JWT',
                );

                final refreshed = await _auth.refreshToken();
                if (refreshed) {
                  log.d(
                    '✅ [WooInterceptor] Token refresh-ato, retry richiesta',
                  );

                  final newToken = _auth.session?.token;
                  if (newToken == null) {
                    log.e('❌ [WooInterceptor] Refresh riuscito ma token NULL');
                    return handler.next(error);
                  }

                  error.requestOptions.headers['Authorization'] =
                      'Bearer $newToken';
                  error.requestOptions.extra['jwt_retried'] = true;

                  try {
                    // Ricrea l'istanza Dio se resettata dal refresh
                    final dio = _auth.getAuthenticatedDio();
                    final response = await dio.fetch(error.requestOptions);
                    return handler.resolve(response);
                  } catch (e) {
                    log.e(
                      '❌ [WooInterceptor] Richiesta fallita dopo refresh: $e',
                    );
                    return handler.next(error);
                  }
                } else {
                  log.e(
                    '❌ [WooInterceptor] Refresh token fallito, re-login necessario',
                  );
                }
              }

              return handler.next(error);
            },
          ),
        ],
      );

      log.i('✅ WooCommerce inizializzato con JWT Bearer Token');
    } else {
      // Autenticazione WooCommerce API
      if (_consumerKey == null ||
          _consumerSecret == null ||
          _auth.currentSiteUrl == null) {
        log.e('❌ Tentativo di accesso WooCommerce senza credenziali API');
        throw UnauthorizedException();
      }

      log.d(
        '🔧 Creazione nuova istanza WooCommerce con API per: ${_auth.currentSiteUrl}',
      );

      // Crea WooCommerce con Consumer Key e Secret
      _woo = WooCommerce(
        baseUrl: _auth.currentSiteUrl!,
        consumerKey: _consumerKey!,
        consumerSecret: _consumerSecret!,
        useFaker: false,
        // isDebug: false → niente PrettyDioLogger (body JSON completi nei log).
        isDebug: false,
        interceptors: [],
      );

      log.i('✅ WooCommerce inizializzato con Consumer Key/Secret');
    }

    return _woo!;
  }

  /// Dio autenticato per le rotte che non sono WooCommerce, cioe' MGWS.
  ///
  /// `WooConnect` e' l'unico owner dei connettori: restituisce il Dio del
  /// connettore realmente in uso, cosi' le rotte MGWS viaggiano con le stesse
  /// credenziali della sessione attiva. Usare un connettore dedicato qui
  /// produrrebbe richieste non allineate alla sessione e MGWS risulterebbe
  /// irraggiungibile.
  ///
  /// In modalita' Consumer Key/Secret il Basic Auth e' quello WooCommerce:
  /// le chiavi `ck_`/`cs_` autenticano solo le rotte `wc/`, quindi MGWS
  /// risponde 401 e l'app degrada MGWS come non disponibile. Il limite e' del
  /// backend: MGWS richiede un utente WordPress.
  Dio getAuthenticatedDio() {
    if (_isWordPress) {
      return _wpAuth.getAuthenticatedDio();
    }
    if (_isJWT) {
      return _auth.getAuthenticatedDio();
    }
    return _apiDio();
  }

  Dio _apiDio() {
    final key = _consumerKey;
    final secret = _consumerSecret;
    final site = _auth.currentSiteUrl;
    if (key == null || secret == null || site == null || site.isEmpty) {
      throw UnauthorizedException();
    }
    if (_apiDioInstance != null) return _apiDioInstance!;

    final cleanBaseUrl = site.endsWith('/')
        ? site.substring(0, site.length - 1)
        : site;
    final encoded = base64Encode(utf8.encode('$key:$secret'));
    _apiDioInstance = Dio(
      BaseOptions(
        baseUrl: cleanBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Basic $encoded',
        },
      ),
    );
    return _apiDioInstance!;
  }

  /// Verifica se la connessione è pronta
  bool get isReady => _isWordPress
      ? _wpAuth.isConnected
      : _isJWT
      ? _auth.isConnected
      : (_consumerKey != null && _consumerSecret != null);

  /// Ottiene l'URL del sito corrente
  String? get siteUrl =>
      _isWordPress ? _wpAuth.currentSiteUrl : _auth.currentSiteUrl;

  /// Verifica se l'utente è autenticato
  bool get isAuthenticated => _isWordPress
      ? _wpAuth.isConnected
      : _isJWT
      ? _auth.isConnected
      : (_consumerKey != null && _consumerSecret != null);

  /// Username dell'utente autenticato (WordPress o JWT), se noto.
  ///
  /// Solo identificativo non segreto: la cassa lo usa come operatore dello
  /// scontrino perche l'utente loggato e l'utente che usa la cassa.
  /// In modalita Consumer Key/Secret non esiste uno username: ritorna null.
  Future<String?> loggedUsername() async {
    if (_isWordPress) {
      return _wpAuth.session?.username;
    }
    final inMemory = _auth.currentUsername;
    if (inMemory != null && inMemory.trim().isNotEmpty) return inMemory;
    final stored = await SecureStorageService.loadLoginUsername();
    if (stored != null && stored.trim().isNotEmpty) return stored;
    // Backfill per sessioni create prima del salvataggio username:
    // legge l'identita da /wp/v2/users/me con la sessione attiva.
    if (_auth.isConnected) {
      try {
        final site = _auth.currentSiteUrl;
        if (site != null) {
          final uri = _auth.buildUri(site, '/wp-json/wp/v2/users/me');
          final response = await _auth.authenticatedRequest('GET', uri);
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final username = (data['slug'] ?? data['name'] ?? '')
                .toString()
                .trim();
            if (username.isNotEmpty) {
              await SecureStorageService.saveLoginUsername(username);
              return username;
            }
          }
        }
      } catch (_) {
        // Identita non risolvibile: la cassa resta senza operatore
        // senza bloccare la vendita.
      }
    }
    return null;
  }

  /// Profilo dell'utente corrente dallo stesso sito WP (avatar incluso).
  ///
  /// Legge `GET /wp-json/wp/v2/users/me` con il connettore attivo (JWT o
  /// WordPress Basic Auth) e restituisce `name/slug/avatar_urls`.
  /// Ritorna null se non autenticato o se il profilo non e leggibile.
  Future<UserGlobal?> currentUserProfile() async {
    if (!isAuthenticated) return null;
    try {
      if (_isWordPress) {
        final dio = _wpAuth.getAuthenticatedDio();
        final response = await dio.get('/wp-json/wp/v2/users/me');
        if (response.statusCode == 200 && response.data is Map) {
          return UserGlobal.fromWordPressData(
            Map<String, dynamic>.from(response.data as Map),
          );
        }
        return null;
      }
      if (_isJWT) {
        final site = _auth.currentSiteUrl;
        if (site == null) return null;
        final uri = _auth.buildUri(site, '/wp-json/wp/v2/users/me');
        final response = await _auth.authenticatedRequest('GET', uri);
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return UserGlobal.fromWordPressData(data);
        }
        if (data is Map) {
          return UserGlobal.fromWordPressData(Map<String, dynamic>.from(data));
        }
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// MGWS e' utilizzabile secondo l'ultima verifica centralizzata.
  bool get isMgwsAvailable => MgwsConnection.instance.isConnected;

  /// Verifica MGWS colpendo la rete e aggiorna lo stato centralizzato.
  Future<bool> refreshMgwsAvailability() => MgwsConnection.instance.verify();

  /// Invalida lo stato MGWS. Va chiamata a ogni cambio di sessione.
  void markMgwsUnavailable() => MgwsConnection.instance.markDisconnected();

  /// Verifica MGWS solo se la sessione WordPress e' viva.
  ///
  /// E' il punto in cui la catena di login chiude: se il login e' riuscito
  /// MGWS viene verificato, se il login e' fallito MGWS non viene toccato e
  /// resta semplicemente non verificato.
  Future<bool> _verifyMgwsAfterLogin() async {
    if (!isAuthenticated) {
      MgwsConnection.instance.markDisconnected(
        reason: MgwsUnavailableReason.noSession,
      );
      return false;
    }
    final available = await MgwsConnection.instance.verify();
    if (!available) {
      log.w('MGWS non disponibile: la connessione WooCommerce resta attiva');
    }
    return available;
  }

  /// Connessione con JWT
  Future<void> connectWithJwt({
    required String siteUrl,
    required String username,
    required String password,
    String? customEndpoint,
  }) async {
    log.d('🔑 WooConnect: Connessione con JWT');
    MgwsConnection.instance.markDisconnected();
    _isJWT = true;
    _isWordPress = false;
    _consumerKey = null;
    _consumerSecret = null;
    _woo = null;
    _apiDioInstance = null;

    await _auth.connect(
      siteUrl: siteUrl,
      username: username,
      password: password,
      customEndpoint: customEndpoint,
    );
    _autoConnectAttempts = 0; // Login esplicito riuscito: reset limite

    await _verifyMgwsAfterLogin();
    log.i('✅ Connessione JWT completata');
  }

  /// Connessione con WordPress Basic Auth (Application Password)
  Future<void> connectWithWordPress({
    required String siteUrl,
    required String username,
    required String password,
  }) async {
    log.d('🔑 WooConnect: Connessione con WordPress Basic Auth');
    MgwsConnection.instance.markDisconnected();
    _isJWT = false;
    _isWordPress = true;
    _consumerKey = null;
    _consumerSecret = null;
    _woo = null;
    _apiDioInstance = null;

    await _wpAuth.connect(
      siteUrl: siteUrl,
      username: username,
      password: password,
    );
    _autoConnectAttempts = 0; // Login esplicito riuscito: reset limite

    // La sessione WordPress e' un utente WordPress a tutti gli effetti: MGWS
    // va verificato anche qui, altrimenti i moduli MGWS resterebbero chiusi
    // per sempre dopo un login wp-admin riuscito.
    await _verifyMgwsAfterLogin();

    log.i('✅ Connessione WordPress Basic Auth completata');
  }

  /// Connessione con WooCommerce API
  Future<void> connectWithApi({
    required String siteUrl,
    required String consumerKey,
    required String consumerSecret,
  }) async {
    log.d('🔑 WooConnect: Connessione con API');
    MgwsConnection.instance.markDisconnected();
    _isJWT = false;
    _isWordPress = false;
    _consumerKey = consumerKey;
    _consumerSecret = consumerSecret;
    _woo = null;
    _apiDioInstance = null;

    // Salva l'URL del sito in _auth per compatibilità
    _auth.setSiteUrl(siteUrl);
    _autoConnectAttempts = 0; // Login esplicito riuscito: reset limite

    await _verifyMgwsAfterLogin();

    log.i('✅ Connessione API configurata');
  }

  /// Tenta la connessione automatica
  Future<bool> tryAutoConnect() async {
    // Protezione anti-loop: massimo N tentativi per sessione app
    _autoConnectAttempts++;
    if (_autoConnectAttempts > _maxAutoConnectAttempts) {
      log.w(
        '⚠️ WooConnect: auto-connect limit raggiunto '
        '($_autoConnectAttempts/$_maxAutoConnectAttempts). '
        'Login manuale richiesto.',
      );
      MgwsConnection.instance.markDisconnected();
      return false;
    }

    log.d(
      '🔄 WooConnect: auto-connect tentativo '
      '$_autoConnectAttempts/$_maxAutoConnectAttempts',
    );

    if (!isAuthenticated) {
      // Nessuna connessione attiva in memoria (es. primo avvio dopo un
      // login WordPress): ripristina il tipo dall'ultimo login salvato.
      // Senza questo, un utente autenticato con WordPress Admin verrebbe
      // rivalidato come JWT all'avvio → sessione "persa".
      final prefs = await SharedPreferences.getInstance();
      final savedAuthType = prefs.getString('login_auth_type');
      if (savedAuthType == 'wordpress') {
        _isWordPress = true;
        _isJWT = false;
        log.d('🔄 WooConnect: tipo auth ripristinato da preferenze: WordPress');
      }
    }

    if (_isWordPress) {
      MgwsConnection.instance.markDisconnected();
      try {
        final success = await _wpAuth.tryAutoConnect();
        if (success) {
          _woo = null;
          _apiDioInstance = null;
          _autoConnectAttempts = 0; // Auto-connect riuscito: reset limite
          // Stessa verifica dei rami JWT e API: senza questa MGWS resterebbe
          // non disponibile per tutta la sessione dopo il riavvio dell'app.
          await _verifyMgwsAfterLogin();
          log.i('✅ Auto-connect WordPress riuscito');
        }
        return success;
      } catch (_) {
        MgwsConnection.instance.markDisconnected();
        rethrow;
      }
    }

    // Per ora supporta solo JWT auto-connect
    if (_isJWT) {
      MgwsConnection.instance.markDisconnected();
      try {
        final success = await _auth.tryAutoConnect();
        if (success) {
          // Reset dell'istanza WooCommerce per forzare la ricreazione
          // con le credenziali appena caricate
          _woo = null;
          _autoConnectAttempts = 0; // Auto-connect riuscito: reset limite
          await _verifyMgwsAfterLogin();
          log.i(
            '✅ Auto-connect riuscito, WooCommerce pronto per essere inizializzato',
          );
        }
        return success;
      } catch (_) {
        MgwsConnection.instance.markDisconnected();
        rethrow;
      }
    }
    MgwsConnection.instance.markDisconnected();
    return false;
  }

  /// Disconnessione
  Future<void> disconnect() async {
    log.d('🔄 WooConnect: Disconnessione');
    MgwsConnection.instance.markDisconnected();
    _woo = null;
    _apiDioInstance = null;
    _isJWT = true;
    _isWordPress = false;
    _consumerKey = null;
    _consumerSecret = null;
    // NOTA: il contatore _autoConnectAttempts NON si resetta qui.
    // Resettarlo nel disconnect automatico (es. test fallito) vanifica
    // il limite anti-loop. Reset solo a login esplicito riuscito.
    await _auth.disconnect();
    await _wpAuth.disconnect();
  }

  /// Reset della connessione (chiamalo dopo logout)
  void reset() {
    log.d('🔄 WooConnect: Reset istanza WooCommerce');
    _woo = null;
  }

  /// Test di connessione - verifica che WooCommerce risponda
  Future<bool> testConnection() async {
    try {
      log.d('🧪 WooConnect: Test connessione WooCommerce');

      // Verifica prima che siamo autenticati
      if (!isAuthenticated) {
        log.w('❌ Test connessione saltato: non autenticato');
        MgwsConnection.instance.markDisconnected(
          reason: MgwsUnavailableReason.noSession,
        );
        return false;
      }

      // Prova a fare una richiesta semplice (ottenere 1 prodotto)
      await woo.getProducts(perPage: 1, page: 1);

      // Il test di connessione rivalida MGWS: e' una verifica esplicita della
      // sessione, non un'azione di modulo, quindi colpisce la rete.
      await _verifyMgwsAfterLogin();

      log.i('✅ Test connessione WooCommerce riuscito');
      return true;
    } catch (e) {
      log.e('❌ Test connessione WooCommerce fallito', e);

      // Se la connessione fallisce, potrebbe essere che:
      // 1. Il server non è raggiungibile
      // 2. Il token è scaduto/non valido
      // 3. Le credenziali non sono più valide
      // In tutti questi casi, meglio disconnettere l'utente
      log.w('Disconnessione automatica dopo test fallito');
      await disconnect();

      return false;
    }
  }
}
