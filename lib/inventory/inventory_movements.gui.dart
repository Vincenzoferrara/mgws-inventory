// inventory_movements.gui.dart
//
// Il ledger MGWS, letto per operazione.
//
// Una riga e' un'operazione, non un prodotto: MGWS registra una riga per
// prodotto, quindi i movimenti che condividono origine e documento vengono
// accorpati da `groupMovements`. L'operatore ragiona per operazione ("quel
// carico di ieri sera"), quindi e' questo il taglio giusto.
//
// Il pannello non modifica il ledger: lo legge, e le due azioni che offre
// partono da un movimento per produrre un movimento nuovo. Il doppio click
// apre la schermata dell'operazione, da li' si sceglie se riaprirla nel pannello
// che l'ha prodotta o se annullarla per contromovimento.

import 'package:flutter/material.dart';

import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'inventory.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_movements_detail.gui.dart';

class InventoryMovementLedgerPanel extends StatefulWidget {
  InventoryMovementLedgerPanel({
    super.key,
    InventoryMovementController? controller,
    this.onReopen,
  }) : controller = controller ?? InventoryMovementController();

  final InventoryMovementController controller;

  /// Chiamata quando l'operatore sceglie "Modifica": la pagina che ospita il
  /// pannello fa il salto di modulo. Qui non si sa cosa ci sia fuori, quindi
  /// il pannello passa il seme e non decide nulla.
  final void Function(InventoryPanelSeed seed)? onReopen;

  @override
  State<InventoryMovementLedgerPanel> createState() =>
      _InventoryMovementLedgerPanelState();
}

