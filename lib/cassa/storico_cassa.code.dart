// storico_cassa.code.dart
//
// Local POS history: receipts, closings and shifts.
//
// SharedPreferences/JSON persistence is only a fallback. MGWS is the source
// of truth for the receipt number, the lines and the returnable remainder, so
// the till keeps working without the local copy and loses nothing when the
// device is replaced.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../prodotti/class_prodotti.dart';
import 'class_scontrino.dart';

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
  final String? errore;

  const EsitoReso.ok() : ok = true, errore = null;
  const EsitoReso.ko(this.errore) : ok = false;
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'giornataId': giornataId,
    'turnoId': turnoId,
    'cassaNome': cassaNome,
    'sede': sede,
    'data': data.toIso8601String(),
    'operatoreId': operatoreId,
    'operatoreNome': operatoreNome,
    'operatoreCognome': operatoreCognome,
    'fondoIniziale': fondoIniziale,
    'incassiContanti': incassiContanti,
    'incassiCarta': incassiCarta,
    'incassiAltri': incassiAltri,
    'rimborsi': rimborsi,
    'entrateManuali': entrateManuali,
    'usciteManuali': usciteManuali,
    'contanteContato': contanteContato,
    'cartaContato': cartaContato,
    'causaleDifferenza': causaleDifferenza,
    'note': note,
    'rettifiche': rettifiche,
  };

  factory ChiusuraCassa.fromJson(Map<String, dynamic> json) => ChiusuraCassa(
    id: json['id']?.toString() ?? '',
    giornataId: json['giornataId']?.toString() ?? '',
    turnoId: json['turnoId']?.toString(),
    cassaNome: json['cassaNome']?.toString() ?? 'cassa',
    sede: json['sede']?.toString(),
    data: DateTime.tryParse(json['data']?.toString() ?? '') ?? DateTime.now(),
    operatoreId: (json['operatoreId'] as num?)?.toInt(),
    operatoreNome: json['operatoreNome']?.toString(),
    operatoreCognome: json['operatoreCognome']?.toString(),
    fondoIniziale: (json['fondoIniziale'] as num?)?.toDouble() ?? 0,
    incassiContanti: (json['incassiContanti'] as num?)?.toDouble() ?? 0,
    incassiCarta: (json['incassiCarta'] as num?)?.toDouble() ?? 0,
    incassiAltri: (json['incassiAltri'] as num?)?.toDouble() ?? 0,
    rimborsi: (json['rimborsi'] as num?)?.toDouble() ?? 0,
    entrateManuali: (json['entrateManuali'] as num?)?.toDouble() ?? 0,
    usciteManuali: (json['usciteManuali'] as num?)?.toDouble() ?? 0,
    contanteContato: (json['contanteContato'] as num?)?.toDouble() ?? 0,
    cartaContato: (json['cartaContato'] as num?)?.toDouble() ?? 0,
    causaleDifferenza: json['causaleDifferenza']?.toString(),
    note: json['note']?.toString(),
    rettifiche: ((json['rettifiche'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  ChiusuraCassa withRettifica(String nota) => ChiusuraCassa(
    id: id,
    giornataId: giornataId,
    turnoId: turnoId,
    cassaNome: cassaNome,
    sede: sede,
    data: data,
    operatoreId: operatoreId,
    operatoreNome: operatoreNome,
    operatoreCognome: operatoreCognome,
    fondoIniziale: fondoIniziale,
    incassiContanti: incassiContanti,
    incassiCarta: incassiCarta,
    incassiAltri: incassiAltri,
    rimborsi: rimborsi,
    entrateManuali: entrateManuali,
    usciteManuali: usciteManuali,
    contanteContato: contanteContato,
    cartaContato: cartaContato,
    causaleDifferenza: causaleDifferenza,
    note: note,
    rettifiche: [...rettifiche, nota],
  );
}

/// Local store for the POS history and the closings.
class StoricoCassaStore {
  static const String _scontriniKey = 'storico_cassa_scontrini_pos_v1';
  static const String _chiusureKey = 'storico_cassa_chiusure_v1';
  static const String _turniKey = 'storico_cassa_turni_v1';
  static const String _progressivoKey = 'storico_cassa_progressivo_v1';

  final List<Scontrino> _scontrini = [];
  final List<ChiusuraCassa> _chiusure = [];
  final List<TurnoCassa> _turni = [];
  int _progressivo = 0;
  bool _initialized = false;

  List<Scontrino> get scontrini => List.unmodifiable(_scontrini);
  List<ChiusuraCassa> get chiusure => List.unmodifiable(_chiusure);
  List<TurnoCassa> get turni => List.unmodifiable(_turni);

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _progressivo = prefs.getInt(_progressivoKey) ?? 0;
    final rawScontrini = prefs.getString(_scontriniKey);
    if (rawScontrini != null && rawScontrini.isNotEmpty) {
      try {
        final list = (jsonDecode(rawScontrini) as List).whereType<Map>();
        _scontrini
          ..clear()
          ..addAll(
            list.map((e) => Scontrino.fromJson(Map<String, dynamic>.from(e))),
          );
      } catch (e) {
        AppLogger().w('Storico cassa: scontrini locali non leggibili: $e');
      }
    }
    final rawChiusure = prefs.getString(_chiusureKey);
    if (rawChiusure != null && rawChiusure.isNotEmpty) {
      try {
        final list = (jsonDecode(rawChiusure) as List).whereType<Map>();
        _chiusure
          ..clear()
          ..addAll(
            list.map(
              (e) => ChiusuraCassa.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      } catch (e) {
        AppLogger().w('Storico cassa: chiusure locali non leggibili: $e');
      }
    }
    final rawTurni = prefs.getString(_turniKey);
    if (rawTurni != null && rawTurni.isNotEmpty) {
      try {
        final list = (jsonDecode(rawTurni) as List).whereType<Map>();
        _turni
          ..clear()
          ..addAll(
            list.map((e) => TurnoCassa.fromJson(Map<String, dynamic>.from(e))),
          );
      } catch (e) {
        AppLogger().w('Storico cassa: turni locali non leggibili: $e');
      }
    }
    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressivoKey, _progressivo);
    await prefs.setString(
      _scontriniKey,
      jsonEncode(_scontrini.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _chiusureKey,
      jsonEncode(_chiusure.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _turniKey,
      jsonEncode(_turni.map((e) => e.toJson()).toList()),
    );
  }

  TurnoCassa? turnoAperto({String? cassaNome, String? giornataId}) {
    final cassa = (cassaNome ?? '').trim();
    for (final turno in _turni) {
      if (!turno.isAperto) continue;
      if (giornataId != null && turno.giornataId != giornataId) continue;
      if (cassa.isNotEmpty && turno.cassaNome != cassa) continue;
      return turno;
    }
    return null;
  }

  Future<EsitoReso> apriTurno(TurnoCassa turno) async {
    await init();
    if (turnoAperto(cassaNome: turno.cassaNome) != null) {
      return const EsitoReso.ko(
        'Esiste gia un turno aperto per questa cassa. Chiudilo prima di aprirne un altro.',
      );
    }
    _turni.insert(0, turno);
    await _save();
    AppLogger().i(
      'Turno cassa aperto ${turno.id} (${turno.cassaNome}, fondo €${turno.fondoIniziale.toStringAsFixed(2)})',
    );
    return const EsitoReso.ok();
  }

  Future<EsitoReso> chiudiTurno({
    required String turnoId,
    required ChiusuraCassa chiusura,
  }) async {
    await init();
    final index = _turni.indexWhere((turno) => turno.id == turnoId);
    if (index < 0) return const EsitoReso.ko('Turno non trovato.');
    final turno = _turni[index];
    if (!turno.isAperto) {
      return const EsitoReso.ko('Turno gia chiuso: usare una rettifica.');
    }
    final esitoChiusura = await registraChiusura(chiusura);
    if (!esitoChiusura.ok) return esitoChiusura;
    _turni[index] = turno.chiudi(chiusura.data);
    await _save();
    return const EsitoReso.ok();
  }

  /// Receipts read from the server, falling back to the local store.
  ///
  /// The server is the source: search, filters and paging come from
  /// `GET /pos/receipts`. The local store is only used when the backend does
  /// not answer, because showing an empty history is worse than showing a
  /// device-local one.
/// Receipts read from the server, falling back to the local store.
///
/// Reads from `GET /pos/receipts`. The local store is only a fallback when the
/// backend does not answer, because an empty history is worse than a stale one.
Future<List<Scontrino>> receiptsFromServer({
  String? queryCliente,
  String? cassaNome,
  String? metodoPagamento,
  bool? soloResi,
  String? giornataId,
  int? limit,
}) async {
  try {
    final risposta = await PlatformManager.pos.listReceipts(
      query: queryCliente,
      registerName: cassaNome,
      paymentMethod: metodoPagamento,
      businessDayId: giornataId,
      limit: limit ?? 200,
    );
    if (risposta['success'] != true) return const [];
    final grezzi = risposta['receipts'];
    if (grezzi is! List) return const [];

    final risultato = <Scontrino>[];
    for (final grezzo in grezzi) {
      if (grezzo is! Map) continue;
      final scontrino = _receiptFromMap(Map<String, dynamic>.from(grezzo));
      if (soloResi == true && !scontrino.hasResi) continue;
      risultato.add(scontrino);
    }
    return risultato;
  } catch (errore) {
    AppLogger().w('Storico POS: elenco non letto dal server: $errore');
    return const [];
  }
}

/// Rebuilds a receipt from the server response.
  ///
  /// Lines are not part of the list: they load when the detail is opened, so
  /// the list stays small even with many sales.
/// Rebuilds a receipt from the server response. Lines are not part of the
/// list, they are loaded on demand when the detail is opened.
Scontrino _receiptFromMap(Map<String, dynamic> mappa) {
  return Scontrino(
    id: mappa['receipt_key']?.toString() ?? '',
    data: _dateFromGmt(mappa['issued_at']?.toString()),
    numeroProgressivo: _intFrom(mappa['sequential_number']),
    operatoreNome: _textOr(mappa['operator_name'], null),
    cassaNome: _textOr(mappa['register_name'], null),
    sede: _textOr(mappa['location'], null),
    giornataId: _textOr(mappa['business_day_id'], null),
    turnoId: _intFrom(mappa['shift_id'])?.toString(),
    wooOrderId: _intFrom(mappa['order_id']),
    mgwsOrderId: _intFrom(mappa['order_id']),
    metodoPagamento: _textOr(mappa['payment_method'], 'contanti')!,
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
    dataChiusura: _dateFromGmt(mappa['issued_at']?.toString()),
    tipoOperazione: _operationTypeFrom(mappa['operation_type']?.toString()),
  )
  ..rettifiche = _notesFromCorrections(mappa['corrections']);
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
/// Maps the server status onto the POS history labels.
dynamic _statusFrom(String? stato) {
  switch (stato) {
    case 'cancelled':
      return 'annullato';
    case 'refunded':
      return 'rimborsato';
    default:
      return 'pagato';
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

DateTime _dateFromGmt(String? valore) {
  if (valore == null || valore.isEmpty) return DateTime.now();
  return DateTime.tryParse(valore)?.toLocal() ?? DateTime.now();
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

/// Loads the document lines from the server.
///
/// Lo storico locale le teneva solo sul dispositivo: senza questa lettura il
/// dettaglio perderebbe le righe appena reinstallata l'app.
/// Loads the document lines from the server.
Future<Scontrino?> detailFromServer(String receiptKey) async {
  final chiave = receiptKey.trim();
  if (chiave.isEmpty) return null;

  try {
    final risposta = await PlatformManager.pos.getReceipt(chiave);
    if (risposta['success'] != true) return null;
    final grezzo = risposta['receipt'];
    if (grezzo is! Map) return null;

    final scontrino = _receiptFromMap(Map<String, dynamic>.from(grezzo));
    final righe = grezzo['lines'];
    if (righe is List) {
      for (final riga in righe) {
        if (riga is! Map) continue;
        scontrino.righe.add(_lineFromMap(Map<String, dynamic>.from(riga)));
      }
    }
    return scontrino;
  } catch (errore) {
    AppLogger().w('Storico POS: dettaglio non letto dal server: $errore');
    return null;
  }
}

RigaScontrino _lineFromMap(Map<String, dynamic> mappa) {
  final quantita = _intFrom(mappa['quantity']) ?? 0;
  final unitaio = _doubleFrom(mappa['unit_price']);
  return RigaScontrino(
    prodotto: ProdottoGlobal(
      id: _intFrom(mappa['product_id']),
      nome: mappa['name']?.toString() ?? '',
      barcodeInterno: mappa['barcode']?.toString() ?? '',
    ),
    variante: _intFrom(mappa['variation_id']) != null
        ? VarianteProductGlobal(
            id: _intFrom(mappa['variation_id']),
            codiceProdotto: mappa['sku']?.toString() ?? '',
            barcodeInterno: mappa['barcode']?.toString() ?? '',
          )
        : null,
    quantita: quantita,
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
    recordedPrice: unitaio,
  );
}

/// Righe vendita di uno scontrino con quantita gia resa e residuo.
///
/// Il residuo arriva dal server quando disponibile, perche' il server vede i
/// resi di tutti i dispositivi; senza risposta si ricade sullo store locale.
/// Sold lines with the already-returned quantity and the remainder.
Future<List<RigaRendibile>> returnableLinesFromServer(String receiptKey) async {
    final chiave = receiptKey.trim();
    if (chiave.isEmpty) return const [];

    try {
      final risposta = await PlatformManager.pos.getReceipt(chiave);
      if (risposta['success'] != true) return const [];
      final scontrino = risposta['receipt'];
      if (scontrino is! Map<String, dynamic>) return const [];

      final righe = scontrino['lines'];
      if (righe is! List) return const [];

      final residui = <String, int>{};
      final returnable = scontrino['returnable'];
      if (returnable is Map) {
        for (final entry in returnable.entries) {
          final valore = entry.value;
          if (entry.key is String && valore is num) {
            residui[entry.key as String] = valore.toInt();
          }
        }
      }

      final risultato = <RigaRendibile>[];
      for (final riga in righe) {
        if (riga is! Map) continue;
        if (riga['movement_type'] != 'sale') continue;
        final lineKey = riga['line_key'];
        final quantita = riga['quantity'];
        if (lineKey is! String || quantita is! num) continue;
        final nome = riga['name']?.toString() ?? '';
        final barcode = riga['barcode']?.toString() ?? '';
        final prezzo = riga['unit_price'];
        final residuo = residui[lineKey] ?? quantita.toInt();
        risultato.add(
          RigaRendibile(
            chiaveRiga: lineKey,
            nome: nome,
            barcodeInterno: barcode,
            prezzoUnitario: prezzo is num ? prezzo.toDouble() : 0,
            quantitaVenduta: quantita.toInt(),
            quantitaGiaResa: quantita.toInt() - residuo,
          ),
        );
      }
      return risultato;
    } catch (errore) {
      AppLogger().w('Storico POS: righe rendibili non lette dal server: $errore');
      return const [];
    }
  }

  /// Registra uno scontrino POS chiuso. Gli ordini Woo non entrano mai qui:
  /// resta il documento origine solo come riferimento `wooOrderId`.
  ///
  /// Il progressivo lo assegna MGWS durante il checkout: il contatore locale
  /// resta solo come fallback per quando il backend non ha risposto, perche'
  /// con due casse aperte un contatore locale duplicherebbe i numeri.
  /// The receipt number is allocated by MGWS during checkout. The local
  /// counter remains a fallback when the backend did not answer, because with
  /// two tills open a local counter would duplicate numbers.
  Future<Scontrino> registraScontrinoChiuso(
    Scontrino scontrino, {
    int? serverNumber,
  }) async {
    await init();
    final progressivo = serverNumber != null && serverNumber > 0
        ? serverNumber
        : _assignFallbackNumber();
    scontrino.numeroProgressivo = progressivo;
    _progressivo = progressivo;
    scontrino.canale = 'pos';
    scontrino.dataChiusura = DateTime.now();
    scontrino.giornataId ??= Scontrino.calcolaGiornataId(
      scontrino.data,
      scontrino.cassaNome,
    );
    if (scontrino.stato == 'aperto' || scontrino.stato == 'sospeso') {
      scontrino.stato = scontrino.totale < 0 ? 'rimborsato' : 'pagato';
    }
    _scontrini.insert(0, scontrino);
    await _save();
    AppLogger().i(
      'Storico POS #$progressivo registrato (${scontrino.righe.length} righe)',
    );
    return scontrino;
  }

  /// Counter used only when the server did not return a number.
  ///
  /// Non e' il percorso normale: MGWS assegna il progressivo nel checkout. Il
  /// fallback serve a non perdere la vendita se il numero non arriva, e
  /// riparte dal massimo gia' locale per non andare indietro nella sequenza.
  /// This is not the normal path: MGWS allocates the number during checkout.
  /// The fallback prevents losing a sale when the number does not arrive and
  /// resumes from the local maximum so the sequence never goes backwards.
  int _assignFallbackNumber() {
    var massimo = _progressivo;
    for (final scontrino in _scontrini) {
      final numero = scontrino.numeroProgressivo ?? 0;
      if (numero > massimo) massimo = numero;
    }
    return massimo + 1;
  }

  /// Filtra lo storico, leggendo dal server.
///
/// Il server e' la fonte e sa filtrare meglio di una scansione locale; lo
/// store interviene solo se il backend non risponde.
/// Filters the history, reading from the server. The store is only a fallback.
Future<List<Scontrino>> filter({
  DateTime? dal,
  DateTime? al,
  String? cassaNome,
  String? metodoPagamento,
  String? queryCliente,
  int? operatoreId,
  bool? soloResi,
  String? giornataId,
  int? limit,
}) async {
  final fromServer = await receiptsFromServer(
    queryCliente: queryCliente,
    cassaNome: cassaNome,
    metodoPagamento: metodoPagamento,
    soloResi: soloResi,
    giornataId: giornataId,
    limit: limit,
  );
  if (fromServer.isNotEmpty) return fromServer;
  return filterLocal(
    dal: dal,
    al: al,
    cassaNome: cassaNome,
    metodoPagamento: metodoPagamento,
    queryCliente: queryCliente,
    operatoreId: operatoreId,
    soloResi: soloResi,
  );
}

/// Filtra solo sullo store locale, senza interrogare il server.
/// Filters on the local store only, without asking the server.
List<Scontrino> filterLocal({
  DateTime? dal,
  DateTime? al,
  String? cassaNome,
  String? metodoPagamento,
  String? queryCliente,
  int? operatoreId,
  bool? soloResi,
}) {
  return _scontrini.where((s) {
      if (dal != null && s.data.isBefore(dal)) return false;
      if (al != null && s.data.isAfter(al)) return false;
      if (cassaNome != null && cassaNome.isNotEmpty) {
        if ((s.cassaNome ?? '') != cassaNome) return false;
      }
      if (metodoPagamento != null && metodoPagamento.isNotEmpty) {
        if (s.metodoPagamento != metodoPagamento) return false;
      }
      if (operatoreId != null && s.operatoreId != operatoreId) return false;
      if (soloResi == true && !s.hasResi) return false;
      if (queryCliente != null && queryCliente.trim().isNotEmpty) {
        final q = queryCliente.toLowerCase();
        final haystack =
            '${s.clienteNome ?? ''} ${s.clienteEmail ?? ''} '
            '${s.numeroProgressivo ?? ''} ${s.wooOrderId ?? ''} ${s.id}';
        if (!haystack.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Scontrino? cercaPerId(String id) {
    for (final s in _scontrini) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Cancels a document on the server.
///
/// The server never deletes the row: it changes the status and records the
/// note, so the accounting history stays reconstructable.
Future<EsitoReso> cancelReceipt({
  required String receiptId,
  required String reason,
}) async {
  await init();
  if (reason.trim().isEmpty) {
    return const EsitoReso.ko('Motivo annullamento obbligatorio.');
  }

  try {
    final response = await PlatformManager.pos.updateReceiptStatus(
      receiptKey: receiptId,
      status: 'cancelled',
      note: reason.trim(),
    );
    if (response['success'] == true) {
      await _alignLocalStatus(receiptId, 'annullato', reason.trim());
      return const EsitoReso.ok();
    }
    final message = response['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return EsitoReso.ko(message);
    }
  } catch (error) {
    AppLogger().w('Storico POS: annullamento non riuscito sul server: $error');
  }

  return _cancelLocalReceipt(receiptId: receiptId, reason: reason);
}

/// Aligns the local copy with the document cancelled server-side.
Future<void> _alignLocalStatus(
  String receiptId,
  String status,
  String note,
) async {
  final index = _scontrini.indexWhere((s) => s.id == receiptId);
  if (index < 0) return;
  _scontrini[index].stato = status;
  if (note.isNotEmpty) _scontrini[index].rettifiche.add(note);
  await _save();
}

/// Cancels on the local store only, without asking the server.
Future<EsitoReso> _cancelLocalReceipt({
  required String receiptId,
  required String reason,
}) async {
  final index = _scontrini.indexWhere((s) => s.id == receiptId);
    if (index < 0) return const EsitoReso.ko('Scontrino non trovato.');
    final receipt = _scontrini[index];
    if (receipt.stato == 'annullato') {
      return const EsitoReso.ko('Scontrino gia annullato.');
    }
    if (receipt.stato == 'aperto' || receipt.stato == 'sospeso') {
      return const EsitoReso.ko(
        'Solo scontrini chiusi possono essere annullati.',
      );
    }
    if (reason.trim().isEmpty) {
      return const EsitoReso.ko('Motivo annullo obbligatorio.');
    }
    receipt.stato = 'annullato';
    receipt.aggiungiRettifica('ANNULLO: ${reason.trim()}');
    await _save();
    return const EsitoReso.ok();
  }

  Future<EsitoReso> aggiungiRettificaScontrino({
    required String scontrinoId,
    required String nota,
  }) async {
    await init();
    final scontrino = cercaPerId(scontrinoId);
    if (scontrino == null) return const EsitoReso.ko('Scontrino non trovato.');
    if (nota.trim().isEmpty)
      return const EsitoReso.ko('Nota rettifica obbligatoria.');
    scontrino.aggiungiRettifica(nota);
    await _save();
    return const EsitoReso.ok();
  }

  /// Righe vendita di uno scontrino con quantita gia resa e residuo.
  List<RigaRendibile> righeRendibili(String scontrinoId) {
    final origine = cercaPerId(scontrinoId);
    if (origine == null) return const [];
    if (origine.stato == 'annullato') return const [];
    final rese = <String, int>{};
    for (final s in _scontrini) {
      if (s.stato == 'annullato') continue;
      for (final riga in s.righe) {
        if (riga.isReso &&
            riga.riferimentoScontrinoId == scontrinoId &&
            riga.riferimentoChiaveRiga != null) {
          rese[riga.riferimentoChiaveRiga!] =
              (rese[riga.riferimentoChiaveRiga!] ?? 0) + riga.quantita;
        }
      }
    }
    final out = <RigaRendibile>[];
    for (final riga in origine.righe) {
      if (riga.isReso) continue;
      out.add(
        RigaRendibile(
          chiaveRiga: riga.chiaveRiga,
          nome: riga.nomeCompleto,
          barcodeInterno: riga.barcodeInterno,
          prezzoUnitario: riga.prezzoUnitario,
          quantitaVenduta: riga.quantita,
          quantitaGiaResa: rese[riga.chiaveRiga] ?? 0,
        ),
      );
    }
    return out;
  }

  /// Controllo rigido: il reso esiste solo come riga collegata a una vendita
  /// reale, entro il residuo rendibile e con motivo obbligatorio.
  EsitoReso validaReso({
    required String scontrinoOrigineId,
    required String chiaveRiga,
    required int quantita,
    required String? motivo,
  }) {
    if (cercaPerId(scontrinoOrigineId) == null) {
      return const EsitoReso.ko('Scontrino di origine non trovato.');
    }
    if (cercaPerId(scontrinoOrigineId)!.stato == 'annullato') {
      return const EsitoReso.ko('Scontrino di origine annullato.');
    }
    if (quantita <= 0) {
      return const EsitoReso.ko('Quantita reso non valida.');
    }
    if (motivo == null || motivo.trim().isEmpty) {
      return const EsitoReso.ko('Motivo del reso obbligatorio.');
    }
    RigaRendibile? target;
    for (final r in righeRendibili(scontrinoOrigineId)) {
      if (r.chiaveRiga == chiaveRiga) target = r;
    }
    if (target == null) {
      return const EsitoReso.ko('Riga vendita non trovata nello scontrino.');
    }
    if (quantita > target.quantitaRendibile) {
      return EsitoReso.ko(
        'Disponibili per il reso: ${target.quantitaRendibile} '
        '(venduti ${target.quantitaVenduta}, gia resi ${target.quantitaGiaResa}).',
      );
    }
    return const EsitoReso.ok();
  }

  /// Totali di una giornata o di un turno: base della chiusura.
  ///
  /// Quando viene passato `turnoId` il filtro e solo per turno: un turno che
  /// attraversa la mezzanotte include tutti i suoi scontrini, anche se emessi
  /// in una giornata diversa da quella di apertura.
  Map<String, double> totaliGiornata(String giornataId, {String? turnoId}) {
    double contanti = 0;
    double carta = 0;
    double altri = 0;
    double rimborsi = 0;
    for (final s in _scontrini) {
      if (s.stato == 'annullato') continue;
      if (turnoId != null) {
        if (s.turnoId != turnoId) continue;
      } else {
        if (s.giornataId != giornataId) continue;
      }
      if (s.totale < 0) {
        rimborsi += s.totale.abs();
        continue;
      }
      switch (s.metodoPagamento) {
        case 'contanti':
          contanti += s.totale;
          break;
        case 'carta':
        case 'bancomat':
          carta += s.totale;
          break;
        default:
          altri += s.totale;
      }
    }
    return {
      'contanti': contanti,
      'carta': carta,
      'altri': altri,
      'rimborsi': rimborsi,
    };
  }

  bool hasChiusura(String giornataId, {String? turnoId}) {
    if (turnoId != null) return _chiusure.any((c) => c.turnoId == turnoId);
    return _chiusure.any((c) => c.giornataId == giornataId);
  }

  /// Registra la chiusura. Causale obbligatoria in presenza di differenze.
  /// La chiusura non si modifica: solo note di rettifica append-only.
  Future<EsitoReso> registraChiusura(ChiusuraCassa chiusura) async {
    await init();
    if (hasChiusura(chiusura.giornataId, turnoId: chiusura.turnoId)) {
      return const EsitoReso.ko('Turno gia chiuso: usare una rettifica.');
    }
    if (chiusura.hasDifferenze &&
        (chiusura.causaleDifferenza ?? '').trim().isEmpty) {
      return const EsitoReso.ko(
        'Causale differenza obbligatoria quando contato e atteso non coincidono.',
      );
    }
    _chiusure.insert(0, chiusura);
    await _save();
    return const EsitoReso.ok();
  }

  Future<void> aggiungiRettifica(String chiusuraId, String nota) async {
    await init();
    final index = _chiusure.indexWhere((c) => c.id == chiusuraId);
    if (index < 0) return;
    _chiusure[index] = _chiusure[index].withRettifica(
      '${DateTime.now().toIso8601String()} - $nota',
    );
    await _save();
  }

  ChiusuraCassa? cercaChiusura(String giornataId) {
    for (final c in _chiusure) {
      if (c.giornataId == giornataId) return c;
    }
    return null;
  }

  ChiusuraCassa? cercaChiusuraTurno(String turnoId) {
    for (final c in _chiusure) {
      if (c.turnoId == turnoId) return c;
    }
    return null;
  }
}
