import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../l10n/error_text.dart';
import '../l10n/generated/app_localizations.dart';
import '../login/mgws/query/query_mgws_employees.dart';

/// Testo di un errore delle rotte dipendenti: i casi noti nella lingua
/// dell'app, gli altri con il messaggio del server.
String employeeErrorText(AppLocalizations l10n, Object error) {
  if (error is! MgwsEmployeeException) return localizedErrorText(l10n, error);
  return switch (error.code) {
    'mgws_shift_overlap' => l10n.employeesErrShiftOverlap,
    'mgws_email_exists' => l10n.employeesErrEmailExists,
    'mgws_username_exists' => l10n.employeesErrUsernameExists,
    'mgws_account_required' => l10n.employeesErrAccountRequired,
    'mgws_work_email_required' => l10n.employeesWorkEmailRequired,
    'mgws_schedule_empty' => l10n.employeesShiftsNoSchedule,
    'mgws_file_too_large' => l10n.employeesDocumentTooLarge,
    'mgws_bad_file_type' => l10n.employeesErrBadFileType,
    'mgws_capability_escalation' => l10n.employeesErrEscalation,
    'mgws_forbidden' || 'rest_forbidden' => l10n.employeesErrForbidden,
    _ => error.message,
  };
}

/// Nome di un set di permessi. I due set che il plugin crea da solo
/// arrivano con l'etichetta inglese (il sito non ha la traduzione): finche'
/// nessuno li rinomina, l'app li chiama nella propria lingua.
String nomeSetPermessi(AppLocalizations l10n, Map<String, dynamic> set) {
  final slug = (set['slug'] ?? '').toString();
  final label = (set['label'] ?? '').toString();
  if (slug == 'cashier' && label == 'Cashier') return l10n.permissionSetCashier;
  if (slug == 'warehouse' && label == 'Warehouse operator') {
    return l10n.permissionSetWarehouse;
  }
  return label.isNotEmpty ? label : slug;
}

/// Una fascia di lavoro della settimana tipo, con orari "HH:MM".
class FasciaOraria {
  final String inizio;
  final String fine;

  const FasciaOraria(this.inizio, this.fine);

  /// Giorni nell'ordine del server, da lunedi' a domenica.
  static const List<String> giorni = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  int get minuti => minutiTra(inizio, fine);

  static int _minutiDa(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Minuti fra due orari; una fine prima dell'inizio passa la mezzanotte.
  static int minutiTra(String inizio, String fine) {
    final from = _minutiDa(inizio);
    final to = _minutiDa(fine);
    if (to == from) return 0;
    return to > from ? to - from : to + 1440 - from;
  }

  static Map<String, List<FasciaOraria>> settimanaVuota() =>
      <String, List<FasciaOraria>>{
        for (final giorno in giorni) giorno: const <FasciaOraria>[],
      };

  static Map<String, List<FasciaOraria>> settimanaFromJson(Object? json) {
    final out = settimanaVuota();
    if (json is! Map) return out;
    for (final giorno in giorni) {
      final slots = json[giorno];
      if (slots is! List) continue;
      out[giorno] = <FasciaOraria>[
        for (final slot in slots.whereType<Map>())
          FasciaOraria(
            (slot['start'] ?? '').toString(),
            (slot['end'] ?? '').toString(),
          ),
      ];
    }
    return out;
  }

  static Map<String, dynamic> settimanaToJson(
    Map<String, List<FasciaOraria>> settimana,
  ) => <String, dynamic>{
    for (final giorno in giorni)
      giorno: <Map<String, String>>[
        for (final fascia in settimana[giorno] ?? const <FasciaOraria>[])
          <String, String>{'start': fascia.inizio, 'end': fascia.fine},
      ],
  };
}

/// Minuti come ore e minuti, "38:30"; con [segno] anche "+1:15" o "-0:45".
String formatOre(int minuti, {bool segno = false}) {
  final abs = minuti.abs();
  final testo = '${abs ~/ 60}:${(abs % 60).toString().padLeft(2, '0')}';
  if (!segno) return testo;
  return minuti > 0 ? '+$testo' : (minuti < 0 ? '-$testo' : testo);
}

/// Orario scritto dall'operatore come "9", "930", "0930", "9:30" o "9.30",
/// riscritto "09:30"; null se non e' un'ora valida.
String? normalizzaOra(String input) {
  final value = input.trim().replaceAll('.', ':').replaceAll(',', ':');
  int? ore;
  int? minuti;
  final hm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value);
  final soloCifre = RegExp(r'^\d{1,4}$').hasMatch(value);
  if (hm != null) {
    ore = int.parse(hm.group(1)!);
    minuti = int.parse(hm.group(2)!);
    if (hm.group(2)!.length == 1) minuti *= 10;
  } else if (soloCifre && value.length <= 2) {
    ore = int.parse(value);
    minuti = 0;
  } else if (soloCifre) {
    ore = int.parse(value.substring(0, value.length - 2));
    minuti = int.parse(value.substring(value.length - 2));
  }
  if (ore == null || minuti == null || ore > 23 || minuti > 59) return null;
  return '${ore.toString().padLeft(2, '0')}:${minuti.toString().padLeft(2, '0')}';
}

