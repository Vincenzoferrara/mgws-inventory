import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import '../login/mgws/query/query_mgws_stock_reset.dart';

/// Schermata di reset massivo dello stock di un magazzino.
///
/// Il reset tocca ogni livello del magazzino in un colpo solo, quindi passa
/// sempre da un'anteprima (`dry_run`) e da una conferma esplicita.
class StockResetScreen extends StatefulWidget {
  const StockResetScreen({super.key});

  @override
  State<StockResetScreen> createState() => _StockResetScreenState();
}

class _StockResetScreenState extends State<StockResetScreen> {
  final QueryMgwsStockReset _api = QueryMgwsStockReset();
  final TextEditingController _targetController = TextEditingController();

  List<MgwsInventoryWarehouse>? _warehouses;
  int? _warehouseId;
  bool _loadingWarehouses = true;
  bool _running = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    final result = await QueryMgwsInventory().listWarehouses();
    if (!mounted) return;
    setState(() {
      _loadingWarehouses = false;
      _warehouses = result.success
          ? (result.data ?? const <MgwsInventoryWarehouse>[])
                .where((warehouse) => warehouse.active)
                .toList()
          : null;
    });
  }

  String _warehouseName(int id) {
    for (final warehouse in _warehouses ?? const <MgwsInventoryWarehouse>[]) {
      if (warehouse.id == id) return warehouse.name;
    }
    return '#$id';
  }

  Future<void> _run() async {
    final l10n = context.l10n;
    final warehouseId = _warehouseId ?? 0;
    final targetQty = int.tryParse(_targetController.text.trim());
    if (warehouseId <= 0) {
      setState(() => _result = l10n.mgwsInvalidWarehouse);
      return;
    }
    // Un target vuoto non vale zero: va scritto.
    if (targetQty == null || targetQty < 0) {
      setState(() => _result = l10n.mgwsResetTargetRequired);
      return;
    }
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final preview = await _api.reset(
        warehouseId: warehouseId,
        targetQty: targetQty,
        dryRun: true,
      );
      if (!mounted) return;
      if (preview['ok'] != true) {
        setState(() {
          _running = false;
          _result = preview['message']?.toString() ?? l10n.mgwsResetError;
        });
        return;
      }
      final levels = (preview['reset'] as num?)?.toInt() ?? 0;
      if (levels == 0) {
        setState(() {
          _running = false;
          _result = l10n.mgwsResetNothingToChange;
        });
        return;
      }
      final pieces = (preview['changed_qty'] as num?)?.toInt() ?? 0;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.mgwsResetConfirmTitle),
          content: Text(
            l10n.mgwsResetConfirmBody(
              _warehouseName(warehouseId),
              '$levels',
              '$pieces',
              '$targetQty',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.mgwsRunReset),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _running = false);
        return;
      }
      final res = await _api.reset(
        warehouseId: warehouseId,
        targetQty: targetQty,
      );
      if (!mounted) return;
      final wooFailed = res['woo_failed'];
      final wooFailedCount = wooFailed is List ? wooFailed.length : 0;
      setState(() {
        _running = false;
        _result = res['ok'] == true
            ? <String>[
                l10n.mgwsResetResult('${res['reset']}', '${res['failed']}'),
                if (wooFailedCount > 0)
                  l10n.mgwsResetWooFailed('$wooFailedCount'),
              ].join('\n')
            : (res['message']?.toString() ?? l10n.mgwsResetError);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final warehouses = _warehouses;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mgwsStockResetTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_loadingWarehouses)
              const LinearProgressIndicator()
            else if (warehouses == null)
              Text(l10n.mgwsResetWarehousesUnavailable)
            else
              DropdownButtonFormField<int>(
                initialValue: _warehouseId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.mgwsResetWarehouse),
                items: warehouses
                    .map(
                      (warehouse) => DropdownMenuItem<int>(
                        value: warehouse.id,
                        child: Text(warehouse.name),
                      ),
                    )
                    .toList(),
                onChanged: _running
                    ? null
                    : (value) => setState(() => _warehouseId = value),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              decoration: InputDecoration(labelText: l10n.mgwsTargetQuantity),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _running || warehouses == null ? null : _run,
              child: _running
                  ? const CircularProgressIndicator()
                  : Text(l10n.mgwsRunReset),
            ),
            if (_result != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(_result!),
            ],
          ],
        ),
      ),
    );
  }
}
