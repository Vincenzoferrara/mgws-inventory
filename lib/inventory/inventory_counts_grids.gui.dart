import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../l10n/extensions.dart';
import '../theme/theme.dart';
import 'inventory.code.dart';

class InventoryCountSessionsGrid extends StatelessWidget {
  const InventoryCountSessionsGrid({
    super.key,
    required this.sessions,
    required this.selected,
    required this.onSelected,
  });

  final List<MgwsCountSession> sessions;
  final MgwsCountSession? selected;
  final ValueChanged<MgwsCountSession> onSelected;

  @override
  Widget build(BuildContext context) {
    return DataGridView<MgwsCountSession>(
      columns: [
        DataGridViewColumn(
          id: 'doc',
          label: context.l10n.inventoryColDocument,
          width: 150,
        ),
        DataGridViewColumn(
          id: 'status',
          label: context.l10n.inventoryColStatus,
          width: 110,
        ),
        DataGridViewColumn(
          id: 'site',
          label: context.l10n.inventoryColSite,
          width: 80,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'warehouse',
          label: context.l10n.inventoryColWarehouse,
          width: 110,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'lines',
          label: context.l10n.inventoryColLines,
          width: 90,
          numeric: true,
        ),
      ],
      rows: [for (final session in sessions) _sessionRow(context, session)],
      selectedRowId: selected?.id.toString(),
      onRowSelected: onSelected,
      onRowDoubleTap: onSelected,
    );
  }
}

class InventoryCountLinesGrid extends StatelessWidget {
  const InventoryCountLinesGrid({super.key, required this.lines});

  final List<MgwsCountLine> lines;

  @override
  Widget build(BuildContext context) {
    return DataGridView<MgwsCountLine>(
      columns: [
        DataGridViewColumn(
          id: 'product',
          label: context.l10n.inventoryColProductVariant,
          width: 190,
        ),
        DataGridViewColumn(
          id: 'place',
          label: context.l10n.inventoryColLocation,
          width: 160,
        ),
        DataGridViewColumn(
          id: 'book',
          label: context.l10n.inventoryColBook,
          width: 80,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'physical',
          label: context.l10n.inventoryColPhysical,
          width: 90,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'diff',
          label: 'Delta',
          width: 80,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'move',
          label: context.l10n.inventoryColMovement,
          width: 110,
        ),
      ],
      rows: [for (final line in lines) _lineRow(context, line)],
    );
  }
}

class InventoryCountFeedbackPanel extends StatelessWidget {
  const InventoryCountFeedbackPanel({super.key, required this.feedback});

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
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.message(context.l10n),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final detail in feedback.details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(detail(context.l10n)),
            ),
        ],
      ),
    );
  }
}

DataGridViewRowData<MgwsCountSession> _sessionRow(
  BuildContext context,
  MgwsCountSession session,
) {
  final colors = Theme.of(context).extension<AppColorExtension>()!;
  final posted = session.status.toLowerCase() == 'posted';
  final tone = posted ? colors.successColor : colors.warningColor;
  return DataGridViewRowData(
    id: session.id.toString(),
    value: session,
    backgroundColor: tone.withValues(alpha: 0.06),
    cells: {
      'doc': Text(session.documentNumber),
      'status': Chip(
        label: Text(session.status),
        side: BorderSide(color: tone),
      ),
      'site': Text('${session.siteId}'),
      'warehouse': Text('${session.warehouseId}'),
      'lines': Text('${session.lines.length}'),
    },
  );
}

DataGridViewRowData<MgwsCountLine> _lineRow(
  BuildContext context,
  MgwsCountLine line,
) {
  final colors = Theme.of(context).extension<AppColorExtension>()!;
  final tone = line.discrepancyQuantity == 0
      ? colors.successColor
      : colors.errorColorStatus;
  return DataGridViewRowData(
    id: line.id.toString(),
    value: line,
    foregroundColor: tone,
    cells: {
      'product': Text(
        context.l10n.inventoryProductVariantRef(
          line.productId,
          line.variationId,
        ),
      ),
      'place': Text('${line.room}-${line.rack}-${line.shelf}'),
      'book': Text('${line.bookQuantity}'),
      'physical': Text('${line.physicalQuantity}'),
      'diff': Text('${line.discrepancyQuantity}'),
      'move': Text(
        line.stockMoveId == 0
            ? context.l10n.inventoryNotPosted
            : '#${line.stockMoveId}',
      ),
    },
  );
}
