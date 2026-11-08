import '../l10n/error_text.dart';
import '../l10n/localized_text.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../login/jwt_api/adapter/platform_manager.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview_list.code.dart';
import '../reuse_class/logic/global_pagination_controller.dart';
import 'employee_hr.code.dart';

export 'employee_hr.code.dart';

class Dipendente {
  final int id;
  final int wpUserId;

  /// Login dell'utente WordPress collegato ('' = nessuno).
  final String wpUserLogin;

  /// Sede dell'utente WordPress collegato (0 = nessuna assegnata).
  final int siteId;
  final String nome;
  final String cognome;

  /// Email personale: resta nella scheda, per i contatti.
  final String email;

  /// Email aziendale: e' l'email di accesso dell'utente WordPress.
  final String emailAziendale;
  final String telefono;
  final String ruolo;
  final double stipendio;
  final String stipendioValuta;

  /// Settimana tipo: per ogni giorno ('mon'..'sun') le fasce di lavoro.
  final Map<String, List<FasciaOraria>> settimanaTipo;
  final Contratto contratto;

  String get nomeCompleto => '$nome $cognome'.trim();

  int get minutiSettimanaTipo => settimanaTipo.values
      .expand((fasce) => fasce)
      .fold<int>(0, (sum, fascia) => sum + fascia.minuti);

  /// Campi del dipendente per la lista Dipendenti. MGWS restituisce tutti i
  /// dipendenti in una volta, quindi filtri e ordinamento lavorano in
  /// memoria.
  static final List<DataGridField<Dipendente>> gridFields =
      <DataGridField<Dipendente>>[
        DataGridField<Dipendente>(
          name: 'nome',
          label: (l10n) => l10n.commonName,
          aliases: const <String>['nome', 'cognome', 'dipendente', 'name'],
          read: (d) => <Object?>[d.nomeCompleto],
          sortable: true,
          width: 200,
          flexible: true,
        ),
        DataGridField<Dipendente>(
          name: 'emailAziendale',
          label: (l10n) => l10n.employeesWorkEmail,
          aliases: const <String>['email', 'mail', 'aziendale'],
          read: (d) => <Object?>[d.emailAziendale],
          sortable: true,
          width: 220,
        ),
        DataGridField<Dipendente>(
          name: 'telefono',
          label: (l10n) => l10n.employeesPhone,
          aliases: const <String>['telefono', 'phone', 'cellulare'],
          read: (d) => <Object?>[d.telefono],
          sortable: true,
          width: 140,
        ),
        DataGridField<Dipendente>(
          name: 'ruolo',
          label: (l10n) => l10n.employeesRoleLabel,
          aliases: const <String>['ruolo', 'role', 'mansione'],
          read: (d) => <Object?>[d.ruolo],
          sortable: true,
          width: 160,
        ),
        DataGridField<Dipendente>(
          name: 'stipendio',
          label: (l10n) => l10n.employeesSalaryTitle,
          aliases: const <String>['stipendio', 'salary'],
          type: DataGridFieldType.numero,
          read: (d) => <Object?>[d.stipendio],
          format: (l10n, d) =>
              '${d.stipendio.toStringAsFixed(2)} ${d.stipendioValuta}',
          sortable: true,
          searchable: false,
          width: 130,
          numeric: true,
        ),
        DataGridField<Dipendente>(
          name: 'utenteWordPress',
          label: (l10n) => l10n.employeesWordPressUser,
          aliases: const <String>['utente', 'wordpress', 'wp'],
          type: DataGridFieldType.numero,
          read: (d) => <Object?>[if (d.wpUserId > 0) d.wpUserId],
          format: (l10n, d) => d.wpUserId <= 0
              ? l10n.employeesNotLinked
              : (d.wpUserLogin.isNotEmpty ? d.wpUserLogin : '#${d.wpUserId}'),
          sortable: true,
          searchable: false,
          width: 150,
        ),
      ];

