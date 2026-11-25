// lib/rfid/uhf/uhf_panel_route.dart
//
// Dialog route for the UHF RFID panel. The caller only supplies the gateway,
// the reader callback and the target of the associated load lines, so the
// inventory Add screen keeps no UHF GUI or routing code.

import 'package:material_ui/material_ui.dart';

import '../../inventory/inventory_quick_load.code.dart';
import '../../l10n/extensions.dart';
import '../../login/mgws/query/query_mgws_inventory_models.dart';
import 'uhf_scan.gui.dart';

Future<void> showUhfRfidPanel(
  BuildContext context, {
  required MgwsInventoryGateway gateway,
  required Future<List<String>> Function() readTags,
  required void Function(List<InventoryQuickLoadLineDraft> lines) onSend,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.inventoryRfidTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('inventory-rfid-close'),
                    tooltip: context.l10n.inventoryTooltipChiudi,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InventoryRfidPanel(
                gateway: gateway,
                readTags: readTags,
                onSend: (lines) {
                  onSend(lines);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
