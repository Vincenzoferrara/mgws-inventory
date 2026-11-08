import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_shipments.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key});
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final QueryMgwsShipments _api = QueryMgwsShipments();
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
    final refTypeCtrl = TextEditingController(text: 'receipt');
    final refIdCtrl = TextEditingController();
    final carrierCtrl = TextEditingController();
    final trackCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsShipmentNew),
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
              controller: carrierCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsCarrier),
            ),
            TextField(
              controller: trackCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsTracking),
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
        carrier: carrierCtrl.text.trim(),
        trackingNumber: trackCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _setStatus(int id) async {
    final statusCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsShipmentStatusTitle),
        content: TextField(
          controller: statusCtrl,
          decoration: InputDecoration(
            labelText: ctx.l10n.mgwsStatusPendingSentDelivered,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.mgwsCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.mgwsUpdate),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.updateStatus(id, statusCtrl.text.trim());
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.mgwsShipmentsTitle)),
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
                      context.l10n.mgwsShipmentLine(
                        '${m['reference_type']}',
                        '${m['reference_id']}',
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.mgwsShipmentSubtitle(
                        '${m['status']}',
                        '${m['carrier'] ?? ''}',
                        '${m['tracking_number'] ?? ''}',
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _setStatus(m['id'] as int),
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