  Dipendente({
    required this.id,
    this.wpUserId = 0,
    this.wpUserLogin = '',
    this.siteId = 0,
    required this.nome,
    required this.cognome,
    required this.email,
    this.emailAziendale = '',
    this.telefono = '',
    required this.ruolo,
    required this.stipendio,
    this.stipendioValuta = 'EUR',
    Map<String, List<FasciaOraria>>? settimanaTipo,
    this.contratto = const Contratto(),
  }) : settimanaTipo = settimanaTipo ?? FasciaOraria.settimanaVuota();

  factory Dipendente.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? json['nome'] ?? '').toString();
    final lastName = (json['last_name'] ?? json['cognome'] ?? '').toString();
    final role = (json['role_label'] ?? json['ruolo'] ?? '').toString();
    return Dipendente(
      id: (json['id'] as num?)?.toInt() ?? 0,
      wpUserId: (json['wp_user_id'] as num?)?.toInt() ?? 0,
      wpUserLogin: (json['wp_user_login'] ?? '').toString(),
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      nome: firstName,
      cognome: lastName,
      email: (json['email'] ?? '').toString(),
      emailAziendale: (json['work_email'] ?? '').toString(),
      telefono: (json['phone'] ?? '').toString(),
      ruolo: role,
      stipendio: _salaryFromJson(json),
      stipendioValuta: (json['salary_currency'] ?? 'EUR').toString(),
      settimanaTipo: FasciaOraria.settimanaFromJson(json['weekly_schedule']),
      contratto: Contratto.fromJson(json),
    );
  }

  Map<String, dynamic> toMgwsPayload() {
    return <String, dynamic>{
      'first_name': nome.trim(),
      'last_name': cognome.trim(),
      'email': email.trim(),
      'work_email': emailAziendale.trim(),
      'phone': telefono.trim(),
      'wp_user_id': wpUserId,
      // La sede vive sull'utente WordPress: senza utente collegato non c'e'
      // nessuno a cui assegnarla.
      if (wpUserId > 0) 'site_id': siteId,
      'role_label': ruolo.trim(),
      'salary_cents': (stipendio * 100).round(),
      'salary_currency': stipendioValuta.trim().isEmpty
          ? 'EUR'
          : stipendioValuta.trim().toUpperCase(),
      'status': 'active',
      'weekly_schedule': FasciaOraria.settimanaToJson(settimanaTipo),
      ...contratto.toMgwsPayload(),
    };
  }

  static double _salaryFromJson(Map<String, dynamic> json) {
    final cents = json['salary_cents'];
    if (cents is num) return cents.toInt() / 100;
    final legacy = json['stipendio'];
    if (legacy is num) return legacy.toDouble();
    return 0;
  }
}

/// Tipi di contratto che il server accetta, nell'ordine del menu.
enum TipoContratto { permanent, fixedTerm, apprenticeship, internship, other }

extension TipoContrattoMgws on TipoContratto {
  String get mgws => switch (this) {
    TipoContratto.permanent => 'permanent',
    TipoContratto.fixedTerm => 'fixed_term',
    TipoContratto.apprenticeship => 'apprenticeship',
    TipoContratto.internship => 'internship',
    TipoContratto.other => 'other',
  };

  static TipoContratto? parse(String value) {
    for (final tipo in TipoContratto.values) {
      if (tipo.mgws == value) return tipo;
    }
    return null;
  }
}

/// Dati del contratto: tipo, livello, periodo e ore settimanali.
class Contratto {
  final TipoContratto? tipo;
  final String livello;
  final DateTime? inizio;
  final DateTime? fine;

  /// Ore settimanali del contratto, in minuti (0 = non indicate).
  final int minutiSettimana;

  const Contratto({
    this.tipo,
    this.livello = '',
    this.inizio,
    this.fine,
    this.minutiSettimana = 0,
  });

