// checkout_history.code.dart
//
// POS history read from MGWS: receipts, lines, returns, shifts and closings.
//
// The device keeps no copy. The server allocates the receipt number, stores
// the lines and computes the returnable remainder, so replacing or
// reinstalling the device loses nothing.

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../products/class_products.dart';
import 'checkout_failure.dart';
import 'checkout_metrics.dart';
import 'class_receipt.dart';

/// Istante GMT del server (`Y-m-d H:i:s`) convertito nell'ora locale.
///
/// Il server non mette il fuso: letto cosi' com'e' Dart lo tratterebbe come
/// ora locale e lo storico slitterebbe di un'ora o due.
/// Server GMT timestamp converted to local time. Without the explicit UTC
/// marker Dart would read it as local time.
DateTime parseServerGmt(String? valore) {
  final testo = (valore ?? '').trim();
  if (testo.isEmpty) return DateTime.now();
  var iso = testo.replaceFirst(' ', 'T');
  final haFuso = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso);
  if (!haFuso) iso = '${iso}Z';
  return DateTime.tryParse(iso)?.toLocal() ?? DateTime.now();
}

/// Sold line with the quantity still returnable.
class RigaRendibile {
  final String chiaveRiga;
  final String nome;
  final String barcodeInterno;
  final double prezzoUnitario;
  final int quantitaVenduta;
  final int quantitaGiaResa;

  const RigaRendibile({
    required this.chiaveRiga,
    required this.nome,
    required this.barcodeInterno,
    required this.prezzoUnitario,
    required this.quantitaVenduta,
    required this.quantitaGiaResa,
  });

  int get quantitaRendibile => quantitaVenduta - quantitaGiaResa;
  bool get isEsaurita => quantitaRendibile <= 0;
}

/// Outcome of a strict return check.
class EsitoReso {
  final bool ok;
  final CassaFailure? errore;

  const EsitoReso.ok() : ok = true, errore = null;
  const EsitoReso.ko(CassaFailure this.errore) : ok = false;
}

/// Daily closing for a register. Immutable once recorded: corrections go
/// through a new rettifica note, never by editing the totals.
class ChiusuraCassa {
  final String id;
  final String giornataId;
  final String? turnoId;
  final String cassaNome;
  final String? sede;
  final DateTime data;
  final int? operatoreId;
  final String? operatoreNome;
  final String? operatoreCognome;
  final double fondoIniziale;
  final double incassiContanti;
  final double incassiCarta;
  final double incassiAltri;
  final double rimborsi;
  final double entrateManuali;
  final double usciteManuali;
  final double contanteContato;
  final double cartaContato;
  final String? causaleDifferenza;
  final String? note;
  final List<String> rettifiche;

  const ChiusuraCassa({
    required this.id,
    required this.giornataId,
    this.turnoId,
    required this.cassaNome,
    this.sede,
    required this.data,
    this.operatoreId,
    this.operatoreNome,
    this.operatoreCognome,
    this.fondoIniziale = 0,
    this.incassiContanti = 0,
    this.incassiCarta = 0,
    this.incassiAltri = 0,
    this.rimborsi = 0,
    this.entrateManuali = 0,
    this.usciteManuali = 0,
    this.contanteContato = 0,
    this.cartaContato = 0,
    this.causaleDifferenza,
    this.note,
    this.rettifiche = const [],
  });

  double get contanteAtteso =>
      fondoIniziale +
      incassiContanti +
      entrateManuali -
      rimborsi -
      usciteManuali;

  double get differenzaContanti => contanteContato - contanteAtteso;

  double get cartaAttesa => incassiCarta;

  double get differenzaCarta => cartaContato - cartaAttesa;

  bool get hasDifferenze =>
      differenzaContanti.abs() > 0.009 || differenzaCarta.abs() > 0.009;

