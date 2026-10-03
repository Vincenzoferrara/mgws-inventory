// cassa.code.dart

import 'dart:async';

import '../prodotti/class_prodotti.dart';
import '../prodotti/prodotti_gestisci/product_picker.dart';
import 'class_scontrino.dart';
import 'checkout_payload.dart';
import 'cassa_metrics.dart';
import 'fiscal_register/fiscal_register_repository.dart';
import 'storico_cassa.code.dart';
import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../settings/cassa_settings.dart';

/// Rappresenta un elemento della lista cassa (può essere un prodotto o una variante)
class ElementoCassa {
  final ProdottoGlobal prodotto;
  final VarianteProductGlobal? variante;

  ElementoCassa(this.prodotto, [this.variante]);

  String get nome => variante?.nomeVisualizzabile ?? prodotto.nome ?? '';
  String get barcodeInterno =>
      variante?.barcodeInterno ?? prodotto.barcodeInterno ?? '';
  String get barcodeProduttore {
    final values = <String?>[
      variante?.barcodeFornitore,
      prodotto.barcodeProduttore,
      variante?.metadatiCustom?['barcode_manufacturer']?.toString(),
      prodotto.metadatiCustom?['barcode_manufacturer']?.toString(),
      variante?.metadatiCustom?['barcode_produttore']?.toString(),
      prodotto.metadatiCustom?['barcode_produttore']?.toString(),
      variante?.metadatiCustom?['supplier_sku']?.toString(),
      prodotto.metadatiCustom?['supplier_sku']?.toString(),
      variante?.metadatiCustom?['barcode']?.toString(),
      prodotto.metadatiCustom?['barcode']?.toString(),
    ];
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  double get prezzoNormale => variante?.prezzo ?? prodotto.prezzoNormale ?? 0;
  double? get prezzoScontato =>
      variante?.prezzoScontato ?? prodotto.prezzoScontato;
  double get prezzoEffettivo =>
      variante?.prezzoEffettivo ?? prodotto.prezzoEffettivo;
  double? get percentualeSconto =>
      variante?.percentualeSconto ?? prodotto.percentualeSconto;
  String? get immagineUrl => variante?.immagineUrl ?? prodotto.immagineUrl;
  bool get isDisponibile {
    // Se c'è una variante specifica, controlla solo la quantità (ignora flag attiva)
    if (variante != null) {
      final disponibile = variante!.quantita > 0;
      if (!disponibile) {
        AppLogger().d(
          '❌ Variante ${variante!.barcodeInterno} non disponibile: quantita=${variante!.quantita}',
        );
      }
      return disponibile;
    }
    // Per prodotti con varianti, controlla se almeno una ha stock > 0
    if (prodotto.varianti != null && prodotto.varianti!.isNotEmpty) {
      final disponibile = prodotto.varianti!.any((v) => v.quantita > 0);
      if (!disponibile) {
        AppLogger().d(
          '❌ Prodotto ${prodotto.nome} non disponibile: nessuna variante con stock',
        );
      }
      return disponibile;
    }
    // Prodotto semplice
    final disponibile = prodotto.inStock && (prodotto.quantitaTotale ?? 0) > 0;
    if (!disponibile) {
      AppLogger().d(
        '❌ Prodotto ${prodotto.nome} non disponibile: inStock=${prodotto.inStock}, qty=${prodotto.quantitaTotale}',
      );
    }
    return disponibile;
  }

  int get quantitaStock => variante?.quantita ?? prodotto.quantitaTotale ?? 0;
}

/// Controller per la gestione della cassa
class CassaController {
  Scontrino _scontrinoCorrente;
  // Risultati della ricerca on-demand (barcode scanner o testo): la cassa
  // NON carica mai il catalogo; popola solo gli elementi che servono.
  List<ElementoCassa> _elementiFiltrati = [];
  String _filtroRicerca = '';
  Timer? _debounceRicerca;
  final CassaMetricheStore _metricheStore = CassaMetricheStore();

  // Cliente selezionato (opzionale)
  String? _clienteNome;
  String? _clienteEmail;
  String? _clienteTelefono;

  // Scontrini sospesi
  final List<Scontrino> _scontriniSospesi = [];

  // Storico POS locale (SharedPreferences/JSON) separato dagli ordini Woo.
  final StoricoCassaStore storicoStore = StoricoCassaStore();

  // Operatore di cassa: l'utente loggato e l'utente che usa la cassa.
  // Risolto automaticamente dalla sessione (WordPress o JWT), mai impostato
  // a mano: niente picker dipendenti in cassa.
  int? _operatoreId;
  String? _operatoreNome;
  String? _operatoreCognome;
  bool _operatoreRisolto = false;

  CassaController()
    : _scontrinoCorrente = Scontrino(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: DateTime.now(),
      );

  // Getters
  Scontrino get scontrinoCorrente => _scontrinoCorrente;
  List<ElementoCassa> get elementi => _elementiFiltrati;
  String get filtroRicerca => _filtroRicerca;
  String? get clienteNome => _clienteNome;
  String? get clienteEmail => _clienteEmail;
  String? get clienteTelefono => _clienteTelefono;
  List<Scontrino> get scontriniSospesi => List.unmodifiable(_scontriniSospesi);
  CassaMetricheSnapshot get metricheSnapshot => _metricheStore.snapshot;
  int? get operatoreId => _operatoreId;
  String? get operatoreNome => _operatoreNome;
  String? get operatoreCognome => _operatoreCognome;
  String get operatoreLabel {
    final nome = [
      _operatoreNome ?? '',
      _operatoreCognome ?? '',
    ].join(' ').trim();
    if (nome.isEmpty) return 'Operatore non assegnato';
    if (_operatoreId != null) return '$nome (id $_operatoreId)';
    return nome;
  }

  String get cassaCorrenteLabel {
    final cassa = cassaSettings.nomeCassa.trim();
    return cassa.isEmpty ? 'cassa' : cassa;
  }

  String get sedeCorrenteLabel => cassaSettings.sede.trim();

  /// Turno aperto per la cassa corrente. Il filtro e solo sulla cassa, non
  /// sulla giornata: un turno resta "aperto" finche non viene chiuso, anche
  /// se la giornata operativa e cambiata a mezzanotte.
  TurnoCassa? get turnoCorrente =>
      storicoStore.turnoAperto(cassaNome: cassaCorrenteLabel);

  bool get hasTurnoAperto => turnoCorrente != null;
  bool get richiedeTurnoAperto => cassaSettings.turnoObbligatorio;

