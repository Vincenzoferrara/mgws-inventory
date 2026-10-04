import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import '../logic/global_pagination_controller.dart';
import '../../traduzioni/estensioni.dart';

/// Larghezza del campo "righe visualizzate".
///
/// Non e' un numero scelto a occhio: e' la somma di cio' che il campo contiene
/// davvero. Le misure dei testi sono sui glifi del Roboto.
///   8   padding interno sinistro
///   4   distanza testo-bordo (`InputDecoration.inputGap`)
///   40  freccia del menu, piu' larga di qualsiasi testo che ci sta dentro
///   4   distanza freccia-testo (`inputToSuffixGap`)
///   26  area testo utile, dove "100" (25.6px a 14px) ci sta con margine
///
/// La floating label "Righe" (36.0px) non aggiunge niente: l'`InputDecorator`
/// le concede tutta la larghezza del campo, non l'area testo.
///
/// Senza `width` il campo occuperebbe 118px: `DropdownMenu` ha un floor interno
/// di 112px che nessun `IntrinsicWidth` riesca a scavalcare, e a 118px la
/// barra non starebbe piu' su una riga sola.
const double _kPageSizeFieldWidth = 82;

/// Tra due gruppi di controlli, non dentro un gruppo: i quattro pulsanti di
/// navigazione restano attaccati perche' hanno gia' il padding interno.
const double _kGroupGap = 4;

class GlobalPaginationBar extends StatefulWidget {
  final AppSettings settings;
  final GlobalPaginationController<dynamic> controller;
  final Future<void> Function()? onFirstPage;
  final Future<void> Function()? onPreviousPage;
  final Future<void> Function()? onNextPage;
  final Future<void> Function()? onLastPage;
  final Future<void> Function(GlobalPageMode mode, int pageSize)?
  onModeOrPageSizeChanged;
  final int? totalRows;
  final int selectedRows;

  const GlobalPaginationBar({
    super.key,
    required this.settings,
    required this.controller,
    this.onFirstPage,
    this.onPreviousPage,
    this.onNextPage,
    this.onLastPage,
    this.onModeOrPageSizeChanged,
    this.totalRows,
    this.selectedRows = 0,
  });

  @override
  State<GlobalPaginationBar> createState() => _GlobalPaginationBarState();
}

class _GlobalPaginationBarState extends State<GlobalPaginationBar> {
  late final TextEditingController _pageSizeController;

  @override
  void initState() {
    super.initState();
    _pageSizeController = TextEditingController(
      text: _displayTextFor(widget.controller.pageSizeText),
    );
    widget.controller.addListener(_syncControllerText);
  }

