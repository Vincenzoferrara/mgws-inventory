import 'package:flutter/material.dart';
import './rfid.dart';
import '../l10n/extensions.dart';

/// Widget per testare RFID nel dashboard o inventory
class RFIDTestWidget extends StatefulWidget {
  const RFIDTestWidget({super.key});

  @override
  State<RFIDTestWidget> createState() => _RFIDTestWidgetState();
}

class _RFIDTestWidgetState extends State<RFIDTestWidget> {
  final RFIDManager _rfidManager = RFIDManager();
  List<String> _tags = [];
  bool _isScanning = false;
  String _status = 'Non connesso';

  @override
  void initState() {
    super.initState();
    _initRFID();
  }

  Future<void> _initRFID() async {
    await _rfidManager.init();
    setState(() {
      _status = _rfidManager.isConnected ? 'Connesso' : 'Non connesso';
    });
  }

  Future<void> _connect() async {
    final connected = await _rfidManager.connect();
    setState(() {
      _status = connected ? 'Connesso' : 'Connessione fallita';
    });
  }

  Future<void> _scanTags() async {
    setState(() {
      _isScanning = true;
      _tags.clear();
    });

    try {
      final tags = await _rfidManager.readTags();
      setState(() {
        _tags = tags;
        _status = 'Scan completato: ${tags.length} tag trovati';
      });
    } catch (e) {
      setState(() {
        _status = 'Errore scan: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.rfidTitolo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.rfidStato(_status)),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _connect,
                  child: Text(context.l10n.rfidConnetti),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _rfidManager.isConnected ? _scanTags : null,
                  child: _isScanning
                      ? const CircularProgressIndicator()
                      : Text(context.l10n.rfidScansiona),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_tags.isNotEmpty) ...[
              Text(context.l10n.rfidTagTrovati),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    return Text('- ${_tags[index]}');
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