/// Ore del contratto scritte come "40", "38:30" o "38,5", in minuti; null se
/// non valide, 0 se il campo e' vuoto.
int? parseOreContratto(String input) {
  final value = input.trim();
  if (value.isEmpty) return 0;
  final hm = RegExp(r'^(\d{1,3})(?::([0-5]\d))?$').firstMatch(value);
  int? minuti;
  if (hm != null) {
    minuti = int.parse(hm.group(1)!) * 60 + int.parse(hm.group(2) ?? '0');
  } else {
    final decimal = double.tryParse(value.replaceAll(',', '.'));
    if (decimal != null && decimal >= 0) minuti = (decimal * 60).round();
  }
  if (minuti == null || minuti > 168 * 60) return null;
  return minuti;
}

final DateFormat _giornoMgws = DateFormat('yyyy-MM-dd');

String dataMgws(DateTime date) => _giornoMgws.format(date);

/// Lunedi' della settimana di [date], a mezzanotte.
DateTime lunediDi(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

class TurnoDipendente {
  final int id;
  final DateTime data;
  final String inizio;
  final String fine;
  final int pausaMinuti;
  final int minuti;
  final String nota;

  const TurnoDipendente({
    required this.id,
    required this.data,
    required this.inizio,
    required this.fine,
    this.pausaMinuti = 0,
    required this.minuti,
    this.nota = '',
  });

  factory TurnoDipendente.fromJson(Map<String, dynamic> json) {
    return TurnoDipendente(
      id: (json['id'] as num?)?.toInt() ?? 0,
      data:
          DateTime.tryParse((json['shift_date'] ?? '').toString()) ??
          DateTime(1970),
      inizio: (json['start_time'] ?? '').toString(),
      fine: (json['end_time'] ?? '').toString(),
      pausaMinuti: (json['break_minutes'] as num?)?.toInt() ?? 0,
      minuti: (json['minutes'] as num?)?.toInt() ?? 0,
      nota: (json['note'] ?? '').toString(),
    );
  }
}

/// Ore pianificate di un periodo rispetto a quelle del contratto.
class RiepilogoTurni {
  final int pianificati;
  final int contratto;
  final int differenza;

  const RiepilogoTurni({
    this.pianificati = 0,
    this.contratto = 0,
    this.differenza = 0,
  });

  factory RiepilogoTurni.fromJson(Object? json) {
    if (json is! Map) return const RiepilogoTurni();
    return RiepilogoTurni(
      pianificati: (json['planned_minutes'] as num?)?.toInt() ?? 0,
      contratto: (json['contract_minutes'] as num?)?.toInt() ?? 0,
      differenza: (json['difference_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class TurniPeriodo {
  final List<TurnoDipendente> turni;
  final RiepilogoTurni riepilogo;

  const TurniPeriodo(this.turni, this.riepilogo);
}

/// Tipi di documento che il server accetta.
enum TipoDocumento { contract, idDocument, other }

extension TipoDocumentoMgws on TipoDocumento {
  String get mgws => switch (this) {
    TipoDocumento.contract => 'contract',
    TipoDocumento.idDocument => 'id_document',
    TipoDocumento.other => 'other',
  };

  static TipoDocumento parse(String value) {
    for (final tipo in TipoDocumento.values) {
      if (tipo.mgws == value) return tipo;
    }
    return TipoDocumento.other;
  }
}

class DocumentoDipendente {
  final int id;
  final TipoDocumento tipo;
  final String titolo;
  final String nomeFile;
  final String mime;
  final int byte;
  final DateTime? caricato;

  const DocumentoDipendente({
    required this.id,
    required this.tipo,
    required this.titolo,
    required this.nomeFile,
    required this.mime,
    required this.byte,
    this.caricato,
  });

  factory DocumentoDipendente.fromJson(Map<String, dynamic> json) {
    return DocumentoDipendente(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tipo: TipoDocumentoMgws.parse((json['kind'] ?? '').toString()),
      titolo: (json['title'] ?? '').toString(),
      nomeFile: (json['file_name'] ?? '').toString(),
      mime: (json['mime'] ?? '').toString(),
      byte: (json['size_bytes'] as num?)?.toInt() ?? 0,
      caricato: DateTime.tryParse(
        '${(json['created_at_gmt'] ?? '').toString().replaceFirst(' ', 'T')}Z',
      )?.toLocal(),
    );
  }
}

/// Turni e documenti di un dipendente sul server MGWS.
class DipendenteHrService {
  DipendenteHrService({QueryMgwsEmployees? api})
    : _api = api ?? QueryMgwsEmployees();

  final QueryMgwsEmployees _api;

  /// Il server accetta file fino a 10 MB.
  static const int maxByte = 10 * 1024 * 1024;

  Future<TurniPeriodo> turni(int dipendenteId, DateTime da, DateTime a) async {
    final data = await _api.shifts(dipendenteId, dataMgws(da), dataMgws(a));
    final items = data['items'];
    return TurniPeriodo(<TurnoDipendente>[
      if (items is List)
        for (final item in items.whereType<Map>())
          TurnoDipendente.fromJson(Map<String, dynamic>.from(item)),
    ], RiepilogoTurni.fromJson(data['summary']));
  }

  Future<void> salvaTurno(
    int dipendenteId, {
    int? turnoId,
    required DateTime data,
    required String inizio,
    required String fine,
    int pausaMinuti = 0,
    String nota = '',
  }) async {
    final payload = <String, dynamic>{
      'shift_date': dataMgws(data),
      'start_time': inizio,
      'end_time': fine,
      'break_minutes': pausaMinuti,
      'note': nota.trim(),
    };
    if (turnoId == null) {
      await _api.createShift(dipendenteId, payload);
    } else {
      await _api.updateShift(dipendenteId, turnoId, payload);
    }
  }

  Future<void> eliminaTurno(int dipendenteId, int turnoId) =>
      _api.deleteShift(dipendenteId, turnoId);

  /// Copia la settimana tipo sui giorni del periodo; restituisce quanti
  /// turni ha creato.
  Future<int> copiaSettimanaTipo(
    int dipendenteId,
    DateTime da,
    DateTime a, {
    bool sostituisci = false,
  }) async {
    final data = await _api.generateShifts(
      dipendenteId,
      dataMgws(da),
      dataMgws(a),
      replace: sostituisci,
    );
    return (data['created'] as num?)?.toInt() ?? 0;
  }

  Future<List<DocumentoDipendente>> documenti(int dipendenteId) async {
    final items = await _api.documents(dipendenteId);
    return items.map(DocumentoDipendente.fromJson).toList(growable: false);
  }

  Future<void> caricaDocumento(
    int dipendenteId, {
    required TipoDocumento tipo,
    required String titolo,
    required String nomeFile,
    required Uint8List bytes,
  }) async {
    await _api.uploadDocument(dipendenteId, <String, dynamic>{
      'kind': tipo.mgws,
      'title': titolo.trim(),
      'file_name': nomeFile,
      'content_base64': base64Encode(bytes),
    });
  }

  Future<Uint8List> scaricaDocumento(int dipendenteId, int documentoId) async {
    final data = await _api.downloadDocument(dipendenteId, documentoId);
    return base64Decode((data['content_base64'] ?? '').toString());
  }

  Future<void> eliminaDocumento(int dipendenteId, int documentoId) =>
      _api.deleteDocument(dipendenteId, documentoId);
}
