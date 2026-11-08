import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_transfers.dart';
import '../l10n/extensions.dart';
import 'mgws_pickers.gui.dart';

/// The site sends ids as numbers or as numeric strings ("2"), depending on
/// the database driver.
int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

/// Schermata dei trasferimenti con stato.
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key, this.api});

  /// Tests pass a fake; the app uses the site's MGWS routes.
  final QueryMgwsTransfers? api;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  late final QueryMgwsTransfers _api = widget.api ?? QueryMgwsTransfers();

  bool _isLoading = true;
  bool _forbidden = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _forbidden = false;
    });
    try {
      final data = await _api.list(status: _statusFilter);
      if (!mounted) return;
      final raw = data['items'];
      setState(() {
        _items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        _isLoading = false;
      });
    } on TransfersException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.transfersForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.transfersLoadError(error);
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return context.l10n.transfersStatusDraft;
      case 'sent':
        return context.l10n.transfersStatusSent;
      case 'received':
        return context.l10n.transfersStatusReceived;
      case 'cancelled':
        return context.l10n.transfersStatusCancelled;
      default:
        return status;
    }
  }

  Future<void> _transition(
    Map<String, dynamic> item,
    Future<Map<String, dynamic>> Function(int) action,
    String confirmMessage,
    String successMessage,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action(_asInt(item['id']));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } on TransfersException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.transfersSaveError(error))),
      );
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Bozza nuova: origine, destinazione, poi le righe dal picker prodotti.
  Future<void> _create() async {
    final l10n = context.l10n;
    final from = await pickMgwsWarehouse(
      context,
      title: l10n.transfersPickFrom,
    );
    if (from == null || !mounted) return;
    final to = await pickMgwsWarehouse(
      context,
      title: l10n.transfersPickTo,
      excludeId: from.id,
    );
    if (to == null || !mounted) return;
    try {
      final created = await _api.create(
        fromWarehouseId: from.id,
        toWarehouseId: to.id,
      );
      final id = _asInt(created['id']);
      if (!mounted) return;
      if (id <= 0) {
        _snack(created['message']?.toString() ?? l10n.transfersSaveError(''));
        return;
      }
      _snack(l10n.transfersCreated);
      await _addLines(id);
    } on TransfersException catch (error) {
      if (mounted) _snack(error.message);
    }
  }

  Future<void> _addLines(int transferId) async {
    final lines = await pickMgwsProductLines(context);
    if (!mounted) return;
    var failed = 0;
    for (final line in lines) {
      try {
        await _api.addLine(
          transferId: transferId,
          productId: line.productId,
          variationId: line.variationId,
          qty: line.quantity,
        );
      } on TransfersException {
        failed++;
      }
    }
    if (!mounted) return;
    if (failed > 0) _snack(context.l10n.transfersLinesFailed('$failed'));
    await _load();
  }

  Future<void> _removeLine(int transferId, int lineId) async {
    try {
      await _api.removeLine(transferId, lineId);
    } on TransfersException catch (error) {
      if (mounted) _snack(error.message);
    }
    await _load();
  }

  Widget _lines(Map<String, dynamic> item, bool editable) {
    final raw = item['lines'];
    final lines = raw is List
        ? raw
              .whereType<Map>()
              .map((line) => Map<String, dynamic>.from(line))
              .toList()
        : const <Map<String, dynamic>>[];
    final transferId = _asInt(item['id']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (lines.isEmpty) Text(context.l10n.transfersNoLines),
        for (final line in lines)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '#${line['product_id']}'
                  '${_asInt(line['variation_id']) != 0 ? ' / #${line['variation_id']}' : ''}'
                  '  × ${line['qty']}',
                ),
              ),
              if (editable)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.transfersRemoveLine,
                  onPressed: () => _removeLine(transferId, _asInt(line['id'])),
                ),
            ],
          ),
        if (editable)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.transfersAddLines),
            onPressed: () => _addLines(transferId),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.transfersTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.transfersTitle)),
        body: Center(child: Text(context.l10n.transfersForbidden)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.transfersTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: Text(context.l10n.employeesRetry),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.transfersTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _statusFilter = value == 'all' ? '' : value);
              _load();
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'all', child: Text('All')),
              ...['draft', 'sent', 'received', 'cancelled'].map(
                (s) => PopupMenuItem(value: s, child: Text(_statusLabel(s))),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.transfersNew),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tells this multi-step flow apart from the immediate "Move now"
          // module, whose name used to be almost the same.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              context.l10n.transfersIntro,
              key: const ValueKey('transfers-intro'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _list(context)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    return _items.isEmpty
        ? Center(child: Text(context.l10n.transfersEmpty))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final status = (item['status'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${item['id']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Chip(label: Text(_statusLabel(status))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.l10n.transfersFrom} #${item['from_warehouse_id']}  →  '
                        '${context.l10n.transfersTo} #${item['to_warehouse_id']}',
                      ),
                      if (item['note'] != null)
                        Text((item['note'] ?? '').toString()),
                      const SizedBox(height: 8),
                      _lines(item, status == 'draft'),
                      const SizedBox(height: 8),
                      if (status == 'draft') ...[
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () => _transition(
                                item,
                                _api.send,
                                context.l10n.transfersSendConfirm,
                                context.l10n.transfersSent,
                              ),
                              child: Text(context.l10n.transfersSend),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _transition(
                                item,
                                _api.cancel,
                                context.l10n.transfersCancelConfirm,
                                context.l10n.transfersCancelled,
                              ),
                              child: Text(context.l10n.transfersCancel),
                            ),
                          ],
                        ),
                      ],
                      if (status == 'sent') ...[
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () => _transition(
                                item,
                                _api.receive,
                                context.l10n.transfersReceiveConfirm,
                                context.l10n.transfersReceived,
                              ),
                              child: Text(context.l10n.transfersReceive),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _transition(
                                item,
                                _api.cancel,
                                context.l10n.transfersCancelConfirm,
                                context.l10n.transfersCancelled,
                              ),
                              child: Text(context.l10n.transfersCancel),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
  }
}
