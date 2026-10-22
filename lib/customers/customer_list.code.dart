import '../l10n/error_text.dart';
import '../l10n/localized_text.dart';
import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../log_viewer/app_logger.dart';

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

  List<WooCustomer> _clienti = [];
  WooCustomer? _clienteSelezionato;
  bool _isLoading = false;
  LocalizedText? _errorMessage;

  // Filtri
  String _searchQuery = '';

  /// Clienti mostrati per schermata (massimo accettato da WooCommerce REST).
  static const int _clientiPerPagina = 100;

  // Getters
  List<WooCustomer> get clienti => _clientiFiltrati;
  WooCustomer? get clienteSelezionato => _clienteSelezionato;
  bool get isLoading => _isLoading;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasClienteSelezionato => _clienteSelezionato != null;
  String get searchQuery => _searchQuery;

  /// Carica i clienti dal server
  Future<void> caricaClienti() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      log.i('Caricamento clienti...');

      // NB: non si passa `exclude`. Il wrapper `getCustomers` non lo dichiara e
      // la libreria WooCommerce non inoltra `include`/`exclude` a
      // `WooCustomerQuery`, quindi il parametro verrebbe scartato.
      final page =
          await _clientiQuery.getCustomers(
                perPage: _clientiPerPagina,
                page: 1,
                orderBy: WooOrderBy.registeredDate,
                order: WooSort.desc,
              )
              as WooPage<WooCustomer>;
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

  /// Filtra i clienti in base alla ricerca
  List<WooCustomer> get _clientiFiltrati {
    if (_searchQuery.isEmpty) return _clienti;

    return _clienti.where((cliente) {
      final query = _searchQuery.toLowerCase();

      // Cerca per ID cliente
      final idMatch = cliente.id.toString().contains(query);

      // Cerca per nome
      final firstNameMatch =
          cliente.firstName?.toLowerCase().contains(query) ?? false;
      final lastNameMatch =
          cliente.lastName?.toLowerCase().contains(query) ?? false;
      final usernameMatch =
          cliente.username?.toLowerCase().contains(query) ?? false;

      // Cerca per email
      final emailMatch = cliente.email?.toLowerCase().contains(query) ?? false;

      return idMatch ||
          firstNameMatch ||
          lastNameMatch ||
          usernameMatch ||
          emailMatch;
    }).toList();
  }

  /// Seleziona un cliente
  void selezionaCliente(WooCustomer cliente) {
    _clienteSelezionato = cliente;
    log.d('Cliente selezionato: ${cliente.email}');
  }

  /// Deseleziona il cliente corrente
  void deselezionaCliente() {
    _clienteSelezionato = null;
  }

  /// Verifica se un cliente è selezionato
  bool isClienteSelezionato(WooCustomer cliente) {
    return _clienteSelezionato?.id == cliente.id;
  }

  /// Imposta la query di ricerca
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  /// Cancella tutti i filtri
  void cancellaFiltri() {
    _searchQuery = '';
    log.d('Filtri cancellati');
  }

  /// Aggiorna un cliente
  Future<bool> aggiornaCliente(WooCustomer clienteAggiornato) async {
    try {
      log.i('Aggiornamento cliente #${clienteAggiornato.id}');

      await _clientiQuery.updateCustomer(
        customerId: clienteAggiornato.id!,
        email: clienteAggiornato.email,
        firstName: clienteAggiornato.firstName,
        lastName: clienteAggiornato.lastName,
        billing: clienteAggiornato.billing,
        shipping: clienteAggiornato.shipping,
        metaData: clienteAggiornato.metaData,
      );

      // Ricarica i clienti per aggiornare la lista
      await caricaClienti();

      log.i('Cliente #${clienteAggiornato.id} aggiornato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'aggiornamento del cliente: $e');
      return false;
    }
  }

  /// Crea un nuovo cliente
  Future<bool> creaCliente(WooCustomer nuovoCliente) async {
    try {
      log.i('Creazione nuovo cliente');

      await _clientiQuery.createCustomer(
        email: nuovoCliente.email!,
        firstName: nuovoCliente.firstName,
        lastName: nuovoCliente.lastName,
        username: nuovoCliente.username,
        password: nuovoCliente.password,
        billing: nuovoCliente.billing,
        shipping: nuovoCliente.shipping,
        metaData: nuovoCliente.metaData,
      );

      // Ricarica i clienti per aggiornare la lista
      await caricaClienti();

      log.i('Cliente creato con successo');
      return true;
    } catch (e) {
      log.e('Errore nella creazione del cliente: $e');
      return false;
    }
  }

  /// Elimina un cliente
  Future<bool> eliminaCliente(int clienteId) async {
    try {
      log.i('Eliminazione cliente #$clienteId');

      await _clientiQuery.deleteCustomer(customerId: clienteId);

      // Ricarica i clienti per aggiornare la lista
      await caricaClienti();

      log.i('Cliente #$clienteId eliminato con successo');
      return true;
    } catch (e) {
      log.e('Errore nell\'eliminazione del cliente: $e');
      return false;
    }
  }

  /// Ottiene statistiche sui clienti
  Map<String, dynamic> getStatistiche() {
    final totaleClienti = _clienti.length;
    final clientiPaganti = _clienti
        .where((c) => c.isPayingCustomer == true)
        .length;

    return {'totaleClienti': totaleClienti, 'clientiPaganti': clientiPaganti};
  }
}
