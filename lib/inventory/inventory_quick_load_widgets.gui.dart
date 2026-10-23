import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';

/// "3 righe · 12 pezzi": due numeri e le due parole che li descrivono.
///
/// Le parole sono le stesse in tutto il modulo, quindi stanno nelle traduzioni
/// e la coppia resta leggibile anche in inglese.
String _righeEPezzi(BuildContext context, int righe, int pezzi) =>
    '${righe} ${context.l10n.inventoryParolaRighe} · '
    '${pezzi} ${context.l10n.inventoryParolaPezzi}';

Future<bool?> showInventoryQuickLoadConfirmDialog({
  required BuildContext context,
  required MgwsQuickLoadRequest request,
  required String preview,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.inventoryConfermaCaricoRapido),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.l10n.inventoryEtichettaProdotto}: ${request.productId}',
            ),
            Text(
              '${context.l10n.inventoryEtichettaVariante}: ${request.variationId}',
            ),
            if ((request.barcode ?? '').isNotEmpty)
              Text(
                '${context.l10n.inventoryEtichettaBarcode}: ${request.barcode}',
              ),
            Text(
              '${context.l10n.inventoryEtichettaQuantitaDaAggiungere}: '
              '${request.quantityDelta}',
            ),
            Text('${context.l10n.inventoryEtichettaMotivo}: ${request.reason}'),
            if ((request.note ?? '').isNotEmpty)
              Text('${context.l10n.inventoryEtichettaNota}: ${request.note}'),
            const SizedBox(height: 12),
            Text(preview, key: const ValueKey('inventory-quick-load-preview')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          key: const ValueKey('inventory-quick-load-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.inventoryConfermaCarico),
        ),
      ],
    ),
  );
}

Future<bool?> showInventoryQuickLoadBatchConfirmDialog({
  required BuildContext context,
  required InventoryQuickLoadSubmissionPlan plan,
  InventoryLocationDirectory places = InventoryLocationDirectory.empty,
}) {
  final listHeight = (plan.lines.length * 56.0).clamp(56.0, 280.0);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.inventoryConfermaCaricoRapido),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _righeEPezzi(context, plan.lines.length, plan.totalQuantity),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.l10n.inventoryEtichettaMotivo} ${context.l10n.inventoryStockInReason}',
            ),
            if (plan.warehouseId != null || plan.room != null)
              Text(
                '${context.l10n.inventoryEtichettaPosizioneCondivisa} '
                '${[if (plan.warehouseId != null) places.warehouseLabel(context.l10n, plan.warehouseId!), if (plan.room != null) '${context.l10n.inventoryEtichettaStanza} ${plan.room}'].join(' · ')}',
              ),
            if ((plan.note ?? '').isNotEmpty)
              Text('${context.l10n.inventoryEtichettaNota}: ${plan.note}'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(context.l10n.inventoryNotaConfermaCarico)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                itemCount: plan.lines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final line = plan.lines[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.label),
                    subtitle: Text(
                      [
                        if (line.barcodeInterno?.trim().isNotEmpty == true)
                          '${context.l10n.inventoryBarcodeInterno} ${line.barcodeInterno}',
                        if (line.rack?.trim().isNotEmpty == true)
                          '${context.l10n.inventoryEtichettaScaffale} ${line.rack}',
                        if (line.shelf?.trim().isNotEmpty == true)
                          '${context.l10n.inventoryEtichettaRipiano} ${line.shelf}',
                      ].join(' · '),
                    ),
                    trailing: Text('× ${line.quantity}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-quick-load-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.playlist_add_check),
          label: Text(context.l10n.inventoryConfermaCarico),
        ),
      ],
    ),
  );
}

