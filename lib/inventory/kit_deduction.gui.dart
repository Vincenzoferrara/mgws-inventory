import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../login/mgws/query/query_mgws_kits.dart';

/// Schermata di deduzione stock dei componenti di un kit.
///
/// Mostra, per ogni sede fisica, quanti kit si possono costruire dai componenti
/// disponibili. La sede fisica e' l'unita' di deduzione: nessun fallback tra
/// sedi. Il magazzino virtuale e' solo un raggruppamento; stanza/scaffale/
/// ripiano localizzano il pezzo.
class KitDeductionScreen extends StatefulWidget {
  const KitDeductionScreen({
    super.key,
    required this.productId,
    this.variationId = 0,
    this.productName,
  });

  final int productId;
  final int variationId;
  final String? productName;

  @override
  State<KitDeductionScreen> createState() => _KitDeductionScreenState();
}

class _KitDeductionScreenState extends State<KitDeductionScreen> {
  final QueryMgwsKits _api = QueryMgwsKits();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _sites = <Map<String, dynamic>>[];
  late int _productId = widget.productId;
  final TextEditingController _productController = TextEditingController();
  int _qty = 1;
  int? _selectedSiteId;

  @override
  void dispose() {
    _productController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (_productId > 0) _productController.text = _productId.toString();
    _load();
  }

  Future<void> _load() async {
    if (_productId <= 0) {
      setState(() {
        _loading = false;
        _error = context.l10n.mgwsEnterKitProductId;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.availability(
        productId: _productId,
        variationId: widget.variationId,
        qty: _qty,
      );
      final sites = res['sites'];
      setState(() {
        _sites = sites is List
            ? sites.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deduct() async {
    final siteId = _selectedSiteId;
    if (siteId == null) {
      setState(() => _error = context.l10n.mgwsSelectSite);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.deduct(
        siteId: siteId,
        productId: _productId,
        variationId: widget.variationId,
        qty: _qty,
      );
      if (res['ok'] == true) {
        setState(() {
          _loading = false;
          _error = context.l10n.mgwsDeductionOkShortfall(
            '${res['shortfall'] ?? 0}',
          );
        });
        await _load();
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Errore';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.productName == null
        ? l10n.mgwsKitDeductionTitle
        : l10n.mgwsKitDeductionTitleWithName(widget.productName!);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(l10n.mgwsKitProductId),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: _productController,
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null) _productId = n;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  child: Text(l10n.mgwsSearch),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(l10n.mgwsKitQuantity),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: _qty.toString()),
                    onChanged: (v) {
                      final n = int.tryParse(v.trim());
                      if (n != null && n > 0) {
                        _qty = n;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  child: Text(l10n.mgwsRefresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Text(
              l10n.mgwsPhysicalSitesAvailable,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _sites.length,
                itemBuilder: (context, index) {
                  final site = _sites[index];
                  final siteId = site['site_id'] as int? ?? 0;
                  final siteName =
                      site['site_name']?.toString() ??
                      l10n.mgwsSiteFallbackName('$siteId');
                  final availableKits = site['available_kits'] as int? ?? 0;
                  final available = site['available'] == true;
                  final components = site['components'];
                  final selected = _selectedSiteId == siteId;
                  return Card(
                    color: selected
                        ? Colors.blue.shade50
                        : (available ? null : Colors.grey.shade200),
                    child: InkWell(
                      onTap: available
                          ? () => setState(() => _selectedSiteId = siteId)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: available ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    siteName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              available
                                  ? l10n.mgwsKitsAvailable('$availableKits')
                                  : l10n.mgwsNotAvailableInSite,
                              style: TextStyle(
                                color: available ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (components is List)
                              ...components.map((c) {
                                final m = c as Map;
                                final avail = m['available_qty'] ?? 0;
                                final need = m['needed_per_kit'] ?? 0;
                                final room = m['room']?.toString() ?? '';
                                final rack = m['rack']?.toString() ?? '';
                                final shelf = m['shelf']?.toString() ?? '';
                                final loc = <String>[
                                  if (room.isNotEmpty) l10n.mgwsRoom(room),
                                  if (rack.isNotEmpty) l10n.mgwsRack(rack),
                                  if (shelf.isNotEmpty) l10n.mgwsShelf(shelf),
                                ].join(' · ');
                                return Text(
                                  l10n.mgwsComponentLine(
                                    '${m['product_id']}',
                                    '$avail',
                                    '$need',
                                    loc.isEmpty ? '' : ' — $loc',
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading || _selectedSiteId == null ? null : _deduct,
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(l10n.mgwsDeductFromSelectedSite),
            ),
          ],
        ),
      ),
    );
  }
}
