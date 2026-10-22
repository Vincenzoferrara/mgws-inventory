import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import 'inventory.code.dart';
import '../l10n/extensions.dart';

class InventoryReorderPanel extends StatefulWidget {
  InventoryReorderPanel({super.key, InventoryReorderController? controller})
    : controller = controller ?? InventoryReorderController();

  final InventoryReorderController controller;

  @override
  State<InventoryReorderPanel> createState() => _InventoryReorderPanelState();
}

class _InventoryReorderPanelState extends State<InventoryReorderPanel> {
  final _siteController = TextEditingController();
  final _warehouseController = TextEditingController();
  InventoryActionFeedback? _feedback;
  MgwsReorderSuggestion? _selected;
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _siteController.dispose();
    _warehouseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final feedback = await widget.controller.loadSuggestions(
      siteIdText: _siteController.text,
      warehouseIdText: _warehouseController.text,
    );
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
      if (_selected == null && widget.controller.suggestions.isNotEmpty) {
        _selected = widget.controller.suggestions.first;
      }
    });
  }

  Future<void> _createDraft() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _creating = true);
    final feedback = await widget.controller.createDraftFromSuggestion(
      selected,
    );
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _creating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-reorder-panel'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.trending_up,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Riordino',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Suggerimenti MGWS da soglie stock basse: genera bozze ordine senza mutare giacenze.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _filters(),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (widget.controller.suggestions.isEmpty)
                _EmptyReorder(colors: colors)
              else
                SizedBox(height: 300, child: _grid()),
              const SizedBox(height: 12),
              _summary(colors),
              const SizedBox(height: 12),
              if (_feedback != null) _ReorderFeedback(feedback: _feedback!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _field(_siteController, 'Site ID', 'inventory-reorder-site-field'),
        _field(
          _warehouseController,
          'Warehouse ID',
          'inventory-reorder-warehouse-field',
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.inventoryAggiornaSuggerimenti),
        ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-reorder-create-draft'),
          onPressed: _selected == null || _creating ? null : _createDraft,
          icon: _creating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add),
          label: Text(context.l10n.inventoryCreaBozzaOrdine),
        ),
      ],
    );
  }

  Widget _grid() {
    return DataGridView<MgwsReorderSuggestion>(
      columns: const [
        DataGridViewColumn(id: 'product', label: 'Prodotto', width: 170),
        DataGridViewColumn(id: 'supplier', label: 'Fornitore', width: 120),
        DataGridViewColumn(
          id: 'stock',
          label: 'Stock',
          width: 110,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'target',
          label: 'Target',
          width: 120,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'qty',
          label: 'Da ordinare',
          width: 130,
          numeric: true,
        ),
        DataGridViewColumn(id: 'lead', label: 'Lead time', width: 120),
      ],
      rows: [
        for (final suggestion in widget.controller.suggestions)
          _row(suggestion),
      ],
      selectedRowId: _selected == null ? null : _id(_selected!),
      onRowSelected: (suggestion) => setState(() => _selected = suggestion),
      onRowDoubleTap: (suggestion) => setState(() => _selected = suggestion),
    );
  }

  DataGridViewRowData<MgwsReorderSuggestion> _row(
    MgwsReorderSuggestion suggestion,
  ) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    return DataGridViewRowData(
      id: _id(suggestion),
      value: suggestion,
      backgroundColor: suggestion.currentStock <= suggestion.reorderPoint
          ? colors.warningColor.withValues(alpha: 0.08)
          : null,
      cells: {
        'product': Text(
          suggestion.variationId > 0
              ? 'Prodotto #${suggestion.productId} / Variante ${suggestion.variationId}'
              : 'Prodotto #${suggestion.productId}',
        ),
        'supplier': Text('#${suggestion.supplierId}'),
        'stock': Text(
          '${suggestion.currentStock} / ${suggestion.reorderPoint}',
        ),
        'target': Text('${suggestion.targetStock}'),
        'qty': Chip(label: Text('${suggestion.suggestedQuantity}')),
        'lead': Text(
          '${suggestion.leadTimeDays}g + safety ${suggestion.safetyDays}g',
        ),
      },
    );
  }

  Widget _summary(AppColorExtension colors) {
    final selected = _selected;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text(
            context.l10n.inventorySuggestionCount(
              '${widget.controller.suggestions.length}',
            ),
          ),
        ),
        if (selected != null) ...[
          Chip(
            label: Text(
              context.l10n.inventoryRegolaNumero('${selected.ruleId}'),
            ),
          ),
          Chip(
            label: Text(
              context.l10n.inventoryMagazzinoNumero('${selected.warehouseId}'),
            ),
          ),
          Chip(
            label: Text(
              'Stock ${selected.currentStock} -> ${selected.targetStock}',
            ),
            side: BorderSide(color: colors.warningColor),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, String key) {
    return SizedBox(
      width: 180,
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String _id(MgwsReorderSuggestion suggestion) =>
      '${suggestion.ruleId}-${suggestion.productId}-${suggestion.variationId}';
}

class _EmptyReorder extends StatelessWidget {
  const _EmptyReorder({required this.colors});
  final AppColorExtension colors;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.priceBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(context.l10n.inventoryNessunSuggerimento),
  );
}

class _ReorderFeedback extends StatelessWidget {
  const _ReorderFeedback({required this.feedback});
  final InventoryActionFeedback feedback;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final detail in feedback.details)
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