  String get turnoLabel {
    final turno = turnoCorrente;
    if (turno == null) return 'Turno non aperto';
    final ora =
        '${turno.dataApertura.hour.toString().padLeft(2, '0')}:${turno.dataApertura.minute.toString().padLeft(2, '0')}';
    return 'Turno aperto $ora · fondo €${turno.fondoIniziale.toStringAsFixed(2)}';
  }

  /// Etichetta compatta per la barra cassa: evita overflow su schermi stretti.
  String get turnoBreve {
    final turno = turnoCorrente;
    if (turno == null) return 'Turno non aperto';
    final ora =
        '${turno.dataApertura.hour.toString().padLeft(2, '0')}:${turno.dataApertura.minute.toString().padLeft(2, '0')}';
    return 'Aperto $ora';
  }

  TipoOperazioneCassa get tipoOperazioneCorrente =>
      _scontrinoCorrente.tipoOperazione;
  TipoOperazioneCassa get tipoOperazioneEffettivaCorrente =>
      _scontrinoCorrente.tipoOperazioneEffettiva;
  bool get isOperazioneCambio =>
      _scontrinoCorrente.tipoOperazione == TipoOperazioneCassa.cambio;
  bool get isOperazioneReso =>
      _scontrinoCorrente.tipoOperazione == TipoOperazioneCassa.reso;
  bool get isOperazioneVendita =>
      _scontrinoCorrente.tipoOperazione == TipoOperazioneCassa.vendita;

  bool get hasFiltroAttivo => _filtroRicerca.isNotEmpty;
  bool get hasCliente => _clienteNome != null;
  bool get hasScontriniSospesi => _scontriniSospesi.isNotEmpty;
  int get numeroScontriniSospesi => _scontriniSospesi.length;

  void setTipoOperazione(TipoOperazioneCassa tipo) {
    _scontrinoCorrente.tipoOperazione = tipo;
    _scontrinoCorrente.calcolaTotale();
  }

  /// Risolve l'operatore dalla sessione di login: l'utente autenticato e
  /// l'utente che usa la cassa. Non blocca mai la vendita: se l'identita
  /// non e disponibile, lo scontrino resta senza operatore.
  Future<void> risolviOperatoreDaLogin({bool force = false}) async {
    if (_operatoreRisolto && !force) return;
    try {
      final username = await PlatformManager.loggedUsername();
      final nome = (username ?? '').trim();
      _operatoreId = null;
      _operatoreCognome = null;
      _operatoreNome = nome.isEmpty ? null : nome;
    } catch (e) {
      AppLogger().w('Operatore cassa: identita login non leggibile: $e');
      _operatoreId = null;
      _operatoreNome = null;
      _operatoreCognome = null;
    }
    _operatoreRisolto = true;
    _scontrinoCorrente.operatoreId = _operatoreId;
    _scontrinoCorrente.operatoreNome = _operatoreNome;
    _scontrinoCorrente.operatoreCognome = _operatoreCognome;
    _applicaContestoCassa(_scontrinoCorrente);
  }

  Future<EsitoReso> apriTurno({required double fondoIniziale}) async {
    await storicoStore.init();
    await risolviOperatoreDaLogin();
    final cassa = cassaCorrenteLabel;
    final sede = sedeCorrenteLabel;
    if (storicoStore.turnoAperto(cassaNome: cassa) != null) {
      return const EsitoReso.ko(
        'Esiste già un turno aperto per questa cassa. Chiudilo prima di aprirne un altro.',
      );
    }
    final now = DateTime.now();
    final turno = TurnoCassa(
      id: 'turno-${now.millisecondsSinceEpoch}',
      giornataId: Scontrino.calcolaGiornataId(now, cassa),
      cassaNome: cassa,
      sede: sede.isEmpty ? null : sede,
      operatoreId: _operatoreId,
      operatoreNome: _operatoreNome,
      operatoreCognome: _operatoreCognome,
      dataApertura: now,
      fondoIniziale: fondoIniziale,
    );

    // Enforcement server-first: si apre lo shift MGWS PRIMA del turno locale.
    // Il server è autorevole: se non conferma (409 già aperto, backend giù…)
    // nessun turno locale. Lo shift_key coincide con turno.id, così il
    // checkout lo riferirà come shift_id e il server lo risolve by key.
    final shiftResponse = await PlatformManager.pos.openShift(<String, dynamic>{
      'shift_key': turno.id,
      'giornata_id': turno.giornataId,
      'cassa_name': turno.cassaNome,
      'sede': turno.sede ?? '',
      'operator_id': turno.operatoreId ?? 0,
      'operator_name': turno.operatoreLabel,
      'fondo_iniziale': turno.fondoIniziale,
    });
    final esitoServer = _esitoShiftServer(shiftResponse);
    if (!esitoServer.ok) return esitoServer;

    final esito = await storicoStore.apriTurno(turno);
    if (esito.ok) _applicaContestoCassa(_scontrinoCorrente);
    return esito;
  }

  /// Valuta una risposta openShift/closeShift del server MGWS. Il server è
  /// autorevole: conferma solo se risponde con una shift strutturata
  /// (id/shift_key) o con uno status 2xx. Qualsiasi errore → l'operazione
  /// locale NON viene eseguita.
  EsitoReso _esitoShiftServer(dynamic risposta) {
    if (risposta is! Map) {
      return const EsitoReso.ko('Risposta del backend MGWS non valida.');
    }
    final map = risposta;
    final ok =
        map['success'] == true ||
        map['id'] != null ||
        map['shift_key'] != null ||
        (map['status_code'] is num &&
            (map['status_code'] as num) >= 200 &&
            (map['status_code'] as num) < 300);
    if (ok) return const EsitoReso.ok();
    final messaggio =
        map['message']?.toString() ??
        'Operazione turno cassa MGWS non riuscita';
    return EsitoReso.ko(messaggio);
  }

