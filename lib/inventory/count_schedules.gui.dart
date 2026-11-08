import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import 'mgws_pickers.gui.dart';
import '../login/mgws/query/query_mgws_count_schedules.dart';

class CountSchedulesScreen extends StatefulWidget {
  const CountSchedulesScreen({super.key});
  @override
  State<CountSchedulesScreen> createState() => _CountSchedulesScreenState();
}

class _CountSchedulesScreenState extends State<CountSchedulesScreen> {
  final QueryMgwsCountSchedules _api = QueryMgwsCountSchedules();
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
    // Il magazzino porta con sé la sua sede: niente ID da digitare.
    final warehouse = await pickMgwsWarehouse(
      context,
      title: context.l10n.mgwsResetWarehouse,
    );
    if (warehouse == null || !mounted) return;
    final freqCtrl = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsCountScheduleNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(warehouse.name),
            TextField(
              controller: freqCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.mgwsFrequencyDays,
              ),
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
        siteId: warehouse.siteId,
        warehouseId: warehouse.id,
        frequencyDays: int.tryParse(freqCtrl.text.trim()) ?? 30,
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _runDue() async {
    try {
      final res = await _api.runDue();
      setState(
        () =>
            _error = context.l10n.mgwsAdvancedCount('${res['advanced'] ?? 0}'),
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mgwsCountSchedulesTitle),
        actions: [
          IconButton(
            onPressed: _runDue,
            icon: const Icon(Icons.play_arrow),
            tooltip: context.l10n.mgwsRunDue,
          ),
        ],
      ),
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
                    title: Text(context.l10n.mgwsScheduleLine('${m['id']}')),
                    subtitle: Text(
                      context.l10n.mgwsScheduleSubtitle(
                        '${m['site_id']}',
                        '${m['warehouse_id']}',
                        '${m['frequency_days']}',
                      ),
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
