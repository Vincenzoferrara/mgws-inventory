// inventory_movements_detail.gui.dart
//
// La schermata di un movimento di magazzino, aperta con il doppio click sulla
// riga del ledger.
//
// Qui l'operatore vede l'operazione intera e sceglie cosa farne. I due tasti
// hanno limiti dichiarati: nessuno dei due cancella la riga, perche' il ledger
// non si modifica. "Modifica" riapre il pannello che ha prodotto il movimento,
// "Annulla" registra il contromovimento che riporta lo stock a prima. Quando un
// tasto non e' disponibile, la schermata dice perche' invece di accenderlo e
// far perdere tempo, o peggio far credere che il pulsante funzioni.

import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'inventory.code.dart';
import 'inventory_movement_groups.code.dart';

/// Cosa ha chiesto l'operatore sulla schermata del movimento.
enum InventoryMovementAction { reopen, revert }

/// Apre la schermata del movimento e restituisce l'azione scelta.
///
/// `null` significa che l'operatore ha chiuso senza fare niente, che e' il
/// modo normale per cui si esce da una schermata di lettura.
Future<InventoryMovementAction?> showInventoryMovementDialog(
  BuildContext context,
  InventoryMovementGroup group,
) {
  return showDialog<InventoryMovementAction>(
    context: context,
    builder: (context) => _InventoryMovementDialog(group: group),
  );
}

class _InventoryMovementDialog extends StatelessWidget {
  const _InventoryMovementDialog({required this.group});

