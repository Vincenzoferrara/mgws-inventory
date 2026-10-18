import 'package:dio/dio.dart';

import 'query_mgws_base.dart';

/// Una sede del negozio (post `mg_site` su WordPress).
class MgwsSite {
  const MgwsSite({required this.id, required this.name});

  final int id;
  final String name;

  static MgwsSite? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = int.tryParse('${value['id']}') ?? 0;
    if (id <= 0) return null;
    final name = '${value['name'] ?? ''}'.trim();
    return MgwsSite(id: id, name: name.isEmpty ? 'Sede $id' : name);
  }
}

/// Sede in uso dall'utente collegato, come la calcola MGWS.
///
/// La regola sta sul server: la sede assegnata all'utente, oppure l'unica
/// sede del negozio, altrimenti nessuna. Senza sede l'inventario non si usa.
class MgwsSiteStatus {
  const MgwsSiteStatus({
    required this.siteId,
    required this.siteName,
    required this.sitesCount,
    required this.canChange,
    required this.canCreate,
    required this.sites,
  });

  final int siteId;
  final String siteName;
  final int sitesCount;

  /// Admin e chi gestisce i dipendenti: possono cambiare la sede in uso.
  final bool canChange;

  /// Possono creare una sede (stessi permessi di [canChange]).
  final bool canCreate;

  /// Tutte le sedi per chi puo' cambiarla, altrimenti solo quella in uso.
  final List<MgwsSite> sites;

  bool get hasSite => siteId > 0;

  bool get noSitesExist => sitesCount == 0;

  factory MgwsSiteStatus.fromMap(Map<String, dynamic> data) {
    return MgwsSiteStatus(
      siteId: int.tryParse('${data['site_id']}') ?? 0,
      siteName: '${data['site_name'] ?? ''}',
      sitesCount: int.tryParse('${data['sites_count']}') ?? 0,
      canChange: data['can_change'] == true,
      canCreate: data['can_create'] == true,
      sites: [
        for (final item in (data['sites'] as List? ?? const []))
          ?MgwsSite.fromMap(item),
      ],
    );
  }
}

/// Errore leggibile dall'operatore, con il messaggio del server quando c'e'.
class MgwsSiteException implements Exception {
  const MgwsSiteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lettura e scelta della sede in uso, creazione di una sede.
class QueryMgwsSite {
  QueryMgwsSite({QueryMgwsBase? base}) : _base = base ?? QueryMgwsBase();

  final QueryMgwsBase _base;

  static const String _meSite = '/wp-json/mgws/v1/me/site';

  Future<MgwsSiteStatus> getMySite() => _status(() => _base.get(_meSite));

  Future<MgwsSiteStatus> setMySite(int siteId) =>
      _status(() => _base.put(_meSite, data: {'site_id': siteId}));

  Future<MgwsSite> createSite(String name) async {
    try {
      final response = await _base.post(
        '/wp-json/mgws/v1/sites',
        data: {'name': name.trim()},
      );
      final site = MgwsSite.fromMap(response.data);
      if (site == null) {
        throw const MgwsSiteException('Risposta del server non valida.');
      }
      return site;
    } on DioException catch (e) {
      throw MgwsSiteException(_message(e));
    }
  }

  Future<MgwsSiteStatus> _status(Future<dynamic> Function() call) async {
    try {
      final Response<dynamic> response = await call();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const MgwsSiteException('Risposta del server non valida.');
      }
      return MgwsSiteStatus.fromMap(data);
    } on DioException catch (e) {
      throw MgwsSiteException(_message(e));
    }
  }

  static String _message(DioException e) {
    if (e.response?.statusCode == 404 &&
        '${e.requestOptions.path}'.endsWith('/me/site')) {
      return 'Il plugin MGWS sul sito e\' troppo vecchio: aggiornalo alla '
          'versione 2.4.0 o successiva per usare le sedi.';
    }
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return 'Server MGWS non raggiungibile.';
  }
}
