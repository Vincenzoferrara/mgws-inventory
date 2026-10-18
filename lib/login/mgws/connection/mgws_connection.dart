import 'mgws_auth.dart';

/// Unico proprietario dello stato di connessione MGWS.
///
/// Tutti i moduli che hanno bisogno di MGWS passano da qui. Nessun modulo
/// chiama [verify] per decisione propria: il colpo di rete e' di
/// [ensureConnected], che usa lo stato in cache quando la verifica e' gia'
/// stata fatta nella sessione corrente.
///
/// Il percorso e' sempre lo stesso del login: quando la sessione WordPress
/// cambia, [markDisconnected] invalida lo stato e MGWS viene riverificato
/// solo se il login e' riuscito.
class MgwsConnection {
  MgwsConnection({MgwsAuth? auth}) : _auth = auth ?? MgwsAuth();

  final MgwsAuth _auth;

  static MgwsConnection? _instance;

  /// Istanza condivisa da tutta l'app.
  static MgwsConnection get instance => _instance ??= MgwsConnection();

  bool _isConnected = false;
  bool _isChecked = false;
  MgwsUnavailableReason _lastFailure = MgwsUnavailableReason.unknown;
  String? _pluginVersion;
  Future<bool>? _inFlight;

  /// Generazione dello stato, incrementata a ogni invalidazione.
  ///
  /// Una verifica in volo la cattura all'avvio e non scrive il risultato se nel
  /// frattempo lo stato e' stato invalidato: altrimenti una verifica partita
  /// prima di un logout completerebbe e riattiverebbe MGWS su una sessione che
  /// non esiste piu'.
  int _generation = 0;

  /// MGWS e' utilizzabile secondo l'ultima verifica.
  bool get isConnected => _isConnected;

  /// La verifica e' stata eseguita almeno una volta nella sessione corrente.
  ///
  /// Distingue "MGWS non risponde" da "MGWS non e' ancora stato verificato":
  /// il primo e' un problema, il secondo e' semplicemente un modulo che non
  /// ha ancora chiesto nulla.
  bool get isChecked => _isChecked;

  /// Motivo dell'ultimo fallimento, per l'avviso all'utente.
  MgwsUnavailableReason get lastFailure => _lastFailure;

  /// Versione del plugin MGWS dichiarata dal sito all'ultima verifica.
  String? get pluginVersion => _pluginVersion;

  /// Verifica MGWS colpendo la rete e aggiorna lo stato.
  ///
  /// Va chiamata solo da un'azione esplicita dell'utente o dalla fine della
  /// catena di login. Chiamate concorrenti condividono la stessa richiesta.
  Future<bool> verify() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final generation = _generation;
    final future = _runVerify(generation);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<bool> _runVerify(int generation) async {
    final result = await _auth.verify();

    // Lo stato e' stato invalidato mentre la richiesta era in volo: il
    // risultato riguarda una sessione che non esiste piu' e va scartato.
    if (generation != _generation) return false;

    _isConnected = result.available;
    _isChecked = true;
    _pluginVersion = result.pluginVersion;
    _lastFailure = result.available
        ? MgwsUnavailableReason.unknown
        : result.reason;
    return _isConnected;
  }

  /// Garantisce che lo stato sia noto e restituisce se MGWS e' utilizzabile.
  ///
  /// Usa il risultato della verifica se e' gia' stata fatta nella sessione
  /// corrente, altrimenti verifica adesso. E' il metodo da usare nei moduli.
  Future<bool> ensureConnected() async {
    if (_isChecked) return _isConnected;
    return verify();
  }

  /// Invalida lo stato di connessione.
  ///
  /// Va chiamata a ogni cambio di sessione (login, logout, cambio sito) e
  /// quando una chiamata MGWS fallisce. La verifica successiva riparte da
  /// zero, cosi' uno stato stale non blocca i moduli.
  void markDisconnected({MgwsUnavailableReason reason = MgwsUnavailableReason.unknown}) {
    _generation++;
    _isConnected = false;
    _isChecked = false;
    _lastFailure = reason;
  }
}
