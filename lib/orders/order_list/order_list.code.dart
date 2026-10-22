import '../../l10n/localized_text.dart';
import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../log_viewer/app_logger.dart';
import '../class_orders.dart';
import '../../l10n/extensions.dart';

/// Controller per la gestione degli ordini
class OrdiniGestioneController {
  // Usa PlatformManager invece di istanza diretta
  dynamic get _ordiniQuery => PlatformManager.ordini;

  List<OrdiniGlobal> _ordini = [];
  OrdiniGlobal? _ordineSelezionato;
  bool _isLoading = false;
  LocalizedText? _errorMessage;

  // Filtri
  OrdineStatus? _filtroStatus;
  String _searchQuery = '';

  // Getters
  List<OrdiniGlobal> get ordini => _ordiniFiltrati;
  OrdiniGlobal? get ordineSelezionato => _ordineSelezionato;
  bool get isLoading => _isLoading;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasOrdineSelezionato => _ordineSelezionato != null;
  OrdineStatus? get filtroStatus => _filtroStatus;
  String get searchQuery => _searchQuery;

  /// Carica gli ordini dal server
  Future<void> caricaOrdini() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      log.i('Caricamento ordini...');

      final ordini = await _ordiniQuery.getOrders(
        perPage: 100,
        status: _filtroStatus,
      );

