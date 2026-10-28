import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/extensions.dart';
import '../../notification/notification_service.dart';
import 'datagridview.code.dart';
import 'datagridview_filters.dart';
import 'datagridview_list.code.dart';

/// Raggio dei pannelli della lista (barra filtri aperta).
const double kDataGridCardRadius = 18;

/// Spazio fra i controlli della barra e della lista.
const double kDataGridControlGap = 8;

/// Inset orizzontale dei controlli che toccano il bordo dello schermo.
///
/// Le liste sono a filo: niente padding esterno, niente cornice. Restano
/// pero' 6px, perche' `DataTable2` centra la colonna checkbox in
/// `horizontalMargin / 2`, cioe' 6px: senza questo inset la toolbar del filtro
/// risulterebbe 6px a sinistra della checkbox e le due cose sembrerebbero
/// disallineate.
const double kDataGridEdgeInset = 6;

/// Inset verticale delle barre agganciate al bordo.
///
/// Non e' zero perche' la toolbar `Filtro` chiusa e alta quanto un `titleSmall`
/// (~20px): a zero scenderebbe sotto i 48dp di tap target minimi di Android.
const double kDataGridEdgeInsetVertical = 4;

/// Barra "Filtro" delle liste gestionali: ricerca rapida, filtri avanzati per
/// campo, ordinamento e comandi della lista.
///
/// I campi offerti in filtri e ordinamento sono quelli del modello passati
/// in [fields]; lo stato vive in [controller].
class DataGridFiltersBar<T> extends StatefulWidget {
  final DataGridListController<T> controller;
  final List<DataGridField<T>> fields;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenColumns;

  /// Comandi in piu' accanto ad "Aggiorna" (es. stampa etichette).
  final List<Widget> actions;

  /// Filtri in piu' accanto all'ordinamento (es. "nascondi esauriti").
  final List<Widget> extraFilters;

  /// Chip in piu' nell'elenco dei filtri attivi.
  final List<Widget> extraActiveChips;

  /// Vero quando uno dei filtri in piu' e' attivo: abilita "Cancella tutti".
  final bool hasExtraFilters;

  /// Chiamato da "Cancella tutti" per spegnere i filtri in piu'.
  final VoidCallback? onClearExtraFilters;

  /// Esempio mostrato nel campo valore quando si filtra per un campo.
  final String? filterValueHint;

  const DataGridFiltersBar({
    super.key,
    required this.controller,
    required this.fields,
    this.onRefresh,
    this.onOpenColumns,
    this.actions = const <Widget>[],
    this.extraFilters = const <Widget>[],
    this.extraActiveChips = const <Widget>[],
    this.hasExtraFilters = false,
    this.onClearExtraFilters,
    this.filterValueHint,
  });

  @override
  State<DataGridFiltersBar<T>> createState() => _DataGridFiltersBarState<T>();
}

class _DataGridFiltersBarState<T> extends State<DataGridFiltersBar<T>> {
  /// Voce "Ricerca rapida" del menu dei campi: non e' un campo del modello.
  static const String _ricercaRapida = '';

  final _valueCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _campo = _ricercaRapida;
  DataGridFilterOperator _operatore = DataGridFilterOperator.contiene;
  // null = default automatico (retratto su stretto, espanso su desktop).
  // Dopo il primo tap manuale il valore resta sotto controllo utente.
  bool? _espanso;

  List<DataGridField<T>> get _filterFields =>
      widget.fields.where((f) => f.filterable).toList();

  DataGridField<T>? get _campoField => _campo == _ricercaRapida
      ? null
      : DataGridFilterEngine.fieldByName(widget.fields, _campo);

  bool get _isRicercaRapida => _campoField == null;

  @override
  void initState() {
    super.initState();
    _valueCtrl.text = widget.controller.search;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _valueCtrl.dispose();
    super.dispose();
  }

  bool _operatoreDisponibile(DataGridFilterOperator o) {
    final field = _campoField;
    if (field == null) return o == DataGridFilterOperator.contiene;
    return DataGridFilterEngine.supportsOperator(field.type, o);
  }

