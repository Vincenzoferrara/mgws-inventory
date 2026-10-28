import '../l10n/error_text.dart';
import '../l10n/localized_text.dart';
import 'package:flutter/foundation.dart';

import '../login/jwt_api/adapter/platform_manager.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview_list.code.dart';
import '../reuse_class/logic/global_pagination_controller.dart';

class Dipendente {
  final int id;
  final int wpUserId;

  /// Sede dell'utente WordPress collegato (0 = nessuna assegnata).
  final int siteId;
  final String nome;
  final String cognome;
  final String email;
  final String ruolo;
  final double stipendio;
  final String stipendioValuta;
  final DateTime? dataNascita;
  final DateTime? dataAssunzione;
  final String?
  tipoContratto; // full-time, part-time, contratto a tempo determinato, etc.
  final String? orarioLavoro; // es. "9:00-18:00"
  final int giorniFerieDisponibili;
  final int giorniFerieUsati;
  final int giorniMalattia;
  final List<Map<String, dynamic>>?
  storicoPagamenti; // lista di mappe con data, importo, etc.
  final List<String>? benefici; // lista di benefici
  final List<String>? formazione; // corsi di formazione
  final List<Map<String, dynamic>>? valutazioni; // valutazioni performance
  final List<String>? documenti; // nomi file documenti allegati
  final double? venditeTotali; // per ruoli di vendita
  final int? produzioneTotale; // per ruoli di produzione

  String get nomeCompleto => '$nome $cognome'.trim();

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
          name: 'email',
          label: (l10n) => l10n.employeesEmailLabel,
          aliases: const <String>['email', 'mail'],
          read: (d) => <Object?>[d.email],
          sortable: true,
          width: 220,
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
          format: (l10n, d) =>
              d.wpUserId > 0 ? '#${d.wpUserId}' : l10n.employeesNotLinked,
          sortable: true,
          searchable: false,
          width: 150,
        ),
      ];

  Dipendente({
    required this.id,
    this.wpUserId = 0,
    this.siteId = 0,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.ruolo,
    required this.stipendio,
    this.stipendioValuta = 'EUR',
    this.dataNascita,
    this.dataAssunzione,
    this.tipoContratto,
    this.orarioLavoro,
    this.giorniFerieDisponibili = 0,
    this.giorniFerieUsati = 0,
    this.giorniMalattia = 0,
    this.storicoPagamenti,
    this.benefici,
    this.formazione,
    this.valutazioni,
    this.documenti,
    this.venditeTotali,
    this.produzioneTotale,
  });

  factory Dipendente.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? json['nome'] ?? '').toString();
    final lastName = (json['last_name'] ?? json['cognome'] ?? '').toString();
    final role = (json['role_label'] ?? json['ruolo'] ?? '').toString();
    return Dipendente(
      id: (json['id'] as num?)?.toInt() ?? 0,
      wpUserId: (json['wp_user_id'] as num?)?.toInt() ?? 0,
      siteId: (json['site_id'] as num?)?.toInt() ?? 0,
      nome: firstName,
      cognome: lastName,
      email: (json['email'] ?? '').toString(),
      ruolo: role,
      stipendio: _salaryFromJson(json),
      stipendioValuta: (json['salary_currency'] ?? 'EUR').toString(),
      dataNascita: json['dataNascita'] != null
          ? DateTime.parse(json['dataNascita'])
          : null,
      dataAssunzione: json['dataAssunzione'] != null
          ? DateTime.parse(json['dataAssunzione'])
          : null,
      tipoContratto: json['tipoContratto'],
      orarioLavoro: json['orarioLavoro'],
      giorniFerieDisponibili: json['giorniFerieDisponibili'] ?? 0,
      giorniFerieUsati: json['giorniFerieUsati'] ?? 0,
      giorniMalattia: json['giorniMalattia'] ?? 0,
      storicoPagamenti: json['storicoPagamenti'] != null
          ? List<Map<String, dynamic>>.from(json['storicoPagamenti'])
          : null,
      benefici: json['benefici'] != null
          ? List<String>.from(json['benefici'])
          : null,
      formazione: json['formazione'] != null
          ? List<String>.from(json['formazione'])
          : null,
      valutazioni: json['valutazioni'] != null
          ? List<Map<String, dynamic>>.from(json['valutazioni'])
          : null,
      documenti: json['documenti'] != null
          ? List<String>.from(json['documenti'])
          : null,
      venditeTotali: json['venditeTotali']?.toDouble(),
      produzioneTotale: json['produzioneTotale']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wp_user_id': wpUserId,
      'site_id': siteId,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'ruolo': ruolo,
      'stipendio': stipendio,
      'stipendioValuta': stipendioValuta,
      'dataNascita': dataNascita?.toIso8601String(),
      'dataAssunzione': dataAssunzione?.toIso8601String(),
      'tipoContratto': tipoContratto,
      'orarioLavoro': orarioLavoro,
      'giorniFerieDisponibili': giorniFerieDisponibili,
      'giorniFerieUsati': giorniFerieUsati,
      'giorniMalattia': giorniMalattia,
      'storicoPagamenti': storicoPagamenti,
      'benefici': benefici,
      'formazione': formazione,
      'valutazioni': valutazioni,
      'documenti': documenti,
      'venditeTotali': venditeTotali,
      'produzioneTotale': produzioneTotale,
    };
  }

  Map<String, dynamic> toMgwsPayload() {
    return <String, dynamic>{
      'first_name': nome.trim(),
      'last_name': cognome.trim(),
      'email': email.trim(),
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

class DipendentiService extends ChangeNotifier {
  List<Dipendente> _dipendenti = [];
  bool _isLoading = false;
  LocalizedText? _errore;

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

  Future<bool> addDipendente(Dipendente dipendente) async {
    _errore = null;
    try {
      final response = await PlatformManager.dipendenti.createEmployee(
        dipendente.toMgwsPayload(),
      );
      final created = Dipendente.fromJson(response);
      _dipendenti = <Dipendente>[..._dipendenti, created];
      notifyListeners();
      return true;
    } catch (error) {
      _errore = (l10n) =>
          l10n.employeesCreateError(localizedErrorText(l10n, error));
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDipendente(Dipendente dipendente) async {
    _errore = null;
    try {
      final response = await PlatformManager.dipendenti.updateEmployee(
        dipendente.id,
        dipendente.toMgwsPayload(),
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
      _errore = (l10n) =>
          l10n.employeesUpdateError(localizedErrorText(l10n, error));
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
