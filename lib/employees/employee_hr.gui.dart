import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/extensions.dart';
import '../reuse_class/logic/save_file_dialog.dart';
import 'employees.code.dart';

/// Nome del giorno ('mon'..'sun') nella lingua dell'app.
String nomeGiorno(BuildContext context, String giorno) {
  // 2024-01-01 e' un lunedi': l'indice del giorno da' la data giusta.
  final data = DateTime(2024, 1, 1 + FasciaOraria.giorni.indexOf(giorno));
  return DateFormat.EEEE(
    Localizations.localeOf(context).toString(),
  ).format(data);
}

String nomeTipoContratto(BuildContext context, TipoContratto tipo) {
  final l10n = context.l10n;
  return switch (tipo) {
    TipoContratto.permanent => l10n.employeesContractPermanent,
    TipoContratto.fixedTerm => l10n.employeesContractFixedTerm,
    TipoContratto.apprenticeship => l10n.employeesContractApprenticeship,
    TipoContratto.internship => l10n.employeesContractInternship,
    TipoContratto.other => l10n.employeesContractOther,
  };
}

String nomeTipoDocumento(BuildContext context, TipoDocumento tipo) {
  final l10n = context.l10n;
  return switch (tipo) {
    TipoDocumento.contract => l10n.employeesDocumentContract,
    TipoDocumento.idDocument => l10n.employeesDocumentIdCard,
    TipoDocumento.other => l10n.employeesDocumentOther,
  };
}

/// Settimana tipo: per ogni giorno fino a tre fasce di lavoro. Un giorno
/// senza fasce e' di riposo. Gli orari si scrivono a tastiera ("9:30",
/// "930", "9"), e il lunedi' si copia sui giorni feriali con un click.
class SettimanaTipoEditor extends StatelessWidget {
  const SettimanaTipoEditor({
    super.key,
    required this.settimana,
    required this.onChanged,
  });

  final Map<String, List<FasciaOraria>> settimana;
  final ValueChanged<Map<String, List<FasciaOraria>>> onChanged;

  static const int _maxFasce = 3;

  /// Giorni su cui si copia il lunedi'.
  static const List<String> _feriali = <String>['tue', 'wed', 'thu', 'fri'];

  void _aggiorna(String giorno, List<FasciaOraria> fasce) {
    onChanged(<String, List<FasciaOraria>>{...settimana, giorno: fasce});
  }

  void _modificaOra(
    String giorno,
    int indice,
    String ora, {
    required bool inizio,
  }) {
    final fasce = List<FasciaOraria>.of(settimana[giorno] ?? const []);
    final fascia = fasce[indice];
    fasce[indice] = inizio
        ? FasciaOraria(ora, fascia.fine)
        : FasciaOraria(fascia.inizio, ora);
    _aggiorna(giorno, fasce);
  }

  void _copiaLunedi() {
    final lunedi = List<FasciaOraria>.of(settimana['mon'] ?? const []);
    onChanged(<String, List<FasciaOraria>>{
      ...settimana,
      for (final giorno in _feriali) giorno: List<FasciaOraria>.of(lunedi),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lunedi = settimana['mon'] ?? const <FasciaOraria>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final giorno in FasciaOraria.giorni)
          Padding(
            key: ValueKey('schedule-day-$giorno'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 100,
                  child: Text(
                    nomeGiorno(context, giorno),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if ((settimana[giorno] ?? const []).isEmpty)
                        Text(l10n.employeesScheduleDayOff),
                      for (
                        var i = 0;
                        i < (settimana[giorno] ?? const []).length;
                        i++
                      )
                        _FasciaEditor(
                          key: ValueKey('schedule-$giorno-$i'),
                          fascia: settimana[giorno]![i],
                          onInizio: (ora) =>
                              _modificaOra(giorno, i, ora, inizio: true),
                          onFine: (ora) =>
                              _modificaOra(giorno, i, ora, inizio: false),
                          onElimina: () => _aggiorna(
                            giorno,
                            List<FasciaOraria>.of(settimana[giorno]!)
                              ..removeAt(i),
                          ),
                        ),
                      if ((settimana[giorno] ?? const []).length < _maxFasce)
                        IconButton(
                          key: ValueKey('schedule-add-$giorno'),
                          tooltip: l10n.employeesScheduleAddSlot,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            final fasce = List<FasciaOraria>.of(
                              settimana[giorno] ?? const [],
                            );
                            // La seconda fascia propone il pomeriggio.
                            fasce.add(
                              fasce.isEmpty
                                  ? const FasciaOraria('09:00', '13:00')
                                  : const FasciaOraria('15:00', '19:00'),
                            );
                            _aggiorna(giorno, fasce);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (lunedi.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('schedule-copy-monday'),
            onPressed: _copiaLunedi,
            icon: const Icon(Icons.content_copy, size: 18),
            label: Text(l10n.employeesScheduleCopyMonday),
          ),
      ],
    );
  }
}

/// Una fascia oraria con inizio e fine scritti a tastiera.
class _FasciaEditor extends StatelessWidget {
  const _FasciaEditor({
    super.key,
    required this.fascia,
    required this.onInizio,
    required this.onFine,
    required this.onElimina,
  });

  final FasciaOraria fascia;
  final ValueChanged<String> onInizio;
  final ValueChanged<String> onFine;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _OraField(
            valore: fascia.inizio,
            label: context.l10n.employeesShiftStart,
            onChanged: onInizio,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('–'),
          ),
          _OraField(
            valore: fascia.fine,
            label: context.l10n.employeesShiftEnd,
            onChanged: onFine,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.commonDelete,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onElimina,
          ),
        ],
      ),
    );
  }
}