      _ordini = ordini;
      log.i('Caricati ${_ordini.length} ordini');
    } catch (e) {
      log.e('Errore nel caricamento degli ordini: $e');
      _errorMessage = (l10n) => l10n.ordersLoadError('$e');
      _ordini = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Filtra gli ordini in base alla ricerca
  List<OrdiniGlobal> get _ordiniFiltrati {
    if (_searchQuery.isEmpty) return _ordini;

    return _ordini.where((ordine) {
      final query = _searchQuery.toLowerCase();

      // Cerca per ID ordine
      final idMatch = ordine.id.toString().contains(query);
      final numberMatch = ordine.number?.toLowerCase().contains(query) ?? false;

      // Cerca per nome cliente
      final firstNameMatch =
          ordine.billing?.firstName?.toLowerCase().contains(query) ?? false;
      final lastNameMatch =
          ordine.billing?.lastName?.toLowerCase().contains(query) ?? false;
      final emailMatch =
          ordine.billing?.email?.toLowerCase().contains(query) ?? false;

      return idMatch ||
          numberMatch ||
          firstNameMatch ||
          lastNameMatch ||
          emailMatch;
    }).toList();
  }

  /// Seleziona un ordine
  void selezionaOrdine(OrdiniGlobal ordine) {
    _ordineSelezionato = ordine;
    log.d('Ordine selezionato: #${ordine.number}');
  }

  /// Deseleziona l'ordine corrente
  void deselezionaOrdine() {
    _ordineSelezionato = null;
  }

  /// Verifica se un ordine è selezionato
  bool isOrdineSelezionato(OrdiniGlobal ordine) {
    return _ordineSelezionato?.id == ordine.id;
  }

  /// Imposta il filtro per stato
  void setFiltroStatus(OrdineStatus? status) {
    _filtroStatus = status;
    log.d('Filtro stato impostato: ${status?.name ?? "tutti"}');
  }

  /// Imposta la query di ricerca
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  /// Cancella tutti i filtri
  void cancellaFiltri() {
    _filtroStatus = null;
    _searchQuery = '';
    log.d('Filtri cancellati');
  }

  /// Aggiorna lo stato di un ordine
  Future<bool> aggiornaStatoOrdine(
    int ordineId,
    OrdineStatus nuovoStato,
  ) async {
    try {
      log.i('Aggiornamento stato ordine #$ordineId a ${nuovoStato.name}');

      final ordine = _ordini.firstWhere((o) => o.id == ordineId);
      final ordineAggiornato = ordine.copyWith(status: nuovoStato);

      await _ordiniQuery.updateOrder(ordineAggiornato);

      // Ricarica gli ordini per aggiornare la lista
      await caricaOrdini();

      log.i('Stato ordine #$ordineId aggiornato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'aggiornamento dello stato ordine: $e');
      return false;
    }
  }

  /// Ottiene il numero totale di ordini per stato
  Map<String, int> getStatisticheStati() {
    final stats = <String, int>{};

    for (final ordine in _ordini) {
      final stato = ordine.status?.name ?? 'unknown';
      stats[stato] = (stats[stato] ?? 0) + 1;
    }

    return stats;
  }

  /// Calcola il totale delle vendite
  double getTotaleVendite() {
    return _ordini.fold(0.0, (sum, ordine) {
      final total = ordine.total ?? 0.0;
      return sum + total;
    });
  }

  /// Ottiene i dettagli completi di un ordine
  Future<OrdiniGlobal?> getDettagliOrdine(int ordineId) async {
    try {
      log.i('Caricamento dettagli ordine #$ordineId');
      final ordine = await _ordiniQuery.getOrderById(ordineId);
      log.i('Dettagli ordine #$ordineId caricati');
      return ordine;
    } catch (e) {
      log.e('Errore nel caricamento dettagli ordine: $e');
      return null;
    }
  }

  /// Elimina un ordine
  Future<bool> eliminaOrdine(int ordineId, {bool force = false}) async {
    try {
      log.i('Eliminazione ordine #$ordineId (force: $force)');

      final success = await _ordiniQuery.deleteOrder(ordineId, force: force);

      if (success) {
        // Ricarica gli ordini per aggiornare la lista
        await caricaOrdini();
        log.i('Ordine #$ordineId eliminato con successo');
      }

      return success;
    } catch (e) {
      log.e('Errore nell\'eliminazione dell\'ordine: $e');
      return false;
    }
  }

  /// Aggiunge una nota a un ordine
  Future<bool> aggiungiNota(
    int ordineId,
    String nota, {
    bool notaCliente = false,
  }) async {
    try {
      log.i('Aggiunta nota all\'ordine #$ordineId');

      await _ordiniQuery.addOrderNote(
        ordineId,
        note: nota,
        customerNote: notaCliente,
      );

      log.i('Nota aggiunta all\'ordine #$ordineId');
      return true;
    } catch (e) {
      log.e('Errore nell\'aggiunta della nota: $e');
      return false;
    }
  }

  /// Ottiene le note di un ordine
  Future<List<dynamic>> getNoteOrdine(int ordineId) async {
    try {
      log.i('Caricamento note ordine #$ordineId');
      final note = await _ordiniQuery.getOrderNotes(ordineId);
      log.i('Caricate ${note.length} note per ordine #$ordineId');
      return note;
    } catch (e) {
      log.e('Errore nel caricamento note ordine: $e');
      return [];
    }
  }

  /// Crea un nuovo ordine
  Future<OrdiniGlobal?> creaOrdine(OrdiniGlobal nuovoOrdine) async {
    try {
      log.i('Creazione nuovo ordine');

      final ordine = await _ordiniQuery.createOrder(nuovoOrdine);

      // Ricarica gli ordini per aggiornare la lista
      await caricaOrdini();

      log.i('Ordine creato con successo: #${ordine.number}');
      return ordine;
    } catch (e) {
      log.e('Errore nella creazione dell\'ordine: $e');
      return null;
    }
  }

  /// Aggiorna un ordine completo
  Future<bool> aggiornaOrdine(OrdiniGlobal ordineAggiornato) async {
    try {
      log.i('Aggiornamento ordine #${ordineAggiornato.id}');

      await _ordiniQuery.updateOrder(ordineAggiornato);

      // Ricarica gli ordini per aggiornare la lista
      await caricaOrdini();

      log.i('Ordine #${ordineAggiornato.id} aggiornato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'aggiornamento dell\'ordine: $e');
      return false;
    }
  }

  /// Ottiene tutti gli stati ordine disponibili
  List<OrdineStatus> getStatiDisponibili() {
    return [
      OrdineStatus.pending,
      OrdineStatus.processing,
      OrdineStatus.onHold,
      OrdineStatus.completed,
      OrdineStatus.cancelled,
      OrdineStatus.refunded,
      OrdineStatus.failed,
    ];
  }

  /// Ottiene tutti i valori degli stati ordine (per enumerazione in GUI)
  List<OrdineStatus> getAllStatiValues() {
    return OrdineStatus.values;
  }

  /// Ottiene il colore associato a uno stato ordine
  String getColoreStato(OrdineStatus status) {
    return status.colore;
  }

  /// Ottiene il testo tradotto per uno stato ordine
  String getTestoStato(AppLocalizations l10n, OrdineStatus status) {
    return ordineStatusLabel(l10n, status);
  }
}
