// lib/rfid/uhf/uhf_scan.gui.dart
//
// Pannello RFID con due schede: lettura corrente e associazioni. Tutta la
// testualita' visibile passa da context.l10n: qui non esistono stringhe fisse.
// Il pannello non scrive stock: prepara solo le righe associate per Add.

import 'package:material_ui/material_ui.dart';

import '../../inventory/inventory_quick_load.code.dart';
import '../../l10n/extensions.dart';
import '../../login/mgws/query/query_mgws_inventory_models.dart';
import '../../theme/theme.dart';
import 'uhf_scan.code.dart';

class InventoryRfidPanel extends StatefulWidget {
  const InventoryRfidPanel({
    super.key,
    required this.gateway,
    required this.readTags,
    required this.onSend,
  });

  final MgwsInventoryGateway gateway;
  final Future<List<String>> Function() readTags;
  final void Function(List<InventoryQuickLoadLineDraft> lines) onSend;

  @override
  State<InventoryRfidPanel> createState() => _InventoryRfidPanelState();
}

class _InventoryRfidPanelState extends State<InventoryRfidPanel> {
  final InventoryRfidScanController _controller = InventoryRfidScanController();
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;

    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: [
              Tab(text: context.l10n.inventoryRfidTabRead),
              Tab(text: context.l10n.inventoryRfidTabAssociations),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                style: TextStyle(color: colors.errorColorStatus),
              ),
            ),
          SizedBox(
            height: 360,
            child: TabBarView(
              children: [
                _buildReadTab(context),
                _buildAssociationsTab(context),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildReadTab(BuildContext context) {
    final rows = _controller.rows;
    if (rows.isEmpty) {
      return Center(child: Text(context.l10n.inventoryRfidEmpty));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        final subtitle = <String>[
          if (row.gtin != null)
            '${context.l10n.inventoryRfidColumnGtin}: ${row.gtin}',
          if (row.serial != null)
            '${context.l10n.inventoryRfidColumnSerial}: ${row.serial}',
        ].join(' · ');
        return ListTile(
          key: ValueKey('inventory-rfid-read-$index'),
          tileColor: _rowTint(context, row),
          title: Text(row.epc),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: IconButton(
            key: ValueKey('inventory-rfid-remove-$index'),
            tooltip: context.l10n.inventoryTooltipRimuovi,
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _controller.removeAt(index);
              _error = null;
            }),
          ),
        );
      },
    );
  }

  Widget _buildAssociationsTab(BuildContext context) {
    final rows = _controller.rows;
    if (rows.isEmpty) {
      return Center(child: Text(context.l10n.inventoryRfidEmpty));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  context.l10n.inventoryRfidColumnEpc,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  context.l10n.inventoryRfidColumnProduct,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  context.l10n.inventoryRfidColumnStatus,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          for (final row in rows)
            Container(
              color: _rowTint(context, row),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        row.epc,
                        key: ValueKey('inventory-rfid-assoc-epc-${row.epc}'),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.isAssociated
                            ? row.productName ?? row.epc
                            : context.l10n.inventoryRfidReasonNotAssociated,
                        key: ValueKey(
                          'inventory-rfid-assoc-product-${row.epc}',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _status(context, row),
                        key: ValueKey('inventory-rfid-assoc-status-${row.epc}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Solo le righe associate prendono il verde: le altre restano chiare, con
  /// una sfumatura rossa quando c'e' stato un errore di risoluzione.
  Color? _rowTint(BuildContext context, RfidTagScanRow row) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    if (row.isAssociated) return colors.successColor.withAlpha(24);
    if (row.reason == 'mgws_unavailable') {
      return colors.errorColorStatus.withAlpha(20);
    }
    return colors.neutralColor.withAlpha(12);
  }

  String _status(BuildContext context, RfidTagScanRow row) {
    if (row.isAssociated) {
      switch (row.resolution) {
        case RfidResolutionSource.gs1:
          return context.l10n.inventoryRfidResolutionGs1;
        case RfidResolutionSource.table:
          return context.l10n.inventoryRfidResolutionTable;
        case RfidResolutionSource.none:
          return context.l10n.inventoryRfidResolutionTable;
      }
    }
    switch (row.reason) {
      case 'epc_not_registered':
        return context.l10n.inventoryRfidReasonEpcNotRegistered;
      case 'mgws_unavailable':
        return context.l10n.inventoryRfidReasonMgwsUnavailable;
      case 'not_associated':
      default:
        return context.l10n.inventoryRfidReasonNotAssociated;
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.inventoryRfidAssociatedCount(
                    _controller.associatedRows.length,
                  ),
                  key: const ValueKey('inventory-rfid-associated-count'),
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.inventoryRfidUnassociatedCount(
                    _controller.unassociatedRows.length,
                  ),
                  key: const ValueKey('inventory-rfid-unassociated-count'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('inventory-rfid-scan'),
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.nfc),
                  label: Text(context.l10n.inventoryRfidScan),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('inventory-rfid-refresh'),
                  onPressed: _busy || _controller.rows.isEmpty
                      ? null
                      : _resolve,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.inventoryRfidRefresh),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('inventory-rfid-send'),
                  onPressed: _busy || _controller.associatedRows.isEmpty
                      ? null
                      : _send,
                  icon: const Icon(Icons.send),
                  label: Text(context.l10n.inventoryRfidSend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tags = await widget.readTags();
      if (!mounted) return;
      setState(() => _controller.addRawTags(tags));
      await _resolve();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.inventoryRfidScanFailed;
        _busy = false;
      });
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.resolve(gateway: widget.gateway);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.inventoryRfidResolveFailed;
        _busy = false;
      });
    }
  }

  Future<void> _send() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.inventoryRfidSend),
        content: Text(
          context.l10n.inventoryRfidSendConfirm(
            _controller.unassociatedRows.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonAnnulla),
          ),
          TextButton(
            key: const ValueKey('inventory-rfid-send-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.inventoryRfidSend),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onSend(_controller.toLoadLines());
  }
}
