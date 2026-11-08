import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_supplier_prices.dart';

class SupplierPricesScreen extends StatefulWidget {
  const SupplierPricesScreen({super.key});
  @override
  State<SupplierPricesScreen> createState() => _SupplierPricesScreenState();
}

class _SupplierPricesScreenState extends State<SupplierPricesScreen> {
  final QueryMgwsSupplierPrices _api = QueryMgwsSupplierPrices();
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
    final supplierCtrl = TextEditingController();
    final productCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsSupplierPriceNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsSupplierId),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: productCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsProductId),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(labelText: ctx.l10n.mgwsPriceCents),
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
        supplierId: int.tryParse(supplierCtrl.text.trim()) ?? 0,
        productId: int.tryParse(productCtrl.text.trim()) ?? 0,
        priceCents: int.tryParse(priceCtrl.text.trim()) ?? 0,
      );
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.mgwsSupplierPricesTitle)),
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
                      context.l10n.mgwsSupplierProductLine(
                        '${m['supplier_id']}',
                        '${m['product_id']}',
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.mgwsPriceCentsLine('${m['price_cents']}'),
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