  /// Chiusura come la restituisce `GET /pos/closings`.
  /// Closing as returned by `GET /pos/closings`.
  factory ChiusuraCassa.fromServer(Map<String, dynamic> mappa) {
    double numero(Object? valore) =>
        valore is num ? valore.toDouble() : double.tryParse('$valore') ?? 0;
    String? testo(Object? valore) {
      final t = valore?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final rettifiche = <String>[];
    final correzioni = mappa['corrections'];
    if (correzioni is List) {
      for (final voce in correzioni) {
        if (voce is Map && voce['note'] != null) {
          rettifiche.add('${voce['at'] ?? ''} - ${voce['note']}'.trim());
        }
      }
    }
    return ChiusuraCassa(
      id: mappa['closing_key']?.toString() ?? '',
      giornataId: mappa['business_day_id']?.toString() ?? '',
      turnoId: testo(mappa['shift_key']),
      cassaNome: testo(mappa['register_name']) ?? 'cassa',
      sede: testo(mappa['location']),
      data: parseServerGmt(mappa['closed_at']?.toString()),
      operatoreId: (mappa['operator_id'] as num?)?.toInt(),
      operatoreNome: testo(mappa['operator_name']),
      fondoIniziale: numero(mappa['opening_float']),
      incassiContanti: numero(mappa['cash_collected']),
      incassiCarta: numero(mappa['card_collected']),
      incassiAltri: numero(mappa['other_collected']),
      rimborsi: numero(mappa['refunds']),
      entrateManuali: numero(mappa['manual_in']),
      usciteManuali: numero(mappa['manual_out']),
      contanteContato: numero(mappa['cash_counted']),
      cartaContato: numero(mappa['card_counted']),
      causaleDifferenza: testo(mappa['difference_reason']),
      note: testo(mappa['note']),
      rettifiche: rettifiche,
    );
  }
}

/// Storico cassa letto dal server MGWS.
///
/// Non salva nulla sul dispositivo: l'unico stato in memoria e' il turno
/// aperto della cassa, riletto dal server a ogni apertura della schermata.
/// POS history read from MGWS. Nothing is stored on the device: the only
/// in-memory state is the open shift, reloaded from the server.
class StoricoCassaServer {
  TurnoCassa? _turnoAperto;
  ChiusuraCassa? _ultimaChiusura;

  TurnoCassa? get turnoAperto => _turnoAperto;

  /// Ultima chiusura registrata da questa schermata, per il riepilogo.
  ChiusuraCassa? get ultimaChiusura => _ultimaChiusura;

  /// Rilegge dal server il turno aperto della cassa.
  ///
  /// Se il server non risponde il turno gia' noto resta: una rete lenta non
  /// deve far sembrare chiusa una cassa aperta.
  /// Reloads the open shift of the register. When the server does not answer
  /// the known shift stays.
  Future<TurnoCassa?> aggiornaTurno(String cassaNome) async {
    try {
      final risposta = await PlatformManager.pos.listShifts(
        status: 'open',
        cassaName: cassaNome,
      );
      if (risposta['success'] != true) return _turnoAperto;
      final turni = risposta['shifts'];
      _turnoAperto = null;
      if (turni is List) {
        for (final turno in turni) {
          if (turno is! Map) continue;
          _turnoAperto = _shiftFromMap(Map<String, dynamic>.from(turno));
          break;
        }
      }
    } catch (errore) {
      AppLogger().w('Storico POS: turno aperto non letto dal server: $errore');
    }
    return _turnoAperto;
  }

  /// Turno aperto confermato dal server.
  /// Open shift confirmed by the server.
  void registraTurnoAperto(TurnoCassa turno) {
    _turnoAperto = turno;
    AppLogger().i(
      'Turno cassa aperto ${turno.id} (${turno.cassaNome}, fondo €${turno.fondoIniziale.toStringAsFixed(2)})',
    );
  }

  TurnoCassa _shiftFromMap(Map<String, dynamic> mappa) {
    return TurnoCassa(
      id: mappa['shift_key']?.toString() ?? '',
      giornataId: mappa['giornata_id']?.toString() ?? '',
      cassaNome: _textOr(mappa['cassa_name'], 'cassa')!,
      sede: _textOr(mappa['sede'], null),
      operatoreId: _intFrom(mappa['operator_id']),
      operatoreNome: _textOr(mappa['operator_name'], null),
      dataApertura: parseServerGmt(mappa['opened_at_gmt']?.toString()),
      fondoIniziale: _doubleFrom(mappa['fondo_iniziale']),
      stato: mappa['status'] == 'closed'
          ? StatoTurnoCassa.chiuso
          : StatoTurnoCassa.aperto,
    );
  }

