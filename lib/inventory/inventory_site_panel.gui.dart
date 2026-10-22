// Sede in uso: pannello condiviso da Inventario e Impostazioni.
//
// La sede e' obbligatoria per usare l'inventario. Il server decide quale vale
// (quella assegnata all'utente, oppure l'unica del negozio); qui si mostra il
// caso giusto:
//  - nessuna sede nel negozio: chi puo' crearla e' guidato, gli altri sanno a
//    chi chiedere;
//  - piu' sedi e nessuna assegnata: chi puo' sceglie, gli altri sanno a chi
//    chiedere;
//  - sede presente: chi gestisce i dipendenti puo' cambiarla, gli altri la
//    vedono bloccata.

import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_site.dart';
import '../l10n/extensions.dart';

class InventorySitePanel extends StatefulWidget {
  const InventorySitePanel({
    super.key,
    required this.onStatusChanged,
    this.query,
  });

  /// Riceve lo stato quando c'e' una sede in uso, `null` finche' non c'e':
  /// chi ospita il pannello blocca l'inventario su `null`.
  final ValueChanged<MgwsSiteStatus?> onStatusChanged;

  final QueryMgwsSite? query;

  @override
  State<InventorySitePanel> createState() => _InventorySitePanelState();
}

class _InventorySitePanelState extends State<InventorySitePanel> {
  late final QueryMgwsSite _query = widget.query ?? QueryMgwsSite();
  final TextEditingController _nameController = TextEditingController();

  MgwsSiteStatus? _status;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _creating = false;

  /// Valore della voce "Nuova sede…" nel menu delle sedi.
  static const int _nuovaSede = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _run(_query.getMySite);
  }

  Future<void> _choose(int siteId) async {
    if (siteId == _status?.siteId) return;
    await _run(() => _query.setMySite(siteId));
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await _run(() async {
      await _query.createSite(name);
      return _query.getMySite();
    });
    if (mounted && _error == null) {
      _nameController.clear();
      setState(() => _creating = false);
    }
  }

  /// Esegue una chiamata che restituisce lo stato aggiornato e lo applica.
  Future<void> _run(Future<MgwsSiteStatus> Function() call) async {
    setState(() => _busy = true);
    try {
      final status = await call();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
      widget.onStatusChanged(status.hasSite ? status : null);
    } on MgwsSiteException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (_status == null) widget.onStatusChanged(null);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _status;

    if (_loading) {
      return _card(
        context,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.sedeCaricamento)),
          ],
        ),
      );
    }

    if (status == null) {
      return _message(
        context,
        icon: Icons.cloud_off,
        title: l10n.sedeInUso,
        text: _error ?? '',
        action: TextButton.icon(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.sedeRiprova),
        ),
      );
    }

    final Widget content;
    if (_creating || (status.noSitesExist && status.canCreate)) {
      content = _createForm(context, first: status.noSitesExist);
    } else if (status.hasSite) {
      content = _inUse(context, status);
    } else if (status.noSitesExist) {
      content = _message(
        context,
        icon: Icons.store_mall_directory_outlined,
        title: l10n.sedeNessunaTitolo,
        text: l10n.sedeNessunaTesto,
      );
    } else if (status.canChange) {
      content = _chooser(context, status);
    } else {
      content = _message(
        context,
        icon: Icons.person_off_outlined,
        title: l10n.sedeNonAssegnataTitolo,
        text: l10n.sedeNonAssegnataTesto,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _inUse(BuildContext context, MgwsSiteStatus status) {
    final l10n = context.l10n;
    if (!status.canChange) {
      return InputDecorator(
        key: const ValueKey('inventory-site-field'),
        decoration: InputDecoration(
          labelText: l10n.sedeInUso,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          helperText: l10n.sedeBloccata,
        ),
        child: Text(status.siteName),
      );
    }
    return DropdownButtonFormField<int>(
      key: const ValueKey('inventory-site-field'),
      initialValue: status.siteId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.sedeInUso,
        prefixIcon: const Icon(Icons.store_outlined, size: 18),
        helperText: l10n.sedeModificabile,
      ),
      items: [
        for (final site in status.sites)
          DropdownMenuItem(value: site.id, child: Text(site.name)),
        DropdownMenuItem(value: _nuovaSede, child: Text(l10n.sedeNuova)),
      ],
      onChanged: _busy
          ? null
          : (value) {
              if (value == null) return;
              if (value == _nuovaSede) {
                setState(() => _creating = true);
              } else {
                _choose(value);
              }
            },
    );
  }

  Widget _chooser(BuildContext context, MgwsSiteStatus status) {
    final l10n = context.l10n;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context, Icons.store_outlined, l10n.sedeSceltaTitolo),
          const SizedBox(height: 6),
          Text(l10n.sedeSceltaTesto),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('inventory-site-choice'),
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.sedeInUso),
            items: [
              for (final site in status.sites)
                DropdownMenuItem(value: site.id, child: Text(site.name)),
              DropdownMenuItem(value: _nuovaSede, child: Text(l10n.sedeNuova)),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    if (value == _nuovaSede) {
                      setState(() => _creating = true);
                    } else {
                      _choose(value);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _createForm(BuildContext context, {required bool first}) {
    final l10n = context.l10n;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            context,
            Icons.add_business_outlined,
            first ? l10n.sedeCreaPrimaTitolo : l10n.sedeNuova,
          ),
          if (first) ...[
            const SizedBox(height: 6),
            Text(l10n.sedeCreaPrimaTesto),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('inventory-site-name'),
            controller: _nameController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.sedeNome),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!first)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _creating = false),
                  child: Text(l10n.commonCancel),
                ),
              FilledButton.icon(
                key: const ValueKey('inventory-site-create'),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add),
                label: Text(l10n.sedeCrea),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
    Widget? action,
  }) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(context, icon, title),
          if (text.isNotEmpty) ...[const SizedBox(height: 6), Text(text)],
          if (action != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      key: const ValueKey('inventory-site-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