  /// Ricerca rapida mentre si scrive: aspetta una pausa di 300 ms, cosi' una
  /// parola scritta in fretta produce una sola ricerca e non una per lettera.
  /// Le risposte arrivate fuori ordine le scarta il controller.
  void _scheduleQuickSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.controller.setSearch(value);
    });
  }

  void _onCampoChanged(String value) {
    final text = _valueCtrl.text;
    final eraRicercaRapida = _isRicercaRapida;
    setState(() {
      _campo = value;
      if (!_operatoreDisponibile(_operatore)) {
        final field = _campoField;
        _operatore = field == null
            ? DataGridFilterOperator.contiene
            : DataGridFilterEngine.defaultOperator(field.type);
      }
      _valueCtrl.text = text;
      _valueCtrl.selection = TextSelection.collapsed(offset: text.length);
    });
    if (eraRicercaRapida && !_isRicercaRapida) {
      _searchDebounce?.cancel();
      widget.controller.setSearch('');
    } else if (_isRicercaRapida) {
      _searchDebounce?.cancel();
      widget.controller.setSearch(text);
    }
  }

  void _applyFilter() {
    final raw = _valueCtrl.text.trim();
    if (raw.isEmpty) return;
    final field = _campoField;
    if (field == null) {
      _searchDebounce?.cancel();
      widget.controller.setSearch(raw);
      return;
    }
    if (!_operatoreDisponibile(_operatore)) {
      NotificationService.instance.messageBar(
        'warning',
        widget.controller.cache.key,
        context.l10n.productsOperatorNotAvailable,
      );
      return;
    }
    final valori = DataGridFilterEngine.splitValues(
      raw,
    ).map((v) => field.optionValue(context.l10n, v)).toList();
    if (valori.isEmpty) return;
    widget.controller.addFilter(
      DataGridFilter(fieldName: field.name, operatore: _operatore, valori: valori),
    );
    _valueCtrl.clear();
    setState(() {});
  }

  void _clearAll() {
    _searchDebounce?.cancel();
    _valueCtrl.clear();
    widget.onClearExtraFilters?.call();
    widget.controller.clearFilters();
    setState(() {});
  }

  String _sortLabel(DataGridSort? sort) {
    if (sort == null) return context.l10n.productsSortBy;
    final field = DataGridFilterEngine.fieldByName(
      widget.fields,
      sort.fieldName,
    );
    final label = field?.label(context.l10n) ?? sort.fieldName;
    return sort.ascending
        ? context.l10n.dataGridSortAscending(label)
        : context.l10n.dataGridSortDescending(label);
  }

  List<DataGridSort?> _sortOptions() => <DataGridSort?>[
    null,
    for (final field in widget.fields.where((f) => f.sortable)) ...[
      DataGridSort(field.name),
      DataGridSort(field.name, ascending: false),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final sortOptions = _sortOptions();
    final hasAnyFilter =
        controller.search.isNotEmpty ||
        controller.filters.isNotEmpty ||
        widget.hasExtraFilters;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final searchWidth = narrow ? constraints.maxWidth : 320.0;
        // Default automatico solo finche l'utente non sceglie: retratto su
        // smartphone per lasciare spazio al datagrid, espanso su desktop.
        // Dopo il primo tap vale solo la scelta manuale.
        final espanso = _espanso ?? !narrow;
        void toggleEspanso() => setState(() => _espanso = !espanso);
        // Chiuso e una toolbar: solo icona, etichetta e freccia, senza riquadro
        // per non contendere spazio alla griglia. Aperto diventa un pannello con
        // riempimento tonale, che lo distingue dal fondo del pane senza
        // aggiungere un secondo bordo accanto a quello del pane stesso.
        return Container(
          margin: const EdgeInsets.fromLTRB(
            kDataGridEdgeInset,
            kDataGridEdgeInsetVertical,
            kDataGridEdgeInset,
            kDataGridEdgeInsetVertical,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kDataGridEdgeInset,
            vertical: kDataGridEdgeInsetVertical,
          ),
          decoration: BoxDecoration(
            color: espanso
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(kDataGridCardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: toggleEspanso,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          color: theme.primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: kDataGridControlGap),
                        Text(
                          context.l10n.productsFilter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: toggleEspanso,
                          tooltip: espanso
                              ? context.l10n.productsCollapseFilters
                              : context.l10n.productsExpandFilters,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            espanso ? Icons.expand_less : Icons.expand_more,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataGridCommandIconButton(
                    onPressed: widget.onOpenColumns,
                    icon: Icons.view_column_outlined,
                    tooltip: context.l10n.prodottiScegliColonne,
                    color: theme.primaryColor,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: espanso
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: kDataGridControlGap),
                          Wrap(
                            spacing: kDataGridControlGap,
                            runSpacing: kDataGridControlGap,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: searchWidth,
                                child: _buildValueField(),
                              ),
                              SizedBox(
                                width: narrow
                                    ? (constraints.maxWidth -
                                              kDataGridControlGap) /
                                          2
                                    : 220,
                                child: _buildFieldDropdown(),
                              ),
                              SizedBox(
                                width: narrow
                                    ? (constraints.maxWidth -
                                              kDataGridControlGap) /
                                          2
                                    : 180,
                                child: _buildOperatorDropdown(),
                              ),
                              FilledButton.icon(
                                onPressed: _applyFilter,
                                icon: const Icon(Icons.add),
                                label: Text(
                                  _isRicercaRapida
                                      ? context.l10n.productsApplySearch
                                      : context.l10n.productsAddFilter,
                                ),
                              ),
                              DataGridCommandIconButton(
                                onPressed: widget.onRefresh == null
                                    ? null
                                    : () => widget.onRefresh!(),
                                icon: Icons.refresh,
                                tooltip: context.l10n.prodottiAggiornaCache,
                                color: theme.colorScheme.secondary,
                              ),
                              ...widget.actions,
                            ],
                          ),
                          const SizedBox(height: kDataGridControlGap),
                          Wrap(
                            spacing: kDataGridControlGap,
                            runSpacing: kDataGridControlGap,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (sortOptions.length > 1)
                                SizedBox(
                                  width: narrow ? constraints.maxWidth : 260,
                                  child: _buildSortDropdown(sortOptions),
                                ),
                              ...widget.extraFilters,
                              TextButton.icon(
                                onPressed: hasAnyFilter ? _clearAll : null,
                                icon: const Icon(Icons.clear_all),
                                label: Text(context.l10n.prodottiCancellaTutti),
                              ),
                            ],
                          ),
                          if (widget.extraActiveChips.isNotEmpty ||
                              controller.filters.isNotEmpty) ...[
                            const SizedBox(height: kDataGridControlGap),
                            Wrap(
                              spacing: kDataGridControlGap,
                              runSpacing: kDataGridControlGap,
                              children: [
                                ...widget.extraActiveChips,
                                for (
                                  int i = 0;
                                  i < controller.filters.length;
                                  i++
                                )
                                  InputChip(
                                    label: Text(
                                      controller.filters[i].chipLabel(
                                        context.l10n,
                                        widget.fields,
                                      ),
                                    ),
                                    onDeleted: () =>
                                        controller.removeFilterAt(i),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValueField() {
    return TextField(
      controller: _valueCtrl,
      decoration: InputDecoration(
        labelText: _isRicercaRapida
            ? context.l10n.productsQuickSearch
            : context.l10n.productsFilterValue,
        hintText: _isRicercaRapida
            ? context.l10n.productsSearchAllFields
            : _campoField!.options.isNotEmpty
            ? _campoField!.options.map((o) => o.label(context.l10n)).join(', ')
            : widget.filterValueHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _valueCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchDebounce?.cancel();
                  setState(() => _valueCtrl.clear());
                  if (_isRicercaRapida) widget.controller.setSearch('');
                },
              )
            : null,
      ),
      onChanged: (v) {
        if (_isRicercaRapida) _scheduleQuickSearch(v);
        setState(() {});
      },
      onSubmitted: (_) => _applyFilter(),
    );
  }

  Widget _buildFieldDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _campo,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.prodottiCampoFiltro,
        isDense: true,
      ),
      onChanged: (v) {
        if (v != null) _onCampoChanged(v);
      },
      items: [
        DropdownMenuItem(
          value: _ricercaRapida,
          child: Text(context.l10n.prodottiFiltroCampo_ricercaRapida),
        ),
        for (final field in _filterFields)
          DropdownMenuItem(
            value: field.name,
            child: Text(field.label(context.l10n)),
          ),
      ],
    );
  }

  Widget _buildOperatorDropdown() {
    return DropdownButtonFormField<DataGridFilterOperator>(
      // La chiave cambia col campo: le voci ammesse cambiano, e il menu deve
      // ripartire dall'operatore corretto invece che dal primo valore visto.
      key: ValueKey('op-$_campo'),
      initialValue: _operatore,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.prodottiOperatore,
        isDense: true,
      ),
      onChanged: (v) {
        if (v != null) setState(() => _operatore = v);
      },
      items: DataGridFilterEngine.orderedOperators
          .where(_operatoreDisponibile)
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Tooltip(
                waitDuration: const Duration(milliseconds: 850),
                message: DataGridFilterEngine.operatoreTooltip(context.l10n, o),
                child: Text(
                  DataGridFilterEngine.operatoreLabel(context.l10n, o),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSortDropdown(List<DataGridSort?> options) {
    final theme = Theme.of(context);
    final current = widget.controller.sort;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<DataGridSort?>(
            value: options.contains(current) ? current : null,
            isExpanded: true,
            icon: Icon(Icons.sort, color: theme.primaryColor),
            onChanged: widget.controller.setSort,
            items: options
                .map(
                  (o) => DropdownMenuItem<DataGridSort?>(
                    value: o,
                    child: Text(_sortLabel(o)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

/// Pulsante icona tonale dei comandi della lista.
class DataGridCommandIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;
  final Color color;

  const DataGridCommandIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.10),
        foregroundColor: color,
      ),
    );
  }
}
