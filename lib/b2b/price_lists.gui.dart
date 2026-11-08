import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_price_lists.dart';
import '../inventory/mgws_pickers.gui.dart';
import '../l10n/extensions.dart';

/// Schermata dei listini prezzi B2B.
class PriceListsScreen extends StatefulWidget {
  const PriceListsScreen({super.key});

  @override
  State<PriceListsScreen> createState() => _PriceListsScreenState();
}

class _PriceListsScreenState extends State<PriceListsScreen> {
  final QueryMgwsPriceLists _api = QueryMgwsPriceLists();

  bool _isLoading = true;
  bool _forbidden = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

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
      final data = await _api.list();
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
    } on PriceListsException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.priceListsForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.priceListsLoadError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.priceListsNew),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: context.l10n.priceListsName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.priceListsNoName)),
        );
      }
      return;
    }
    try {
      await _api.create(name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.priceListsCreated)),
      );
      await _load();
    } on PriceListsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.priceListsSaveError(error))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.priceListsTitle),
        content: Text((item['name'] ?? '').toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.priceListsDeleted),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete((item['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.priceListsDeleted)),
      );
      await _load();
    } on PriceListsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.priceListsSaveError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.priceListsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.priceListsTitle)),
        body: Center(child: Text(context.l10n.priceListsForbidden)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.priceListsTitle)),
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
      appBar: AppBar(title: Text(context.l10n.priceListsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: context.l10n.priceListsNew,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.l10n.priceListsEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final items = item['items'];
                final count = items is List ? items.length : 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PriceListDetailScreen(
                            listId: (item['id'] as num).toInt(),
                            name: (item['name'] ?? '').toString(),
                          ),
                        ),
                      );
                      await _load();
                    },
                    title: Text((item['name'] ?? '').toString()),
                    subtitle: Text(
                      '${item['currency'] ?? 'EUR'} • $count items'
                      '${item['active'] == false ? ' • (inactive)' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Righe di un listino: articolo, prezzo e quantità minima.
class PriceListDetailScreen extends StatefulWidget {
  const PriceListDetailScreen({super.key, required this.listId, required this.name});

  final int listId;
  final String name;

  @override
  State<PriceListDetailScreen> createState() => _PriceListDetailScreenState();
}

class _PriceListDetailScreenState extends State<PriceListDetailScreen> {
  final QueryMgwsPriceLists _api = QueryMgwsPriceLists();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];

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
      final data = await _api.get(widget.listId);
      if (!mounted) return;
      final raw = data['items'];
      setState(() {
        _rows = raw is List
            ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : <Map<String, dynamic>>[];
        _isLoading = false;
      });
    } on PriceListsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Prezzo scritto dall'operatore ("12,50") in centesimi; null se non valido.
  static int? _toCents(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  Future<void> _addItems() async {
    final lines = await pickMgwsProductLines(context);
    for (final line in lines) {
      if (!mounted) return;
      final priceCtrl = TextEditingController();
      final minCtrl = TextEditingController(text: '${line.quantity}');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(line.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: priceCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: dialogContext.l10n.priceListsPrice),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: minCtrl,
                decoration: InputDecoration(labelText: dialogContext.l10n.priceListsMinQty),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.l10n.commonConfirm),
            ),
          ],
        ),
      );
      final cents = _toCents(priceCtrl.text);
      final minQty = int.tryParse(minCtrl.text.trim()) ?? 1;
      priceCtrl.dispose();
      minCtrl.dispose();
      if (confirmed != true || !mounted) continue;
      if (cents == null) {
        _snack(context.l10n.priceListsInvalidPrice);
        continue;
      }
      try {
        await _api.upsertItem(
          listId: widget.listId,
          productId: line.productId,
          variationId: line.variationId,
          priceCents: cents,
          minQty: minQty < 1 ? 1 : minQty,
        );
      } on PriceListsException catch (error) {
        if (mounted) _snack(error.message);
      }
    }
    if (mounted) await _load();
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    try {
      await _api.removeItem(widget.listId, (row['id'] as num).toInt());
      if (!mounted) return;
      _snack(context.l10n.priceListsItemRemoved);
    } on PriceListsException catch (error) {
      if (mounted) _snack(error.message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addItems,
        icon: const Icon(Icons.add),
        label: Text(l10n.priceListsAddItem),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _rows.isEmpty
          ? Center(child: Text(l10n.priceListsNoItems))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                for (final row in _rows)
                  Card(
                    child: ListTile(
                      title: Text(
                        '#${row['product_id']}'
                        '${(row['variation_id'] as num?)?.toInt() != 0 ? ' / #${row['variation_id']}' : ''}',
                      ),
                      subtitle: Text(
                        '${l10n.priceListsPrice}: ${(((row['price_cents'] as num?) ?? 0) / 100).toStringAsFixed(2)}'
                        '  •  ${l10n.priceListsMinQty}: ${row['min_qty'] ?? 1}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(row),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