/// Campo ora: accetta "9", "930", "9:30" o "9.30" e lo riscrive come
/// "09:30" quando si esce dal campo. Un valore non valido resta rosso e non
/// cambia la fascia.
class _OraField extends StatefulWidget {
  const _OraField({
    required this.valore,
    required this.label,
    required this.onChanged,
  });

  final String valore;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_OraField> createState() => _OraFieldState();
}

class _OraFieldState extends State<_OraField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.valore,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _valido = true;

  @override
  void didUpdateWidget(covariant _OraField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.valore != _controller.text) {
      _controller.text = widget.valore;
      _valido = true;
    }
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      return;
    }
    final ora = normalizzaOra(_controller.text);
    if (ora != null) {
      _controller.text = ora;
      if (ora != widget.valore) widget.onChanged(ora);
    }
    setState(() => _valido = ora != null);
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The app theme gives every field an outline and wide padding, which
    // leaves no room for "09:30" here: this compact field sets its own.
    final linea = UnderlineInputBorder(
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return SizedBox(
      width: 56,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: '09:00',
          semanticCounterText: widget.label,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: linea,
          enabledBorder: linea,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
          errorText: _valido ? null : '',
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        onSubmitted: (_) => _focus.unfocus(),
      ),
    );
  }
}

/// Settimana tipo in sola lettura, per il dettaglio del dipendente.
class SettimanaTipoView extends StatelessWidget {
  const SettimanaTipoView({super.key, required this.settimana});

