import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../login/jwt_api/query_wordpress/query_user_wordpress.dart';
import '../login/mgws/query/query_mgws_site.dart';
import '../theme/theme.dart';
import 'employees.code.dart'; // Import the code file for logic
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
  final _wpUserIdController = TextEditingController();
  final _ruoloController = TextEditingController();
  final _stipendioController = TextEditingController();

  /// Sedi del negozio e sede scelta per l'utente collegato. Con piu' sedi e'
  /// obbligatoria: senza, quell'utente non puo' usare l'inventario.
  MgwsSiteStatus? _sedi;
  int? _siteId;

  bool get _haUtente =>
      (int.tryParse(_wpUserIdController.text.trim()) ?? 0) > 0;

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
    } on MgwsSiteException {
      // Senza sedi leggibili il campo non compare: il server rifiutera'
      // comunque un dipendente senza sede quando e' obbligatoria.
    }
  }

  @override
  void initState() {
    super.initState();
    _wpUserIdController.addListener(() => setState(() {}));
    // Chi non gestisce le sedi vede solo quella in uso: se cambia, il menu
    // proporrebbe quella di prima.
    QueryMgwsSite.changes.addListener(_caricaSedi);
    _caricaSedi();
    if (widget.isEdit && widget.dipendente != null) {
      if (widget.dipendente!.siteId > 0) {
        _siteId = widget.dipendente!.siteId;
      }
      _nomeController.text = widget.dipendente!.nome;
      _cognomeController.text = widget.dipendente!.cognome;
      _emailController.text = widget.dipendente!.email;
      if (widget.dipendente!.wpUserId > 0) {
        _wpUserIdController.text = widget.dipendente!.wpUserId.toString();
      }
      _ruoloController.text = widget.dipendente!.ruolo;
      _stipendioController.text = _salaryFormat.format(
        widget.dipendente!.stipendio,
      );
    }
  }

  @override
  void dispose() {
    QueryMgwsSite.changes.removeListener(_caricaSedi);
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    _wpUserIdController.dispose();
    _ruoloController.dispose();
    _stipendioController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? context.l10n.employeesEditTitle
              : context.l10n.employeesAddTooltip,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        decoration: InputDecoration(
                          labelText: context.l10n.commonName,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) => value!.isEmpty
                            ? context.l10n.employeesNameRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cognomeController,
                        decoration: InputDecoration(
                          labelText: context.l10n.employeesSurname,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) => value!.isEmpty
                            ? context.l10n.employeesSurnameRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: context.l10n.employeesEmailLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => !value!.contains('@')
                            ? context.l10n.employeesEmailInvalid
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _wpUserIdController,
                        decoration: InputDecoration(
                          labelText: context.l10n.employeesWpUserId,
                          helperText: context.l10n.employeesWpUserIdHelper,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.account_circle),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return null;
                          final parsed = int.tryParse(trimmed);
                          if (parsed == null || parsed <= 0) {
                            return context.l10n.employeesWpUserIdInvalid;
                          }
                          return null;
                        },
                      ),
                      if (_sedi != null && _sedi!.sites.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: const ValueKey('employee-site-field'),
                          initialValue:
                              _sedi!.sites.any((sede) => sede.id == _siteId)
                              ? _siteId
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.sedeDipendente,
                            helperText: !_haUtente
                                ? context.l10n.sedeDipendenteSenzaUtente
                                : (_sedi!.sitesCount > 1
                                      ? context.l10n.sedeDipendenteObbligatoria
                                      : null),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.store_outlined),
                          ),
                          items: [
                            for (final sede in _sedi!.sites)
                              DropdownMenuItem(
                                value: sede.id,
                                child: Text(sede.name),
                              ),
                          ],
                          onChanged: _haUtente
                              ? (value) => setState(() => _siteId = value)
                              : null,
                          validator: (value) =>
                              _haUtente &&
                                  _sedi!.sitesCount > 1 &&
                                  value == null
                              ? context.l10n.sedeDipendenteObbligatoria
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ruoloController,
                        decoration: InputDecoration(
                          labelText: context.l10n.employeesRoleLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.work),
                        ),
                        validator: (value) => value!.isEmpty
                            ? context.l10n.employeesRoleRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _stipendioController,
                        decoration: InputDecoration(
                          labelText: context.l10n.employeesSalaryLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.euro),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateStipendio,
                      ),
                    ],
                  ),
                ),
              ),
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
                      ? context.l10n.employeesSaveChanges
                      : context.l10n.employeesAddTooltip,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDipendente() async {
    if (_formKey.currentState!.validate()) {
      final stipendio = _parseStipendio(_stipendioController.text)!;
      final wpUserId = int.tryParse(_wpUserIdController.text.trim()) ?? 0;
      final dipendente = Dipendente(
        id: widget.isEdit ? widget.dipendente!.id : 0,
        wpUserId: wpUserId,
        siteId: wpUserId > 0 ? (_siteId ?? 0) : 0,
        nome: _nomeController.text,
        cognome: _cognomeController.text,
        email: _emailController.text,
        ruolo: _ruoloController.text,
        stipendio: stipendio,
        // Per ora non aggiungiamo i nuovi campi nella form, solo nel modello
      );
      final ok = widget.isEdit
          ? await widget.service.updateDipendente(dipendente)
          : await widget.service.addDipendente(dipendente);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.service.errore?.call(context.l10n) ??
                  context.l10n.employeesOperationFailed,
            ),
          ),
        );
        return;
      }
      Navigator.pop(context);
    }
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: color, fontSize: 12),
            textAlign: TextAlign.center,
          ),
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
                      Icons.email,
                      context.l10n.employeesEmailLabel,
                      dipendente.email,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.account_circle,
                      context.l10n.employeesWordPressUser,
                      dipendente.wpUserId > 0
                          ? '#${dipendente.wpUserId}'
                          : context.l10n.employeesNotLinked,
                    ),
                    _buildInfoRow(
                      context,
                      Icons.phone,
                      context.l10n.employeesPhone,
                      'N/A',
                    ), // Placeholder
                    if (dipendente.dataNascita != null)
                      _buildInfoRow(
                        context,
                        Icons.cake,
                        context.l10n.employeesBirthDate,
                        '${dipendente.dataNascita!.day}/${dipendente.dataNascita!.month}/${dipendente.dataNascita!.year}',
                      ),
                    if (dipendente.dataAssunzione != null)
                      _buildInfoRow(
                        context,
                        Icons.work,
                        context.l10n.employeesHireDate,
                        '${dipendente.dataAssunzione!.day}/${dipendente.dataAssunzione!.month}/${dipendente.dataAssunzione!.year}',
                      ),
                    if (dipendente.tipoContratto != null)
                      _buildInfoRow(
                        context,
                        Icons.description,
                        context.l10n.employeesContractType,
                        dipendente.tipoContratto!,
                      ),
                    if (dipendente.orarioLavoro != null)
                      _buildInfoRow(
                        context,
                        Icons.schedule,
                        context.l10n.employeesWorkHours,
                        dipendente.orarioLavoro!,
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
            _DipendenteAccessoPermessiCard(dipendente: dipendente),
            const SizedBox(height: 16),
            // Performance
            if (dipendente.venditeTotali != null ||
                dipendente.produzioneTotale != null)
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
                      Text(
                        context.l10n.employeesPerformance,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dipendente.venditeTotali != null)
                        _buildInfoRow(
                          context,
                          Icons.trending_up,
                          context.l10n.employeesTotalSalesTitle,
                          '€${dipendente.venditeTotali!.toStringAsFixed(2)}',
                        ),
                      if (dipendente.produzioneTotale != null)
                        _buildInfoRow(
                          context,
                          Icons.factory,
                          context.l10n.employeesTotalProductionTitle,
                          context.l10n.employeesProductionUnits(
                            '${dipendente.produzioneTotale}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Ferie e malattie
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
                    Text(
                      context.l10n.employeesLeaveAndSickness,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context.l10n.employeesLeaveAvailable,
                            dipendente.giorniFerieDisponibili.toString(),
                            context.colors.successColor,
                            Icons.beach_access,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context.l10n.employeesLeaveUsed,
                            dipendente.giorniFerieUsati.toString(),
                            context.colors.infoColor,
                            Icons.calendar_today,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      context.l10n.employeesSickDays,
                      dipendente.giorniMalattia.toString(),
                      context.colors.errorColorStatus,
                      Icons.sick,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Benefici
            if (dipendente.benefici != null && dipendente.benefici!.isNotEmpty)
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
                      Text(
                        context.l10n.employeesBenefits,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...dipendente.benefici!.map(
                        (beneficio) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: context.colors.successColor,
                              ),
                              const SizedBox(width: 8),
                              Text(beneficio),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Formazione
            if (dipendente.formazione != null &&
                dipendente.formazione!.isNotEmpty)
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
                      Text(
                        context.l10n.employeesTraining,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...dipendente.formazione!.map(
                        (corso) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.school,
                                color: context.colors.infoColor,
                              ),
                              const SizedBox(width: 8),
                              Text(corso),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Valutazioni
            if (dipendente.valutazioni != null &&
                dipendente.valutazioni!.isNotEmpty)
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
                      Text(
                        context.l10n.employeesReviews,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...dipendente.valutazioni!.map(
                        (valutazione) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: context.colors.warningColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${valutazione['anno']}: ${valutazione['valutazione']}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Documenti
            if (dipendente.documenti != null &&
                dipendente.documenti!.isNotEmpty)
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
                      Text(
                        context.l10n.employeesDocuments,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...dipendente.documenti!.map(
                        (documento) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_file,
                                color: context.colors.neutralColor,
                              ),
                              const SizedBox(width: 8),
                              Text(documento),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  static const Set<String> _capabilityWhitelist = {
    'read',
    'mgws_stock_read',
    'mgws_stock_move',
    'mgws_order_accept',
    'mgws_reports_read',
  };

  final QueryUserWordPress _userApi = PlatformManager.permessiUtente;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  Map<String, bool> _capabilities = <String, bool>{};
  List<String> _roles = <String>[];
  List<String> _editableRoles = <String>[];
  final Set<String> _selectedRoles = <String>{};
  final Map<String, bool> _capabilityChanges = <String, bool>{};

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
      if (!mounted) return;
      setState(() {
        _capabilities = caps;
        _roles = roles;
        _editableRoles = editable;
        _selectedRoles
          ..clear()
          ..addAll(roles);
        _capabilityChanges.clear();
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
                  label: Text(role),
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