  final InventoryMovementGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final scheme = theme.colorScheme;
    return Dialog(
      key: const ValueKey('inventory-movement-dialog'),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, theme, colors),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _chips(context, colors),
                    const SizedBox(height: 12),
                    _texts(context, colors),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.inventoryProdottiToccati(group.productCount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 240, child: _productsGrid(context)),
                  ],
                ),
              ),
            ),
            _actions(context, scheme, colors),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ThemeData theme,
    AppColorExtension colors,
  ) {
    final raw = group.rawType.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.inventoryTitoloMovimento(group.kindLabel),
                  key: const ValueKey('inventory-movement-dialog-title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${context.l10n.inventoryEtichettaOrigine} '
                  '${group.sourceType.isEmpty ? '-' : group.sourceType} '
                  '#${group.sourceId}'
                  '${raw.isEmpty ? '' : ' - $raw'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('inventory-movement-dialog-close'),
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context, AppColorExtension colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          context,
          Icons.event,
          '${context.l10n.commonDate} ${formatMovementDate(group.occurredAtGmt)}',
        ),
        _chip(
          context,
          Icons.history,
          '${context.l10n.inventoryEtichettaUltimaModifica} '
          '${formatMovementDate(group.lastModifiedGmt)}',
          keyName: 'inventory-movement-last-modified',
        ),
        _chip(
          context,
          Icons.person_outline,
          '${context.l10n.inventoryEtichettaOperatore} '
          '#${group.operatorUserId}',
          keyName: 'inventory-movement-operator',
        ),
        _chip(
          context,
          Icons.change_history,
          // Su uno spostamento il delta totale e' zero per definizione, e
          // mostrare "+0" sembrerebbe un'operazione che non ha spostato
          // niente. Quello che interessa e' la merce cambiata di magazzino.
          group.isMove
              ? context.l10n.inventoryPezziSpostati(group.movedQuantity)
              : '${context.l10n.inventoryEtichettaPezzi} '
                    '${movementSigned(group.quantityDelta)}',
          keyName: 'inventory-movement-quantity',
        ),
        _chip(
          context,
          Icons.inventory_2_outlined,
          '${context.l10n.inventoryEtichettaProdotti} ${group.productCount}',
        ),
        if (group.movementId > 0)
          _chip(
            context,
            Icons.tag,
            '${context.l10n.inventoryEtichettaMovimento} #${group.movementId}',
            keyName: 'inventory-movement-id',
          ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    String? keyName,
  }) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Container(
      key: keyName == null ? null : ValueKey(keyName),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.priceBackground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.subtitleColor),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _texts(BuildContext context, AppColorExtension colors) {
    final theme = Theme.of(context);
    Widget line(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.subtitleColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.subtitleColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(
          Icons.help_outline,
          context.l10n.inventoryEtichettaMotivo,
          group.reason.trim(),
        ),
        line(
          Icons.notes_outlined,
          context.l10n.inventoryLabelDettagli,
          group.note.trim(),
        ),
      ],
    );
  }

  /// Una riga per prodotto, non per riga di libro.
  ///
  /// Uno spostamento scrive due righe per codice, una di uscita e una di
  /// entrata. Mostrarle entrambe farebbe sembrare che l'operazione abbia
  /// raddoppiato il prodotto, e il totale del gruppo sarebbe zero accanto a
  /// venti pezzi: due numeri che insieme non tornano e che l'operatore
  /// leggerebbe come un errore.
  Widget _productsGrid(BuildContext context) {
    final columns = <DataGridViewColumn>[
      DataGridViewColumn(
        id: 'product',
        label: context.l10n.inventoryEtichettaProdotto,
        width: 150,
      ),
      DataGridViewColumn(
        id: 'variation',
        label: context.l10n.inventoryEtichettaVariante,
        width: 90,
      ),
      DataGridViewColumn(
        id: 'quantity',
        label: group.isMove
            ? context.l10n.inventoryEtichettaPezzi
            : context.l10n.inventoryEtichettaDelta,
        width: 80,
        numeric: true,
      ),
      if (group.isMove)
        DataGridViewColumn(
          id: 'route',
          label: context.l10n.inventoryEtichettaDaA,
          width: 140,
        )
      else
        DataGridViewColumn(
          id: 'stock',
          label: context.l10n.inventoryEtichettaPrimaDopo,
          width: 150,
          numeric: true,
        ),
      if (!group.isMove)
        DataGridViewColumn(
          id: 'location',
          label: context.l10n.inventoryEtichettaUbicazione,
          width: 180,
        ),
      DataGridViewColumn(
        id: 'effect',
        label: context.l10n.inventoryEtichettaEffetto,
        width: 100,
      ),
      DataGridViewColumn(
        id: 'reason',
        label: context.l10n.inventoryEtichettaMotivoRiga,
        flexible: true,
      ),
    ];
    return DataGridView<InventoryMovementProduct>(
      columns: columns,
      rows: [
        for (final product in group.products) _productRow(context, product),
      ],
    );
  }

  DataGridViewRowData<InventoryMovementProduct> _productRow(
    BuildContext context,
    InventoryMovementProduct product,
  ) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    // Uno spostamento ha delta zero e pezzi > 0: colorarlo di rosso o di verde
    // come una correzione sarebbe falso. Il tono segue l'effetto sul totale, e
    // quando l'effetto e' nullo la riga resta col colore del testo normale.
    final tone = product.quantityDelta > 0
        ? colors.successColor
        : (product.quantityDelta < 0
              ? colors.errorColorStatus
              : Theme.of(context).colorScheme.onSurface);
    return DataGridViewRowData(
      id: '${product.productId}:${product.variationId}',
      value: product,
      foregroundColor: tone,
      cells: {
        'product': Text('#${product.productId}'),
        'variation': Text(
          product.variationId > 0 ? '${product.variationId}' : '-',
        ),
        'quantity': Text(
          group.isMove
              ? '${product.quantity}'
              : movementSigned(product.quantityDelta),
        ),
        if (group.isMove)
          'route': Text(product.routeText.isEmpty ? '-' : product.routeText)
        else ...{
          'stock': Text(
            '${movementStock(product.stockBefore)} -> '
            '${movementStock(product.stockAfter)}',
          ),
          'location': Text(_locationText(product.movements.first.location)),
        },
        'effect': Text(product.movements.first.stockEffect),
        'reason': Text(product.movements.first.reasonCode),
      },
    );
  }

  String _locationText(MgwsLocation location) =>
      'S${location.siteId} W${location.warehouseId} '
      '${location.room}/${location.rack}/${location.shelf}';

  Widget _actions(
    BuildContext context,
    ColorScheme scheme,
    AppColorExtension colors,
  ) {
    final theme = Theme.of(context);
    final canReopen = group.canResume;
    final canRevert = group.canRevert;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // I motivi dei tasti spenti stanno sopra i tasti: se l'operatore
          // preme e non parte, la spiegazione e' gia' li', non in un altro
          // posto da dover cercare.
          if (!canReopen)
            Text(
              group.resumeBlockMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.warningColor,
              ),
            ),
          if (!canRevert)
            Text(
              group.revertBlockMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.warningColor,
              ),
            ),
          const SizedBox(height: 10),
          // Wrap e non Row: su telefono i tre pulsanti non stanno in una
          // riga e andavano in overflow; cosi' vanno a capo.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonClose),
              ),
              OutlinedButton.icon(
                key: const ValueKey('inventory-movement-revert'),
                onPressed: canRevert
                    ? () => Navigator.of(
                        context,
                      ).pop(InventoryMovementAction.revert)
                    : null,
                icon: const Icon(Icons.undo),
                label: Text(context.l10n.inventoryAnnullaMovimento),
              ),
              FilledButton.icon(
                key: const ValueKey('inventory-movement-reopen'),
                onPressed: canReopen
                    ? () => Navigator.of(
                        context,
                      ).pop(InventoryMovementAction.reopen)
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.l10n.commonEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Esito di un'azione sul ledger, mostrato sotto la tabella.
class InventoryMovementFeedback extends StatelessWidget {
  const InventoryMovementFeedback({super.key, required this.feedback});

  final InventoryActionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
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
            style: theme.textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final detail in feedback.details)
            Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
