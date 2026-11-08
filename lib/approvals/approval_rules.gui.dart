import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_approval_rules.dart';
import '../l10n/extensions.dart';

/// Schermata delle regole di approvazione.
class ApprovalRulesScreen extends StatefulWidget {
  const ApprovalRulesScreen({super.key});

  @override
  State<ApprovalRulesScreen> createState() => _ApprovalRulesScreenState();
}

class _ApprovalRulesScreenState extends State<ApprovalRulesScreen> {
  final QueryMgwsApprovalRules _api = QueryMgwsApprovalRules();

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
    } on ApprovalRulesException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.approvalRulesForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.approvalRulesLoadError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final typeController = TextEditingController();
    final capController = TextEditingController();
    final thresholdController = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.approvalRulesNew),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration:
                    InputDecoration(labelText: context.l10n.approvalRulesDocumentType),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: thresholdController,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: context.l10n.approvalRulesThreshold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capController,
                decoration:
                    InputDecoration(labelText: context.l10n.approvalRulesCapability),
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
    );
    if (confirmed != true) return;
    final type = typeController.text.trim();
    final cap = capController.text.trim();
    if (type.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.approvalRulesNoType)),
        );
      }
      return;
    }
    if (cap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.approvalRulesNoCapability)),
        );
      }
      return;
    }
    try {
      await _api.create(
        documentType: type,
        thresholdCents: int.tryParse(thresholdController.text.trim()) ?? 0,
        requiredCapability: cap,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalRulesCreated)),
      );
      await _load();
    } on ApprovalRulesException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalRulesSaveError(error))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    try {
      await _api.delete((item['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalRulesDeleted)),
      );
      await _load();
    } on ApprovalRulesException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.approvalRulesSaveError(error))),
      );
    }
  }

  /// Prova senza effetti: "se questo documento costasse X, servirebbe
  /// un'approvazione?" (POST /approval-rules/check).
  Future<void> _check() async {
    final l10n = context.l10n;
    final typeCtrl = TextEditingController(text: 'purchase_order');
    final amountCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.approvalRulesCheckTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(controller: typeCtrl, decoration: InputDecoration(labelText: l10n.approvalRulesCheckType)),
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: l10n.approvalRulesCheckAmount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    final type = typeCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
    typeCtrl.dispose();
    amountCtrl.dispose();
    if (go != true || !mounted || type.isEmpty || amount == null) return;
    try {
      final res = await _api.check(documentType: type, amountCents: (amount * 100).round());
      if (!mounted) return;
      final message = res['required'] == true
          ? l10n.approvalRulesCheckRequired((res['capability'] ?? '').toString())
          : l10n.approvalRulesCheckNotRequired;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApprovalRulesException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.approvalRulesTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.approvalRulesTitle)),
        body: Center(child: Text(context.l10n.approvalRulesForbidden)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.approvalRulesTitle)),
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
      appBar: AppBar(
        title: Text(context.l10n.approvalRulesTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: context.l10n.approvalRulesCheckTitle,
            onPressed: _check,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: context.l10n.approvalRulesNew,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? Center(child: Text(context.l10n.approvalRulesEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text((item['document_type'] ?? '').toString()),
                    subtitle: Text(
                      '${context.l10n.approvalRulesThreshold}: ${item['threshold_cents']}'
                      ' • ${item['required_capability']}'
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
