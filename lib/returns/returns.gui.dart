import 'package:flutter/material.dart';

import '../inventory/mgws_pickers.gui.dart';
import '../login/mgws/query/query_mgws_returns.dart';
import '../l10n/extensions.dart';

/// Schermata dei resi (RMA) con stato.
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final QueryMgwsReturns _api = QueryMgwsReturns();

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
    } on ReturnsException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.returnsForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.returnsLoadError(error);
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'requested':
        return context.l10n.returnsStatusRequested;
      case 'approved':
        return context.l10n.returnsStatusApproved;
      case 'received':
        return context.l10n.returnsStatusReceived;
      case 'refunded':
        return context.l10n.returnsStatusRefunded;
      case 'rejected':
        return context.l10n.returnsStatusRejected;
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
      await action((item['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _load();
    } on ReturnsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.returnsSaveError(error))),
      );
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Reso nuovo: ordine (facoltativo) e motivo, poi le righe dal picker.
  Future<void> _create() async {
    final l10n = context.l10n;
    final orderCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.returnsNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: orderCtrl,
              decoration: InputDecoration(labelText: l10n.returnsOrderOptional),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(labelText: l10n.returnsReason),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    final orderId = int.tryParse(orderCtrl.text.trim()) ?? 0;
    final reason = reasonCtrl.text.trim();
    orderCtrl.dispose();
    reasonCtrl.dispose();
    if (confirmed != true || !mounted) return;
    try {
      final created = await _api.create(
        orderId: orderId,
        reason: reason.isEmpty ? null : reason,
      );
      final id = (created['id'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (id <= 0) {
        _snack(created['message']?.toString() ?? l10n.returnsSaveError(''));
        return;
      }
      await _addLines(id);
    } on ReturnsException catch (error) {
      if (mounted) _snack(error.message);
    }
  }

  Future<void> _addLines(int returnId) async {
    final lines = await pickMgwsProductLines(context);
    if (!mounted) return;
    var failed = 0;
    for (final line in lines) {
      try {
        await _api.addLine(
          returnId: returnId,
          productId: line.productId,
          variationId: line.variationId,
          qty: line.quantity,
        );
      } on ReturnsException {
        failed++;
      }
    }
    if (!mounted) return;
    if (failed > 0) _snack(context.l10n.transfersLinesFailed('$failed'));
    await _load();
  }

  Future<void> _removeLine(int returnId, int lineId) async {
    try {
      await _api.removeLine(returnId, lineId);
    } on ReturnsException catch (error) {
      if (mounted) _snack(error.message);
    }
    await _load();
  }

  Widget _lines(Map<String, dynamic> item) {
    final raw = item['lines'];
    final lines = raw is List
        ? raw.whereType<Map>().map((line) => Map<String, dynamic>.from(line)).toList()
        : const <Map<String, dynamic>>[];
    // Le righe si cambiano solo finché il reso è richiesto (regola del plugin).
    final editable = (item['status'] ?? '').toString() == 'requested';
    final returnId = (item['id'] as num).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty) Text(context.l10n.returnsNoLines),
        for (final line in lines)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${context.l10n.returnsLineProduct} #${line['product_id']}'
                  '${(line['variation_id'] as num?)?.toInt() != 0 ? ' / #${line['variation_id']}' : ''}'
                  '  × ${line['qty']}',
                ),
              ),
              if (editable)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.transfersRemoveLine,
                  onPressed: () => _removeLine(returnId, (line['id'] as num).toInt()),
                ),
            ],
          ),
        if (editable)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.transfersAddLines),
            onPressed: () => _addLines(returnId),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.returnsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.returnsTitle)),
        body: Center(child: Text(context.l10n.returnsForbidden)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.returnsTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(context.l10n.employeesRetry)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.returnsTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _statusFilter = value == 'all' ? '' : value);
              _load();
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'all',
                child: Text(context.l10n.returnsFilterAll),
              ),
              ...['requested', 'approved', 'received', 'refunded', 'rejected']
                  .map((s) => PopupMenuItem(value: s, child: Text(_statusLabel(s)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.returnsNew),
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.l10n.returnsEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final status = (item['status'] ?? '').toString();
                final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
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
                        if (orderId > 0)
                          Text(
                            '${context.l10n.returnsOrder} #$orderId',
                          ),
                        if (item['reason'] != null)
                          Text((item['reason'] ?? '').toString()),
                        if (item['note'] != null)
                          Text((item['note'] ?? '').toString()),
                        const SizedBox(height: 8),
                        _lines(item),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (status == 'requested')
                              FilledButton(
                                onPressed: () => _transition(
                                  item,
                                  _api.approve,
                                  context.l10n.returnsApproveConfirm,
                                  context.l10n.returnsApproved,
                                ),
                                child: Text(context.l10n.returnsApprove),
                              ),
                            if (status == 'approved')
                              FilledButton(
                                onPressed: () => _transition(
                                  item,
                                  _api.receive,
                                  context.l10n.returnsReceiveConfirm,
                                  context.l10n.returnsReceived,
                                ),
                                child: Text(context.l10n.returnsReceive),
                              ),
                            if (status == 'received')
                              FilledButton(
                                onPressed: () => _transition(
                                  item,
                                  _api.close,
                                  context.l10n.returnsCloseConfirm,
                                  context.l10n.returnsClosed,
                                ),
                                child: Text(context.l10n.returnsClose),
                              ),
                            if (status == 'requested' || status == 'approved')
                              TextButton(
                                onPressed: () => _transition(
                                  item,
                                  _api.reject,
                                  context.l10n.returnsRejectConfirm,
                                  context.l10n.returnsRejected,
                                ),
                                child: Text(context.l10n.returnsReject),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