  /// Registra la chiusura del turno appena chiuso sul server.
  ///
  /// La chiusura e' un dato contabile: finisce in `mg_pos_closings` con una
  /// chiave legata al turno, cosi' un doppio invio non ne crea due.
  /// Records the closing of the shift just closed server-side. The key is
  /// tied to the shift, so a double submit cannot create two closings.
  Future<EsitoReso> registraChiusura(
    ChiusuraCassa chiusura, {
    int? serverShiftId,
  }) async {
    if (chiusura.hasDifferenze &&
        (chiusura.causaleDifferenza ?? '').trim().isEmpty) {
      return const EsitoReso.ko(
        CassaFailure(CassaFailureCode.differenceReasonRequired),
      );
    }
    _turnoAperto = null;
    try {
      final risposta = await PlatformManager.pos.createClosing(
        <String, dynamic>{
          'closing_key': chiusura.id,
          'business_day_id': chiusura.giornataId,
          'register_name': chiusura.cassaNome,
          'location': chiusura.sede ?? '',
          'shift_id': serverShiftId ?? 0,
          'operator_id': chiusura.operatoreId ?? 0,
          'operator_name': [
            chiusura.operatoreNome ?? '',
            chiusura.operatoreCognome ?? '',
          ].join(' ').trim(),
          'opening_float': chiusura.fondoIniziale,
          'cash_collected': chiusura.incassiContanti,
          'card_collected': chiusura.incassiCarta,
          'other_collected': chiusura.incassiAltri,
          'refunds': chiusura.rimborsi,
          'manual_in': chiusura.entrateManuali,
          'manual_out': chiusura.usciteManuali,
          'cash_counted': chiusura.contanteContato,
          'card_counted': chiusura.cartaContato,
          if ((chiusura.causaleDifferenza ?? '').isNotEmpty)
            'difference_reason': chiusura.causaleDifferenza,
          if ((chiusura.note ?? '').isNotEmpty) 'note': chiusura.note,
        },
      );
      if (risposta['success'] == true) {
        _ultimaChiusura = chiusura;
        return const EsitoReso.ok();
      }
      final messaggio = risposta['message']?.toString();
      if (messaggio != null && messaggio.isNotEmpty) {
        return EsitoReso.ko(CassaFailure.server(messaggio));
      }
    } catch (errore) {
      AppLogger().w('Storico POS: chiusura non registrata sul server: $errore');
    }
    return const EsitoReso.ko(
      CassaFailure(CassaFailureCode.invalidServerResponse),
    );
  }

  /// Chiusura gia' registrata per un turno, se esiste.
  /// Closing already recorded for a shift, if any.
  Future<ChiusuraCassa?> cercaChiusuraTurno(
    String turnoId, {
    String? cassaNome,
  }) async {
    try {
      final risposta = await PlatformManager.pos.listClosings(
        registerName: cassaNome,
      );
      final chiusure = risposta['closings'];
      if (risposta['success'] != true || chiusure is! List) return null;
      for (final grezza in chiusure) {
        if (grezza is! Map) continue;
        final chiusura = ChiusuraCassa.fromServer(
          Map<String, dynamic>.from(grezza),
        );
        if (chiusura.turnoId == turnoId) return chiusura;
      }
    } catch (errore) {
      AppLogger().w('Storico POS: chiusure non lette dal server: $errore');
    }
    return null;
  }

  /// Appende una rettifica a una chiusura: i totali non cambiano.
  /// Appends a correction to a closing; the totals never change.
  Future<EsitoReso> aggiungiRettifica(String chiusuraId, String nota) async {
    if (nota.trim().isEmpty) {
      return const EsitoReso.ko(
        CassaFailure(CassaFailureCode.adjustmentNoteRequired),
      );
    }
    try {
      final risposta = await PlatformManager.pos.addClosingCorrection(
        closingKey: chiusuraId,
        note: nota.trim(),
      );
      if (risposta['success'] == true) return const EsitoReso.ok();
      final messaggio = risposta['message']?.toString();
      if (messaggio != null && messaggio.isNotEmpty) {
        return EsitoReso.ko(CassaFailure.server(messaggio));
      }
    } catch (errore) {
      AppLogger().w('Storico POS: rettifica chiusura non riuscita: $errore');
    }
    return const EsitoReso.ko(
      CassaFailure(CassaFailureCode.invalidServerResponse),
    );
  }

