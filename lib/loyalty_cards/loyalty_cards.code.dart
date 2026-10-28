import '../l10n/localized_text.dart';
import '../customers/customer_list.code.dart';
import '../reuse_class/datagridview/datagridview_list.code.dart';
import '../reuse_class/logic/global_pagination_controller.dart';
import 'class_loyalty_card.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../log_viewer/app_logger.dart';
import 'loyalty_stats.dart';

/// Controller per la gestione delle carte fedeltà
class CartaFedeltaController {
  // Usa PlatformManager per accedere alle query
  dynamic get _cartaFedeltaQuery => PlatformManager.cartaFedelta;

  final log = AppLogger();

  Future<bool> _mgwsDisponibile() => PlatformManager.refreshCanUseMgws();

  // Stato
  Map<String, dynamic>? _cartaSelezionata;
  LoyaltyStats? _statistiche;
  LocalizedText? _errorMessage;

  /// Carte MGWS per cliente, lette una volta per caricamento della lista.
  Map<int, Map<String, dynamic>> _cartePerCliente = const {};

  // Getters
  Map<String, dynamic>? get cartaSelezionata => _cartaSelezionata;
  LoyaltyStats? get statistiche => _statistiche;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasCartaSelezionata => _cartaSelezionata != null;

  /// Pagina della lista Carte fedelta': i clienti arrivano dal negozio con i
  /// parametri dei clienti (nome, email), le carte da MGWS. Le carte si
  /// rileggono alla prima pagina di ogni caricamento.
  ///
  /// Se MGWS non risponde i clienti si vedono comunque, senza carta.
  Future<PaginatedResult<CartaFedeltaGlobal>> caricaPagina(
    DataGridPageRequest request,
  ) async {
    final clientiFuture = ClientiGestioneController().caricaPagina(request);
    if (request.page == 1 || _cartePerCliente.isEmpty) {
      _cartePerCliente = await _caricaCarte();
    }
    final clienti = await clientiFuture;
    return PaginatedResult<CartaFedeltaGlobal>(
      items: [
        for (final cliente in clienti.items)
          CartaFedeltaGlobal.daCliente(cliente, _cartePerCliente[cliente.id]),
      ],
      page: clienti.page,
      perPage: clienti.perPage,
      totalItems: clienti.totalItems,
      totalPages: clienti.totalPages,
      hasMore: clienti.hasMore,
    );
  }

  Future<Map<int, Map<String, dynamic>>> _caricaCarte() async {
    try {
      final carte = await _cartaFedeltaQuery.listAllCards()
          as List<Map<String, dynamic>>;
      return <int, Map<String, dynamic>>{
        for (final carta in carte)
          if ((carta['customer_id'] as num?)?.toInt() case final id?) id: carta,
      };
    } catch (e) {
      log.w('Carte fedeltà non caricate, mostro solo clienti: $e');
      return const <int, Map<String, dynamic>>{};
    }
  }

  /// Cerca una carta per numero
  Future<Map<String, dynamic>?> cercaCartaPerNumero(String numeroCarta) async {
    if (!await _mgwsDisponibile()) return null;
    try {
      log.i('Ricerca carta numero: $numeroCarta');

      final carta = await _cartaFedeltaQuery.findCustomerByCardNumber(
        numeroCarta,
      );

      if (carta != null) {
        log.i('Carta trovata per cliente #${carta['customer_id']}');
        return carta;
      }

      log.w('Nessuna carta trovata con numero: $numeroCarta');
      return null;
    } catch (e) {
      log.e('Errore nella ricerca carta: $e');
      return null;
    }
  }

  /// Seleziona una carta
  void selezionaCarta(Map<String, dynamic> carta) {
    _cartaSelezionata = carta;
    log.d('Carta selezionata: ${carta['card_number']}');
  }

  /// Deseleziona la carta corrente
  void deselezionaCarta() {
    _cartaSelezionata = null;
  }

  /// Ottiene i punti di un cliente
  Future<int> getPuntiCliente(int customerId) async {
    if (!await _mgwsDisponibile()) return 0;
    try {
      return await _cartaFedeltaQuery.getCustomerPoints(customerId);
    } catch (e) {
      log.e('Errore nel recupero punti: $e');
      return 0;
    }
  }

  /// Aggiunge punti a un cliente
  Future<bool> aggiungiPunti({
    required int customerId,
    required int punti,
    String? note,
  }) async {
    if (!await _mgwsDisponibile()) return false;
    try {
      log.i('Aggiunta $punti punti a cliente #$customerId');

      final success = await _cartaFedeltaQuery.addPointsToCustomer(
        customerId: customerId,
        points: punti,
        reference: 'manual_add',
        note: note ?? 'Points added manually',
      );

      if (success) {
        log.i('Punti aggiunti con successo');

        // Aggiorna la carta selezionata se è quella del cliente
        if (_cartaSelezionata != null &&
            _cartaSelezionata!['customer_id'] == customerId) {
          final nuoviPunti = await getPuntiCliente(customerId);
          _cartaSelezionata!['points'] = nuoviPunti;
        }

      }

      return success;
    } catch (e) {
      log.e('Errore nell\'aggiunta punti: $e');
      return false;
    }
  }

