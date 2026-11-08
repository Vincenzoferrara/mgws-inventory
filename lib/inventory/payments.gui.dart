import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_payments.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final QueryMgwsPayments _api = QueryMgwsPayments();
  List<dynamic> _items = [];
  Map<String, dynamic>? _aging;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await _api.list();
      _aging = await _api.aging();
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final refTypeCtrl = TextEditingController(text: 'invoice');
    final refIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsPaymentNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: refTypeCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.mgwsReferenceType,
              ),
            ),
            TextField(
              controller: refIdCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsReferenceId),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsAmountCents),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.mgwsCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.mgwsCreate),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.create(
        referenceType: refTypeCtrl.text.trim(),
        referenceId: int.tryParse(refIdCtrl.text.trim()) ?? 0,
        amountCents: int.tryParse(amountCtrl.text.trim()) ?? 0,
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.mgwsPaymentsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_aging != null) Text(context.l10n.mgwsAgingLine('$_aging')),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final m = _items[i] as Map;
                  return ListTile(
                    title: Text(
                      context.l10n.mgwsPaymentLine(
                        '${m['reference_type']}',
                        '${m['reference_id']}',
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.mgwsPaymentSubtitle('${m['amount_cents']}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
