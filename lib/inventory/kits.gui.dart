import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_kits.dart';
import 'kit_deduction.gui.dart';
import 'mgws_pickers.gui.dart';

/// Definizione dei kit: quale prodotto venduto è un kit e di quali componenti
/// è fatto. Senza una definizione la deduzione dei componenti non scala nulla.
class KitsScreen extends StatefulWidget {
  const KitsScreen({super.key});

  @override
  State<KitsScreen> createState() => _KitsScreenState();
}

class _KitsScreenState extends State<KitsScreen> {
  final QueryMgwsKits _api = QueryMgwsKits();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _kits = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final kits = await _api.list();
      if (!mounted) return;
      setState(() {
        _kits = kits;
        _isLoading = false;
      });
    } on KitDeductionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.nonAutorizzato
            ? context.l10n.kitsForbidden
            : error.message;
        _isLoading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final picked = await pickMgwsProductLines(context);
    if (picked.isEmpty || !mounted) return;
    final product = picked.first;
    try {
      final created = await _api.create(
        name: product.label,
        productId: product.productId,
        variationId: product.variationId,
      );
      final id = (created['id'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      if (id <= 0) {
        _snack(created['message']?.toString() ?? l10n.kitsSaveError);
        return;
      }
      _snack(l10n.kitsCreated);
      await _addComponents(id);
    } on KitDeductionException catch (error) {
      if (mounted) _snack(error.message);
    }
  }

  Future<void> _addComponents(int kitId) async {
    final lines = await pickMgwsProductLines(context);
    for (final line in lines) {
      try {
        await _api.addComponent(
          kitId: kitId,
          productId: line.productId,
          variationId: line.variationId,
          qty: line.quantity,
        );
      } on KitDeductionException catch (error) {
        if (mounted) _snack(error.message);
      }
    }
    if (mounted) await _load();
  }

  Future<void> _removeComponent(int componentId) async {
    try {
      await _api.removeComponent(componentId);
    } on KitDeductionException catch (error) {
      if (mounted) _snack(error.message);
    }
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> kit) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.kitsDeleteConfirm((kit['name'] ?? '').toString())),
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
    if (confirmed != true) return;
    try {
      await _api.delete((kit['id'] as num).toInt());
    } on KitDeductionException catch (error) {
      if (mounted) _snack(error.message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kitsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _create,
        icon: const Icon(Icons.add),
        label: Text(l10n.kitsNew),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _kits.isEmpty
          ? Center(child: Text(l10n.kitsEmpty))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[for (final kit in _kits) _kitCard(kit)],
            ),
    );
  }

  Widget _kitCard(Map<String, dynamic> kit) {
    final l10n = context.l10n;
    final kitId = (kit['id'] as num).toInt();
    final productId = (kit['product_id'] as num?)?.toInt() ?? 0;
    final variationId = (kit['variation_id'] as num?)?.toInt() ?? 0;
    final raw = kit['components'];
    final components = raw is List
        ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : const <Map<String, dynamic>>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    (kit['name'] ?? '').toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.inventory),
                  tooltip: l10n.mgwsKitDeductionTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => KitDeductionScreen(
                        productId: productId,
                        variationId: variationId,
                        productName: (kit['name'] ?? '').toString(),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(kit),
                ),
              ],
            ),
            Text('#$productId${variationId != 0 ? ' / #$variationId' : ''}'),
            const SizedBox(height: 8),
            if (components.isEmpty) Text(l10n.kitsNoComponents),
            for (final component in components)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '#${component['product_id']}'
                      '${(component['variation_id'] as num?)?.toInt() != 0 ? ' / #${component['variation_id']}' : ''}'
                      '  × ${component['qty']}',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        _removeComponent((component['id'] as num).toInt()),
                  ),
                ],
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.kitsAddComponents),
              onPressed: () => _addComponents(kitId),
            ),
          ],
        ),
      ),
    );
  }
}
