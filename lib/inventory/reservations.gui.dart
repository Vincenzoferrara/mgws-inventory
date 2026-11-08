import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_reservations.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final QueryMgwsReservations _api = QueryMgwsReservations();
  List<dynamic> _items = [];
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
    final productCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsReservationNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: productCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsProductId),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: qtyCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsQuantity),
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
        productId: int.tryParse(productCtrl.text.trim()) ?? 0,
        qty: int.tryParse(qtyCtrl.text.trim()) ?? 1,
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.mgwsReservationsTitle)),
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
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final m = _items[i] as Map;
                  return ListTile(
                    title: Text(
                      context.l10n.mgwsReservationLine(
                        '${m['id']}',
                        '${m['product_id']}',
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.mgwsReservationSubtitle(
                        '${m['qty']}',
                        '${m['status']}',
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            await _api.consume(m['id'] as int);
                            await _load();
                          },
                          tooltip: context.l10n.mgwsConsume,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await _api.release(m['id'] as int);
                            await _load();
                          },
                          tooltip: context.l10n.mgwsRelease,
                        ),
                      ],
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
