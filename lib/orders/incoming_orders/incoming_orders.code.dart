import '../../l10n/localized_text.dart';
import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../log_viewer/app_logger.dart';
import '../class_orders.dart';

/// Risultato della verifica locale di un prodotto ordine.
class RisultatoVerifica {
  const RisultatoVerifica({
    required this.trovato,
    this.prodotto,
    this.codiceScansionato,
    this.nessunOrdine = false,
  });

  final bool trovato;

  /// La verifica non e partita perche non c'e un ordine selezionato.
  final bool nessunOrdine;
  final ProdottoOrdine? prodotto;
  final String? codiceScansionato;
}

/// Controller per la gestione degli ordini in arrivo
class OrdiniInArrivoController {
  // Usa PlatformManager invece di istanza diretta
  dynamic get _ordiniQuery => PlatformManager.ordini;

  List<OrdiniGlobal> _ordini = [];
  OrdiniGlobal? _ordineSelezionato;
  bool _isLoading = false;
  LocalizedText? _errorMessage;

  // Filtri
  OrdineStatus? _filtroStatus = OrdineStatus.processing;
  String _searchQuery = '';

  // Verifiche prodotti
  final Set<String> _barcodeInterniVerificati = {};

  // Getters
  List<OrdiniGlobal> get ordini => _ordiniFiltrati;
  OrdiniGlobal? get ordineSelezionato => _ordineSelezionato;
  bool get isLoading => _isLoading;
  LocalizedText? get errorMessage => _errorMessage;
  bool get hasOrdineSelezionato => _ordineSelezionato != null;
  OrdineStatus? get filtroStatus => _filtroStatus;
  String get searchQuery => _searchQuery;
  Set<String> get barcodeInterniVerificati =>
      Set.unmodifiable(_barcodeInterniVerificati);

  /// Carica gli ordini dal server
  Future<void> caricaOrdini() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      log.i('Caricamento ordini in arrivo...');

      final ordini = await _ordiniQuery.getOrders(
        perPage: 100,
        status: _filtroStatus,
      );

      _ordini = ordini;
      log.i('Caricati ${_ordini.length} ordini in arrivo');
    } catch (e) {
      log.e('Errore nel caricamento degli ordini in arrivo: $e');
      _errorMessage = (l10n) => l10n.ordersIncomingLoadError('$e');
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
    if (_ordineSelezionato?.id != ordine.id) {
      _barcodeInterniVerificati.clear();
    }
    _ordineSelezionato = ordine;
    log.d('Ordine in arrivo selezionato: #${ordine.number}');
  }

  /// Deseleziona l'ordine corrente
  void deselezionaOrdine() {
    resetVerifiche();
  }

  /// Verifica se un ordine è selezionato
  bool isOrdineSelezionato(OrdiniGlobal ordine) {
    return _ordineSelezionato?.id == ordine.id;
  }

  /// Imposta il filtro per stato
  void setFiltroStatus(OrdineStatus? status) {
    _filtroStatus = status;
    log.d(
      'Filtro stato ordini in arrivo impostato: ${status?.name ?? "tutti"}',
    );
  }

  /// Imposta la query di ricerca
  void setSearchQuery(String query) {
    _searchQuery = query;
  }

  /// Cancella tutti i filtri
  void cancellaFiltri() {
    _filtroStatus = OrdineStatus.processing;
    _searchQuery = '';
    log.d('Filtri ordini in arrivo cancellati');
  }

  /// Verifica se uno SKU è già stato controllato
  bool isBarcodeInternoVerificato(String? barcodeInterno) {
    final barcodeInternoNormalizzato = _normalizzaBarcodeInterno(
      barcodeInterno,
    );
    if (barcodeInternoNormalizzato.isEmpty) return false;
    return _barcodeInterniVerificati.contains(barcodeInternoNormalizzato);
  }

  /// Cancella le verifiche e deseleziona l'ordine corrente
  void resetVerifiche() {
    _barcodeInterniVerificati.clear();
    _ordineSelezionato = null;
    log.d('Verifiche prodotti ordini in arrivo cancellate');
  }

  /// Numero di prodotti distinti già verificati per l'ordine selezionato
  int get numeroProdottiVerificati {
    final barcodeInterniOrdine = _barcodeInterniDistintiOrdineSelezionato;
    if (barcodeInterniOrdine.isEmpty) return _barcodeInterniVerificati.length;

    return barcodeInterniOrdine
        .where(_barcodeInterniVerificati.contains)
        .length;
  }

  /// Numero totale di prodotti distinti nell'ordine selezionato
  int get numeroProdottiTotali {
    final lineItems = _ordineSelezionato?.lineItems ?? [];
    final barcodeInterniOrdine = _barcodeInterniDistintiOrdineSelezionato;
    if (barcodeInterniOrdine.isNotEmpty) return barcodeInterniOrdine.length;

    return lineItems.length;
  }

  /// Indica se tutti i prodotti dell'ordine selezionato sono stati verificati
  bool get verificaCompleta {
    final totale = numeroProdottiTotali;
    return totale > 0 && numeroProdottiVerificati == totale;
  }

  /// Verifica localmente un codice prodotto rispetto all'ordine selezionato
  RisultatoVerifica verificaCodiceProdotto(String codice) {
    final ordine = _ordineSelezionato;
    if (ordine == null) {
      log.e('Nessun ordine selezionato per verifica prodotto');
      return const RisultatoVerifica(trovato: false, nessunOrdine: true);
    }

    final codiceNormalizzato = _normalizzaBarcodeInterno(codice);
    for (final prodotto in ordine.lineItems ?? <ProdottoOrdine>[]) {
      final barcodeNormalizzato = _normalizzaBarcodeInterno(
        prodotto.barcodeInterno,
      );
      if (barcodeNormalizzato.isEmpty) continue;

      if (barcodeNormalizzato == codiceNormalizzato) {
        _barcodeInterniVerificati.add(barcodeNormalizzato);
        log.i(
          'Prodotto verificato per ordine #${ordine.number}: ${prodotto.barcodeInterno}',
        );
        return RisultatoVerifica(trovato: true, prodotto: prodotto);
      }
    }

    log.e('Codice prodotto non trovato per ordine #${ordine.number}: $codice');
    return RisultatoVerifica(trovato: false, codiceScansionato: codice);
  }

  Set<String> get _barcodeInterniDistintiOrdineSelezionato {
    final lineItems = _ordineSelezionato?.lineItems ?? [];
    return lineItems
        .map((prodotto) => _normalizzaBarcodeInterno(prodotto.barcodeInterno))
        .where((barcodeInterno) => barcodeInterno.isNotEmpty)
        .toSet();
  }

  String _normalizzaBarcodeInterno(String? barcodeInterno) {
    return barcodeInterno?.trim().toUpperCase() ?? '';
  }
}
