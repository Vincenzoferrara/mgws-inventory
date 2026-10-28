import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../log_viewer/app_logger.dart';
import '../class_orders.dart';
import '../../l10n/extensions.dart';
import '../../reuse_class/datagridview/datagridview_list.code.dart';
import '../../reuse_class/datagridview/datagridview_filters.dart';
import '../../reuse_class/logic/global_pagination_controller.dart';

/// Controller per la gestione degli ordini
class OrdiniGestioneController {
  // Usa PlatformManager invece di istanza diretta
  dynamic get _ordiniQuery => PlatformManager.ordini;

  OrdiniGlobal? _ordineSelezionato;

  // Getters
  OrdiniGlobal? get ordineSelezionato => _ordineSelezionato;
  bool get hasOrdineSelezionato => _ordineSelezionato != null;

  /// Ordini per stato su tutto il negozio, letti da `X-WP-Total`.
  Map<OrdineStatus, int> _conteggiStati = const <OrdineStatus, int>{};
  Map<OrdineStatus, int> get conteggiStati => _conteggiStati;

  /// Pagina della lista Ordini: ricerca, stato e ordinamento passano al
  /// server con i parametri dei campi di [OrdiniGlobal.gridFields].
  Future<PaginatedResult<OrdiniGlobal>> caricaPagina(
    DataGridPageRequest request,
  ) async {
    final query = PlatformManager.ordini;
    final statoFiltro = request.filterOn('stato');
    final sort = request.sort;
    final sortField = sort == null
        ? null
        : DataGridFilterEngine.fieldByName(
            OrdiniGlobal.gridFields,
            sort.fieldName,
          );
    final result = await query.getOrdiniPaginati(
      page: request.page,
      perPage: request.perPage,
      search: request.search,
      stati: statoFiltro?.valori
          .map((name) => OrdineStatus.values.asNameMap()[name])
          .whereType<OrdineStatus>()
          .map<String>((stato) => query.statoWoo(stato) as String)
          .toList(),
      orderBy: sortField?.serverSortParam ?? 'date',
      ascending: sort?.ascending ?? false,
    );
    return result as PaginatedResult<OrdiniGlobal>;
  }

  /// Conta gli ordini per stato sul server. Le statistiche non dipendono
  /// dalla pagina visibile ne' dai filtri della lista.
  Future<void> caricaConteggiStati() async {
    final query = PlatformManager.ordini;
    final perSlug = Map<String, dynamic>.from(await query.getOrderStats());
    _conteggiStati = <OrdineStatus, int>{
      for (final stato in OrdiniGlobal.statiOrdine)
        stato: (perSlug[query.statoWoo(stato)] as num?)?.toInt() ?? 0,
    };
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

  /// Aggiorna lo stato di un ordine
  Future<bool> aggiornaStatoOrdine(
    int ordineId,
    OrdineStatus nuovoStato,
  ) async {
    try {
      log.i('Aggiornamento stato ordine #$ordineId a ${nuovoStato.name}');

      final ordine = _ordineSelezionato!;
      if (ordine.id != ordineId) return false;
      final ordineAggiornato = ordine.copyWith(status: nuovoStato);

      await _ordiniQuery.updateOrder(ordineAggiornato);
      _ordineSelezionato = ordineAggiornato;

      log.i('Stato ordine #$ordineId aggiornato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'aggiornamento dello stato ordine: $e');
      return false;
    }
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
        if (_ordineSelezionato?.id == ordineId) _ordineSelezionato = null;
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
