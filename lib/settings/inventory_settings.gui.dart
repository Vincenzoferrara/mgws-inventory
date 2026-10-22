import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../inventory/inventory_site_panel.gui.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import '../login/mgws/query/query_mgws_site.dart';
import 'inventory_quick_load_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

class InventorySettingsTab extends StatefulWidget {
  const InventorySettingsTab({super.key});

  @override
  State<InventorySettingsTab> createState() => _InventorySettingsTabState();
}

class _InventorySettingsTabState extends State<InventorySettingsTab> {
  final _warehouseController = TextEditingController();
  final _roomController = TextEditingController();
  final _rackController = TextEditingController();
  final _shelfController = TextEditingController();
  bool _didSeed = false;
  bool _saving = false;

  /// Magazzini registrati sul server per la sede in uso. `null` finche' non
  /// c'e' una sede o mentre si leggono.
  List<MgwsInventoryWarehouse>? _magazzini;
  bool _magazziniInCaricamento = false;

  Future<void> _onSede(MgwsSiteStatus? stato) async {
    if (stato == null) {
      setState(() => _magazzini = null);
      return;
    }
    setState(() => _magazziniInCaricamento = true);
    final result = await QueryMgwsInventory().listWarehouses(
      siteId: stato.siteId,
    );
    if (!mounted) return;
    setState(() {
      _magazziniInCaricamento = false;
      _magazzini = result.success
          ? (result.data ?? const <MgwsInventoryWarehouse>[])
                .where((magazzino) => magazzino.active)
                .toList()
          : null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeed) return;
    final settings = context.read<InventoryQuickLoadSettings>();
    _warehouseController.text = settings.warehouseOptions.join(', ');
    _roomController.text = settings.roomOptions.join(', ');
    _rackController.text = settings.rackOptions.join(', ');
    _shelfController.text = settings.shelfOptions.join(', ');
    _didSeed = true;
  }

  @override
  void dispose() {
    _warehouseController.dispose();
    _roomController.dispose();
    _rackController.dispose();
    _shelfController.dispose();
    super.dispose();
  }

  Future<void> _saveOptions(InventoryQuickLoadSettings settings) async {
    setState(() => _saving = true);
    await settings.setWarehouseOptions(
      parseInventoryQuickLoadOptions(_warehouseController.text),
    );
    await settings.setRoomOptions(
      parseInventoryQuickLoadOptions(_roomController.text),
    );
    await settings.setRackOptions(
      parseInventoryQuickLoadOptions(_rackController.text),
    );
    await settings.setShelfOptions(
      parseInventoryQuickLoadOptions(_shelfController.text),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsQuickLoadSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryQuickLoadSettings>(
      builder: (context, settings, _) {
        return ListView(
          padding: context.spacing.iL,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.settingsInventoryTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.settingsInventoryDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  // La sede in uso vale anche qui: i magazzini che contano
                  // sono quelli della sede, letti dal server.
                  Card(
                    child: Padding(
                      padding: context.spacing.iL,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InventorySitePanel(onStatusChanged: _onSede),
                          if (_magazziniInCaricamento) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(),
                          ] else if (_magazzini != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.sedeMagazzini,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            if (_magazzini!.isEmpty)
                              Text(context.l10n.sedeNessunMagazzino)
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final magazzino in _magazzini!)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.warehouse_outlined,
                                        size: 18,
                                      ),
                                      label: Text(magazzino.name),
                                    ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: context.spacing.iL,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.settingsInventorySelectable,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(context.l10n.settingsInventorySelectableHint),
                          const SizedBox(height: 16),
                          _OptionsField(
                            controller: _warehouseController,
                            label: context.l10n.settingsInventoryWarehouses,
                            hint: '1, 2, 3',
                          ),
                          _OptionsField(
                            controller: _roomController,
                            label: context.l10n.settingsInventoryRooms,
                            hint: context.l10n.settingsInventoryRoomsHint,
                          ),
                          _OptionsField(
                            controller: _rackController,
                            label: context.l10n.settingsInventoryRacks,
                            hint: context.l10n.settingsInventoryRacksHint,
                          ),
                          _OptionsField(
                            controller: _shelfController,
                            label: context.l10n.settingsInventoryShelves,
                            hint: context.l10n.settingsInventoryShelvesHint,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _saveOptions(settings),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                context.l10n.settingsInventorySaveOptions,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: context.spacing.iL,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.settingsInventoryDefaults,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (settings.warehouseEnabled)
                                _defaultSelector(
                                  label: context
                                      .l10n
                                      .settingsInventoryDefaultWarehouse,
                                  options: settings.warehouseOptions,
                                  value: settings.defaultWarehouse,
                                  onChanged: (value) => settings.setDefaults(
                                    warehouse: value,
                                    room: settings.defaultRoom,
                                    rack: settings.defaultRack,
                                    shelf: settings.defaultShelf,
                                  ),
                                ),
                              if (settings.roomEnabled)
                                _defaultSelector(
                                  label:
                                      context.l10n.settingsInventoryDefaultRoom,
                                  options: settings.roomOptions,
                                  value: settings.defaultRoom,
                                  onChanged: (value) => settings.setDefaults(
                                    warehouse: settings.defaultWarehouse,
                                    room: value,
                                    rack: settings.defaultRack,
                                    shelf: settings.defaultShelf,
                                  ),
                                ),
                              if (settings.rackEnabled)
                                _defaultSelector(
                                  label:
                                      context.l10n.settingsInventoryDefaultRack,
                                  options: settings.rackOptions,
                                  value: settings.defaultRack,
                                  onChanged: (value) => settings.setDefaults(
                                    warehouse: settings.defaultWarehouse,
                                    room: settings.defaultRoom,
                                    rack: value,
                                    shelf: settings.defaultShelf,
                                  ),
                                ),
                              if (settings.shelfEnabled)
                                _defaultSelector(
                                  label: context
                                      .l10n
                                      .settingsInventoryDefaultShelf,
                                  options: settings.shelfOptions,
                                  value: settings.defaultShelf,
                                  onChanged: (value) => settings.setDefaults(
                                    warehouse: settings.defaultWarehouse,
                                    room: settings.defaultRoom,
                                    rack: settings.defaultRack,
                                    shelf: value,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _defaultSelector({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value-${options.length}'),
        initialValue: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(context.l10n.settingsInventoryNone),
          ),
          for (final option in options)
            DropdownMenuItem<String>(value: option, child: Text(option)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _OptionsField extends StatelessWidget {
  const _OptionsField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.m),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 2,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