  /// Scontrini letti da `GET /pos/receipts`, con ricerca e filtri del server.
  ///
  /// Le righe non fanno parte dell'elenco: arrivano con il dettaglio, cosi'
  /// l'elenco resta leggero anche con molte vendite.
  /// Receipts from `GET /pos/receipts`. Lines are loaded with the detail.
  Future<List<Scontrino>> filter({
    String? queryCliente,
    String? cassaNome,
    String? metodoPagamento,
    bool? soloResi,
    String? giornataId,
    String? turnoId,
    int? limit,
  }) async {
    try {
      final risposta = await PlatformManager.pos.listReceipts(
        query: queryCliente,
        registerName: cassaNome,
        paymentMethod: metodoPagamento,
        businessDayId: giornataId,
        shiftId: turnoId,
        limit: limit ?? 200,
      );
      if (risposta['success'] != true) return const [];
      final grezzi = risposta['receipts'];
      if (grezzi is! List) return const [];

      final risultato = <Scontrino>[];
      for (final grezzo in grezzi) {
        if (grezzo is! Map) continue;
        final scontrino = _receiptFromMap(Map<String, dynamic>.from(grezzo));
        if (soloResi == true &&
            scontrino.tipoOperazione == TipoOperazioneCassa.vendita) {
          continue;
        }
        risultato.add(scontrino);
      }
      return risultato;
    } catch (errore) {
      AppLogger().w('Storico POS: elenco non letto dal server: $errore');
      return const [];
    }
  }

  /// Rebuilds a receipt from the server response.
  Scontrino _receiptFromMap(Map<String, dynamic> mappa) {
    final emesso = parseServerGmt(mappa['issued_at']?.toString());
    final turno = _textOr(mappa['shift_key'], null);
    return Scontrino(
      id: mappa['receipt_key']?.toString() ?? '',
      data: emesso,
      numeroProgressivo: _intFrom(mappa['sequential_number']),
      operatoreNome: _textOr(mappa['operator_name'], null),
      cassaNome: _textOr(mappa['register_name'], null),
      sede: _textOr(mappa['location'], null),
      giornataId: _textOr(mappa['business_day_id'], null),
      turnoId: turno,
      wooOrderId: _intFrom(mappa['order_id']),
      mgwsOrderId: _intFrom(mappa['order_id']),
      metodoPagamento: _textOr(mappa['payment_method'], 'contanti')!,
      clienteId: (_intFrom(mappa['customer_id']) ?? 0) > 0
          ? '${mappa['customer_id']}'
          : null,
      clienteNome: _textOr(mappa['customer_name'], null),
      couponCode: _textOr(mappa['coupon_code'], null),
      note: _textOr(mappa['note'], null),
      stato: _statusFrom(mappa['status']?.toString()),
      totale: _doubleFrom(mappa['total']),
      subtotale: _doubleFrom(mappa['subtotal']),
      sconto: _doubleFrom(mappa['discount_total']),
      couponSconto: _doubleFrom(mappa['coupon_discount']),
      iva: _doubleFrom(mappa['vat_total']),
      aliquotaIva: _doubleFrom(mappa['tax_rate'], fallback: 22),
      canale: 'pos',
      dataChiusura: emesso,
      tipoOperazione: _operationTypeFrom(mappa['operation_type']?.toString()),
    )..rettifiche = _notesFromCorrections(mappa['corrections']);
  }

  List<String> _notesFromCorrections(Object? correzioni) {
    if (correzioni is! List) return const [];
    final note = <String>[];
    for (final voce in correzioni) {
      if (voce is Map && voce['note'] != null) {
        note.add(voce['note'].toString());
      }
    }
    return note;
  }

  /// Document status, mapped onto the POS history labels.
  ///
  /// The server speaks `paid`/`cancelled`/`refunded` while the history keeps
  /// Italian labels: the conversion lives here, not in the widgets.
  String _statusFrom(String? stato) {
    switch (stato) {
      case 'cancelled':
        return 'annullato';
      case 'refunded':
        return 'rimborsato';
      default:
        return 'pagato';
    }
  }

  String _statusToServer(String stato) {
    switch (stato) {
      case 'annullato':
        return 'cancelled';
      case 'rimborsato':
        return 'refunded';
      default:
        return 'paid';
    }
  }

