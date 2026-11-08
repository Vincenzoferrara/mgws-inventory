import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_product_barcodes.dart';
import '../products/sku_barcode_screen.gui.dart';

class ProductBarcodesScreen extends StatefulWidget {
  const ProductBarcodesScreen({super.key});
  @override
  State<ProductBarcodesScreen> createState() => _ProductBarcodesScreenState();
}

class _ProductBarcodesScreenState extends State<ProductBarcodesScreen> {
  final QueryMgwsProductBarcodes _api = QueryMgwsProductBarcodes();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  final _productCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  @override
  void dispose() {
    _productCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final pid = int.tryParse(_productCtrl.text.trim()) ?? 0;
    if (pid <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _result = await _api.get(pid);
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

  Future<void> _upsert() async {
    final pid = int.tryParse(_productCtrl.text.trim()) ?? 0;
    final barcode = _barcodeCtrl.text.trim();
    if (pid <= 0 || barcode.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _result = await _api.upsert(productId: pid, barcode: barcode);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mgwsProductBarcodesTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.mgwsOpenSkuBarcodePatterns,
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SkuBarcodeScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextField(
              controller: _productCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.mgwsProductId,
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(labelText: context.l10n.mgwsBarcode),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _lookup,
                  child: Text(context.l10n.mgwsSearch),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _upsert,
                  child: Text(context.l10n.mgwsSave),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_result != null) Text(context.l10n.mgwsResultLine('$_result')),
          ],
        ),
      ),
    );
  }
}
