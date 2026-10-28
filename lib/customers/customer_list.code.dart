import '../l10n/error_text.dart';
import '../l10n/localized_text.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../log_viewer/app_logger.dart';
import '../reuse_class/datagridview/datagridview_filters.dart';
import '../reuse_class/datagridview/datagridview_list.code.dart';
import '../reuse_class/logic/global_pagination_controller.dart';
import 'class_customer.dart';

/// Controller per la gestione dei clienti.
///
/// Singleton: la lista clienti è globale e condivisa con le altre
/// sezioni (es. Carte Fedeltà), che la riusano senza ricaricarla
/// con chiamate WooCommerce dirette.
class ClientiGestioneController {
  static final ClientiGestioneController _instance =
      ClientiGestioneController._internal();
  factory ClientiGestioneController() => _instance;
  ClientiGestioneController._internal();

  // Usa PlatformManager invece di istanza diretta
  dynamic get _clientiQuery => PlatformManager.clienti;

  List<ClienteGlobal> _clienti = [];
  ClienteGlobal? _clienteSelezionato;
  bool _isLoading = false;
  LocalizedText? _errorMessage;

  /// Clienti chiesti in una volta da [caricaClienti] (massimo accettato da
  /// WooCommerce REST).
  static const int _clientiPerPagina = 100;

  // Getters
  List<ClienteGlobal> get clienti => _clienti;
  ClienteGlobal? get clienteSelezionato => _clienteSelezionato;
  bool get isLoading => _isLoading;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasClienteSelezionato => _clienteSelezionato != null;

  /// Pagina della lista Clienti: ricerca, email esatta e ordinamento passano
  /// al server con i parametri dei campi di [ClienteGlobal.gridFields].
  Future<PaginatedResult<ClienteGlobal>> caricaPagina(
    DataGridPageRequest request,
  ) async {
    final email = request.filterOn('email');
    final sort = request.sort;
    final sortField = sort == null
        ? null
        : DataGridFilterEngine.fieldByName(
            ClienteGlobal.gridFields,
            sort.fieldName,
          );
    final result = await _clientiQuery.getClientiPaginati(
      page: request.page,
      perPage: request.perPage,
      search: request.search,
      email: email?.valori.first,
      orderBy: sortField?.serverSortParam ?? 'registered_date',
      ascending: sort?.ascending ?? false,
    );
    return result as PaginatedResult<ClienteGlobal>;
  }

  /// Carica i primi clienti per chi li riusa fuori dalla lista Clienti (carte
  /// fedeltà).
  Future<void> caricaClienti() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      log.i('Caricamento clienti...');
      final page = await caricaPagina(
        const DataGridPageRequest(page: 1, perPage: _clientiPerPagina),
      );
      _clienti = page.items;
      log.i('Caricati ${_clienti.length} clienti');
    } catch (e) {
      log.e('Errore nel caricamento dei clienti: $e');
      _errorMessage = (l10n) =>
          l10n.customersLoadError(localizedErrorText(l10n, e));
      _clienti = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Seleziona un cliente
  void selezionaCliente(ClienteGlobal cliente) {
    _clienteSelezionato = cliente;
    log.d('Cliente selezionato: ${cliente.email}');
  }

  /// Deseleziona il cliente corrente
  void deselezionaCliente() {
    _clienteSelezionato = null;
  }

  /// Verifica se un cliente è selezionato
  bool isClienteSelezionato(ClienteGlobal cliente) {
    return _clienteSelezionato?.id == cliente.id;
  }

  /// Elimina un cliente
  Future<bool> eliminaCliente(int clienteId) async {
    try {
      log.i('Eliminazione cliente #$clienteId');
      await _clientiQuery.deleteCustomer(customerId: clienteId);
      log.i('Cliente #$clienteId eliminato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'eliminazione del cliente: $e');
      return false;
    }
  }
}
