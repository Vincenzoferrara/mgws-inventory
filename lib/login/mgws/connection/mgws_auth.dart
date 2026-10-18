import 'package:dio/dio.dart';
import '../../../log_viewer/app_logger.dart';
import '../../jwt_api/woo_connect.dart';

/// Motivo per cui MGWS risulta non utilizzabile.
///
/// L'avviso mostrato all'utente distingue i tre casi perche' richiedono
/// interventi diversi: un backend irraggiungibile e' un problema di rete o di
/// URL, un servizio spento e' un problema di configurazione del plugin, le
/// tabelle mancanti indicano un'installazione incompleta.
enum MgwsUnavailableReason {
  /// MGWS non e' mai stato verificato nella sessione corrente.
  unknown,

  /// Nessuna sessione WordPress attiva: le rotte MGWS non possono partire.
  noSession,

  /// Le rotte di stato non rispondono o rispondono con errore.
  unreachable,

  /// Le rotte rispondono ma il servizio e' disabilitato (`enabled: false`).
  serviceDisabled,

  /// Il plugin dichiara una versione piu' vecchia di [MgwsAuth.minPluginVersion].
  pluginOutdated,
}

/// Verifica di stato dei servizi MGWS.
///
/// Sta in `connection/` e non importa i client di `query/`: la disponibilita'
/// di MGWS non deve dipendere da un client specifico, altrimenti lo stato
/// erediterebbe i difetti di quel client. Le rotte di stato sono lette qui
/// direttamente, con il Dio autenticato del connettore attivo.
class MgwsAuth {
  MgwsAuth({WooConnect? woo}) : _woo = woo ?? WooConnect();

  final WooConnect _woo;
  final AppLogger _log = AppLogger();

  static const String _inventoryStatusPath =
      '/wp-json/mgws/v1/inventory/status';
  static const String _loyaltyStatusPath = '/wp-json/mgws/v1/loyalty/status';

  /// Versione minima del plugin MGWS che questa app sa usare. Va alzata
  /// quando l'app comincia a dipendere da una rotta o da un campo nuovo.
  static const String minPluginVersion = '2.4.0';

  /// Verifica MGWS e restituisce l'esito con il motivo dell'eventuale
  /// fallimento. Non solleva eccezioni: un errore di rete e' un esito
  /// negativo, non un'eccezione da gestire a monte.
  Future<MgwsAuthResult> verify() async {
    if (!_woo.isAuthenticated) {
      return const MgwsAuthResult(
        available: false,
        reason: MgwsUnavailableReason.noSession,
      );
    }

    final siteUrl = _woo.siteUrl;
    if (siteUrl == null || siteUrl.isEmpty) {
      return const MgwsAuthResult(
        available: false,
        reason: MgwsUnavailableReason.noSession,
      );
    }

    try {
      final dio = _woo.getAuthenticatedDio();
      final results = await Future.wait([
        _readServiceStatus(dio, siteUrl, _inventoryStatusPath),
        _readServiceStatus(dio, siteUrl, _loyaltyStatusPath),
      ]);

      // Un solo servizio spento rende MGWS inutilizzabile: inventario e
      // loyalty sono le due funzionalita' che i moduli MGWS espongono, e
      // un'installazione parziale produrrebbe errori a meta' operazione.
      final failed = results.where((result) => !result.usable).toList();

      // I plugin precedenti a `plugin_version` non lo inviano: in quel caso
      // la versione non e' nota e non blocca, per non rompere i siti che
      // funzionano gia'.
      final installata = results.first.pluginVersion;
      if (installata != null &&
          !isVersionAtLeast(installata, minPluginVersion)) {
        _log.w('Plugin MGWS $installata < $minPluginVersion richiesta');
        return MgwsAuthResult(
          available: false,
          reason: MgwsUnavailableReason.pluginOutdated,
          pluginVersion: installata,
        );
      }

      if (failed.isEmpty) {
        return const MgwsAuthResult(
          available: true,
          reason: MgwsUnavailableReason.unknown,
        );
      }

      final reachable = results.any((result) => result.reachable);
      return MgwsAuthResult(
        available: false,
        reason: reachable
            ? MgwsUnavailableReason.serviceDisabled
            : MgwsUnavailableReason.unreachable,
      );
    } catch (e) {
      _log.w('MGWS non raggiungibile: $e');
      return const MgwsAuthResult(
        available: false,
        reason: MgwsUnavailableReason.unreachable,
      );
    }
  }

  Future<_ServiceProbe> _readServiceStatus(
    Dio dio,
    String siteUrl,
    String path,
  ) async {
    try {
      final response = await dio.get<dynamic>('$siteUrl$path');
      if (response.statusCode != 200) {
        return const _ServiceProbe(reachable: false, usable: false);
      }
      final data = response.data;
      final version = data is Map ? data['plugin_version'] : null;
      return _ServiceProbe(
        reachable: true,
        usable: isServiceBodyUsable(data),
        pluginVersion: version is String && version.isNotEmpty ? version : null,
      );
    } catch (_) {
      return const _ServiceProbe(reachable: false, usable: false);
    }
  }

  /// Le rotte `status` rispondono 200 anche quando il servizio e' spento, per
  /// esempio con le tabelle MGWS non installate: in quel caso `enabled` e
  /// `ok` valgono `false`. Guardare solo lo status HTTP dichiarerebbe MGWS
  /// disponibile e ogni chiamata reale fallirebbe sul campo, quindi la
  /// disponibilita' si legge dal corpo della risposta.
  ///
  /// Vive qui e non nel trasporto perche' e' la lettura del contratto di
  /// stato MGWS: [MgwsConnection] e i client di `query/` devono condividere
  /// la stessa interpretazione del corpo.
  static bool isServiceUsable(Response<dynamic> response) {
    if (response.statusCode != 200) return false;
    return isServiceBodyUsable(response.data);
  }

  static bool isServiceBodyUsable(Object? data) {
    if (data is! Map) return true;
    final enabled = data['enabled'];
    if (enabled is bool) return enabled;
    final ok = data['ok'];
    if (ok is bool) return ok;
    return true;
  }

  /// Confronta due versioni `x.y.z`; le parti mancanti o non numeriche
  /// valgono 0 (`2.3` equivale a `2.3.0`, `2.4.0-beta` a `2.4.0`).
  static bool isVersionAtLeast(String version, String minimum) {
    List<int> parti(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((p) => p.isNotEmpty)
        .map(int.parse)
        .toList();
    final a = parti(version);
    final b = parti(minimum);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return true;
  }
}

class MgwsAuthResult {
  const MgwsAuthResult({
    required this.available,
    required this.reason,
    this.pluginVersion,
  });

  final bool available;
  final MgwsUnavailableReason reason;

  /// Versione dichiarata dal plugin, se la invia.
  final String? pluginVersion;
}

class _ServiceProbe {
  const _ServiceProbe({
    required this.reachable,
    required this.usable,
    this.pluginVersion,
  });

  /// La rotta ha risposto qualcosa, anche se il servizio e' spento.
  final bool reachable;

  /// Il servizio dichiara di poter operare.
  final bool usable;

  /// Versione del plugin letta dalla rotta di stato, se presente.
  final String? pluginVersion;
}
