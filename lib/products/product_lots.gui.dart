import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_lots.dart';
import '../l10n/extensions.dart';

/// Schermata dei lotti di un articolo.
///
/// Un lotto e' un'etichetta: non cambia la quantita' del magazzino e non
/// porta costo. La schermata ne mostra lo stato (scadenza) e permette di
/// crearne/eliminarne.
class ProductLotsScreen extends StatefulWidget {
  final int productId;
  final int variationId;

  const ProductLotsScreen({
    super.key,
    required this.productId,
    this.variationId = 0,
  });

  @override
  State<ProductLotsScreen> createState() => _ProductLotsScreenState();
}

class _ProductLotsScreenState extends State<ProductLotsScreen> {
  final QueryMgwsLots _api = QueryMgwsLots();

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
      final data = await _api.list(
        productId: widget.productId,
        variationId: widget.variationId,
      );
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
    } on LotsException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.lotsForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.lotsLoadError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final codeController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? expires;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.lotsNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(labelText: context.l10n.lotsCode),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(labelText: context.l10n.lotsNote),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expires == null
                            ? context.l10n.lotsExpiresAt
                            : expires!.toIso8601String().split('T').first,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => expires = picked);
                        }
                      },
                      child: const Icon(Icons.calendar_today),
                    ),
                  ],
                ),
              ],
            ),
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
      ),
    );
    if (confirmed != true) return;
    final code = codeController.text.trim();
    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.lotsAtLeastCode)),
        );
      }
      return;
    }
    try {
      await _api.create(
        productId: widget.productId,
        variationId: widget.variationId,
        lotCode: code,
        expiresAtGmt: expires?.toUtc().toIso8601String(),
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lotsCreated)),
      );
      await _load();
    } on LotsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lotsSaveError(error))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final code = (item['lot_code'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.lotsDelete),
        content: Text(context.l10n.lotsDeleteConfirm(code)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.lotsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete((item['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lotsDeleted)),
      );
      await _load();
    } on LotsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lotsSaveError(error))),
      );
    }
  }

  bool _isExpired(Map<String, dynamic> item) {
    final raw = item['expires_at_gmt'];
    if (raw == null) return false;
    final dt = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (dt == null) return false;
    return dt.isBefore(DateTime.now().toUtc());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.lotsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.lotsTitle)),
        body: Center(child: Text(context.l10n.lotsForbidden)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.lotsTitle)),
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
      appBar: AppBar(title: Text(context.l10n.lotsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: context.l10n.lotsNew,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.l10n.lotsEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final expired = _isExpired(item);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text((item['lot_code'] ?? '').toString()),
                    subtitle: Text(
                      '${context.l10n.lotsExpiresAt}: ${(item['expires_at_gmt'] ?? '-').toString()}'
                      '${item['supplier_id'] != null && item['supplier_id'] != 0 ? ' • ${context.l10n.lotsSupplier} #${item['supplier_id']}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                    tileColor: expired ? Colors.red.withAlpha(20) : null,
                  ),
                );
              },
            ),
    );
  }
}