  TipoOperazioneCassa _operationTypeFrom(String? tipo) {
    switch (tipo) {
      case 'return':
        return TipoOperazioneCassa.reso;
      case 'exchange':
        return TipoOperazioneCassa.cambio;
      default:
        return TipoOperazioneCassa.vendita;
    }
  }

  int? _intFrom(Object? valore) {
    if (valore is num) return valore.toInt();
    if (valore is String) return int.tryParse(valore);
    return null;
  }

  double _doubleFrom(Object? valore, {double fallback = 0}) {
    if (valore is num) return valore.toDouble();
    if (valore is String) return double.tryParse(valore) ?? fallback;
    return fallback;
  }

  String? _textOr(Object? valore, String? fallback) {
    final testo = valore?.toString().trim();
    if (testo == null || testo.isEmpty) return fallback;
    return testo;
  }

  /// Documento completo letto dal server, righe comprese.
  ///
  /// E' anche la ricerca per id: lo storico non esiste altrove.
  /// Full document read from the server, lines included. It is also the
  /// lookup by id: the history exists nowhere else.
  Future<Scontrino?> cercaPerId(String receiptKey) async {
    final dettaglio = await _detail(receiptKey);
    return dettaglio?.scontrino;
  }

  Future<_DettaglioScontrino?> _detail(String receiptKey) async {
    final chiave = receiptKey.trim();
    if (chiave.isEmpty) return null;

    try {
      final risposta = await PlatformManager.pos.getReceipt(chiave);
      if (risposta['success'] != true) return null;
      final grezzo = risposta['receipt'];
      if (grezzo is! Map) return null;

      final scontrino = _receiptFromMap(Map<String, dynamic>.from(grezzo));
      final rendibili = <RigaRendibile>[];
      final righe = grezzo['lines'];
      if (righe is List) {
        for (final riga in righe) {
          if (riga is! Map) continue;
          final mappa = Map<String, dynamic>.from(riga);
          final linea = _lineFromMap(mappa);
          scontrino.righe.add(linea);
          if (linea.isReso) continue;
          final venduta = _intFrom(mappa['quantity']) ?? 0;
          final resa = _intFrom(mappa['returned_quantity']) ?? 0;
          rendibili.add(
            RigaRendibile(
              chiaveRiga: linea.chiaveRiga,
              nome: linea.nomeCompleto,
              barcodeInterno: mappa['barcode']?.toString() ?? '',
              prezzoUnitario: linea.prezzoUnitario,
              quantitaVenduta: venduta,
              // Un documento annullato non ha piu' nulla da rendere.
              quantitaGiaResa: scontrino.stato == 'annullato' ? venduta : resa,
            ),
          );
        }
      }
      return _DettaglioScontrino(scontrino, rendibili);
    } catch (errore) {
      AppLogger().w('Storico POS: dettaglio non letto dal server: $errore');
      return null;
    }
  }

  RigaScontrino _lineFromMap(Map<String, dynamic> mappa) {
    final variazione = _intFrom(mappa['variation_id']) ?? 0;
    return RigaScontrino(
      prodotto: ProdottoGlobal(
        id: _intFrom(mappa['product_id']),
        nome: mappa['name']?.toString() ?? '',
        barcodeInterno: mappa['barcode']?.toString() ?? '',
      ),
      variante: variazione > 0
          ? VarianteProductGlobal(
              id: variazione,
              codiceProdotto: mappa['sku']?.toString() ?? '',
              barcodeInterno: mappa['barcode']?.toString() ?? '',
            )
          : null,
      quantita: _intFrom(mappa['quantity'])?.abs() ?? 0,
      subtotale: _doubleFrom(mappa['subtotal']),
      scontoRiga: _doubleFrom(mappa['discount_total']),
      scontoPercentuale: _doubleFrom(mappa['discount_percent']),
      tipoMovimento: mappa['movement_type'] == 'return'
          ? TipoRigaCassa.reso
          : TipoRigaCassa.vendita,
      riferimentoScontrinoId: _textOr(mappa['source_sale_id'], null),
      riferimentoChiaveRiga: _textOr(mappa['source_line_key'], null),
      motivoReso: _textOr(mappa['return_reason'], null),
      esitoMerce: _textOr(mappa['return_outcome'], null),
      recordedPrice: _doubleFrom(mappa['unit_price']),
      recordedLineKey: _textOr(mappa['line_key'], null),
    );
  }

