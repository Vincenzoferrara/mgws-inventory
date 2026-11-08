import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_documents.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final QueryMgwsDocuments _api = QueryMgwsDocuments();
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
    final typeCtrl = TextEditingController(text: 'ddt');
    final numCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.mgwsDocumentNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.mgwsDocumentTypeLabel,
              ),
            ),
            TextField(
              controller: numCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.mgwsDocumentNumber,
              ),
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
        documentType: typeCtrl.text.trim(),
        documentNumber: numCtrl.text.trim(),
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
        title: Text(ctx.l10n.mgwsDocumentStatusTitle),
        content: TextField(
          controller: statusCtrl,
          decoration: InputDecoration(
            labelText: ctx.l10n.mgwsStatusDraftIssuedSentCancelled,
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
      appBar: AppBar(title: Text(context.l10n.mgwsDocumentsTitle)),
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
                      context.l10n.mgwsDocumentLine(
                        '${m['document_type']}',
                        '${m['document_number']}',
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.mgwsDocumentSubtitle('${m['status']}'),
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