  @override
  void didUpdateWidget(covariant GlobalPaginationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncControllerText);
      widget.controller.addListener(_syncControllerText);
      _syncControllerText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllerText);
    _pageSizeController.dispose();
    super.dispose();
  }

  /// Il controller lavora con la parola "Infinito", ma nel campo si vede il
  /// simbolo: senza questa mappatura il campo mostrerebbe la parola e
  /// sforerebbe la larghezza calcolata in [_kPageSizeFieldWidth].
  static String _displayTextFor(String raw) {
    if (GlobalPaginationOptions.isInfiniteLabel(raw)) {
      return GlobalPaginationOptions.infiniteDisplayLabel;
    }
    return raw;
  }

  void _syncControllerText() {
    final next = _displayTextFor(widget.controller.pageSizeText);
    if (_pageSizeController.text == next) return;
    _pageSizeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _applyPageSizeValue(String raw) async {
    if (GlobalPaginationOptions.isInfiniteLabel(raw)) {
      widget.controller.setMode(GlobalPageMode.infinite);
      await widget.onModeOrPageSizeChanged?.call(
        GlobalPageMode.infinite,
        GlobalPaginationOptions.infiniteChunkSize,
      );
      return;
    }

    final parsed = GlobalPaginationOptions.tryParsePageSize(raw);
    if (parsed == null) {
      _syncControllerText();
      return;
    }

    await widget.controller.persistPageSize(widget.settings, parsed);
    widget.controller.setMode(GlobalPageMode.paged, resetPage: false);
    await widget.onModeOrPageSizeChanged?.call(
      GlobalPageMode.paged,
      widget.controller.pageSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            // Nessuna elevation: questa barra vive dentro un riquadro che ha
            // gia la sua ombra, e un altro strato Galleggiante produceva un
            // terzo bordo in basso. Un semplice filetto superiore separa la
            // barra dal contenuto, come fa la barra azioni della modalita
            // cassa nella stessa schermata.
            return Material(
              elevation: 0,
              color: Theme.of(context).cardColor,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Center(
                  // Il blocco di navigazione (freccie, selettore righe, indicatore)
                  // viene centrato orizzontalmente nella barra, invece di essere
                  // attaccato al lato sinistro. Il Row deve essere min, altrimenti
                  // occupa tutta la larghezza e il Center non ha effetto.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: _buildRow(isCompact),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Una sola riga: frecce indietro a sinistra, "righe" e "Pag. x/y" al
  /// centro, frecce avanti a destra.
  ///
  /// Il conto sullo schermo piu' stretto (320dp: 296px utili dopo gli insets
  /// del riquadro e il padding della barra):
  ///   160  quattro pulsanti da 40
  ///    82  campo righe
  ///    12  tre gruppi separati da [_kGroupGap]
  ///   ----
  ///    42  per l'indicatore: regge "12/12" (37.9px a 14px) e si tronca solo
  ///         su un caso estremo come "999/999" (54.1px)
  ///
  /// I quattro pulsanti stanno fuori da ogni widget flessibile, quindi hanno
  /// sempre la loro dimensione piena. L'unico elemento che puo' cedere spazio
  /// e' l'indicatore di pagina: per quanto diventi grande il catalogo, e' lui
  /// che si comprime, mai le frecce.
  List<Widget> _buildRow(bool isCompact) {
    final controller = widget.controller;
    final isInfinite = controller.isInfinite;
    final showLoading = isInfinite && controller.isLoadingMore;

    return <Widget>[
      if (!isInfinite) ...[
        _navButton(
          icon: Icons.first_page,
          tooltip: context.l10n.sharedPaginaPrima,
          enabled: controller.canGoFirst,
          onPressed: () async {
            if (widget.onFirstPage != null) {
              await widget.onFirstPage!();
            } else {
              controller.goToFirstPage();
            }
          },
        ),
        _navButton(
          icon: Icons.chevron_left,
          tooltip: context.l10n.sharedPaginaPrecedente,
          enabled: controller.canGoPrevious,
          onPressed: () async {
            if (widget.onPreviousPage != null) {
              await widget.onPreviousPage!();
            } else {
              controller.goToPreviousPage();
            }
          },
        ),
        const SizedBox(width: _kGroupGap),
      ],
      _buildPageSizeField(),
      const SizedBox(width: _kGroupGap),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isCompact ? 54 : 96),
        child: showLoading
            ? const _LoadingHint()
            : _PageIndicator(
                caption: controller.progressCaption,
                value: controller.progressValue,
              ),
      ),
      if (!isInfinite) ...[
        const SizedBox(width: _kGroupGap),
        _navButton(
          icon: Icons.chevron_right,
          tooltip: context.l10n.sharedPaginaSuccessiva,
          enabled: controller.canGoNext,
          onPressed: () async {
            if (widget.onNextPage != null) {
              await widget.onNextPage!();
            } else {
              controller.goToNextPage();
            }
          },
        ),
        _navButton(
          icon: Icons.last_page,
          tooltip: context.l10n.sharedPaginaUltima,
          enabled: controller.canGoLast,
          onPressed: () async {
            if (widget.onLastPage != null) {
              await widget.onLastPage!();
            } else {
              controller.goToLastPage();
            }
          },
        ),
      ],
      if (!isCompact) ...[
        // Doppio gap: le pillole sono un blocco accessorio a se' stante, non un
        // quinto gruppo di navigazione.
        const SizedBox(width: _kGroupGap * 2),
        _RowStats(
          totalRows: widget.totalRows ?? controller.totalItems,
          selectedRows: widget.selectedRows,
        ),
      ],
    ];
  }

  Widget _navButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required Future<void> Function() onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      // 40x40 esatti invece dei 48 che darebbe il tap target di Material: con
      // 48 i quattro pulsanti da soli mangiano 192px e la barra va a capo. Il
      // `fixedSize` rende la misura identica su Android e su desktop, dove la
      // densita' adattiva del tema cambierebbe il risultato.
      style: const ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size(40, 40)),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: enabled ? onPressed : null,
    );
  }

  Widget _buildPageSizeField() {
    return DropdownMenu<String>(
      width: _kPageSizeFieldWidth,
      controller: _pageSizeController,
      initialSelection: widget.controller.pageSizeText,
      requestFocusOnTap: true,
      enableFilter: true,
      // `decorationBuilder` invece di `label:` perche' serve a portare anche i
      // due vincoli di larghezza. `applyDefaults` riempie il resto dal tema
      // dell'app, quindi bordo e sfondo grigio restano quelli di sempre.
      decorationBuilder: (context, _) => InputDecoration(
        label: Text(context.l10n.sharedRighe),
        contentPadding: EdgeInsets.fromLTRB(8, 12, 4, 12),
        // La freccia e' un IconButton che chiede 48px di tap target: lasciarglieli
        // cosi' il campo dovrebbe arrivare a 104px solo per la freccia. Qui le si
        // danno esattamente i 40 del suo contenuto (8 di padding + 24 di icona),
        // cosi' la larghezza del campo e' uguale su Android e su desktop.
        suffixIconConstraints: BoxConstraints.tightFor(width: 40, height: 40),
      ),
      onSelected: (value) {
        if (value == null) return;
        _applyPageSizeValue(value);
      },
      dropdownMenuEntries: <DropdownMenuEntry<String>>[
        for (final option in GlobalPaginationOptions.defaultPageSizes)
          DropdownMenuEntry<String>(
            value: option.toString(),
            label: option.toString(),
          ),
        const DropdownMenuEntry<String>(
          value: GlobalPaginationOptions.infiniteLabel,
          label: GlobalPaginationOptions.infiniteDisplayLabel,
        ),
      ],
    );
  }
}