class _InventoryMovementLedgerPanelState
    extends State<InventoryMovementLedgerPanel> {
  final _productController = TextEditingController();
  final _variationController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _sourceController = TextEditingController();
  final _operatorController = TextEditingController();
  final _reasonController = TextEditingController();
  final _effectController = TextEditingController();

  /// L'annullamento ha il suo controller perche' il piano di ripristino e'
  /// diverso da quello di una rettifica normale: verifica lo stock attuale
  /// prima di toccare qualcosa.
  final _revert = InventoryMovementRevertController();

  InventoryActionFeedback? _feedback;
  InventoryMovementGroup? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _productController.dispose();
    _variationController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _sourceController.dispose();
    _operatorController.dispose();
    _reasonController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  InventoryMovementFilterForm _form() => InventoryMovementFilterForm(
    productIdText: _productController.text,
    variationIdText: _variationController.text,
    dateFromText: _fromController.text,
    dateToText: _toController.text,
    sourceTypeText: _sourceController.text,
    operatorUserIdText: _operatorController.text,
    reasonCodeText: _reasonController.text,
    stockEffectText: _effectController.text,
  );

  List<InventoryMovementGroup> get _groups =>
      groupMovements(widget.controller.movements);

  /// `true` se il backend ha tagliato la risposta.
  ///
  /// Il raggruppamento per operazione si regge su una cosa sola: i prodotti della
  /// stessa operazione devono arrivare insieme. MGWS pagina e non filtra per
  /// documento, quindi un'operazione piu' grande di una pagina verrebbe
  /// accordata in due righe, e l'operatore vedrebbe due operazioni dove ce
  /// n'e' una sola. Meglio dirlo che farlo notare a metta.
  bool get _pageIsTruncated {
    final page = widget.controller.movementPage;
    if (page == null) return false;
    return widget.controller.movements.length < page.total;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final feedback = await widget.controller.load(_form());
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
      _selected = null;
    });
  }

  Future<void> _openGroup(InventoryMovementGroup group) async {
    setState(() => _selected = group);
    final action = await showInventoryMovementDialog(context, group);
    if (!mounted) return;
    switch (action) {
      case InventoryMovementAction.reopen:
        _reopen(group);
      case InventoryMovementAction.revert:
        await _revertGroup(group);
      case null:
        break;
    }
  }

  /// Riapre l'operazione nel pannello che l'ha prodotta.
  ///
  /// Il seme porta solo i prodotti, il motivo e i dettagli: sono i dati che il
  /// ledger registra davvero. Se il pannello non e' collegato a nessuna pagina
  /// non si fa niente in silenzio, si dice.
  void _reopen(InventoryMovementGroup group) {
    final callback = widget.onReopen;
    final module = group.resumeModule;
    if (callback == null || module == null) return;
    callback(
      InventoryPanelSeed(
        module: module,
        movements: group.movements,
        products: group.products,
        reason: group.reason,
        details: group.note,
      ),
    );
  }

  /// Prepara il contromovimento, mostra cosa succedera' e solo dopo chiede.
  ///
  /// Il piano si costruisce leggendo lo stock attuale di ogni prodotto: se
  /// nel frattempo qualcun altro ha mosso la merce, l'annullamento di quel
  /// prodotto viene bloccato e l'operatore vede il nome del prodotto e il
  /// motivo, non un errore generico.
  Future<void> _revertGroup(InventoryMovementGroup group) async {
    setState(() => _feedback = null);
    final prepared = await _revert.prepare(group);
    if (!mounted) return;
    final plan = _revert.lastPlan;
    if (plan == null || !plan.canRevert) {
      setState(() => _feedback = prepared);
      return;
    }
    final confirmed = await _confirmRevert(plan);
    if (!mounted || confirmed != true) return;
    final feedback = await _revert.execute(plan);
    if (!mounted) return;
    setState(() => _feedback = feedback);
    // Il ledger e' cambiato: senza ricaricare la lista mostrerebbe uno stock
    // che non esiste piu' e l'operatore prenderebbe decisioni su numeri vecchi.
    await _load();
  }

  Future<bool?> _confirmRevert(InventoryMovementRevertPlan plan) {
    final isMove = plan.group.isMove;
    // Su uno spostamento la riga non riporta il totale a un numero: dice
    // quanti pezzi tornano indietro e da quale magazzino a quale. Dire "da 40 a
    // 40" sarebbe un annullamento che non annulla niente.
    final lines = <String>[
      for (final line in plan.revertable)
        if (line.isReverseMove)
          '${line.productLabel}: ${line.quantity} '
              '${context.l10n.inventoryParolaPezzi}, ${line.routeText}'
        else
          '${line.productLabel}: '
              '${context.l10n.inventoryParolaDa(line.currentStock ?? '?')} '
              '${context.l10n.inventoryParolaA(line.restoreTo)}',
      for (final line in plan.blocked)
        '${line.productLabel}: '
            '${context.l10n.inventoryMovimentiRigaSaltata(line.blockMessage)}',
    ];
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('inventory-movement-revert-confirm'),
        title: Text(context.l10n.inventoryAnnullareMovimento),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMove
                      ? context.l10n.inventoryAnnullamentoNotaSpostamento
                      : context.l10n.inventoryAnnullamentoNotaRettifica,
                ),
                const SizedBox(height: 12),
                for (final line in lines) Text(line),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isMove
                  ? context.l10n.inventorySpostaIndietro
                  : context.l10n.inventoryRiportaIndietro,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final groups = _groups;
    return Card(
      key: const ValueKey('inventory-movements-panel'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.timeline, color: theme.colorScheme.primary),
                title: Text(
                  context.l10n.inventoryMovimentiTitolo,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  context.l10n.inventoryMovimentiSottotitolo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _filters(),
              const SizedBox(height: 10),
              if (_pageIsTruncated) ...[
                _truncationNotice(),
                const SizedBox(height: 10),
              ],
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (groups.isEmpty)
                _empty(colors)
              else
                SizedBox(height: 320, child: _grid(groups)),
              const SizedBox(height: 10),
              if (_feedback != null)
                InventoryMovementFeedback(feedback: _feedback!),
            ],
          ),
        ),
      ),
    );
  }

  /// Larghezza dei campi filtro: 180 px, ma su telefono due per riga, così
  /// non resta mezza riga vuota accanto a ogni campo.
  double _larghezzaCampo = 180;

  Widget _filters() => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 12.0;
      _larghezzaCampo = constraints.maxWidth < 180 * 2 + spacing
          ? (constraints.maxWidth - spacing) / 2
          : 180;
      return _filtersWrap();
    },
  );

  Widget _filtersWrap() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _field(
        _productController,
        context.l10n.inventoryEtichettaProductId,
        'inventory-movement-product-field',
      ),
      _field(
        _variationController,
        context.l10n.inventoryEtichettaVariationId,
        'inventory-movement-variation-field',
      ),
      _field(
        _fromController,
        context.l10n.inventoryEtichettaDaData,
        'inventory-movement-from-field',
      ),
      _field(
        _toController,
        context.l10n.inventoryEtichettaAData,
        'inventory-movement-to-field',
      ),
      _field(
        _sourceController,
        context.l10n.inventoryEtichettaSource,
        'inventory-movement-source-field',
      ),
      _field(
        _operatorController,
        context.l10n.inventoryEtichettaOperatore,
        'inventory-movement-operator-field',
      ),
      _field(
        _reasonController,
        context.l10n.inventoryEtichettaReason,
        'inventory-movement-reason-field',
      ),
      _field(
        _effectController,
        context.l10n.inventoryEtichettaEffetto,
        'inventory-movement-effect-field',
      ),
      OutlinedButton.icon(
        key: const ValueKey('inventory-movement-refresh'),
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.inventoryAggiornaMovimenti),
      ),
    ],
  );

  Widget _grid(List<InventoryMovementGroup> groups) =>
      DataGridView<InventoryMovementGroup>(
        columns: [
          DataGridViewColumn(
            id: 'time',
            label: context.l10n.commonDate,
            width: 175,
          ),
          DataGridViewColumn(
            id: 'kind',
            label: context.l10n.inventoryEtichettaTipo,
            width: 120,
          ),
          DataGridViewColumn(
            id: 'operator',
            label: context.l10n.inventoryEtichettaOperatore,
            width: 110,
          ),
          DataGridViewColumn(
            id: 'delta',
            label: context.l10n.inventoryEtichettaPezzi,
            width: 80,
            numeric: true,
          ),
          DataGridViewColumn(
            id: 'products',
            label: context.l10n.inventoryEtichettaProdotti,
            width: 90,
            numeric: true,
          ),
          DataGridViewColumn(
            id: 'last',
            label: context.l10n.inventoryEtichettaUltimaModifica,
            width: 175,
          ),
          DataGridViewColumn(
            id: 'reason',
            label: context.l10n.inventoryEtichettaMotivoEDettagli,
            flexible: true,
          ),
        ],
        rows: [for (final group in groups) _row(group)],
        selectedRowId: _selected?.key,
        onRowSelected: (group) => setState(() => _selected = group),
        onRowDoubleTap: _openGroup,
        // Su telefono il doppio tocco non lo prova nessuno: basta un tocco.
        onRowTap: MediaQuery.sizeOf(context).width < 600 ? _openGroup : null,
        contextActions: [
          DataGridViewContextAction<InventoryMovementGroup>(
            label: context.l10n.inventoryApriMovimento,
            icon: Icons.open_in_new,
            onSelected: _openGroup,
          ),
        ],
      );

  DataGridViewRowData<InventoryMovementGroup> _row(
    InventoryMovementGroup group,
  ) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    // Il colore del delta ha tre casi, non due. Lo spostamento non cambia il
    // totale, quindi il suo delta e' zero per costruzione: colorarlo di verde
    // come un aumento direbbe "e' andata bene", che e' un'altra informazione da
    // quella che la riga sta dando. Un delta zero dice solo che il totale non si
    // e' mosso, e il totale non muoversi e' il fatto normale, non una buona
    // notizia. Il colore del testo di base e' quello giusto per un dato che non
    // ha un peso.
    final tone = group.quantityDelta == 0
        ? Theme.of(context).colorScheme.onSurface
        : (group.quantityDelta > 0
              ? colors.successColor
              : colors.errorColorStatus);
    // Sullo spostamento la colonna del delta mostrerebbe uno zero che non dice
    // niente, mentre l'informazione utile e' quanti pezzi hanno cambiato
    // magazzino. La riga e' gia' etichettata come spostamento nella colonna
    // della tipologia, quindi qui basta il numero senza segno: il segno
    // suggerirebbe una variazione che non c'e' stata.
    final deltaCell = group.isMove
        ? Text('${group.movedQuantity} ${context.l10n.inventoryParolaPezzi}')
        : Text(movementSigned(group.quantityDelta));
    return DataGridViewRowData(
      id: group.key,
      value: group,
      foregroundColor: tone,
      cells: {
        'time': Text(formatMovementDate(group.occurredAtGmt)),
        // Il tipo che MGWS scrive resta visibile accanto all'etichetta quando
        // non e' uno che l'app conosce: meglio una parola grezza che un
        //-etichetta indovinata.
        'kind': Text(
          group.kind == InventoryMovementKind.altro
              ? '${group.kindLabel} (${group.rawType})'
              : group.kindLabel,
        ),
        'operator': Text('#${group.operatorUserId}'),
        'delta': deltaCell,
        'products': Text('${group.productCount}'),
        'last': Text(formatMovementDate(group.lastModifiedGmt)),
        'reason': Text(group.reasonAndDetails),
      },
    );
  }

  Widget _field(TextEditingController controller, String label, String key) {
    return SizedBox(
      width: _larghezzaCampo,
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  /// Avviso che la risposta e' stata tagliata dal backend.
  Widget _truncationNotice() {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final total = widget.controller.movementPage!.total;
    final shown = widget.controller.movements.length;
    return Container(
      key: const ValueKey('inventory-movement-truncated'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warningColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.inventoryMovimentiAvviso('$shown', '$total'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppColorExtension colors) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.priceBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(context.l10n.inventoryMovimentiNessuno),
  );
}