  /// Righe vendute con quantita' gia' resa e residuo, calcolati dal server.
  ///
  /// Il server vede i resi di tutte le casse, quindi il residuo non dipende
  /// dal dispositivo che apre il documento.
  /// Sold lines with returned and remaining quantities, computed server-side.
  Future<List<RigaRendibile>> righeRendibili(String receiptKey) async {
    final dettaglio = await _detail(receiptKey);
    return dettaglio?.rendibili ?? const [];
  }

  /// Controllo rigido: il reso esiste solo come riga collegata a una vendita
  /// reale, entro il residuo rendibile calcolato dal server e con motivo
  /// obbligatorio. Il server ripete lo stesso controllo nel checkout.
  /// Strict check against the server remainder; the checkout repeats it.
  Future<EsitoReso> validaReso({
    required String scontrinoOrigineId,
    required String chiaveRiga,
    required int quantita,
    required String? motivo,
  }) async {
    final verifica = await verificaReso(
      scontrinoOrigineId: scontrinoOrigineId,
      chiaveRiga: chiaveRiga,
      quantita: quantita,
      motivo: motivo,
    );
    return verifica.esito;
  }

  /// Come [validaReso], ma restituisce anche il documento di origine e la
  /// riga venduta, letti con la stessa richiesta.
  /// Like [validaReso], also returning the origin document and the sold line
  /// read with the same request.
  Future<({EsitoReso esito, Scontrino? origine, RigaScontrino? venduta})>
  verificaReso({
    required String scontrinoOrigineId,
    required String chiaveRiga,
    required int quantita,
    required String? motivo,
  }) async {
    ({EsitoReso esito, Scontrino? origine, RigaScontrino? venduta}) ko(
      CassaFailure errore,
    ) => (esito: EsitoReso.ko(errore), origine: null, venduta: null);

    final dettaglio = await _detail(scontrinoOrigineId);
    if (dettaglio == null) {
      return ko(const CassaFailure(CassaFailureCode.originReceiptNotFound));
    }
    final origine = dettaglio.scontrino;
    if (origine.stato == 'annullato') {
      return ko(const CassaFailure(CassaFailureCode.originReceiptCancelled));
    }
    if (motivo == null || motivo.trim().isEmpty) {
      return ko(const CassaFailure(CassaFailureCode.returnReasonRequired));
    }
    RigaRendibile? target;
    for (final r in dettaglio.rendibili) {
      if (r.chiaveRiga == chiaveRiga) target = r;
    }
    RigaScontrino? venduta;
    for (final riga in origine.righe) {
      if (!riga.isReso && riga.chiaveRiga == chiaveRiga) venduta = riga;
    }
    if (target == null || venduta == null) {
      return ko(const CassaFailure(CassaFailureCode.saleLineNotFound));
    }
    if (target.isEsaurita) {
      return ko(const CassaFailure(CassaFailureCode.lineFullyReturned));
    }
    if (quantita <= 0) {
      return ko(const CassaFailure(CassaFailureCode.invalidReturnQuantity));
    }
    if (quantita > target.quantitaRendibile) {
      return ko(
        CassaFailure(
          CassaFailureCode.returnExceedsRemaining,
          disponibili: target.quantitaRendibile,
          venduti: target.quantitaVenduta,
          giaResi: target.quantitaGiaResa,
        ),
      );
    }
    return (esito: const EsitoReso.ok(), origine: origine, venduta: venduta);
  }

  /// Annulla un documento sul server.
  ///
  /// Il server non cancella mai la riga: cambia lo stato e registra la nota,
  /// cosi' lo storico contabile resta ricostruibile.
  /// Cancels a document on the server; the row is never deleted.
  Future<EsitoReso> cancelReceipt({
    required String receiptId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return const EsitoReso.ko(
        CassaFailure(CassaFailureCode.cancelReasonRequired),
      );
    }
    return _updateStatus(receiptId, 'cancelled', 'ANNULLO: ${reason.trim()}');
  }