/// Indicatore di pagina su due livelli: didascalia sopra, valore sotto.
///
/// "Pag." sta sopra a "1/12" perche' la larghezza la comanda solo il numero:
/// il caso peggiore "999/999" misura 54.1px a 14px, mentre "Pag. 1/12" su una
/// riga sola costerebbe 76px e la barra sforerebbe. Per questo la didascalia
/// puo' restare a 11px senza costare nulla in larghezza.
class _PageIndicator extends StatelessWidget {
  final String caption;
  final String value;

  const _PageIndicator({required this.caption, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall,
        ),
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Testo che sta nello slot dell'indicatore mentre in modalita' infinito si
/// caricano le righe successive.
///
/// Il messaggio precedente ("Caricamento delle prossime 50 righe in corso...")
/// misura 129px e non entrava piu' in una riga sola; qui la barra e' gia'
/// stretta perche' i pulsanti di navigazione spariscono in questa modalita'.
class _LoadingHint extends StatelessWidget {
  const _LoadingHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Caricamento…',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pillole "Tot:" e "Sel:". Mostrate solo quando c'e' spazio, cioe' da 600px in
/// su: su schermi stretti la larghezza va alle frecce, che sono la cosa che
/// l'utente deve poter premere sempre.
class _RowStats extends StatelessWidget {
  final int? totalRows;
  final int selectedRows;

  const _RowStats({required this.totalRows, required this.selectedRows});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatPill(
          label: 'Tot:',
          value: totalRows?.toString() ?? '-',
          style: style,
        ),
        const SizedBox(width: 8),
        _StatPill(label: 'Sel:', value: selectedRows.toString(), style: style),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;

  const _StatPill({
    required this.label,
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text('$label $value', style: style),
    );
  }
}
