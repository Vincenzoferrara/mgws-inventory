import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';

class InventoryCountFilters extends StatelessWidget {
  const InventoryCountFilters({
    super.key,
    required this.siteController,
    required this.warehouseController,
    required this.loading,
    required this.onRefresh,
  });

  final TextEditingController siteController;
  final TextEditingController warehouseController;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      inventoryCountField(
        siteController,
        'Site ID',
        'inventory-count-filter-site',
      ),
      inventoryCountField(
        warehouseController,
        'Warehouse ID',
        'inventory-count-filter-warehouse',
      ),
      OutlinedButton.icon(
        onPressed: loading ? null : onRefresh,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.inventoryAggiornaSessioni),
      ),
    ],
  );
}

class InventoryCountSessionFields extends StatelessWidget {
  const InventoryCountSessionFields({
    super.key,
    required this.siteController,
    required this.warehouseController,
    required this.documentController,
    required this.notesController,
    required this.busy,
    required this.hasSelection,
    required this.posted,
    required this.onCreate,
    required this.onApprove,
  });

  final TextEditingController siteController;
  final TextEditingController warehouseController;
  final TextEditingController documentController;
  final TextEditingController notesController;
  final bool busy;
  final bool hasSelection;
  final bool posted;
  final VoidCallback onCreate;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      inventoryCountField(
        siteController,
        'Site ID *',
        'inventory-count-site-field',
      ),
      inventoryCountField(
        warehouseController,
        'Warehouse ID *',
        'inventory-count-warehouse-field',
      ),
      inventoryCountField(
        documentController,
        'Documento *',
        'inventory-count-document-field',
      ),
      inventoryCountField(
        notesController,
        'Note',
        'inventory-count-notes-field',
      ),
      ElevatedButton.icon(
        key: const ValueKey('inventory-count-create'),
        onPressed: busy ? null : onCreate,
        icon: const Icon(Icons.add_task),
        label: Text(context.l10n.inventoryCreaSessione),
      ),
      ElevatedButton.icon(
        key: const ValueKey('inventory-count-approve'),
        onPressed: busy || !hasSelection || posted ? null : onApprove,
        icon: const Icon(Icons.verified),
        label: Text(context.l10n.inventoryApprovaEPosta),
      ),
    ],
  );
}

class InventoryCountLineFields extends StatelessWidget {
  const InventoryCountLineFields({
    super.key,
    required this.sessionController,
    required this.productController,
    required this.variationController,
    required this.barcodeController,
    required this.tagController,
    required this.quantityController,
    required this.reasonController,
    required this.busy,
    required this.onSave,
  });

  final TextEditingController sessionController;
  final TextEditingController productController;
  final TextEditingController variationController;
  final TextEditingController barcodeController;
  final TextEditingController tagController;
  final TextEditingController quantityController;
  final TextEditingController reasonController;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      inventoryCountField(
        sessionController,
        'Sessione',
        'inventory-count-session-field',
      ),
      inventoryCountField(
        productController,
        context.l10n.inventoryEtichettaProductId,
        'inventory-count-product-field',
      ),
      inventoryCountField(
        variationController,
        context.l10n.inventoryEtichettaVariationId,
        'inventory-count-variation-field',
      ),
      inventoryCountField(
        barcodeController,
        'Barcode',
        'inventory-count-barcode-field',
      ),
      inventoryCountField(
        tagController,
        'Tag RFID',
        'inventory-count-tag-field',
      ),
      inventoryCountField(
        quantityController,
        'Quantita fisica *',
        'inventory-count-quantity-field',
      ),
      inventoryCountField(
        reasonController,
        context.l10n.inventoryEtichettaReason,
        'inventory-count-reason-field',
      ),
      ElevatedButton.icon(
        key: const ValueKey('inventory-count-line-save'),
        onPressed: busy ? null : onSave,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(context.l10n.inventorySalvaRigaConteggio),
      ),
    ],
  );
}

Widget inventoryCountField(
  TextEditingController controller,
  String label,
  String key,
) {
  return SizedBox(
    width: 185,
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class InventoryCountReadOnlyBanner extends StatelessWidget {
  const InventoryCountReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(context.l10n.inventorySessioneRegistrata),
    );
  }
}

class InventoryCountEmptyState extends StatelessWidget {
  const InventoryCountEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.priceBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(context.l10n.inventoryNessunaSessione),
    );
  }
}
