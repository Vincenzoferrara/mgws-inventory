import '../l10n/localized_text.dart';
import '../customers/customer_list.code.dart';
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
  List<Map<String, dynamic>> _clientiConCarta = [];
  Map<String, dynamic>? _cartaSelezionata;
  LoyaltyStats? _statistiche;
  bool _isLoading = false;
  LocalizedText? _errorMessage;
  String _searchQuery = '';

  // Getters
  List<Map<String, dynamic>> get clientiConCarta => _clientiFiltrati;
  Map<String, dynamic>? get cartaSelezionata => _cartaSelezionata;
  LoyaltyStats? get statistiche => _statistiche;
  bool get isLoading => _isLoading;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasCartaSelezionata => _cartaSelezionata != null;
  String get searchQuery => _searchQuery;

  /// Carica tutti i clienti arricchendoli con la carta fedeltà, se presente.
  ///
  /// I clienti WooCommerce e le carte MGWS vengono caricati in parallelo
  /// con un'unica chiamata per backend. Se MGWS non è disponibile i
  /// clienti vengono comunque mostrati senza dati carta, senza bloccare
  /// la lista e senza azzerare quanto caricato.
  Future<void> caricaClientiConCarta() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      log.i('Caricamento clienti e carte fedeltà in parallelo...');

      // Usa la lista clienti globale (stessa della sezione Clienti):
      // niente chiamate WooCommerce dirette da qui.
      final clientiGlobali = ClientiGestioneController();
      final Future<void> clientiFuture =
          clientiGlobali.clienti.isEmpty && !clientiGlobali.isLoading
          ? clientiGlobali.caricaClienti()
          : Future.value();
      // Le carte sono opzionali: se MGWS fallisce, i clienti vengono
      // comunque mostrati senza dati carta.
      final Future<List<Map<String, dynamic>>> carteFuture = PlatformManager
          .cartaFedelta
          .listAllCards()
          .catchError((Object e) {
            log.w('Carte fedeltà non caricate, mostro solo clienti: $e');
            return <Map<String, dynamic>>[];
          });
      await Future.wait([clientiFuture, carteFuture]);

      final clienti = clientiGlobali.clienti.map((c) => c.toJson()).toList();
      final carte = await carteFuture;

      // Mappa delle carte per customer_id
      final cartePerCliente = <int, Map<String, dynamic>>{};
      for (final carta in carte) {
        final id = (carta['customer_id'] as num?)?.toInt();
        if (id != null) {
          cartePerCliente[id] = carta;
        }
      }

      // Unisce i dati: ogni cliente porta la propria carta, se presente
      _clientiConCarta = clienti.map((cliente) {
        final id = (cliente['id'] as num?)?.toInt();
        final carta = id != null ? cartePerCliente[id] : null;
        return {
          ...cliente,
          // Il dettaglio e le azioni sui punti leggono 'customer_id', mentre
          // il cliente globale espone solo 'id': lo riporto qui.
          'customer_id': id,
          'has_card': carta != null,
          if (carta != null) ...{
            'card_number': carta['card_number'] ?? '',
            'tier': carta['tier'] ?? 'bronze',
            'points': carta['points'] ?? 0,
            'card_id': carta['id'] ?? 0,
            'card_enabled': carta['enabled'] ?? false,
          },
        };
      }).toList();

      log.i('Caricati ${_clientiConCarta.length} clienti');
    } catch (e) {
      log.e('Errore nel caricamento clienti con carta: $e');
      _errorMessage = (l10n) => l10n.loyaltyLoadError('$e');
      // Non azzero la lista: se i clienti erano arrivati, restano visibili.
      // L'errore è informativo, non bloccante.
    } finally {
      _isLoading = false;
    }
  }

  /// Filtra i clienti in base alla ricerca
  List<Map<String, dynamic>> get _clientiFiltrati {
    if (_searchQuery.isEmpty) return _clientiConCarta;

    return _clientiConCarta.where((carta) {
      final query = _searchQuery.toLowerCase();

      final cardNumber = carta['card_number']?.toString().toLowerCase() ?? '';
      final firstName = carta['first_name']?.toString().toLowerCase() ?? '';
      final lastName = carta['last_name']?.toString().toLowerCase() ?? '';
      final email = carta['email']?.toString().toLowerCase() ?? '';

      return cardNumber.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query) ||
          email.contains(query);
    }).toList();
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

  /// Imposta la query di ricerca
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  /// Cancella i filtri
  void cancellaFiltri() {
    _searchQuery = '';
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

        // Ricarica la lista
        await caricaClientiConCarta();
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

        // Ricarica la lista
        await caricaClientiConCarta();
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
        await caricaClientiConCarta();
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

        await caricaClientiConCarta();
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

        await caricaClientiConCarta();
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