  final Map<String, List<FasciaOraria>> settimana;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final giorno in FasciaOraria.giorni)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                SizedBox(width: 110, child: Text(nomeGiorno(context, giorno))),
                Expanded(
                  child: Text(
                    (settimana[giorno] ?? const []).isEmpty
                        ? context.l10n.employeesScheduleDayOff
                        : settimana[giorno]!
                              .map((f) => '${f.inizio}–${f.fine}')
                              .join('  ·  '),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Turni di un dipendente, una settimana alla volta, con le ore pianificate
/// confrontate con quelle del contratto.
class DipendenteTurniScreen extends StatefulWidget {
  const DipendenteTurniScreen({
    super.key,
    required this.dipendente,
    this.service,
  });

  final Dipendente dipendente;
  final DipendenteHrService? service;

  @override
  State<DipendenteTurniScreen> createState() => _DipendenteTurniScreenState();
}

class _DipendenteTurniScreenState extends State<DipendenteTurniScreen> {
  late final DipendenteHrService _service =
      widget.service ?? DipendenteHrService();
  DateTime _lunedi = lunediDi(DateTime.now());
  TurniPeriodo? _periodo;
  String? _errore;
  bool _loading = false;

  DateTime get _domenica => _lunedi.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _loading = true;
      _errore = null;
    });
    try {
      final periodo = await _service.turni(
        widget.dipendente.id,
        _lunedi,
        _domenica,
      );
      if (!mounted) return;
      setState(() {
        _periodo = periodo;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errore = context.l10n.employeesShiftsError(
          employeeErrorText(context.l10n, error),
        );
        _loading = false;
      });
    }
  }

  void _sposta(int settimane) {
    setState(() => _lunedi = _lunedi.add(Duration(days: 7 * settimane)));
    _carica();
  }

  void _avvisa(String testo) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(testo)));

  Future<void> _copiaSettimanaTipo() async {
    final l10n = context.l10n;
    if (widget.dipendente.minutiSettimanaTipo == 0) {
      _avvisa(l10n.employeesShiftsNoSchedule);
      return;
    }
    var sostituisci = false;
    if ((_periodo?.turni ?? const []).isNotEmpty) {
      final scelta = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.employeesShiftsReplaceTitle),
          content: Text(l10n.employeesShiftsReplaceBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.employeesShiftsKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.employeesShiftsReplace),
            ),
          ],
        ),
      );
      if (scelta == null) return;
      sostituisci = scelta;
    }
    try {
      final creati = await _service.copiaSettimanaTipo(
        widget.dipendente.id,
        _lunedi,
        _domenica,
        sostituisci: sostituisci,
      );
      if (!mounted) return;
      _avvisa(l10n.employeesShiftsCopyDone('$creati'));
      await _carica();
    } catch (error) {
      if (!mounted) return;
      _avvisa(l10n.employeesShiftSaveError(employeeErrorText(l10n, error)));
    }
  }

  Future<void> _modifica({DateTime? giorno, TurnoDipendente? turno}) async {
    final salvato = await showDialog<bool>(
      context: context,
      builder: (_) => _TurnoDialog(
        dipendenteId: widget.dipendente.id,
        service: _service,
        giorno: giorno ?? turno!.data,
        turno: turno,
      ),
    );
    if (salvato == true) await _carica();
  }

  Widget _riepilogo(BuildContext context) {
    final l10n = context.l10n;
    final riepilogo = _periodo?.riepilogo ?? const RiepilogoTurni();
    final colors = Theme.of(context).colorScheme;
    Widget cella(String titolo, String valore, {Color? colore}) => Expanded(
      child: Column(
        children: <Widget>[
          Text(
            valore,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colore,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(titolo),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          key: const ValueKey('shifts-summary'),
          children: <Widget>[
            cella(
              l10n.employeesShiftsPlanned,
              formatOre(riepilogo.pianificati),
            ),
            cella(l10n.employeesShiftsContract, formatOre(riepilogo.contratto)),
            cella(
              l10n.employeesShiftsDifference,
              formatOre(riepilogo.differenza, segno: true),
              colore: riepilogo.differenza < 0
                  ? colors.error
                  : (riepilogo.differenza > 0 ? colors.tertiary : null),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final breve = DateFormat.MMMd(locale);
    final turni = _periodo?.turni ?? const <TurnoDipendente>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.employeesShiftsTitle} · ${widget.dipendente.nomeCompleto}',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.employeesShiftsCopyWeek,
            icon: const Icon(Icons.content_copy),
            onPressed: _loading ? null : _copiaSettimanaTipo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carica,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.employeesShiftsPrevWeek,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _sposta(-1),
                ),
                Expanded(
                  child: Text(
                    l10n.employeesShiftsWeekOf(
                      breve.format(_lunedi),
                      breve.format(_domenica),
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.employeesShiftsNextWeek,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _sposta(1),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_errore != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _errore!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _riepilogo(context),
            for (var d = 0; d < 7; d++)
              _giorno(context, _lunedi.add(Duration(days: d)), turni),
          ],
        ),
      ),
    );
  }

  Widget _giorno(
    BuildContext context,
    DateTime giorno,
    List<TurnoDipendente> turni,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final delGiorno = turni
        .where((t) => DateUtils.isSameDay(t.data, giorno))
        .toList(growable: false);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            title: Text(
              DateFormat.MMMEd(locale).format(giorno),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: delGiorno.isEmpty ? Text(l10n.employeesShiftNone) : null,
            trailing: IconButton(
              tooltip: l10n.employeesShiftAdd,
              icon: const Icon(Icons.add),
              onPressed: () => _modifica(giorno: giorno),
            ),
          ),
          for (final turno in delGiorno)
            ListTile(
              dense: true,
              leading: const Icon(Icons.schedule),
              title: Text(
                '${turno.inizio}–${turno.fine}'
                '${turno.pausaMinuti > 0 ? '  (−${turno.pausaMinuti}′)' : ''}',
              ),
              subtitle: turno.nota.isEmpty ? null : Text(turno.nota),
              trailing: Text(formatOre(turno.minuti)),
              onTap: () => _modifica(turno: turno),
            ),
        ],
      ),
    );
  }
}

class _TurnoDialog extends StatefulWidget {
  const _TurnoDialog({
    required this.dipendenteId,
    required this.service,
    required this.giorno,
    this.turno,
  });

  final int dipendenteId;
  final DipendenteHrService service;
  final DateTime giorno;
  final TurnoDipendente? turno;

