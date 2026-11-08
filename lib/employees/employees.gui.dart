import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../login/jwt_api/query_wordpress/query_user_wordpress.dart';
import '../login/mgws/query/query_mgws_employees.dart';
import '../login/mgws/query/query_mgws_permission_sets.dart';
import '../login/mgws/query/query_mgws_site.dart';
import '../theme/theme.dart';
import 'employees.code.dart'; // Import the code file for logic
import 'employee_hr.gui.dart';
import 'permission_sets.gui.dart';
import '../l10n/extensions.dart';
import '../reuse_class/datagridview/datagridview_list.gui.dart';

class DipendentiGui extends StatefulWidget {
  const DipendentiGui({super.key});

  @override
  _DipendentiGuiState createState() => _DipendentiGuiState();
}

/// Elenco dipendenti su [DataGridListView]: MGWS restituisce tutti i
/// dipendenti in una volta, e la lista li filtra e pagina in memoria.
class _DipendentiGuiState extends State<DipendentiGui> {
  final DipendentiService _service = DipendentiService();
  late final DataGridListController<Dipendente> _listController =
      DataGridListController<Dipendente>(
        fields: Dipendente.gridFields,
        idOf: _idOf,
        loadPage: _service.caricaPagina,
        cacheKey: 'dipendenti',
        serverFiltering: false,
      );

  static String _idOf(Dipendente dipendente) => '${dipendente.id}';

  @override
  void initState() {
    super.initState();
    // La sede di un dipendente e' quella in uso del suo utente WordPress: se
    // l'utente collegato la cambia, la sua riga in elenco va riletta.
    QueryMgwsSite.changes.addListener(_ricarica);
  }

  @override
  void dispose() {
    QueryMgwsSite.changes.removeListener(_ricarica);
    _listController.dispose();
    super.dispose();
  }

  /// Ricarica da MGWS e rimette nel dettaglio il dipendente aggiornato (o
  /// niente, se non c'e' piu').
  Future<void> _ricarica() async {
    final selezionato = _listController.selected.value?.id;
    await _listController.reload(force: true);
    if (!mounted) return;
    Dipendente? aggiornato;
    for (final dipendente in _listController.cache.items) {
      if (dipendente.id == selezionato) aggiornato = dipendente;
    }
    _listController.select(aggiornato);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addDipendente,
        tooltip: context.l10n.employeesAddTooltip,
        child: const Icon(Icons.add),
      ),
      body: DataGridListView<Dipendente>(
        controller: _listController,
        fields: Dipendente.gridFields,
        idOf: _idOf,
        loadPage: _service.caricaPagina,
        cacheKey: 'dipendenti',
        serverFiltering: false,
        defaultColumns: const [
          'nome',
          'email',
          'ruolo',
          'stipendio',
          'utenteWordPress',
        ],
        defaultMobileColumns: const ['nome', 'ruolo'],
        onRefresh: _ricarica,
        toolbarActions: <Widget>[
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: context.l10n.permissionSetsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PermissionSetsScreen(),
              ),
            ),
          ),
        ],
        cellsOf: (context, dipendente) => <String, Widget>{
          'nome': Text(
            dipendente.nomeCompleto.isEmpty ? '-' : dipendente.nomeCompleto,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        },
        contextActions: (context) => [
          DataGridViewContextAction<Dipendente>(
            label: context.l10n.commonNew,
            icon: Icons.add_circle_outline,
            onSelected: (_) async => _addDipendente(),
          ),
          DataGridViewContextAction<Dipendente>(
            label: context.l10n.commonEdit,
            icon: Icons.edit_outlined,
            onSelected: (dipendente) async => _editDipendente(dipendente),
          ),
          DataGridViewContextAction<Dipendente>(
            label: context.l10n.commonDelete,
            icon: Icons.delete_outline,
            onSelected: (dipendente) async => _deleteDipendente(dipendente.id),
          ),
        ],
        onRowActivated: _editDipendente,
        emptyDetailsIcon: Icons.badge_outlined,
        // Il dettaglio ha gia' il suo Scaffold: va bene sia nel pannello sia
        // come pagina su telefono.
        detailsOf: (context, dipendente, inPage) =>
            DipendenteDetailScreen(dipendente: dipendente),
      ),
    );
  }

  void _addDipendente() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DipendenteFormScreen(isEdit: false, service: _service),
      ),
    ).then((_) => _ricarica());
  }

  void _editDipendente(Dipendente dipendente) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DipendenteFormScreen(
          isEdit: true,
          dipendente: dipendente,
          service: _service,
        ),
      ),
    ).then((_) => _ricarica());
  }

  void _deleteDipendente(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.commonConfirm),
        content: Text(context.l10n.employeesDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteDipendente(id);
              await _ricarica();
            },
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }
}

class DipendenteFormScreen extends StatefulWidget {
  final bool isEdit;
  final Dipendente? dipendente;
  final DipendentiService service;

  const DipendenteFormScreen({
    super.key,
    required this.isEdit,
    required this.service,
    this.dipendente,
  });

  @override
  _DipendenteFormScreenState createState() => _DipendenteFormScreenState();
}

/// Come il dipendente entra nell'app: ogni dipendente e' anche un utente del
/// sito, creato insieme alla scheda o scelto fra quelli che esistono gia'.
enum _Accesso { crea, collega }

