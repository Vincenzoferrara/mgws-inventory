import 'package:flutter/material.dart';

import '../inventory/product_barcodes.gui.dart';
import '../l10n/extensions.dart';
import '../products/sku_barcode_generator.dart';

/// Schermata di generazione SKU da pattern e codici a barre (EAN-13/UPC-A).
class SkuBarcodeScreen extends StatefulWidget {
  const SkuBarcodeScreen({super.key});

  @override
  State<SkuBarcodeScreen> createState() => _SkuBarcodeScreenState();
}

class _SkuBarcodeScreenState extends State<SkuBarcodeScreen> {
  final TextEditingController _patternController =
      TextEditingController(text: '{brand}-{category}-{seq:4}');
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _seqController = TextEditingController(text: '1');
  final TextEditingController _prefixController = TextEditingController();

  int _count = 5;
  String _barcodeType = 'ean13';
  List<String> _skus = <String>[];
  List<String> _barcodes = <String>[];

  @override
  void dispose() {
    _patternController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _seqController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  void _generate() {
    final pattern = _patternController.text.trim();
    final seq = int.tryParse(_seqController.text.trim()) ?? 1;
    final vars = <String, String>{
      'brand': _brandController.text.trim(),
      'category': _categoryController.text.trim(),
    };
    final skus = <String>[];
    final barcodes = <String>[];
    for (var i = 0; i < _count; i++) {
      skus.add(SkuBarcodeGenerator.skuFromPattern(pattern, seq: seq + i, vars: vars));
      if (_barcodeType == 'ean13') {
        barcodes.add(SkuBarcodeGenerator.ean13(prefix: _prefixController.text.trim(), seq: seq + i));
      } else {
        barcodes.add(SkuBarcodeGenerator.upcA(prefix: _prefixController.text.trim(), seq: seq + i));
      }
    }
    setState(() {
      _skus = skus;
      _barcodes = barcodes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pattern SKU e codici a barre'),
        actions: [
          IconButton(
            tooltip: context.l10n.mgwsOpenProductBarcodesMgws,
            icon: const Icon(Icons.qr_code),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductBarcodesScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: <Widget>[
            TextField(
              controller: _patternController,
              decoration: const InputDecoration(labelText: 'Pattern SKU'),
            ),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            TextField(
              controller: _seqController,
              decoration: const InputDecoration(labelText: 'Sequenza iniziale'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _prefixController,
              decoration: const InputDecoration(labelText: 'Prefisso codice a barre'),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Text('Quantità:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _count,
                  items: const <int>[1, 5, 10, 20, 50]
                      .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) => setState(() => _count = v ?? 5),
                ),
                const SizedBox(width: 16),
                const Text('Tipo:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _barcodeType,
                  items: const <String>['ean13', 'upca']
                      .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _barcodeType = v ?? 'ean13'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _generate, child: const Text('Genera')),
            const SizedBox(height: 16),
            if (_skus.isNotEmpty) ...<Widget>[
              const Text('SKU generati:', style: TextStyle(fontWeight: FontWeight.bold)),
              for (var i = 0; i < _skus.length; i++)
                Text('${_skus[i]}  ->  ${_barcodes[i]}'),
            ],
          ],
        ),
      ),
    );
  }
}