  @override
  State<_TurnoDialog> createState() => _TurnoDialogState();
}

class _TurnoDialogState extends State<_TurnoDialog> {
  late final TextEditingController _inizio = TextEditingController(
    text: widget.turno?.inizio ?? '09:00',
  );
  late final TextEditingController _fine = TextEditingController(
    text: widget.turno?.fine ?? '13:00',
  );
  late final TextEditingController _pausa = TextEditingController(
    text: '${widget.turno?.pausaMinuti ?? 0}',
  );
  late final TextEditingController _nota = TextEditingController(
    text: widget.turno?.nota ?? '',
  );
  String? _errore;
  bool _saving = false;

  @override
  void dispose() {
    _inizio.dispose();
    _fine.dispose();
    _pausa.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final l10n = context.l10n;
    final inizio = normalizzaOra(_inizio.text);
    final fine = normalizzaOra(_fine.text);
    if (inizio == null || fine == null || inizio == fine) {
      setState(() => _errore = l10n.employeesShiftTimeInvalid);
      return;
    }
    _inizio.text = inizio;
    _fine.text = fine;
    final pausa = int.tryParse(_pausa.text.trim()) ?? -1;
    if (pausa < 0 || pausa >= FasciaOraria.minutiTra(inizio, fine)) {
      setState(() => _errore = l10n.employeesShiftBreakInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _errore = null;
    });
    try {
      await widget.service.salvaTurno(
        widget.dipendenteId,
        turnoId: widget.turno?.id,
        data: widget.giorno,
        inizio: inizio,
        fine: fine,
        pausaMinuti: pausa,
        nota: _nota.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errore = l10n.employeesShiftSaveError(employeeErrorText(l10n, error));
      });
    }
  }

  Future<void> _elimina() async {
    final l10n = context.l10n;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.employeesShiftDeleteTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    try {
      await widget.service.eliminaTurno(widget.dipendenteId, widget.turno!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errore = l10n.employeesShiftSaveError(
          employeeErrorText(l10n, error),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Typed, like the usual week: "9", "930" and "9:30" all work.
    Widget ora(String label, TextEditingController controller) => Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(labelText: label, hintText: '09:00'),
      ),
    );
    return AlertDialog(
      title: Text(
        '${widget.turno == null ? l10n.employeesShiftAdd : l10n.employeesShiftEdit} · '
        '${DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(widget.giorno)}',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                ora(l10n.employeesShiftStart, _inizio),
                const SizedBox(width: 16),
                ora(l10n.employeesShiftEnd, _fine),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pausa,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.employeesShiftBreak),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nota,
              decoration: InputDecoration(labelText: l10n.employeesShiftNote),
            ),
            if (_errore != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.turno != null)
          TextButton(
            onPressed: _saving ? null : _elimina,
            child: Text(l10n.commonDelete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _salva,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// Documenti del dipendente (contratto firmato, documento d'identita', altro)
/// salvati in modo privato sul sito.
class DipendenteDocumentiCard extends StatefulWidget {
  const DipendenteDocumentiCard({
    super.key,
    required this.dipendente,
    this.service,
  });

  final Dipendente dipendente;
  final DipendenteHrService? service;

  @override
  State<DipendenteDocumentiCard> createState() =>
      _DipendenteDocumentiCardState();
}

class _DipendenteDocumentiCardState extends State<DipendenteDocumentiCard> {
  late final DipendenteHrService _service =
      widget.service ?? DipendenteHrService();
  List<DocumentoDipendente> _documenti = const <DocumentoDipendente>[];
  String? _errore;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final documenti = await _service.documenti(widget.dipendente.id);
      if (!mounted) return;
      setState(() {
        _documenti = documenti;
        _errore = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errore = context.l10n.employeesDocumentsError(
          employeeErrorText(context.l10n, error),
        );
        _loading = false;
      });
    }
  }

  void _avvisa(String testo) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(testo)));

  Future<void> _caricaDocumento() async {
    final caricato = await showDialog<bool>(
      context: context,
      builder: (_) => _CaricaDocumentoDialog(
        dipendenteId: widget.dipendente.id,
        service: _service,
      ),
    );
    if (caricato == true) await _carica();
  }

  Future<void> _scarica(DocumentoDipendente documento) async {
    final l10n = context.l10n;
    try {
      final bytes = await _service.scaricaDocumento(
        widget.dipendente.id,
        documento.id,
      );
      final percorso = await saveFileWithDialog(
        fileName: documento.nomeFile,
        bytes: bytes,
        mimeType: documento.mime,
      );
      if (percorso != null && mounted) {
        _avvisa(l10n.employeesDocumentSaved(percorso));
      }
    } catch (error) {
      if (mounted) {
        _avvisa(l10n.employeesDocumentsError(employeeErrorText(l10n, error)));
      }
    }
  }

  Future<void> _elimina(DocumentoDipendente documento) async {
    final l10n = context.l10n;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.employeesDocumentDeleteTitle(documento.titolo)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    try {
      await _service.eliminaDocumento(widget.dipendente.id, documento.id);
      await _carica();
    } catch (error) {
      if (mounted) {
        _avvisa(l10n.employeesDocumentsError(employeeErrorText(l10n, error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = DateFormat.yMd(Localizations.localeOf(context).toString());
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
                Expanded(
                  child: Text(
                    l10n.employeesDocuments,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('employee-document-upload'),
                  onPressed: _caricaDocumento,
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.employeesDocumentUpload),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_errore != null) Text(_errore!),
            if (!_loading && _errore == null && _documenti.isEmpty)
              Text(l10n.employeesDocumentsEmpty),
            for (final documento in _documenti)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  documento.mime == 'application/pdf'
                      ? Icons.picture_as_pdf
                      : Icons.image_outlined,
                ),
                title: Text(documento.titolo),
                subtitle: Text(
                  '${nomeTipoDocumento(context, documento.tipo)}'
                  '${documento.caricato == null ? '' : ' · ${data.format(documento.caricato!)}'}'
                  ' · ${(documento.byte / 1024).ceil()} KB',
                ),
                trailing: Wrap(
                  children: <Widget>[
                    IconButton(
                      tooltip: l10n.employeesDocumentDownload,
                      icon: const Icon(Icons.download),
                      onPressed: () => _scarica(documento),
                    ),
                    IconButton(
                      tooltip: l10n.commonDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _elimina(documento),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaricaDocumentoDialog extends StatefulWidget {
  const _CaricaDocumentoDialog({
    required this.dipendenteId,
    required this.service,
  });

  final int dipendenteId;
  final DipendenteHrService service;

  @override
  State<_CaricaDocumentoDialog> createState() => _CaricaDocumentoDialogState();
}

class _CaricaDocumentoDialogState extends State<_CaricaDocumentoDialog> {
  TipoDocumento _tipo = TipoDocumento.contract;
  final TextEditingController _titolo = TextEditingController();
  String _nomeFile = '';
  Uint8List? _bytes;
  String? _errore;
  bool _saving = false;

  @override
  void dispose() {
    _titolo.dispose();
    super.dispose();
  }

  Future<void> _scegli() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _nomeFile = file.name;
      _bytes = bytes;
      _errore = bytes.length > DipendenteHrService.maxByte
          ? context.l10n.employeesDocumentTooLarge
          : null;
      if (_titolo.text.trim().isEmpty) {
        final dot = file.name.lastIndexOf('.');
        _titolo.text = dot > 0 ? file.name.substring(0, dot) : file.name;
      }
    });
  }

  Future<void> _salva() async {
    final l10n = context.l10n;
    final bytes = _bytes;
    if (bytes == null) return;
    if (bytes.length > DipendenteHrService.maxByte) {
      setState(() => _errore = l10n.employeesDocumentTooLarge);
      return;
    }
    setState(() {
      _saving = true;
      _errore = null;
    });
    try {
      await widget.service.caricaDocumento(
        widget.dipendenteId,
        tipo: _tipo,
        titolo: _titolo.text,
        nomeFile: _nomeFile,
        bytes: bytes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errore = l10n.employeesDocumentsError(employeeErrorText(l10n, error));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.employeesDocumentUpload),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<TipoDocumento>(
              initialValue: _tipo,
              decoration: InputDecoration(
                labelText: l10n.employeesDocumentKind,
              ),
              items: <DropdownMenuItem<TipoDocumento>>[
                for (final tipo in TipoDocumento.values)
                  DropdownMenuItem(
                    value: tipo,
                    child: Text(nomeTipoDocumento(context, tipo)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _tipo = value ?? TipoDocumento.other),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titolo,
              decoration: InputDecoration(
                labelText: l10n.employeesDocumentTitle,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _scegli,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _bytes == null ? l10n.employeesDocumentChooseFile : _nomeFile,
              ),
            ),
            if (_errore != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving || _bytes == null || _errore != null
              ? null
              : _salva,
          child: Text(l10n.employeesDocumentUpload),
        ),
      ],
    );
  }
}
