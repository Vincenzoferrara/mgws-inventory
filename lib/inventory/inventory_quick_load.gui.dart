import 'package:flutter/material.dart';

import '../login/gui/login.code.dart';
import '../settings/inventory_quick_load_settings.dart';
import '../reuse_class/datagridview/datagridview_image_preview.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';
import 'inventory_quick_load_picker.gui.dart';
import 'inventory_quick_load_widgets.gui.dart';

typedef InventoryQuickLoadPickerLauncher =
    Future<List<InventoryQuickLoadLineDraft>?> Function(
      BuildContext context,
      List<InventoryQuickLoadLineDraft> initialLines,
    );

class InventoryQuickLoadPanel extends StatefulWidget {
  InventoryQuickLoadPanel({
    super.key,
    InventoryQuickLoadController? controller,
    InventoryQuickLoadSettings? settings,
    this.pickerLauncher,
  }) : controller = controller ?? InventoryQuickLoadController(),
       settings = settings ?? inventoryQuickLoadSettings;

  final InventoryQuickLoadController controller;
  final InventoryQuickLoadSettings settings;
  final InventoryQuickLoadPickerLauncher? pickerLauncher;

  @override
  State<InventoryQuickLoadPanel> createState() =>
      _InventoryQuickLoadPanelState();
}

