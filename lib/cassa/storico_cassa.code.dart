// storico_cassa.code.dart
//
// Storico scontrini POS separato dagli ordini WooCommerce, resi vincolati
// alla riga venduta, turni cassa espliciti e chiusure. Persistenza locale in
// SharedPreferences/JSON in attesa dell'enforcement server-side MGWS.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import 'class_scontrino.dart';

/// Riga vendita con residuo rendibile.
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

/// Esito del controllo rigido sul reso.
class EsitoReso {
  final bool ok;
  final String? errore;

  const EsitoReso.ok() : ok = true, errore = null;
  const EsitoReso.ko(this.errore) : ok = false;
}

/// Chiusura di giornata per una cassa. Immodificabile dopo la registrazione:
/// eventuali correzioni passano da una nuova nota di rettifica, mai da edit.
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

/// Store locale dello storico POS + chiusure.
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

  /// Righe vendita di uno scontrino con quantita gia resa e residuo.
///
/// Il residuo arriva dal server quando disponibile, perche' il server vede i
/// resi di tutti i dispositivi; senza risposta si ricade sullo store locale.
/// Sold lines with the already-returned quantity and the remainder.
Future<List<RigaRendibile>> righeRendibiliDaServer(String receiptKey) async {
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
    int? progressivoServer,
  }) async {
    await init();
    final progressivo = progressivoServer != null && progressivoServer > 0
        ? progressivoServer
        : _assegnaProgressivoFallback();
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
  int _assegnaProgressivoFallback() {
    var massimo = _progressivo;
    for (final scontrino in _scontrini) {
      final numero = scontrino.numeroProgressivo ?? 0;
      if (numero > massimo) massimo = numero;
    }
    return massimo + 1;
  }

  List<Scontrino> filtra({
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

  Future<EsitoReso> annullaScontrino({
    required String scontrinoId,
    required String motivo,
  }) async {
    await init();
    final index = _scontrini.indexWhere((s) => s.id == scontrinoId);
    if (index < 0) return const EsitoReso.ko('Scontrino non trovato.');
    final scontrino = _scontrini[index];
    if (scontrino.stato == 'annullato') {
      return const EsitoReso.ko('Scontrino gia annullato.');
    }
    if (scontrino.stato == 'aperto' || scontrino.stato == 'sospeso') {
      return const EsitoReso.ko(
        'Solo scontrini chiusi possono essere annullati.',
      );
    }
    if (motivo.trim().isEmpty) {
      return const EsitoReso.ko('Motivo annullo obbligatorio.');
    }
    scontrino.stato = 'annullato';
    scontrino.aggiungiRettifica('ANNULLO: ${motivo.trim()}');
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