  /// Estrae `expected_totals` dalla chiusura server (root
  /// `close_totals.expected_totals`, con fallback a root `expected_totals`).
  /// I totali attesi sono SERVER-side: l'app non li ricalcola da sé.
  Map<String, double> _expectedTotalsDaChiusura(dynamic risposta) {
    if (risposta is! Map) return const <String, double>{};
    dynamic aggiornati;
    final closeTotals = risposta['close_totals'];
    if (closeTotals is Map) aggiornati = closeTotals['expected_totals'];
    aggiornati ??= risposta['expected_totals'];
    if (aggiornati is! Map) return const <String, double>{};
    return <String, double>{
      'contanti': (aggiornati['contanti'] as num?)?.toDouble() ?? 0,
      'carta': (aggiornati['carta'] as num?)?.toDouble() ?? 0,
      'altri': (aggiornati['altri'] as num?)?.toDouble() ?? 0,
      'rimborsi': (aggiornati['rimborsi'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<EsitoReso> chiudiTurno({
    required double contanteContato,
    required double cartaContato,
    String? causaleDifferenza,
    String? note,
  }) async {
    await storicoStore.init();
    final turno = turnoCorrente;
    if (turno == null) return const EsitoReso.ko('Nessun turno aperto.');
    if (!_scontrinoCorrente.isVuoto) {
      return const EsitoReso.ko(
        'Chiudi o sospendi lo scontrino corrente prima di chiudere il turno.',
      );
    }
    // Enforcement server-first: si chiude lo shift MGWS col «contato» PRIMA
    // della chiusura locale. Il server calcola expected_totals dagli ordini
    // (HPOS-safe) e restituisce le differenze; l'app manda SOLO i conteggi.
    // Errore server → nessuna chiusura locale.
    final shiftResponse = await PlatformManager.pos
        .closeShift(turno.id, <String, dynamic>{
          'contante_contato': contanteContato,
          'carta_contato': cartaContato,
          if (causaleDifferenza != null && causaleDifferenza.isNotEmpty)
            'causale_differenza': causaleDifferenza,
          if (note != null && note.isNotEmpty) 'note': note,
        });
    final esitoServer = _esitoShiftServer(shiftResponse);
    if (!esitoServer.ok) return esitoServer;

    // Totali attesi dal server (autorevoli); fallback locale solo se il
    // backend non espone close_totals (compatibilità con versioni vecchie).
    final attesi = _expectedTotalsDaChiusura(shiftResponse);
    final totali = storicoStore.totaliGiornata(
      turno.giornataId,
      turnoId: turno.id,
    );
    final chiusura = ChiusuraCassa(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      giornataId: turno.giornataId,
      turnoId: turno.id,
      cassaNome: turno.cassaNome,
      sede: turno.sede,
      data: DateTime.now(),
      operatoreId: turno.operatoreId,
      operatoreNome: turno.operatoreNome,
      operatoreCognome: turno.operatoreCognome,
      fondoIniziale: turno.fondoIniziale,
      incassiContanti: attesi['contanti'] ?? totali['contanti'] ?? 0,
      incassiCarta: attesi['carta'] ?? totali['carta'] ?? 0,
      incassiAltri: attesi['altri'] ?? totali['altri'] ?? 0,
      rimborsi: attesi['rimborsi'] ?? totali['rimborsi'] ?? 0,
      contanteContato: contanteContato,
      cartaContato: cartaContato,
      causaleDifferenza: (causaleDifferenza ?? '').trim().isEmpty
          ? null
          : causaleDifferenza!.trim(),
      note: (note ?? '').trim().isEmpty ? null : note!.trim(),
    );
    final esito = await storicoStore.chiudiTurno(
      turnoId: turno.id,
      chiusura: chiusura,
    );
    if (esito.ok) _applicaContestoCassa(_scontrinoCorrente);
    return esito;
  }

  Map<String, double> totaliTurnoCorrente() {
    final turno = turnoCorrente;
    if (turno == null) {
      return const {'contanti': 0, 'carta': 0, 'altri': 0, 'rimborsi': 0};
    }
    return storicoStore.totaliGiornata(turno.giornataId, turnoId: turno.id);
  }

  void _applicaContestoCassa(Scontrino scontrino) {
    scontrino.canale = 'pos';
    scontrino.operatoreId = _operatoreId;
    scontrino.operatoreNome = _operatoreNome;
    scontrino.operatoreCognome = _operatoreCognome;
    final cassa = cassaSettings.nomeCassa.trim();
    final sede = cassaSettings.sede.trim();
    scontrino.cassaNome = cassa.isEmpty ? null : cassa;
    scontrino.sede = sede.isEmpty ? null : sede;
    scontrino.giornataId = Scontrino.calcolaGiornataId(
      scontrino.data,
      scontrino.cassaNome,
    );
    scontrino.turnoId = turnoCorrente?.id;
  }

  /// Reso vincolato rigido: parte da una riga vendita dello storico POS,
  /// eredita prezzo/sconti reali e blocca quantita oltre il residuo rendibile.
  /// Restituisce null in caso di successo, altrimenti il messaggio di errore.
  Future<String?> preparaResoVincolato({
    required String scontrinoOrigineId,
    required String chiaveRiga,
    required int quantita,
    required String motivo,
    String esitoMerce = 'reintegro',
    bool preparaCambio = false,
  }) async {
    await storicoStore.init();
    // Il residuo rendibile viene chiesto al server: conosce i resi di tutti i
    // dispositivi, quindi il controllo non dipende dal telefono che apre il
    // documento. Se il server non risponde si ricade sullo store locale.
    // The returnable remainder comes from the server, which sees returns from
    // every device; without a response the local store is used.
    var righeRendibili = await storicoStore.righeRendibiliDaServer(
      scontrinoOrigineId,
    );
    if (righeRendibili.isEmpty) {
      righeRendibili = storicoStore.righeRendibili(scontrinoOrigineId);
    }

    final esito = _validaResoConRighe(
      righeRendibili: righeRendibili,
      chiaveRiga: chiaveRiga,
      quantita: quantita,
      motivo: motivo,
    );
    if (!esito.ok) return esito.errore ?? 'Reso non consentito.';

    final origine = storicoStore.cercaPerId(scontrinoOrigineId);
    RigaScontrino? venduta;
    if (origine != null) {
      for (final r in origine.righe) {
        if (!r.isReso && r.chiaveRiga == chiaveRiga) venduta = r;
      }
    }
    // Il documento puo' non essere nello store locale, perche' la sua esistenza
    // e' sul server. In quel caso la riga si ricostruisce dai dati letti.
    final rigaVenduta = venduta ??
        _rigaDaRendibile(righeRendibili, chiaveRiga) ??
        (quantita > 0
            ? _rigaDaReso(scontrinoOrigineId, chiaveRiga, quantita)
            : null);
    if (rigaVenduta == null) return 'Riga vendita non trovata.';
    venduta = rigaVenduta;

    // Nuovo scontrino di reso collegato, con prezzo reale della vendita.
    await risolviOperatoreDaLogin();
    _scontrinoCorrente = Scontrino(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: DateTime.now(),
      tipoOperazione: preparaCambio
          ? TipoOperazioneCassa.cambio
          : TipoOperazioneCassa.reso,
      metodoPagamento: origine?.metodoPagamento ?? 'contanti',
      clienteId: origine?.clienteId,
      clienteNome: origine?.clienteNome,
      clienteEmail: origine?.clienteEmail,
      clienteTelefono: origine?.clienteTelefono,
    );
    _applicaContestoCassa(_scontrinoCorrente);
    final unitario = venduta.prezzoUnitario;
    final quotaScontoRiga = venduta.quantita > 0
        ? venduta.scontoRiga * quantita / venduta.quantita
        : 0.0;
    final rigaReso = RigaScontrino(
      prodotto: venduta.prodotto,
      variante: venduta.variante,
      quantita: quantita,
      subtotale: 0,
      scontoRiga: double.parse(quotaScontoRiga.toStringAsFixed(2)),
      scontoPercentuale: venduta.scontoPercentuale,
      tipoMovimento: TipoRigaCassa.reso,
      riferimentoScontrinoId: scontrinoOrigineId,
      riferimentoChiaveRiga: chiaveRiga,
      motivoReso: motivo.trim(),
      esitoMerce: esitoMerce,
    );
    // Forza il prezzo reale: allinea il listino usato per il calcolo al prezzo
    // effettivamente pagato, poi ricalcola il totale dello scontrino.
    final prezzoReale = unitario;
    final lordo = prezzoReale * quantita;
    double netto = lordo;
    if (rigaReso.scontoPercentuale > 0) {
      netto -= netto * (rigaReso.scontoPercentuale / 100);
    }
    netto -= rigaReso.scontoRiga;
    rigaReso.subtotale = netto > 0 ? double.parse(netto.toStringAsFixed(2)) : 0;
    _scontrinoCorrente.aggiungiRiga(rigaReso);
    _clienteNome = _scontrinoCorrente.clienteNome;
    _clienteEmail = _scontrinoCorrente.clienteEmail;
    _clienteTelefono = _scontrinoCorrente.clienteTelefono;
    return null;
  }

  /// Imposta il filtro di ricerca.
  ///
  /// La cassa NON carica mai il catalogo: ogni digitazione lancia una ricerca
  /// ON-DEMAND su WooCommerce (debounce 400 ms) e i risultati sostituiscono
  /// la lista corrente. Se il filtro è vuoto la lista si svuota.
  Future<void> setFiltroRicerca(String filtro) async {
    _filtroRicerca = filtro.trim();
    _debounceRicerca?.cancel();
    if (_filtroRicerca.isEmpty) {
      _elementiFiltrati = [];
      return;
    }
    _debounceRicerca = Timer(const Duration(milliseconds: 400), () {
      _ricercaOnDemand(_filtroRicerca);
    });
  }

  /// Cancella il filtro di ricerca
  Future<void> cancellaFiltro() async {
    _debounceRicerca?.cancel();
    _filtroRicerca = '';
    _elementiFiltrati = [];
  }

  /// Ricerca ON-DEMAND su WooCommerce per un termine testo.
  ///
  /// Non materializza mai il catalogo: interroga il backend solo per il
  /// termine digitato e, per i prodotti variabili, carica SOLO le varianti
  /// del prodotto in questione.
  Future<void> _ricercaOnDemand(String query) async {
    if (query.trim().isEmpty) {
      _elementiFiltrati = [];
      return;
    }
    try {
      final risultati = <ElementoCassa>[];

      // 1) Corrispondenza esatta per barcode interno (global_unique_id).
      final esatto = await ricercaPerBarcode(query);
      if (esatto != null) {
        risultati.add(esatto);
      }

      // 2) Ricerca generica WooCommerce (nome/sku/barcode) solo se il lookup
      //    esatto non ha già prodotto un risultato univoco.
      if (esatto == null) {
        final candidati = await PlatformManager.prodotti.searchProducts(
          query,
          limit: 10,
        );
        for (final prodotto in candidati) {
          final hasVariationIds =
              prodotto.variations != null && prodotto.variations!.isNotEmpty;
          if (hasVariationIds && (prodotto.id ?? 0) > 0) {
            try {
              final varianti = await PlatformManager.varianti.getAllVariations(
                prodotto.id,
              );
              for (final variante in varianti) {
                risultati.add(ElementoCassa(prodotto, variante));
              }
            } catch (e) {
              AppLogger().w(
                '⚠️ Varianti del prodotto ${prodotto.id} non caricate: $e',
              );
            }
          } else {
            // Prodotto semplice: un singolo elemento.
            risultati.add(ElementoCassa(prodotto));
          }
        }
      }

      _elementiFiltrati = risultati;
    } catch (e) {
      AppLogger().w('🔍 Ricerca cassa "$query" fallita: $e');
      _elementiFiltrati = [];
    }
  }

  /// Converte prodotti selezionati da "Prodotti gestisci" negli elementi
  /// cassa. La cassa NON usa un catalogo pre-caricato: recupera ON-DEMAND
  /// per ID solo i prodotti/varianti selezionati dal picker.
  Future<List<ElementoCassa>> elementiPerProdotti(
    List<ProdottoGlobal> prodotti,
  ) async {
    final elementi = <ElementoCassa>[];
    // Il picker puo' restituire prodotti semplici e variabili insieme:
    // expandSelectedProducts stacca il caso e lascia una riga per ogni
    // unita' vendibile, cosi' qui non si deve distinguere nulla.
    for (final unita in expandSelectedProducts(prodotti)) {
      final productId = unita.productId;
      final variante = unita.variant;
      if (variante == null) {
        // Prodotto semplice: recupera i dati freschi (stock/prezzo) per ID.
        try {
          final fresco = await PlatformManager.prodotti.getProductById(
            productId,
          );
          elementi.add(ElementoCassa(fresco));
        } catch (e) {
          AppLogger().w('⚠️ Prodotto semplice $productId non recuperabile: $e');
          // Fallback: usa l'oggetto passato dal picker.
          elementi.add(ElementoCassa(unita.product));
        }
        continue;
      }

      // Prodotto variabile: recupera ogni variante selezionata per ID.
      try {
        final varianteFresca = await PlatformManager.varianti.getVariationById(
          productId,
          variante.id,
        );
        elementi.add(ElementoCassa(unita.product, varianteFresca));
      } catch (e) {
        AppLogger().w(
          '⚠️ Variante ${variante.id} del prodotto $productId non recuperabile: $e',
        );
        // Fallback: usa l'oggetto passato dal picker.
        elementi.add(ElementoCassa(unita.product, variante));
      }
    }
    return elementi;
  }

  /// Aggiunge un elemento (prodotto o variante) allo scontrino
  /// Restituisce true se l'aggiunta è riuscita, false altrimenti
  bool aggiungiElemento(
    ElementoCassa elemento, {
    int quantita = 1,
    TipoRigaCassa? tipoMovimento,
  }) {
    if (quantita <= 0) {
      AppLogger().w('⚠️ Quantità non valida: $quantita');
      return false;
    }

    final tipoRiga =
        tipoMovimento ??
        (isOperazioneReso ? TipoRigaCassa.reso : TipoRigaCassa.vendita);

    // Controlla se la riga esiste già nello scontrino
    final rigaEsistente = _trovaRigaEsistente(
      elemento,
      tipoMovimento: tipoRiga,
    );

    if (rigaEsistente != null) {
      // Incrementa la quantità della riga esistente
      rigaEsistente.aggiornaQuantita(rigaEsistente.quantita + quantita);
      _scontrinoCorrente.calcolaTotale();
      AppLogger().d(
        '📦 Quantità aggiornata per ${elemento.nome}: ${rigaEsistente.quantita}',
      );
    } else {
      // Crea una nuova riga
      final prezzo = elemento.prezzoEffettivo;
      final subtotale = prezzo * quantita;

      final riga = RigaScontrino(
        prodotto: elemento.prodotto,
        variante: elemento.variante,
        quantita: quantita,
        subtotale: subtotale,
        tipoMovimento: tipoRiga,
      );

      _scontrinoCorrente.aggiungiRiga(riga);
      AppLogger().d('➕ Aggiunto ${elemento.nome} x$quantita al carrello');
    }

    AppLogger().i(
      '✅ Elemento aggiunto. Totale righe: ${_scontrinoCorrente.righe.length}',
    );
    return true;
  }

  /// Trova una riga esistente nello scontrino con stesso prodotto/variante
  RigaScontrino? _trovaRigaEsistente(
    ElementoCassa elemento, {
    required TipoRigaCassa tipoMovimento,
  }) {
    for (final riga in _scontrinoCorrente.righe) {
      if (riga.prodotto.id == elemento.prodotto.id &&
          riga.tipoMovimento == tipoMovimento) {
        // Se entrambi non hanno varianti, è una corrispondenza
        if (elemento.variante == null && riga.variante == null) {
          return riga;
        }
        // Se entrambi hanno la stessa variante, è una corrispondenza
        if (elemento.variante != null &&
            riga.variante != null &&
            riga.variante!.id == elemento.variante!.id) {
          return riga;
        }
      }
    }
    return null;
  }

  /// Rimuove una riga dallo scontrino
  void rimuoviRiga(int index) {
    _scontrinoCorrente.rimuoviRiga(index);
    //AppLogger.info('Riga rimossa. Totale righe: ${_scontrinoCorrente.righe.length}');
  }

  /// Aggiorna la quantità di una riga
  String? aggiornaQuantitaRiga(int index, int nuovaQuantita) {
    if (index < 0 || index >= _scontrinoCorrente.righe.length) {
      return 'Riga non valida.';
    }

    if (nuovaQuantita <= 0) {
      rimuoviRiga(index);
      return null;
    }

    final riga = _scontrinoCorrente.righe[index];
    if (riga.tipoMovimento == TipoRigaCassa.vendita) {
      final stockDisponibile =
          riga.variante?.quantita ?? riga.prodotto.quantitaTotale ?? 0;
      if (nuovaQuantita > stockDisponibile) {
        return 'Stock insufficiente. Disponibili: $stockDisponibile, Richiesti: $nuovaQuantita';
      }
    }

    riga.aggiornaQuantita(nuovaQuantita);
    _scontrinoCorrente.calcolaTotale();
    return null;
  }

  /// Incrementa quantità di una riga dello scontrino
  String? incrementaQuantitaRiga(int index) {
    if (index < 0 || index >= _scontrinoCorrente.righe.length) {
      return 'Riga non valida.';
    }
    final riga = _scontrinoCorrente.righe[index];
    return aggiornaQuantitaRiga(index, riga.quantita + 1);
  }

  /// Decrementa quantità di una riga dello scontrino
  void decrementaQuantitaRiga(int index) {
    if (index >= 0 && index < _scontrinoCorrente.righe.length) {
      final riga = _scontrinoCorrente.righe[index];
      if (riga.quantita > 1) {
        riga.decrementaQuantita();
        _scontrinoCorrente.calcolaTotale();
      } else {
        rimuoviRiga(index);
      }
    }
  }

  /// Svuota il carrello
  void svuotaCarrello() {
    final tipoOperazione = _scontrinoCorrente.tipoOperazione;
    _scontrinoCorrente.reset();
    _scontrinoCorrente.tipoOperazione = tipoOperazione;
    AppLogger().i('🗑️ Carrello svuotato');
  }

  /// Imposta i dati del cliente e carica automaticamente la carta fedeltà
  Future<Map<String, dynamic>?> setCliente({
    String? nome,
    String? email,
    String? telefono,
  }) async {
    _clienteNome = nome;
    _clienteEmail = email;
    _clienteTelefono = telefono;

    _scontrinoCorrente.clienteNome = nome;
    _scontrinoCorrente.clienteEmail = email;
    _scontrinoCorrente.clienteTelefono = telefono;

    // Cerca automaticamente la carta fedeltà associata all'email
    if (email != null &&
        email.isNotEmpty &&
        await PlatformManager.refreshCanUseMgws()) {
      try {
        final carta = await PlatformManager.cartaFedelta.findCustomerByEmail(
          email,
        );
        if (carta != null) {
          _scontrinoCorrente.clienteId = carta['user_id']?.toString();
          return carta;
        }
      } catch (error) {
        AppLogger().w('Ricerca carta fedeltà fallita: ${error.runtimeType}');
      }
    }
    return null;
  }

  /// Cancella i dati del cliente
  void cancellaCliente() {
    _clienteNome = null;
    _clienteEmail = null;
    _clienteTelefono = null;

    _scontrinoCorrente.clienteNome = null;
    _scontrinoCorrente.clienteEmail = null;
    _scontrinoCorrente.clienteTelefono = null;
  }

  /// Applica uno sconto
  void applicaSconto(double sconto) {
    _scontrinoCorrente.sconto = sconto;
    _scontrinoCorrente.calcolaTotale();
  }

  /// Completa la vendita tramite checkout MGWS.
  Future<bool> completaVendita() async {
    return completaOperazione();
  }

  /// Valida un reso sulle righe rendibili, dal server o dallo store locale.
  ///
  /// Il controllo resta identico in entrambi i casi: cambia solo da dove
  /// arrivano le righe.
  /// Validates a return against the returnable lines.
  EsitoReso _validaResoConRighe({
    required List<RigaRendibile> righeRendibili,
    required String chiaveRiga,
    required int quantita,
    required String motivo,
  }) {
    if (righeRendibili.isEmpty) {
      return const EsitoReso.ko(
        'Scontrino di origine non trovato o non disponibile sul server.',
      );
    }
    if (motivo.trim().isEmpty) {
      return const EsitoReso.ko('Motivo del reso obbligatorio.');
    }
    RigaRendibile? riga;
    for (final candidate in righeRendibili) {
      if (candidate.chiaveRiga == chiaveRiga) riga = candidate;
    }
    if (riga == null) return const EsitoReso.ko('Riga venduta non trovata.');
    if (riga.isEsaurita) {
      return const EsitoReso.ko('Riga gia interamente restituita.');
    }
    if (quantita <= 0) {
      return const EsitoReso.ko('Quantita di reso non valida.');
    }
    if (quantita > riga.quantitaRendibile) {
      return EsitoReso.ko(
        'Reso superiore al residuo: disponibili ${riga.quantitaRendibile}.',
      );
    }
    return const EsitoReso.ok();
  }

  /// Ricostruisce la riga venduta dai dati letti dal server.
  /// Rebuilds the sold line from the data read server-side.
  RigaScontrino? _rigaDaRendibile(List<RigaRendibile> righe, String chiaveRiga) {
    for (final candidate in righe) {
      if (candidate.chiaveRiga != chiaveRiga) continue;
      return RigaScontrino(
        prodotto: ProdottoGlobal(
          nome: candidate.nome,
          barcodeInterno: candidate.barcodeInterno,
        ),
        quantita: candidate.quantitaVenduta,
        subtotale: 0,
        riferimentoChiaveRiga: candidate.chiaveRiga,
      );
    }
    return null;
  }

  /// Riga minima per un reso senza documento locale.
  /// Minimal line for a return without a local document.
  RigaScontrino? _rigaDaReso(
    String scontrinoOrigineId,
    String chiaveRiga,
    int quantita,
  ) {
    return RigaScontrino(
      prodotto: ProdottoGlobal(nome: ''),
      quantita: quantita,
      subtotale: 0,
      riferimentoChiaveRiga: chiaveRiga,
      riferimentoScontrinoId: scontrinoOrigineId,
    );
  }

  /// Legge il progressivo scontrino dalla risposta del checkout.
  ///
  /// Il server lo assegna in simulazione; con registratore telematico arriva
  /// gia' emesso dal dispositivo. Se manca, si torna al fallback locale.
  /// Reads the receipt number from the checkout response. The server
  /// allocates it in simulation; with a fiscal register it arrives already
  /// issued by the device. When missing, the local fallback applies.
  int? _leggiProgressivoServer(Map<String, dynamic> response) {
    final valore = response['sequential_number'];
    if (valore is num && valore.toInt() > 0) return valore.toInt();
    if (valore is String) {
      final parsed = int.tryParse(valore);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  Future<bool> completaOperazione() async {
    if (_scontrinoCorrente.isVuoto) {
      AppLogger().w('⚠️ Impossibile completare: scontrino vuoto');
      return false;
    }

    if (richiedeTurnoAperto && !hasTurnoAperto) {
      AppLogger().w('Checkout bloccato: turno cassa non aperto');
      return false;
    }

    if (!await PlatformManager.refreshCanUseMgws()) {
      AppLogger().w('Checkout bloccato: backend MGWS non disponibile');
      return false;
    }

    try {
      AppLogger().i(
        // nel log va lo slug del protocollo, non l'etichetta: i log non hanno
        // una lingua e devono restare confrontabili con quello del backend.
        '💰 Inizio checkout MGWS ${_scontrinoCorrente.tipoOperazioneEffettiva.value} - Saldo: €${_scontrinoCorrente.totale.toStringAsFixed(2)}',
      );

      final checkoutPayload = _buildCheckoutPayload();
      final response = await PlatformManager.pos.checkout(checkoutPayload);
      final success =
          response['success'] == true ||
          response['status_code'] != null &&
              (response['status_code'] as int) >= 200 &&
              (response['status_code'] as int) < 300;

      if (!success) {
        throw Exception(
          response['message']?.toString() ?? 'Checkout MGWS non completato',
        );
      }

      final orderId = PlatformManager.pos.checkoutOrderId(response);
      // Progressivo assegnato dal server: e' il numero che finisce nello
      // storico, cosi' non dipende da un contatore salvato sul dispositivo.
      // Server-allocated number: this is what lands in the history, so it no
      // longer depends on a counter stored on the device.
      final progressivoServer = _leggiProgressivoServer(response);
      await risolviOperatoreDaLogin();
      _applicaContestoCassa(_scontrinoCorrente);
      if (orderId != null) {
        _scontrinoCorrente.wooOrderId = orderId;
        _scontrinoCorrente.mgwsOrderId = orderId;
        AppLogger().i('✅ Checkout MGWS completato - ID ordine: $orderId');
      } else {
        AppLogger().i('✅ Checkout MGWS completato');
      }

      await _metricheStore.registraOperazione(_scontrinoCorrente);

      // Aggiorna lo stato dello scontrino locale
      _scontrinoCorrente.stato = _scontrinoCorrente.totale < 0
          ? 'rimborsato'
          : 'pagato';

      // Emissione sul registratore telematico, se collegato. In modalita'
      // simulazione nessun numero viene emesso e la sequenza resta quella
      // dell'app, quindi il comportamento resta identico a prima.
      // Issues the receipt on the fiscal register when one is attached. In
      // simulation no number is issued and the app keeps its own sequence.
      try {
        final esito = await fiscalRegisterRepository.issueReceipt(
          _scontrinoCorrente,
        );
        final numeroDispositivo = esito.deviceReceiptNumber;
        if (numeroDispositivo != null && numeroDispositivo.isNotEmpty) {
          _scontrinoCorrente.numeroProgressivoDispositivo = numeroDispositivo;
        }
      } catch (e) {
        AppLogger().w('Registratore telematico: emissione non riuscita: $e');
      }

      // Storico POS separato dagli ordini Woo: archivia lo scontrino chiuso
      // con righe, pagamenti, operatore, cassa e riferimento ordine.
      try {
        await storicoStore.registraScontrinoChiuso(
          _scontrinoCorrente,
          progressivoServer: progressivoServer,
        );
      } catch (e) {
        AppLogger().w('Storico POS: archiviazione locale fallita: $e');
      }

      // Crea un nuovo scontrino per la prossima vendita
      _nuovoScontrino();

      return true;
    } catch (e, stackTrace) {
      AppLogger().e(
        '❌ Errore durante il completamento della vendita',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Crea un nuovo scontrino vuoto
  void _nuovoScontrino() {
    final tipoOperazione = _scontrinoCorrente.tipoOperazione;
    _scontrinoCorrente = Scontrino(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: DateTime.now(),
      tipoOperazione: tipoOperazione,
      operatoreId: _operatoreId,
      operatoreNome: _operatoreNome,
      operatoreCognome: _operatoreCognome,
    );
    _applicaContestoCassa(_scontrinoCorrente);
    _clienteNome = null;
    _clienteEmail = null;
    _clienteTelefono = null;
  }

  Map<String, dynamic> _buildCheckoutPayload() {
    return buildMgwsCheckoutPayload(
      scontrino: _scontrinoCorrente,
      customerName: _clienteNome,
      customerEmail: _clienteEmail,
      customerPhone: _clienteTelefono,
    );
  }

  /// Ricerca ON-DEMAND su WooCommerce per barcode (scanner o testo).
  /// Non carica mai il catalogo: interroga il backend e materializza solo
  /// l'elemento che corrisponde al codice (variante se il barcode appartiene
  /// a una variante, prodotto semplice altrimenti).
  Future<ElementoCassa?> ricercaPerBarcode(String barcode) async {
    final codice = barcode.trim();
    if (codice.isEmpty) return null;
    try {
      // 1) Lookup esatto per barcode interno (global_unique_id).
      final prodotto = await PlatformManager.prodotti
          .findProductByBarcodeInternoExact(codice);
      if (prodotto != null) {
        return await _elementoDaProdottoPerBarcode(prodotto, codice);
      }
      // 2) Fallback: ricerca generica WooCommerce sul termine.
      final candidati = await PlatformManager.prodotti.searchProducts(
        codice,
        limit: 5,
      );
      if (candidati.isEmpty) return null;
      if (candidati.length == 1) {
        return await _elementoDaProdottoPerBarcode(candidati.first, codice);
      }
      for (final candidato in candidati) {
        final elemento = await _elementoDaProdottoPerBarcode(candidato, codice);
        if (elemento != null) return elemento;
      }
      return null;
    } catch (e) {
      AppLogger().w('🔍 Ricerca barcode "$codice" fallita: $e');
      return null;
    }
  }

  /// Da un prodotto trovato per barcode restituisce l'elemento corretto:
  /// la variante che contiene il codice, oppure il prodotto se semplice.
  Future<ElementoCassa?> _elementoDaProdottoPerBarcode(
    ProdottoGlobal prodotto,
    String barcode,
  ) async {
    final codice = barcode.trim().toLowerCase();
    final hasVariationIds =
        prodotto.variations != null && prodotto.variations!.isNotEmpty;
    if (!hasVariationIds) {
      return ElementoCassa(prodotto);
    }
    try {
      final varianti = await PlatformManager.varianti.getAllVariations(
        prodotto.id,
      );
      for (final variante in varianti) {
        if (_codiceInVariante(variante, codice)) {
          return ElementoCassa(prodotto, variante);
        }
      }
    } catch (e) {
      AppLogger().w('⚠️ Varianti del prodotto ${prodotto.id} non caricate: $e');
    }
    return null;
  }

  /// Verifica se il codice (barcode) appartiene alla variante, confrontando
  /// barcode interno, barcode fornitore e metadati custom.
  bool _codiceInVariante(VarianteProductGlobal variante, String codice) {
    final codici = <String>[
      variante.barcodeInterno,
      variante.barcodeFornitore,
      variante.metadatiCustom?['barcode_manufacturer']?.toString() ?? '',
      variante.metadatiCustom?['barcode_produttore']?.toString() ?? '',
      variante.metadatiCustom?['supplier_sku']?.toString() ?? '',
      variante.metadatiCustom?['barcode']?.toString() ?? '',
    ];
    return codici
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .any((c) => c.contains(codice));
  }

  // =======================================================
  // == NUOVE FUNZIONALITÀ                                ==
  // =======================================================

  /// Imposta il metodo di pagamento
  void setMetodoPagamento(String metodo) {
    _scontrinoCorrente.metodoPagamento = metodo;
    AppLogger().d('💳 Metodo pagamento impostato: $metodo');
  }

  /// Imposta l'importo ricevuto (per calcolo resto)
  void setImportoRicevuto(double importo) {
    _scontrinoCorrente.importoRicevuto = importo;
    AppLogger().d('💵 Importo ricevuto: €${importo.toStringAsFixed(2)}');
  }

  /// Ottiene il resto da dare
  double get resto => _scontrinoCorrente.resto;

  /// Verifica se l'importo è sufficiente
  bool get importoSufficiente => _scontrinoCorrente.importoSufficiente;

  /// Applica sconto percentuale a una riga
  void applicaScontoRigaPercentuale(int index, double percentuale) {
    if (index >= 0 && index < _scontrinoCorrente.righe.length) {
      _scontrinoCorrente.righe[index].applicaScontoPercentuale(percentuale);
      _scontrinoCorrente.calcolaTotale();
      AppLogger().d('🏷️ Sconto $percentuale% applicato alla riga $index');
    }
  }

  /// Applica sconto fisso a una riga
  void applicaScontoRigaFisso(int index, double sconto) {
    if (index >= 0 && index < _scontrinoCorrente.righe.length) {
      _scontrinoCorrente.righe[index].applicaScontoFisso(sconto);
      _scontrinoCorrente.calcolaTotale();
      AppLogger().d(
        '🏷️ Sconto €${sconto.toStringAsFixed(2)} applicato alla riga $index',
      );
    }
  }

  /// Rimuove sconti da una riga
  void rimuoviScontiRiga(int index) {
    if (index >= 0 && index < _scontrinoCorrente.righe.length) {
      _scontrinoCorrente.righe[index].rimuoviSconti();
      _scontrinoCorrente.calcolaTotale();
    }
  }

  /// Applica sconto percentuale globale
  void applicaScontoPercentuale(double percentuale) {
    _scontrinoCorrente.applicaScontoPercentualeGlobale(percentuale);
    AppLogger().d('🏷️ Sconto globale ${percentuale}% applicato');
  }

  /// Applica un coupon WooCommerce
  Future<bool> applicaCoupon(String codice) async {
    try {
      AppLogger().i('🎟️ Verifica coupon: $codice');

      // Verifica il coupon su WooCommerce
      final coupon = await PlatformManager.coupon.getCouponByCode(codice);

      if (coupon == null) {
        AppLogger().w('⚠️ Coupon non trovato: $codice');
        return false;
      }

      // Verifica validità
      if (coupon.dateExpires != null &&
          coupon.dateExpires!.isBefore(DateTime.now())) {
        AppLogger().w('⚠️ Coupon scaduto: $codice');
        return false;
      }

      // Calcola lo sconto
      double scontoCoupon = 0.0;
      if (coupon.discountType == 'percent') {
        scontoCoupon =
            _scontrinoCorrente.subtotale *
            (double.tryParse(coupon.amount ?? '0') ?? 0) /
            100;
      } else {
        scontoCoupon = double.tryParse(coupon.amount ?? '0') ?? 0;
      }

      // Applica il coupon
      _scontrinoCorrente.couponCode = codice;
      _scontrinoCorrente.couponSconto = scontoCoupon;
      _scontrinoCorrente.calcolaTotale();

      AppLogger().i(
        '✅ Coupon applicato: $codice - Sconto: €${scontoCoupon.toStringAsFixed(2)}',
      );
      return true;
    } catch (e) {
      AppLogger().e('❌ Errore applicazione coupon', e);
      return false;
    }
  }

  /// Rimuove il coupon applicato
  void rimuoviCoupon() {
    _scontrinoCorrente.couponCode = null;
    _scontrinoCorrente.couponSconto = 0.0;
    _scontrinoCorrente.calcolaTotale();
    AppLogger().d('🗑️ Coupon rimosso');
  }

  /// Sospende lo scontrino corrente
  void sospendiScontrino() {
    if (_scontrinoCorrente.isVuoto) {
      AppLogger().w('⚠️ Impossibile sospendere: scontrino vuoto');
      return;
    }

    _scontrinoCorrente.stato = 'sospeso';
    _scontriniSospesi.add(_scontrinoCorrente);
    AppLogger().i('⏸️ Scontrino sospeso - ID: ${_scontrinoCorrente.id}');

    // Crea un nuovo scontrino
    _nuovoScontrino();
  }

  /// Riprende uno scontrino sospeso
  void riprendiScontrino(int index) {
    if (index < 0 || index >= _scontriniSospesi.length) {
      AppLogger().w('⚠️ Indice scontrino sospeso non valido');
      return;
    }

    // Se lo scontrino corrente non è vuoto, lo sospende prima
    if (!_scontrinoCorrente.isVuoto) {
      sospendiScontrino();
    }

    // Riprende lo scontrino sospeso
    _scontrinoCorrente = _scontriniSospesi.removeAt(index);
    _scontrinoCorrente.stato = 'aperto';

    // Ripristina i dati cliente
    _clienteNome = _scontrinoCorrente.clienteNome;
    _clienteEmail = _scontrinoCorrente.clienteEmail;
    _clienteTelefono = _scontrinoCorrente.clienteTelefono;

    AppLogger().i('▶️ Scontrino ripreso - ID: ${_scontrinoCorrente.id}');
  }

  /// Elimina uno scontrino sospeso
  void eliminaScontrinoSospeso(int index) {
    if (index >= 0 && index < _scontriniSospesi.length) {
      final scontrino = _scontriniSospesi.removeAt(index);
      AppLogger().d('🗑️ Scontrino sospeso eliminato - ID: ${scontrino.id}');
    }
  }

  /// Verifica disponibilità stock prima di aggiungere
  /// Restituisce null se disponibile, altrimenti il messaggio di errore
  String? verificaDisponibilitaStock(
    ElementoCassa elemento,
    int quantitaRichiesta,
  ) {
    // Trova quantità già nel carrello
    int quantitaInCarrello = 0;
    final rigaEsistente = _trovaRigaEsistente(
      elemento,
      tipoMovimento: TipoRigaCassa.vendita,
    );
    if (rigaEsistente != null) {
      quantitaInCarrello = rigaEsistente.quantita;
    }

    final quantitaTotale = quantitaInCarrello + quantitaRichiesta;
    final stockDisponibile = elemento.quantitaStock;

    if (quantitaTotale > stockDisponibile) {
      return 'Stock insufficiente. Disponibili: $stockDisponibile, Richiesti: $quantitaTotale';
    }

    return null; // Disponibile
  }

  /// Aggiunge elemento con controllo stock
  /// Restituisce un messaggio di errore se fallisce, null se successo
  String? aggiungiElementoConControlloStock(
    ElementoCassa elemento, {
    int quantita = 1,
    TipoRigaCassa tipoMovimento = TipoRigaCassa.vendita,
  }) {
    if (richiedeTurnoAperto && !hasTurnoAperto) {
      return 'Apri un turno cassa prima di aggiungere prodotti.';
    }
    if (tipoMovimento == TipoRigaCassa.vendita) {
      final errore = verificaDisponibilitaStock(elemento, quantita);
      if (errore != null) {
        AppLogger().w('⚠️ $errore');
        return errore;
      }
    }

    aggiungiElemento(
      elemento,
      quantita: quantita,
      tipoMovimento: tipoMovimento,
    );
    return null;
  }

  /// Imposta le note per una riga
  void setNoteRiga(int index, String? note) {
    if (index >= 0 && index < _scontrinoCorrente.righe.length) {
      _scontrinoCorrente.righe[index].note = note;
    }
  }

  /// Imposta le note dello scontrino
  void setNote(String? note) {
    _scontrinoCorrente.note = note;
  }

  /// Imposta l'aliquota IVA
  void setAliquotaIva(double aliquota) {
    _scontrinoCorrente.aliquotaIva = aliquota.clamp(0, 100);
    _scontrinoCorrente.calcolaTotale();
  }
}