class _DipendenteFormScreenState extends State<DipendenteFormScreen> {
  static final NumberFormat _salaryFormat = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '',
    decimalDigits: 2,
  );

  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailAziendaleController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _ruoloController = TextEditingController();
  final _stipendioController = TextEditingController();
  final _livelloController = TextEditingController();
  final _oreContrattoController = TextEditingController();

  /// Sedi del negozio e sede scelta per l'utente collegato. Con piu' sedi e'
  /// obbligatoria: senza, quell'utente non puo' usare l'inventario.
  MgwsSiteStatus? _sedi;
  int? _siteId;

  _Accesso _accesso = _Accesso.crea;
  int _wpUserId = 0;
  String _wpUserLabel = '';

  /// Set di permessi assegnabili al nuovo utente. Resta vuoto se chi crea
  /// non puo' leggerli: l'utente nasce senza permessi e li riceve dopo.
  List<Map<String, dynamic>> _sets = const <Map<String, dynamic>>[];
  int? _setId;
  bool _inviaInvito = true;

  TipoContratto? _tipoContratto;

  /// Un contratto indeterminato non ha fine: il campo compare solo per
  /// quelli a termine.
  bool get _contrattoATermine => switch (_tipoContratto) {
    TipoContratto.fixedTerm ||
    TipoContratto.apprenticeship ||
    TipoContratto.internship => true,
    _ => false,
  };

  /// Errore del server sull'email aziendale (gia' usata), mostrato sotto il
  /// campo invece che in fondo alla pagina.
  String? _erroreEmailAziendale;
  final GlobalKey _emailAziendaleKey = GlobalKey();
  DateTime? _inizioContratto;
  DateTime? _fineContratto;
  Map<String, List<FasciaOraria>> _settimana = FasciaOraria.settimanaVuota();

  /// Un dipendente gia' collegato non puo' ricevere un secondo account.
  bool get _eraCollegato =>
      widget.isEdit && (widget.dipendente?.wpUserId ?? 0) > 0;

  Future<void> _caricaSet() async {
    try {
      final data = await QueryMgwsPermissionSets().list();
      final items = data['items'];
      if (!mounted || items is! List) return;
      setState(() {
        _sets = items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    } on PermissionSetsException {
      // Senza lettura dei set il menu non compare.
    } catch (_) {
      // Offline: l'utente nasce senza set e lo riceve dopo.
    }
  }

  Future<void> _caricaSedi() async {
    try {
      final stato = await QueryMgwsSite().getMySite();
      if (!mounted) return;
      setState(() {
        _sedi = stato;
        if (_siteId == null && stato.sites.length == 1) {
          _siteId = stato.sites.first.id;
        }
      });
    } catch (_) {
      // Senza sedi leggibili (anche offline) il campo non compare: il server
      // rifiutera' comunque un dipendente senza sede quando e' obbligatoria.
    }
  }

  @override
  void initState() {
    super.initState();
    _caricaSet();
    // Chi non gestisce le sedi vede solo quella in uso: se cambia, il menu
    // proporrebbe quella di prima.
    QueryMgwsSite.changes.addListener(_caricaSedi);
    _caricaSedi();
    final dipendente = widget.dipendente;
    if (widget.isEdit && dipendente != null) {
      if (dipendente.siteId > 0) {
        _siteId = dipendente.siteId;
      }
      _nomeController.text = dipendente.nome;
      _cognomeController.text = dipendente.cognome;
      _emailController.text = dipendente.email;
      _emailAziendaleController.text = dipendente.emailAziendale;
      _telefonoController.text = dipendente.telefono;
      if (dipendente.wpUserId > 0) {
        _accesso = _Accesso.collega;
        _wpUserId = dipendente.wpUserId;
        _wpUserLabel = dipendente.wpUserLogin.isNotEmpty
            ? dipendente.wpUserLogin
            : '#${dipendente.wpUserId}';
      }
      _ruoloController.text = dipendente.ruolo;
      _stipendioController.text = _salaryFormat.format(dipendente.stipendio);
      _tipoContratto = dipendente.contratto.tipo;
      _livelloController.text = dipendente.contratto.livello;
      _inizioContratto = dipendente.contratto.inizio;
      _fineContratto = dipendente.contratto.fine;
      if (dipendente.contratto.minutiSettimana > 0) {
        _oreContrattoController.text = formatOre(
          dipendente.contratto.minutiSettimana,
        );
      }
      _settimana = <String, List<FasciaOraria>>{
        for (final entry in dipendente.settimanaTipo.entries)
          entry.key: List<FasciaOraria>.of(entry.value),
      };
    }
  }

  @override
  void dispose() {
    QueryMgwsSite.changes.removeListener(_caricaSedi);
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    _emailAziendaleController.dispose();
    _telefonoController.dispose();
    _ruoloController.dispose();
    _stipendioController.dispose();
    _livelloController.dispose();
    _oreContrattoController.dispose();
    super.dispose();
  }

  double? _parseStipendio(String input) {
    var value = input.trim().replaceAll('€', '').replaceAll(' ', '');
    if (value.isEmpty) return null;

    final hasComma = value.contains(',');
    final hasDot = value.contains('.');
    if (hasComma && hasDot) {
      final comma = value.lastIndexOf(',');
      final dot = value.lastIndexOf('.');
      if (comma > dot) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (hasComma) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasDot && '.'.allMatches(value).length > 1) {
      value = value.replaceAll('.', '');
    }

    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  String? _validateStipendio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.employeesSalaryRequired;
    }
    if (_parseStipendio(value) == null) {
      return context.l10n.employeesSalaryInvalid;
    }
    return null;
  }

  String? _validaSettimana() {
    for (final giorno in FasciaOraria.giorni) {
      final fasce = List<FasciaOraria>.of(_settimana[giorno] ?? const [])
        ..sort((a, b) => a.inizio.compareTo(b.inizio));
      for (var i = 0; i < fasce.length; i++) {
        if (fasce[i].fine.compareTo(fasce[i].inizio) <= 0) {
          return context.l10n.employeesScheduleSlotInvalid(
            nomeGiorno(context, giorno),
          );
        }
        if (i > 0 && fasce[i].inizio.compareTo(fasce[i - 1].fine) < 0) {
          return context.l10n.employeesScheduleOverlap(
            nomeGiorno(context, giorno),
          );
        }
      }
    }
    return null;
  }

  InputDecoration _decorazione(String label, IconData icon, {String? helper}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon),
      );

  Widget _sezione(String titolo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(titolo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit ? l10n.employeesEditTitle : l10n.employeesAddTooltip,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final dati = _sezione(l10n.employeesPersonalInfo, <Widget>[
                    TextFormField(
                      controller: _nomeController,
                      decoration: _decorazione(l10n.commonName, Icons.person),
                      validator: (value) => value!.trim().isEmpty
                          ? l10n.employeesNameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cognomeController,
                      decoration: _decorazione(
                        l10n.employeesSurname,
                        Icons.person,
                      ),
                      validator: (value) => value!.trim().isEmpty
                          ? l10n.employeesSurnameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('employee-email-field'),
                      controller: _emailController,
                      decoration: _decorazione(
                        l10n.employeesPersonalEmail,
                        Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value!.trim().isNotEmpty && !value.contains('@')
                          ? l10n.employeesEmailInvalid
                          : null,
                    ),
                    SizedBox(key: _emailAziendaleKey, height: 16),
                    TextFormField(
                      key: const ValueKey('employee-work-email-field'),
                      forceErrorText: _erroreEmailAziendale,
                      controller: _emailAziendaleController,
                      decoration: _decorazione(
                        l10n.employeesWorkEmail,
                        Icons.alternate_email,
                        helper: _accesso == _Accesso.crea
                            ? l10n.employeesWorkEmailHelper
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) =>
                          setState(() => _erroreEmailAziendale = null),
                      validator: (value) {
                        final text = value!.trim();
                        if (text.isEmpty) {
                          return _accesso == _Accesso.crea
                              ? l10n.employeesWorkEmailRequired
                              : null;
                        }
                        return text.contains('@')
                            ? null
                            : l10n.employeesEmailInvalid;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('employee-phone-field'),
                      controller: _telefonoController,
                      decoration: _decorazione(
                        l10n.employeesPhone,
                        Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ruoloController,
                      decoration: _decorazione(
                        l10n.employeesRoleLabel,
                        Icons.work,
                      ),
                      validator: (value) => value!.trim().isEmpty
                          ? l10n.employeesRoleRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stipendioController,
                      decoration: _decorazione(
                        l10n.employeesSalaryLabel,
                        Icons.euro,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateStipendio,
                    ),
                  ]);
                  final accesso = _sezione(l10n.employeesAccessTitle, <Widget>[
                    _accessoSection(context),
                    if (_sedi != null && _sedi!.sites.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: const ValueKey('employee-site-field'),
                        initialValue:
                            _sedi!.sites.any((sede) => sede.id == _siteId)
                            ? _siteId
                            : null,
                        isExpanded: true,
                        decoration: _decorazione(
                          l10n.sedeDipendente,
                          Icons.store_outlined,
                          helper: _sedi!.sitesCount > 1
                              ? l10n.sedeDipendenteObbligatoria
                              : null,
                        ),
                        items: [
                          for (final sede in _sedi!.sites)
                            DropdownMenuItem(
                              value: sede.id,
                              child: Text(sede.name),
                            ),
                        ],
                        onChanged: (value) => setState(() => _siteId = value),
                        validator: (value) =>
                            _sedi!.sitesCount > 1 && value == null
                            ? l10n.sedeDipendenteObbligatoria
                            : null,
                      ),
                    ],
                  ]);
                  final contratto = _sezione(
                    l10n.employeesContractTitle,
                    _contrattoFields(context),
                  );
                  final settimana =
                      _sezione(l10n.employeesScheduleTitle, <Widget>[
                        Text(l10n.employeesScheduleHelper),
                        const SizedBox(height: 8),
                        SettimanaTipoEditor(
                          settimana: _settimana,
                          onChanged: (settimana) =>
                              setState(() => _settimana = settimana),
                        ),
                        const SizedBox(height: 8),
                        _totaleSettimana(context),
                      ]);
                  const gap = SizedBox(height: 16, width: 16);
                  // Wide screens get two columns: who the employee is and
                  // how they sign in on the left, contract and hours on the
                  // right, so the form fits without long scrolling.
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // One focus group per column: Tab finishes the left
                        // column before moving right, instead of jumping
                        // across the row.
                        Expanded(
                          child: FocusTraversalGroup(
                            child: Column(
                              children: <Widget>[dati, gap, accesso],
                            ),
                          ),
                        ),
                        gap,
                        Expanded(
                          child: FocusTraversalGroup(
                            child: Column(
                              children: <Widget>[contratto, gap, settimana],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: <Widget>[
                      dati,
                      gap,
                      accesso,
                      gap,
                      contratto,
                      gap,
                      settimana,
                    ],
                  );
                },
              ),
              if (!widget.isEdit) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.employeesDocumentsAfterSave),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveDipendente,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.isEdit
                      ? l10n.employeesSaveChanges
                      : l10n.employeesAddTooltip,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Totale della settimana tipo accanto alle ore del contratto; se non
  /// coincidono lo dice, in colore, invece di lasciarlo da notare.
  Widget _totaleSettimana(BuildContext context) {
    final l10n = context.l10n;
    final contratto = parseOreContratto(_oreContrattoController.text) ?? 0;
    final diverso = contratto > 0 && contratto != _minutiSettimana;
    final colore = diverso ? context.colors.warningColor : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.employeesScheduleVsContract(
            formatOre(_minutiSettimana),
            formatOre(contratto),
          ),
          key: const ValueKey('employee-schedule-total'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colore),
        ),
        if (diverso)
          Row(
            key: const ValueKey('employee-schedule-mismatch'),
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 18, color: colore),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.employeesScheduleMismatch(
                    formatOre(_minutiSettimana - contratto, segno: true),
                  ),
                  style: TextStyle(color: colore),
                ),
              ),
            ],
          ),
      ],
    );
  }

  int get _minutiSettimana => _settimana.values
      .expand((fasce) => fasce)
      .fold<int>(0, (sum, fascia) => sum + fascia.minuti);

  Future<void> _scegliData({required bool inizio}) async {
    final attuale = inizio ? _inizioContratto : _fineContratto;
    final scelta = await showDatePicker(
      context: context,
      initialDate: attuale ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (scelta == null || !mounted) return;
    setState(() {
      if (inizio) {
        _inizioContratto = scelta;
      } else {
        _fineContratto = scelta;
      }
    });
  }

  List<Widget> _contrattoFields(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMd(Localizations.localeOf(context).toString());
    Widget campoData(bool inizio) {
      final valore = inizio ? _inizioContratto : _fineContratto;
      // The whole field opens the calendar, not only the date text.
      return InkWell(
        key: ValueKey(
          inizio ? 'employee-contract-start' : 'employee-contract-end',
        ),
        onTap: () => _scegliData(inizio: inizio),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration:
              _decorazione(
                inizio
                    ? l10n.employeesContractStart
                    : l10n.employeesContractEnd,
                Icons.event,
              ).copyWith(
                errorText:
                    !inizio &&
                        _inizioContratto != null &&
                        _fineContratto != null &&
                        _fineContratto!.isBefore(_inizioContratto!)
                    ? l10n.employeesContractEndBeforeStart
                    : null,
                suffixIcon: valore == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          if (inizio) {
                            _inizioContratto = null;
                          } else {
                            _fineContratto = null;
                          }
                        }),
                      ),
              ),
          child: Text(valore == null ? '—' : date.format(valore)),
        ),
      );
    }

    return <Widget>[
      DropdownButtonFormField<TipoContratto?>(
        key: const ValueKey('employee-contract-type-field'),
        initialValue: _tipoContratto,
        isExpanded: true,
        decoration: _decorazione(
          l10n.employeesContractType,
          Icons.description_outlined,
        ),
        items: <DropdownMenuItem<TipoContratto?>>[
          DropdownMenuItem<TipoContratto?>(
            value: null,
            child: Text(l10n.employeesContractTypeNone),
          ),
          for (final tipo in TipoContratto.values)
            DropdownMenuItem<TipoContratto?>(
              value: tipo,
              child: Text(nomeTipoContratto(context, tipo)),
            ),
        ],
        onChanged: (value) => setState(() => _tipoContratto = value),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _livelloController,
        decoration: _decorazione(
          l10n.employeesContractLevel,
          Icons.stairs_outlined,
        ),
      ),
      const SizedBox(height: 16),
      campoData(true),
      const SizedBox(height: 16),
      if (_contrattoATermine) ...<Widget>[
        campoData(false),
        const SizedBox(height: 16),
      ],
      TextFormField(
        key: const ValueKey('employee-contract-hours-field'),
        controller: _oreContrattoController,
        decoration: _decorazione(
          l10n.employeesContractHours,
          Icons.timelapse,
          helper: l10n.employeesContractHoursHelper,
        ),
        keyboardType: TextInputType.datetime,
        onChanged: (_) => setState(() {}),
        validator: (value) => parseOreContratto(value ?? '') == null
            ? l10n.employeesContractHoursInvalid
            : null,
      ),
    ];
  }

  Future<void> _scegliUtente() async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _LinkableUserDialog(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _wpUserId = (picked['id'] as num?)?.toInt() ?? 0;
      final name = (picked['display_name'] ?? '').toString();
      final login = (picked['login'] ?? '').toString();
      _wpUserLabel = name.isNotEmpty && name != login
          ? '$name ($login)'
          : login;
      final email = (picked['email'] ?? '').toString();
      if (_emailAziendaleController.text.trim().isEmpty && email.isNotEmpty) {
        _emailAziendaleController.text = email;
      }
    });
  }

  Widget _accessoSection(BuildContext context) {
    final l10n = context.l10n;
    final emailAccesso = _emailAziendaleController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!_eraCollegato) ...<Widget>[
          SegmentedButton<_Accesso>(
            segments: <ButtonSegment<_Accesso>>[
              ButtonSegment<_Accesso>(
                value: _Accesso.crea,
                icon: const Icon(Icons.person_add),
                label: Text(l10n.employeesAccessCreate),
              ),
              ButtonSegment<_Accesso>(
                value: _Accesso.collega,
                icon: const Icon(Icons.link),
                label: Text(l10n.employeesAccessLink),
              ),
            ],
            selected: <_Accesso>{_accesso},
            onSelectionChanged: (selection) => setState(() {
              _accesso = selection.first;
              _wpUserId = 0;
              _wpUserLabel = '';
            }),
          ),
          const SizedBox(height: 8),
        ],
        if (_accesso == _Accesso.crea) ...<Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle),
            title: Text(
              emailAccesso.isEmpty
                  ? l10n.employeesWorkEmailRequired
                  : l10n.employeesLoginWillBe(emailAccesso),
            ),
          ),
          if (_sets.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: const ValueKey('employee-permission-set-field'),
              initialValue: _setId,
              isExpanded: true,
              decoration:
                  _decorazione(
                    l10n.employeesPermissionSet,
                    Icons.verified_user_outlined,
                    helper: _setId == null
                        ? l10n.employeesPermissionSetNoneWarning
                        : null,
                  ).copyWith(
                    helperStyle: _setId == null
                        ? TextStyle(color: context.colors.warningColor)
                        : null,
                  ),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.employeesPermissionSetNone),
                ),
                for (final set in _sets)
                  DropdownMenuItem<int?>(
                    value: (set['id'] as num?)?.toInt(),
                    child: Text(nomeSetPermessi(l10n, set)),
                  ),
              ],
              onChanged: (value) => setState(() => _setId = value),
            ),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _inviaInvito,
            onChanged: (value) => setState(() => _inviaInvito = value ?? false),
            title: Text(l10n.employeesSendInvite),
            subtitle: Text(l10n.employeesSendInviteHelper),
          ),
        ],
        if (_accesso == _Accesso.collega)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle),
            title: Text(
              _wpUserId > 0 ? _wpUserLabel : l10n.employeesLinkNoneChosen,
            ),
            trailing: _eraCollegato
                ? null
                : TextButton(
                    onPressed: _scegliUtente,
                    child: Text(l10n.employeesLinkChoose),
                  ),
          ),
      ],
    );
  }

  Future<void> _saveDipendente() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    void avvisa(String testo) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(testo)));
    if (_accesso == _Accesso.collega && _wpUserId <= 0) {
      avvisa(l10n.employeesLinkNoneChosen);
      return;
    }
    if (_contrattoATermine &&
        _inizioContratto != null &&
        _fineContratto != null &&
        _fineContratto!.isBefore(_inizioContratto!)) {
      avvisa(l10n.employeesContractEndBeforeStart);
      return;
    }
    final erroreSettimana = _validaSettimana();
    if (erroreSettimana != null) {
      avvisa(erroreSettimana);
      return;
    }
    final stipendio = _parseStipendio(_stipendioController.text)!;
    final wpUserId = _accesso == _Accesso.collega ? _wpUserId : 0;
    final account = _accesso == _Accesso.crea
        ? <String, dynamic>{
            'create_wp_user': true,
            if (_setId != null) 'permission_set_id': _setId,
            'send_invite': _inviaInvito,
            if (_siteId != null) 'site_id': _siteId,
          }
        : null;
    final dipendente = Dipendente(
      id: widget.isEdit ? widget.dipendente!.id : 0,
      wpUserId: wpUserId,
      siteId: wpUserId > 0 ? (_siteId ?? 0) : 0,
      nome: _nomeController.text,
      cognome: _cognomeController.text,
      email: _emailController.text,
      emailAziendale: _emailAziendaleController.text,
      telefono: _telefonoController.text,
      ruolo: _ruoloController.text,
      stipendio: stipendio,
      settimanaTipo: _settimana,
      contratto: Contratto(
        tipo: _tipoContratto,
        livello: _livelloController.text,
        inizio: _inizioContratto,
        fine: _contrattoATermine ? _fineContratto : null,
        minutiSettimana: parseOreContratto(_oreContrattoController.text) ?? 0,
      ),
    );
    final ok = widget.isEdit
        ? await widget.service.updateDipendente(dipendente, account: account)
        : await widget.service.addDipendente(dipendente, account: account);
    if (!mounted) return;
    if (!ok) {
      final errore = widget.service.ultimaEccezione;
      if (errore is MgwsEmployeeException &&
          errore.code == 'mgws_email_exists') {
        final collegatoA = (errore.data['linked_employee_name'] ?? '')
            .toString();
        setState(() {
          _erroreEmailAziendale = collegatoA.isNotEmpty
              ? l10n.employeesEmailLinkedTo(collegatoA)
              : l10n.employeesErrEmailExists;
        });
        final campo = _emailAziendaleKey.currentContext;
        if (campo != null) {
          await Scrollable.ensureVisible(
            campo,
            duration: const Duration(milliseconds: 300),
            alignment: 0.2,
          );
        }
        return;
      }
      avvisa(
        widget.service.errore?.call(context.l10n) ??
            context.l10n.employeesOperationFailed,
      );
      return;
    }
    // The list underneath shares the messenger, so the message outlives the
    // form that closes now.
    avvisa(
      widget.isEdit
          ? l10n.employeesChangesSaved
          : l10n.employeesCreated(dipendente.nomeCompleto),
    );
    Navigator.pop(context);
  }
}