  factory Contratto.fromJson(Map<String, dynamic> json) {
    return Contratto(
      tipo: TipoContrattoMgws.parse((json['contract_type'] ?? '').toString()),
      livello: (json['contract_level'] ?? '').toString(),
      inizio: DateTime.tryParse((json['contract_start'] ?? '').toString()),
      fine: DateTime.tryParse((json['contract_end'] ?? '').toString()),
      minutiSettimana: (json['contract_minutes_week'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _data(DateTime? value) =>
      value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  Map<String, dynamic> toMgwsPayload() => <String, dynamic>{
    'contract_type': tipo?.mgws ?? '',
    'contract_level': livello.trim(),
    'contract_start': _data(inizio),
    'contract_end': _data(fine),
    'contract_minutes_week': minutiSettimana,
  };
}

class DipendentiService extends ChangeNotifier {
  List<Dipendente> _dipendenti = [];
  bool _isLoading = false;
  LocalizedText? _errore;

  /// Ultimo errore di creazione o modifica, per chi deve capire quale campo
  /// mostrare (es. email aziendale gia' usata).
  Object? ultimaEccezione;

  List<Dipendente> get dipendenti => _dipendenti;
  bool get isLoading => _isLoading;
  LocalizedText? get errore => _errore;

  /// Massimo di dipendenti che MGWS restituisce in una richiesta.
  static const int _limiteMgws = 200;

  /// `loadPage` della lista Dipendenti: MGWS non pagina, quindi la prima
  /// pagina e' gia' l'elenco completo e la lista lo filtra in memoria.
  Future<PaginatedResult<Dipendente>> caricaPagina(
    DataGridPageRequest request,
  ) async {
    final rows = await PlatformManager.dipendenti.listEmployees(
      limit: _limiteMgws,
    );
    final dipendenti = (rows as List<Map<String, dynamic>>)
        .map(Dipendente.fromJson)
        .toList(growable: false);
    _dipendenti = dipendenti;
    return PaginatedResult<Dipendente>(
      items: dipendenti,
      page: request.page,
      perPage: request.perPage,
      totalItems: dipendenti.length,
      hasMore: false,
    );
  }

  Future<void> loadDipendenti() async {
    _isLoading = true;
    _errore = null;
    notifyListeners();
    try {
      final rows = await PlatformManager.dipendenti.listEmployees();
      _dipendenti = rows.map(Dipendente.fromJson).toList(growable: false);
    } catch (error) {
      _errore = (l10n) =>
          l10n.employeesLoadError(localizedErrorText(l10n, error));
      _dipendenti = const <Dipendente>[];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [account] chiede al server di creare anche l'utente WordPress
  /// (`create_wp_user`, set di permessi, sede, invito): il login nasce
  /// dall'email aziendale.
  Future<bool> addDipendente(
    Dipendente dipendente, {
    Map<String, dynamic>? account,
  }) async {
    _errore = null;
    try {
      final response = await PlatformManager.dipendenti.createEmployee(
        <String, dynamic>{...dipendente.toMgwsPayload(), ...?account},
      );
      final created = Dipendente.fromJson(response);
      _dipendenti = <Dipendente>[..._dipendenti, created];
      notifyListeners();
      return true;
    } catch (error) {
      ultimaEccezione = error;
      _errore = (l10n) =>
          l10n.employeesCreateError(employeeErrorText(l10n, error));
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDipendente(
    Dipendente dipendente, {
    Map<String, dynamic>? account,
  }) async {
    _errore = null;
    try {
      final response = await PlatformManager.dipendenti.updateEmployee(
        dipendente.id,
        <String, dynamic>{...dipendente.toMgwsPayload(), ...?account},
      );
      final updated = Dipendente.fromJson(response);
      final index = _dipendenti.indexWhere((d) => d.id == dipendente.id);
      if (index != -1) {
        final copy = List<Dipendente>.from(_dipendenti);
        copy[index] = updated;
        _dipendenti = copy;
      }
      notifyListeners();
      return true;
    } catch (error) {
      ultimaEccezione = error;
      _errore = (l10n) =>
          l10n.employeesUpdateError(employeeErrorText(l10n, error));
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDipendente(int id) async {
    _errore = null;
    try {
      await PlatformManager.dipendenti.deleteEmployee(id);
      _dipendenti = _dipendenti
          .where((d) => d.id != id)
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (error) {
      _errore = (l10n) =>
          l10n.employeesDeactivateError(localizedErrorText(l10n, error));
      notifyListeners();
      return false;
    }
  }
}
