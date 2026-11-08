import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory_quick_load.code.dart';
import 'inventory_quick_load_picker.gui.dart';

/// Selettori condivisi dei moduli MGWS: l'operatore sceglie magazzini e
/// prodotti per nome, non digita ID numerici.

/// Chiede un magazzino attivo. Restituisce null se l'operatore annulla o se
/// i magazzini non si caricano (in quel caso mostra il motivo).
Future<MgwsInventoryWarehouse?> pickMgwsWarehouse(
  BuildContext context, {
  required String title,
  int? excludeId,
}) async {
  final result = await QueryMgwsInventory().listWarehouses();
  if (!context.mounted) return null;
  final warehouses = result.success
      ? (result.data ?? const <MgwsInventoryWarehouse>[])
            .where((warehouse) => warehouse.active && warehouse.id != excludeId)
            .toList()
      : null;
  if (warehouses == null || warehouses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.mgwsResetWarehousesUnavailable)),
    );
    return null;
  }
  return showDialog<MgwsInventoryWarehouse>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: <Widget>[
        for (final warehouse in warehouses)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(warehouse),
            child: Text(warehouse.name),
          ),
      ],
    ),
  );
}

/// Chiede uno o più prodotti con la loro quantità, riusando il picker del
/// carico rapido (ricerca, scansione, varianti). Lista vuota = annullato.
Future<List<InventoryQuickLoadLineDraft>> pickMgwsProductLines(
  BuildContext context,
) async {
  final lines = await showInventoryQuickLoadPicker(context);
  return lines ?? const <InventoryQuickLoadLineDraft>[];
}