  /// Appende una rettifica allo scontrino senza cambiarne lo stato.
  /// Appends a correction to the receipt without changing its status.
  Future<EsitoReso> aggiungiRettificaScontrino({
    required Scontrino scontrino,
    required String nota,
  }) async {
    if (nota.trim().isEmpty) {
      return const EsitoReso.ko(
        CassaFailure(CassaFailureCode.adjustmentNoteRequired),
      );
    }
    return _updateStatus(
      scontrino.id,
      _statusToServer(scontrino.stato),
      nota.trim(),
    );
  }

  Future<EsitoReso> _updateStatus(
    String receiptKey,
    String status,
    String note,
  ) async {
    try {
      final risposta = await PlatformManager.pos.updateReceiptStatus(
        receiptKey: receiptKey,
        status: status,
        note: note,
      );
      if (risposta['success'] == true) return const EsitoReso.ok();
      final messaggio = risposta['message']?.toString();
      if (messaggio != null && messaggio.isNotEmpty) {
        return EsitoReso.ko(CassaFailure.server(messaggio));
      }
    } catch (errore) {
      AppLogger().w(
        'Storico POS: aggiornamento documento non riuscito: $errore',
      );
    }
    return const EsitoReso.ko(
      CassaFailure(CassaFailureCode.invalidServerResponse),
    );
  }

  /// Sintesi di `GET /pos/receipts` per un turno o una giornata.
  ///
  /// I totali li calcola il server, documenti annullati esclusi. Con
  /// `turnoId` il filtro e' solo per turno: un turno che attraversa la
  /// mezzanotte include tutti i suoi scontrini.
  /// Server summary for a shift or a business day, cancelled documents
  /// excluded.
  Future<Map<String, double>> totaliGiornata(
    String giornataId, {
    String? turnoId,
  }) async {
    final totali = <String, double>{
      'contanti': 0,
      'carta': 0,
      'altri': 0,
      'rimborsi': 0,
    };
    final sintesi = await _summary(giornataId: giornataId, turnoId: turnoId);
    final metodi = sintesi?['by_payment_method'];
    if (metodi is! List) return totali;
    for (final voce in metodi) {
      if (voce is! Map) continue;
      final incassato = _doubleFrom(voce['collected']);
      totali['rimborsi'] = totali['rimborsi']! + _doubleFrom(voce['refunded']);
      final chiave = switch (voce['payment_method']?.toString()) {
        'contanti' => 'contanti',
        'carta' || 'bancomat' => 'carta',
        _ => 'altri',
      };
      totali[chiave] = totali[chiave]! + incassato;
    }
    return totali;
  }

  /// Contatori di cassa per un turno o una giornata, dai documenti del server.
  /// Till counters for a shift or a business day, from the server documents.
  Future<CassaMetricheSnapshot> metriche({
    String? giornataId,
    String? turnoId,
  }) async {
    try {
      final risposta = await PlatformManager.pos.listReceipts(
        businessDayId: turnoId == null ? giornataId : null,
        shiftId: turnoId,
        limit: 500,
      );
      if (risposta['success'] != true) return const CassaMetricheSnapshot();
      final grezzi = risposta['receipts'];
      if (grezzi is! List) return const CassaMetricheSnapshot();
      return CassaMetricheSnapshot.fromServerReceipts(
        grezzi.whereType<Map>().map(Map<String, dynamic>.from),
      );
    } catch (errore) {
      AppLogger().w('Storico POS: contatori non letti dal server: $errore');
      return const CassaMetricheSnapshot();
    }
  }

  Future<Map<String, dynamic>?> _summary({
    String? giornataId,
    String? turnoId,
  }) async {
    try {
      final risposta = await PlatformManager.pos.listReceipts(
        businessDayId: turnoId == null ? giornataId : null,
        shiftId: turnoId,
        limit: 1,
      );
      final sintesi = risposta['summary'];
      if (risposta['success'] != true || sintesi is! Map) return null;
      return Map<String, dynamic>.from(sintesi);
    } catch (errore) {
      AppLogger().w('Storico POS: sintesi non letta dal server: $errore');
      return null;
    }
  }
}

class _DettaglioScontrino {
  final Scontrino scontrino;
  final List<RigaRendibile> rendibili;

  const _DettaglioScontrino(this.scontrino, this.rendibili);
}