  /// Sottrae punti da un cliente
  Future<bool> sottraiPunti({
    required int customerId,
    required int punti,
    String? note,
  }) async {
    if (!await _mgwsDisponibile()) return false;
    try {
      log.i('Sottrazione $punti punti da cliente #$customerId');

      final success = await _cartaFedeltaQuery.deductPointsFromCustomer(
        customerId: customerId,
        points: punti,
        reference: 'manual_deduct',
        note: note ?? 'Points removed manually',
      );

      if (success) {
        log.i('Punti sottratti con successo');

        // Aggiorna la carta selezionata
        if (_cartaSelezionata != null &&
            _cartaSelezionata!['customer_id'] == customerId) {
          final nuoviPunti = await getPuntiCliente(customerId);
          _cartaSelezionata!['points'] = nuoviPunti;
        }

      }

      return success;
    } catch (e) {
      log.e('Errore nella sottrazione punti: $e');
      return false;
    }
  }

  /// Crea una nuova carta fedeltà per un cliente
  Future<bool> creaCarta({
    required int customerId,
    required String numeroCarta,
    String tier = 'bronze',
  }) async {
    if (!await _mgwsDisponibile()) return false;
    try {
      log.i('Creazione carta fedeltà per cliente #$customerId');

      // Verifica che il numero carta non sia già usato
      final cartaEsistente = await cercaCartaPerNumero(numeroCarta);
      if (cartaEsistente != null) {
        _errorMessage = (l10n) => l10n.loyaltyCardNumberInUse;
        log.w('Numero carta $numeroCarta già in uso');
        return false;
      }

      final success = await _cartaFedeltaQuery.createOrUpdateLoyaltyCard(
        customerId: customerId,
        cardNumber: numeroCarta,
        tier: tier,
      );

      if (success) {
        log.i('Carta fedeltà creata con successo');
      }

      return success;
    } catch (e) {
      log.e('Errore nella creazione carta: $e');
      _errorMessage = (l10n) => l10n.loyaltyCreateError('$e');
      return false;
    }
  }

  /// Aggiorna il tier di una carta
  Future<bool> aggiornaTier({
    required int customerId,
    required String numeroCarta,
    required String nuovoTier,
  }) async {
    if (!await _mgwsDisponibile()) return false;
    try {
      log.i('Aggiornamento tier per cliente #$customerId a $nuovoTier');

      final success = await _cartaFedeltaQuery.createOrUpdateLoyaltyCard(
        customerId: customerId,
        cardNumber: numeroCarta,
        tier: nuovoTier,
      );

      if (success) {
        log.i('Tier aggiornato con successo');

        // Aggiorna la carta selezionata
        if (_cartaSelezionata != null &&
            _cartaSelezionata!['customer_id'] == customerId) {
          _cartaSelezionata!['tier'] = nuovoTier;
        }

      }

      return success;
    } catch (e) {
      log.e('Errore nell\'aggiornamento tier: $e');
      return false;
    }
  }

  /// Rimuove una carta fedeltà
  Future<bool> rimuoviCarta(int customerId) async {
    if (!await _mgwsDisponibile()) return false;
    try {
      log.i('Rimozione carta fedeltà da cliente #$customerId');

      final success = await _cartaFedeltaQuery.removeLoyaltyCard(customerId);

      if (success) {
        log.i('Carta rimossa con successo');

        // Deseleziona se era selezionata
        if (_cartaSelezionata != null &&
            _cartaSelezionata!['customer_id'] == customerId) {
          deselezionaCarta();
        }

      }

      return success;
    } catch (e) {
      log.e('Errore nella rimozione carta: $e');
      return false;
    }
  }

  /// Ottiene lo storico punti di un cliente
  Future<List<Map<String, dynamic>>> getStoricoPunti(int customerId) async {
    if (!await _mgwsDisponibile()) return [];
    try {
      return await _cartaFedeltaQuery.getPointsHistory(customerId);
    } catch (e) {
      log.e('Errore nel recupero storico: $e');
      return [];
    }
  }

  /// Carica le statistiche del programma fedeltà
  Future<void> caricaStatistiche() async {
    if (!await _mgwsDisponibile()) {
      _statistiche = null;
      return;
    }
    try {
      log.i('Caricamento statistiche programma fedeltà...');

      _statistiche = await _cartaFedeltaQuery.getLoyaltyStats();

      log.i('Statistiche caricate con successo');
    } catch (e) {
      log.e('Errore nel caricamento statistiche: $e');
      _statistiche = null;
    }
  }

  /// Verifica disponibilità loyalty MGWS
  Future<bool> verificaLoyaltyDisponibile() async {
    return await _mgwsDisponibile();
  }

  /// Genera un numero carta casuale
  String generaNumeroCarta() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'CF${timestamp.toString().substring(timestamp.toString().length - 8)}$random';
  }

  /// Ottiene il colore per tier
  String getColoreTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return '#E5E4E2'; // Platino
      case 'gold':
        return '#FFD700'; // Oro
      case 'silver':
        return '#C0C0C0'; // Argento
      case 'bronze':
      default:
        return '#CD7F32'; // Bronzo
    }
  }

  /// Calcola il tier in base ai punti
  String calcolaTierDaPunti(int punti) {
    if (punti >= 1000) return 'platinum';
    if (punti >= 500) return 'gold';
    if (punti >= 250) return 'silver';
    return 'bronze';
  }
}