/// Ricerca di un utente WordPress non ancora collegato a un dipendente.
class _LinkableUserDialog extends StatefulWidget {
  const _LinkableUserDialog();

  @override
  State<_LinkableUserDialog> createState() => _LinkableUserDialogState();
}

class _LinkableUserDialogState extends State<_LinkableUserDialog> {
  final QueryMgwsEmployees _api = QueryMgwsEmployees();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _cerca(String text) async {
    final request = ++_request;
    if (text.trim().length < 2) {
      setState(() => _items = const <Map<String, dynamic>>[]);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.linkableUsers(text);
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.employeesLinkChoose),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.employeesLinkSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _cerca,
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            Expanded(
              child: _items.isEmpty
                  ? Center(child: Text(l10n.employeesLinkSearchHint))
                  : ListView(
                      children: <Widget>[
                        for (final item in _items)
                          ListTile(
                            title: Text(
                              (item['display_name'] ?? item['login'] ?? '')
                                  .toString(),
                            ),
                            subtitle: Text(
                              '${item['login'] ?? ''} · ${item['email'] ?? ''}',
                            ),
                            onTap: () => Navigator.of(context).pop(item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class DipendenteDetailScreen extends StatelessWidget {
  final Dipendente dipendente;

  const DipendenteDetailScreen({super.key, required this.dipendente});

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${dipendente.nome} ${dipendente.cognome}'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informazioni personali
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withAlpha(51),
                          child: Text(
                            '${dipendente.nome.isNotEmpty ? dipendente.nome[0] : '?'}${dipendente.cognome.isNotEmpty ? dipendente.cognome[0] : '?'}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${dipendente.nome} ${dipendente.cognome}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dipendente.ruolo,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: context.colors.subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      Icons.email_outlined,
                      context.l10n.employeesPersonalEmail,
                      dipendente.email.isEmpty ? '—' : dipendente.email,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.alternate_email,
                      context.l10n.employeesWorkEmail,
                      dipendente.emailAziendale.isEmpty
                          ? '—'
                          : dipendente.emailAziendale,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.phone,
                      context.l10n.employeesPhone,
                      dipendente.telefono.isEmpty ? '—' : dipendente.telefono,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.account_circle,
                      context.l10n.employeesWordPressUser,
                      dipendente.wpUserId <= 0
                          ? context.l10n.employeesNotLinked
                          : (dipendente.wpUserLogin.isNotEmpty
                                ? dipendente.wpUserLogin
                                : '#${dipendente.wpUserId}'),
                    ),
                    _buildInfoRow(
                      context,
                      Icons.euro,
                      context.l10n.employeesSalaryTitle,
                      '€${dipendente.stipendio.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _contrattoCard(context),
            const SizedBox(height: 16),
            _orariCard(context),
            const SizedBox(height: 16),
            _DipendenteAccessoPermessiCard(dipendente: dipendente),
            const SizedBox(height: 16),
            DipendenteDocumentiCard(dipendente: dipendente),
          ],
        ),
      ),
    );
  }

  Widget _titoloCard(String testo) => Text(
    testo,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );

  Widget _contrattoCard(BuildContext context) {
    final l10n = context.l10n;
    final contratto = dipendente.contratto;
    final data = DateFormat.yMd(Localizations.localeOf(context).toString());
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _titoloCard(l10n.employeesContractTitle),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              Icons.description_outlined,
              l10n.employeesContractType,
              contratto.tipo == null
                  ? l10n.employeesContractTypeNone
                  : nomeTipoContratto(context, contratto.tipo!),
            ),
            _buildInfoRow(
              context,
              Icons.stairs_outlined,
              l10n.employeesContractLevel,
              contratto.livello.isEmpty ? '—' : contratto.livello,
            ),
            _buildInfoRow(
              context,
              Icons.event,
              l10n.employeesContractStart,
              contratto.inizio == null ? '—' : data.format(contratto.inizio!),
            ),
            _buildInfoRow(
              context,
              Icons.event_busy,
              l10n.employeesContractEnd,
              contratto.fine == null ? '—' : data.format(contratto.fine!),
            ),
            _buildInfoRow(
              context,
              Icons.timelapse,
              l10n.employeesContractHours,
              contratto.minutiSettimana == 0
                  ? '—'
                  : formatOre(contratto.minutiSettimana),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orariCard(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _titoloCard(l10n.employeesScheduleTitle)),
                FilledButton.tonalIcon(
                  key: const ValueKey('employee-open-shifts'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DipendenteTurniScreen(dipendente: dipendente),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(l10n.employeesShiftsOpen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SettimanaTipoView(settimana: dipendente.settimanaTipo),
            const SizedBox(height: 8),
            Text(
              l10n.employeesScheduleVsContract(
                formatOre(dipendente.minutiSettimanaTipo),
                formatOre(dipendente.contratto.minutiSettimana),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DipendenteAccessoPermessiCard extends StatefulWidget {
  final Dipendente dipendente;

  const _DipendenteAccessoPermessiCard({required this.dipendente});

  @override
  State<_DipendenteAccessoPermessiCard> createState() =>
      _DipendenteAccessoPermessiCardState();
}

class _DipendenteAccessoPermessiCardState
    extends State<_DipendenteAccessoPermessiCard> {
  Set<String> _capabilityWhitelist = <String>{};

  final QueryUserWordPress _userApi = PlatformManager.permessiUtente;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  Map<String, bool> _capabilities = <String, bool>{};
  List<String> _roles = <String>[];
  List<String> _editableRoles = <String>[];
  final Set<String> _selectedRoles = <String>{};
  final Map<String, bool> _capabilityChanges = <String, bool>{};
  Map<String, String> _roleLabels = <String, String>{};

  bool _isLoadingCredentials = false;
  String? _credentialsError;
  bool _credentialsForbidden = false;
  List<_CredenzialeRiga> _appPasswords = <_CredenzialeRiga>[];
  List<_CredenzialeRiga> _wooApiKeys = <_CredenzialeRiga>[];

  int get _wpUserId => widget.dipendente.wpUserId;

  @override
  void initState() {
    super.initState();
    if (_wpUserId > 0) {
      _loadPermissions();
      _loadCredentials();
    }
  }

  Future<void> _loadPermissions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _userApi.getUserPermissions(_wpUserId);
      final capsRaw = data['capabilities'];
      final rolesRaw = data['roles'];
      final editableRaw = data['editable_roles'];
      final whitelistRaw = data['capability_whitelist'];
      final roleLabelsRaw = data['role_labels'];
      final caps = <String, bool>{};
      if (capsRaw is Map) {
        for (final entry in capsRaw.entries) {
          caps[entry.key.toString()] = entry.value == true;
        }
      }
      final roles = rolesRaw is List
          ? rolesRaw.map((role) => role.toString()).toList()
          : <String>[];
      final editable = editableRaw is List
          ? editableRaw.map((role) => role.toString()).toList()
          : <String>[];
      final whitelist = whitelistRaw is List
          ? whitelistRaw.map((item) => item.toString()).toSet()
          : <String>{};
      final roleLabels = <String, String>{};
      if (roleLabelsRaw is Map) {
        for (final entry in roleLabelsRaw.entries) {
          roleLabels[entry.key.toString()] = entry.value.toString();
        }
      }
      if (!mounted) return;
      setState(() {
        _capabilities = caps;
        _roles = roles;
        _editableRoles = editable;
        _selectedRoles
          ..clear()
          ..addAll(roles);
        _capabilityChanges.clear();
        if (whitelist.isNotEmpty) {
          _capabilityWhitelist = whitelist;
        }
        _roleLabels = roleLabels;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.employeesPermissionsLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveRoles() async {
    if (_selectedRoles.isEmpty) {
      _showMessage(context.l10n.employeesSelectRoleFirst);
      return;
    }
    await _save(() async {
      final updated = await _userApi.updateUserPermissions(
        userId: _wpUserId,
        roles: _selectedRoles.toList()..sort(),
      );
      _applyUpdatedPermissions(updated);
      _showMessage(context.l10n.employeesRolesUpdated);
    });
  }

  Future<void> _saveCapabilities() async {
    final filtered = <String, bool>{};
    _capabilityChanges.forEach((key, value) {
      if (_capabilityWhitelist.contains(key)) {
        filtered[key] = value;
      }
    });
    if (filtered.isEmpty) {
      _showMessage(context.l10n.employeesNoCapabilitySelected);
      return;
    }
    await _save(() async {
      final updated = await _userApi.updateUserPermissions(
        userId: _wpUserId,
        capabilities: filtered,
      );
      _applyUpdatedPermissions(updated);
      _capabilityChanges.clear();
      _showMessage(context.l10n.employeesCapabilitiesUpdated);
    });
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.employeesSaveError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _applyUpdatedPermissions(Map<String, dynamic> updated) {
    final capsRaw = updated['capabilities'];
    final rolesRaw = updated['roles'];
    setState(() {
      if (capsRaw is Map) {
        _capabilities = {
          for (final entry in capsRaw.entries)
            entry.key.toString(): entry.value == true,
        };
      }
      if (rolesRaw is List) {
        _roles = rolesRaw.map((role) => role.toString()).toList();
        _selectedRoles
          ..clear()
          ..addAll(_roles);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Carica Application Password e Woo API key del dipendente collegato.
  ///
  /// Le credenziali non vengono generate dall'app: l'Application Password del
  /// dispositivo e gia provisionata dal login wp-admin. Qui si legge e si revoca.
  Future<void> _loadCredentials() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCredentials = true;
      _credentialsError = null;
      _credentialsForbidden = false;
    });
    try {
      final appResponse = await _userApi.listApplicationPasswords(_wpUserId);
      final wooResponse = await _userApi.listWooApiKeys(_wpUserId);
      if (!mounted) return;
      setState(() {
        _appPasswords = _readCredentialItems(appResponse, (item) {
          final uuid = (item['uuid'] ?? '').toString();
          if (uuid.isEmpty) return null;
          final lastUsed = (item['last_used'] ?? '').toString();
          return _CredenzialeRiga(
            id: uuid,
            titolo: (item['name'] ?? context.l10n.employeesUnnamed).toString(),
            dettaglio: lastUsed.isEmpty
                ? context.l10n.employeesNeverUsed
                : context.l10n.employeesLastUsed(lastUsed),
          );
        });
        _wooApiKeys = _readCredentialItems(wooResponse, (item) {
          final keyId = (item['key_id'] as num?)?.toInt() ?? 0;
          if (keyId <= 0) return null;
          final permissions = (item['permissions'] ?? '').toString();
          final truncated = (item['truncated_key'] ?? '').toString();
          return _CredenzialeRiga(
            id: keyId.toString(),
            titolo: (item['description'] ?? context.l10n.employeesNoDescription)
                .toString(),
            dettaglio: truncated.isEmpty
                ? permissions.toUpperCase()
                : '${permissions.toUpperCase()} - ...$truncated',
          );
        });
      });
    } on PermessiUtenteException catch (error) {
      if (!mounted) return;
      setState(() {
        _credentialsForbidden = error.nonAutorizzato;
        _credentialsError = error.nonAutorizzato
            ? context.l10n.employeesCredentialsRequireAdmin
            : error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _credentialsError = context.l10n.employeesCredentialsLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCredentials = false;
        });
      }
    }
  }

  List<_CredenzialeRiga> _readCredentialItems(
    Map<String, dynamic> response,
    _CredenzialeRiga? Function(Map<String, dynamic> item) builder,
  ) {
    final raw = response['items'];
    if (raw is! List) return <_CredenzialeRiga>[];
    final rows = <_CredenzialeRiga>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final row = builder(Map<String, dynamic>.from(entry));
      if (row != null) rows.add(row);
    }
    return rows;
  }

  Future<void> _revocaCredenziale(
    _CredenzialeRiga riga,
    bool isAppPassword,
  ) async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.employeesRevokeTitle),
        content: Text(context.l10n.employeesRevokeBody(riga.titolo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.employeesRevoke),
          ),
        ],
      ),
    );
    if (confermato != true) return;

    try {
      if (isAppPassword) {
        await _userApi.deleteApplicationPassword(
          userId: _wpUserId,
          uuid: riga.id,
        );
      } else {
        await _userApi.deleteWooApiKey(
          userId: _wpUserId,
          keyId: int.parse(riga.id),
        );
      }
      _showMessage(context.l10n.employeesRevoked);
      await _loadCredentials();
    } on PermessiUtenteException catch (error) {
      _showMessage(
        error.nonAutorizzato
            ? context.l10n.employeesOperationDenied
            : error.message,
      );
    } catch (error) {
      _showMessage(context.l10n.employeesRevokeFailed(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.employeesAccessPermissions,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_wpUserId > 0)
                  IconButton(
                    tooltip: context.l10n.employeesReloadPermissions,
                    onPressed: _isLoading || _isSaving
                        ? null
                        : _loadPermissions,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_wpUserId <= 0)
              Text(context.l10n.employeesNotLinkedNotice)
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_error != null) ...[
                MaterialBanner(
                  content: Text(_error!),
                  leading: const Icon(Icons.warning_amber),
                  actions: [
                    TextButton(
                      onPressed: _loadPermissions,
                      child: Text(context.l10n.employeesRetry),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(context.l10n.employeesWpUserNumber(_wpUserId)),
              const SizedBox(height: 12),
              _buildRolesSection(),
              const Divider(height: 28),
              _buildCapabilitiesSection(),
              const Divider(height: 28),
              _buildCredentialsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolesSection() {
    final rolesUi = _editableRoles.isNotEmpty ? _editableRoles : _roles;
    if (rolesUi.isEmpty) {
      return Text(context.l10n.employeesNoRolesAvailable);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.employeesRoles,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rolesUi
              .map(
                (role) => FilterChip(
                  label: Text(_roleLabels[role] ?? role),
                  tooltip: role,
                  selected: _selectedRoles.contains(role),
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedRoles.add(role);
                            } else if (_selectedRoles.length > 1) {
                              _selectedRoles.remove(role);
                            }
                          });
                        },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveRoles,
          icon: const Icon(Icons.save),
          label: Text(
            _isSaving
                ? context.l10n.employeesSaving
                : context.l10n.employeesSaveRoles,
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilitiesSection() {
    final visibleCapabilities =
        _capabilities.keys.where(_capabilityWhitelist.contains).toList()
          ..sort();
    if (visibleCapabilities.isEmpty) {
      return Text(context.l10n.employeesNoCapabilitiesAvailable);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.employeesMgwsCapabilities,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...visibleCapabilities.map(
          (capability) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(capability),
            value:
                _capabilityChanges[capability] ??
                (_capabilities[capability] == true),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _capabilityChanges[capability] = value;
                    });
                  },
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveCapabilities,
          icon: const Icon(Icons.save),
          label: Text(
            _isSaving
                ? context.l10n.employeesSaving
                : context.l10n.employeesSaveCapabilities,
          ),
        ),
      ],
    );
  }

  /// Credenziali attive del dipendente collegato: sola lettura e revoca.
  ///
  /// L'app non genera credenziali. L'Application Password del dispositivo viene
  /// gia provisionata dal login wp-admin e le chiavi WooCommerce si creano da
  /// wp-admin, quindi qui ha senso solo controllare e revocare.
  Widget _buildCredentialsSection() {
    if (_credentialsForbidden) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.employeesActiveCredentials,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _credentialsError!,
            style: TextStyle(color: context.colors.subtitleColor),
          ),
        ],
      );
    }

    if (_isLoadingCredentials) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final vuote = _appPasswords.isEmpty && _wooApiKeys.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.employeesActiveCredentials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: context.l10n.employeesRefreshCredentials,
              onPressed: _loadCredentials,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.employeesCredentialsNote,
          style: TextStyle(fontSize: 12, color: context.colors.subtitleColor),
        ),
        if (_credentialsError != null) ...[
          const SizedBox(height: 8),
          Text(
            _credentialsError!,
            style: TextStyle(color: context.colors.errorColorStatus),
          ),
        ],
        const SizedBox(height: 8),
        if (vuote)
          Text(context.l10n.employeesNoActiveCredentials)
        else ...[
          if (_appPasswords.isNotEmpty) ...[
            // "Application Password" e il nome della feature WordPress: non si traduce.
            Text(
              context.l10n.employeesApplicationPassword,
              style: const TextStyle(fontSize: 13),
            ),
            ..._appPasswords.map(
              (riga) => _buildCredenzialeTile(riga, isAppPassword: true),
            ),
          ],
          if (_wooApiKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.employeesWooKeys,
              style: const TextStyle(fontSize: 13),
            ),
            ..._wooApiKeys.map(
              (riga) => _buildCredenzialeTile(riga, isAppPassword: false),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCredenzialeTile(
    _CredenzialeRiga riga, {
    required bool isAppPassword,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(riga.titolo),
      subtitle: Text(riga.dettaglio),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: context.l10n.employeesRevoke,
        onPressed: () => _revocaCredenziale(riga, isAppPassword),
      ),
    );
  }
}

/// Riga di una credenziale attiva, gia normalizzata per la UI.
class _CredenzialeRiga {
  final String id;
  final String titolo;
  final String dettaglio;

  const _CredenzialeRiga({
    required this.id,
    required this.titolo,
    required this.dettaglio,
  });
}