class _InventoryQuickLoadPanelState extends State<InventoryQuickLoadPanel> {
  final _siteController = TextEditingController();
  final _noteController = TextEditingController();
  List<InventoryQuickLoadLineDraft> _lines = const [];
  InventoryActionFeedback? _feedback;
  String? _warehouse;
  String? _room;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _warehouse = widget.settings.defaultWarehouse;
    _room = widget.settings.defaultRoom;
    _loadSettings();
    _loadOperatorSite();
  }

  Future<void> _loadOperatorSite() async {
    final profile = await loginCode.currentUserProfile();
    if (!mounted) return;
    final siteId = profile?.defaultSiteId ?? 0;
    if (siteId > 0 && _siteController.text.trim().isEmpty) {
      setState(() => _siteController.text = siteId.toString());
    }
  }

  Future<void> _loadSettings() async {
    await widget.settings.init();
    if (!mounted) return;
    setState(() {
      _warehouse = widget.settings.defaultWarehouse;
      _room = widget.settings.defaultRoom;
    });
  }

  @override
  void dispose() {
    _siteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openPicker() async {
    final selected = widget.pickerLauncher == null
        ? await showInventoryQuickLoadPicker(context, initialLines: _lines)
        : await widget.pickerLauncher!(context, _lines);
    if (!mounted || selected == null) return;
    setState(() {
      _lines = List<InventoryQuickLoadLineDraft>.unmodifiable(
        selected.map(
          (line) => line.copyWith(
            rack: widget.settings.rackEnabled
                ? line.rack ?? widget.settings.defaultRack
                : '',
            shelf: widget.settings.shelfEnabled
                ? line.shelf ?? widget.settings.defaultShelf
                : '',
          ),
        ),
      );
      _feedback = null;
    });
  }

  InventoryQuickLoadSubmissionPlan _plan() {
    return InventoryQuickLoadSubmissionPlan(
      lines: _lines
          .map(
            (line) => line.copyWith(
              rack: widget.settings.rackEnabled ? line.rack : '',
              shelf: widget.settings.shelfEnabled ? line.shelf : '',
            ),
          )
          .toList(growable: false),
      siteId: int.tryParse(_siteController.text.trim()) ?? 0,
      note: _noteController.text,
      warehouseId: widget.settings.warehouseEnabled
          ? int.tryParse(_warehouse ?? '')
          : null,
      room: widget.settings.roomEnabled ? _room : null,
    );
  }

  Future<void> _startSubmit() async {
    final plan = _plan();
    final parsed = plan.parse();
    if (parsed case InventoryFormInvalid(:final message)) {
      _showFeedback(InventoryActionFeedback(success: false, message: message));
      return;
    }
    final confirmed = await showInventoryQuickLoadBatchConfirmDialog(
      context: context,
      plan: plan,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final feedback = await widget.controller.submitPlan(plan);
    if (!mounted) return;
    final failedLines = widget.controller.retryableLines;
    setState(() {
      _feedback = feedback;
      _submitting = false;
      _lines = failedLines.isEmpty
          ? const <InventoryQuickLoadLineDraft>[]
          : failedLines;
    });
    if (widget.controller.lastQuickLoadResults.any(
      (result) => result.success,
    )) {
      final locationLine = widget.controller.lastQuickLoadResults
          .lastWhere((result) => result.success)
          .line;
      await widget.settings.rememberLocation(
        warehouseId: plan.warehouseId,
        room: plan.room,
        rack: locationLine.rack,
        shelf: locationLine.shelf,
      );
    }
    if (mounted) _snack(feedback.message, success: feedback.success);
  }

  void _removeLine(String key) {
    setState(() {
      _lines = _lines.where((line) => line.key != key).toList(growable: false);
      _feedback = null;
    });
  }

  void _changeQuantity(InventoryQuickLoadLineDraft line, int quantity) {
    if (quantity <= 0) return;
    setState(() {
      _lines = _lines
          .map(
            (item) =>
                item.key == line.key ? item.copyWith(quantity: quantity) : item,
          )
          .toList(growable: false);
      _feedback = null;
    });
  }

  void _changeLocation(
    InventoryQuickLoadLineDraft line, {
    String? rack,
    String? shelf,
  }) {
    setState(() {
      _lines = _lines
          .map(
            (item) => item.key == line.key
                ? item.copyWith(rack: rack, shelf: shelf)
                : item,
          )
          .toList(growable: false);
      _feedback = null;
    });
  }

  void _showFeedback(InventoryActionFeedback feedback) {
    setState(() => _feedback = feedback);
    _snack(feedback.message, success: feedback.success);
  }

  void _snack(String message, {required bool success}) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? colors.successColor
            : colors.errorColorStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-quick-load-card'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InventoryQuickLoadHeader(colors: colors),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                if (!wide) {
                  return Column(
                    children: [
                      _buildLocationCard(),
                      const SizedBox(height: 12),
                      _buildSelectionCard(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildLocationCard()),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: _buildSelectionCard()),
                  ],
                );
              },
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              InventoryQuickLoadFeedbackPanel(
                feedback: _feedback!,
                result: widget.controller.lastQuickLoadResults.length == 1
                    ? widget.controller.lastQuickLoad
                    : null,
              ),
              if (widget.controller.lastQuickLoadResults.isNotEmpty)
                _buildResultList(),
            ],
            const SizedBox(height: 16),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: context.l10n.inventorySezionePosizione1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 540
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: TextField(
                  key: const ValueKey('inventory-quick-load-site-field'),
                  controller: _siteController,
                  decoration: InputDecoration(
                    labelText: context.l10n.inventoryEtichettaSedeObbligatoria,
                    prefixIcon: const Icon(Icons.public),
                  ),
                ),
              ),
              if (widget.settings.warehouseEnabled)
                SizedBox(
                  width: width,
                  child: InventoryQuickLoadSelector(
                    keyName: 'inventory-quick-load-warehouse-field',
                    label: context.l10n.inventoryEtichettaMagazzino,
                    icon: Icons.warehouse_outlined,
                    value: _warehouse,
                    options: widget.settings.warehouseOptions,
                    onChanged: (value) => setState(() => _warehouse = value),
                  ),
                ),
              if (widget.settings.roomEnabled)
                SizedBox(
                  width: width,
                  child: InventoryQuickLoadSelector(
                    keyName: 'inventory-quick-load-room-field',
                    label: context.l10n.inventoryEtichettaStanza,
                    icon: Icons.meeting_room_outlined,
                    value: _room,
                    options: widget.settings.roomOptions,
                    onChanged: (value) => setState(() => _room = value),
                  ),
                ),
              SizedBox(
                width: width,
                child: TextField(
                  key: const ValueKey('inventory-quick-load-note-field'),
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: context.l10n.inventoryEtichettaNotaOperativa,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectionCard() {
    return _SectionCard(
      icon: Icons.inventory_2_outlined,
      title: context.l10n.inventoryTitoloSecondStep,
      trailing: FilledButton.icon(
        key: const ValueKey('inventory-quick-load-open-picker'),
        onPressed: _submitting ? null : _openPicker,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        icon: const Icon(Icons.add),
        label: Text(
          _lines.isEmpty ? 'Seleziona prodotti' : 'Modifica selezione',
        ),
      ),
      child: _lines.isEmpty
          ? const _EmptySelection()
          : Column(
              children: [for (final line in _lines) _buildSelectedLine(line)],
            ),
    );
  }

  Widget _buildSelectedLine(InventoryQuickLoadLineDraft line) {
    return Container(
      key: ValueKey('inventory-quick-load-selected-${line.key}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              DataGridViewImagePreview(
                key: ValueKey(
                  'inventory-quick-load-selected-image-${line.key}',
                ),
                imageUrl: line.imageUrl,
                semanticLabel: 'Copertina ${line.label}',
                size: 48,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (line.barcodeInterno?.trim().isNotEmpty == true)
                      Text(
                        'Barcode interno ${line.barcodeInterno}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              _InlineQuantity(
                line: line,
                onChanged: (quantity) => _changeQuantity(line, quantity),
              ),
              IconButton(
                tooltip: context.l10n.inventoryTooltipRimuovi,
                onPressed: () => _removeLine(line.key),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth >= 420
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (widget.settings.rackEnabled)
                    SizedBox(
                      width: fieldWidth,
                      child: TextFormField(
                        key: ValueKey('inventory-quick-load-rack-${line.key}'),
                        initialValue: line.rack,
                        decoration: InputDecoration(
                          labelText: context.l10n.inventoryLabelScaffale,
                          prefixIcon: Icon(Icons.view_list_outlined),
                        ),
                        onChanged: (value) =>
                            _changeLocation(line, rack: value),
                      ),
                    ),
                  if (widget.settings.shelfEnabled)
                    SizedBox(
                      width: fieldWidth,
                      child: TextFormField(
                        key: ValueKey('inventory-quick-load-shelf-${line.key}'),
                        initialValue: line.shelf,
                        decoration: InputDecoration(
                          labelText: context.l10n.inventoryLabelRipiano,
                          prefixIcon: Icon(Icons.view_agenda_outlined),
                        ),
                        onChanged: (value) =>
                            _changeLocation(line, shelf: value),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final result in widget.controller.lastQuickLoadResults)
            Chip(
              avatar: Icon(
                result.success ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: result.success
                    ? Theme.of(
                        context,
                      ).extension<AppColorExtension>()!.successColor
                    : Theme.of(
                        context,
                      ).extension<AppColorExtension>()!.errorColorStatus,
              ),
              label: Text(result.line.label),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final totalQuantity = _lines.fold<int>(
      0,
      (sum, line) => sum + line.quantity,
    );
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        if (_lines.isNotEmpty)
          Text(
            '${_lines.length} righe · $totalQuantity pezzi',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-quick-load-submit'),
          onPressed: _submitting ? null : _startSubmit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add_check),
          label: Text(
            _submitting
                ? 'Invio in corso'
                : widget.controller.retryableLines.isNotEmpty &&
                      _lines.isNotEmpty
                ? 'Riprova ${_lines.length} righe'
                : 'Controlla e carica',
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    Icon(icon, size: 21),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );
                if (trailing == null) return heading;
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const SizedBox(height: 10), trailing!],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.playlist_add, size: 34),
          SizedBox(height: 8),
          Text(context.l10n.inventoryNessunProdottoSelezionato),
          SizedBox(height: 4),
          Text(
            'Apri il catalogo per scegliere prodotti semplici o varianti.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InlineQuantity extends StatelessWidget {
  const _InlineQuantity({required this.line, required this.onChanged});

  final InventoryQuickLoadLineDraft line;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('inventory-quick-load-minus-${line.key}'),
          tooltip: context.l10n.inventoryTooltipRiduciQuantita,
          visualDensity: VisualDensity.compact,
          onPressed: line.quantity <= 1
              ? null
              : () => onChanged(line.quantity - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '${line.quantity}',
          key: ValueKey('inventory-quick-load-quantity-${line.key}'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        IconButton(
          key: ValueKey('inventory-quick-load-plus-${line.key}'),
          tooltip: context.l10n.inventoryTooltipAumentaQuantita,
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(line.quantity + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