/// Chiede quanti pezzi aggiungere per un prodotto.
///
/// Serve quando l'operatore ha tolto la spunta "aggiungi automaticamente":
/// in quel caso nessuna quantita' viene indovinata, la chiede lui. Restituisce
/// null se annulla, cosi' il chiamante distingue "non ho deciso" da "ho
/// deciso zero" — che non e' una risposta valida.
Future<int?> showInventoryQuantityPrompt({
  required BuildContext context,
  required String label,
  int initial = 1,
}) {
  final controller = TextEditingController(text: '$initial');
  final error = ValueNotifier<String?>(null);

  int? parse() {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      error.value = context.l10n.inventoryErroreQuantitaNonPositiva;
      return null;
    }
    return value;
  }

  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      void add(int step) {
        final current = int.tryParse(controller.text.trim()) ?? 0;
        final next = (current + step).clamp(1, 9999);
        controller.text = '$next';
        error.value = null;
      }

      return AlertDialog(
        title: Text(context.l10n.inventoryTitoloQuantitaPezzi),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('inventory-quantity-prompt-field'),
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.inventoryParolaPezzi,
                        isDense: true,
                      ),
                      onChanged: (_) => error.value = null,
                      onSubmitted: (_) {
                        final value = parse();
                        if (value != null) {
                          Navigator.of(dialogContext).pop(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.inventoryAzioneAggiungi1,
                    onPressed: () => add(1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: context.l10n.inventoryAzioneAggiungi5,
                    onPressed: () => add(5),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              ValueListenableBuilder<String?>(
                valueListenable: error,
                builder: (context, message, _) => message == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message,
                          key: const ValueKey(
                            'inventory-quantity-prompt-error',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            key: const ValueKey('inventory-quantity-prompt-confirm'),
            onPressed: () {
              final value = parse();
              if (value != null) Navigator.of(dialogContext).pop(value);
            },
            child: Text(context.l10n.inventoryAzioneAggiungi),
          ),
        ],
      );
    },
  ).whenComplete(() {
    controller.dispose();
    error.dispose();
  });
}

class InventoryQuickLoadHeader extends StatelessWidget {
  const InventoryQuickLoadHeader({super.key, required this.colors});

  final AppColorExtension colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.flash_on, color: theme.colorScheme.primary),
      title: Text(
        context.l10n.inventoryTitoloCaricoRapido,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        context.l10n.inventorySottotitoloCaricoRapido,
        style: theme.textTheme.bodySmall?.copyWith(color: colors.subtitleColor),
      ),
    );
  }
}

/// Dropdown con le opzioni di posizione e motivo configurate nelle settings.
///
/// Riutilizzato dai pannelli che scrivono su magazzino, cosi la lista di
/// opzioni, il valore di default e la chiave di ricerca restano uguali in
/// ogni schermata.
class InventoryQuickLoadSelector extends StatelessWidget {
  const InventoryQuickLoadSelector({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.keyName,
    this.allowUnset = true,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  /// Prefisso della chiave di ricerca: tiene i test distinguibili per campo.
  final String? keyName;
  final bool allowUnset;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = options.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${keyName ?? label}-$effectiveValue-${options.length}'),
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: [
        if (allowUnset)
          DropdownMenuItem<String>(
            value: null,
            child: Text(context.l10n.inventoryNessuno),
          ),
        for (final option in options)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: options.isEmpty && !allowUnset ? null : onChanged,
    );
  }
}

class InventoryQuickLoadFeedbackPanel extends StatelessWidget {
  const InventoryQuickLoadFeedbackPanel({
    super.key,
    required this.feedback,
    required this.result,
  });

  final InventoryActionFeedback feedback;
  final MgwsQuickLoad? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      key: const ValueKey('inventory-quick-load-feedback'),
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
            feedback.message(context.l10n),
            style: theme.textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final detail in feedback.details)
            Text(detail(context.l10n), style: theme.textTheme.bodySmall),
          if (feedback.success && result != null) ...[
            const SizedBox(height: 8),
            // Solo l'operazione interessa all'operatore. Il numero della riga
            // di libro e' un id interno di MGWS: mostrarlo porta a cercarlo
            // nel database, che non e' dove l'operatore verifica un carico.
            if (result!.movementId > 0)
              Text(
                '${context.l10n.inventoryEtichettaMovimento} #${result!.movementId}',
                style: theme.textTheme.labelLarge,
              ),
            Text(
              '${context.l10n.inventoryEtichettaStock}: '
              '${result!.previousStock} → ${result!.currentStock}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
