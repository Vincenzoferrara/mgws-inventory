import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../theme/theme.dart';
import 'inventory.code.dart';
import '../l10n/extensions.dart';

class InventorySupplierPanel extends StatefulWidget {
  InventorySupplierPanel({super.key, InventorySupplierController? controller})
    : controller = controller ?? InventorySupplierController();

  final InventorySupplierController controller;

  @override
  State<InventorySupplierPanel> createState() => _InventorySupplierPanelState();
}

class _InventorySupplierPanelState extends State<InventorySupplierPanel>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  InventoryActionFeedback? _feedback;
  MgwsSupplier? _selected;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  List<MgwsSupplier> get _filteredSuppliers {
    final query = _searchController.text.trim().toLowerCase();
    final suppliers = widget.controller.suppliers;
    if (query.isEmpty) return suppliers;
    return suppliers
        .where((supplier) {
          return supplier.id.toString().contains(query) ||
              supplier.name.toLowerCase().contains(query) ||
              supplier.email.toLowerCase().contains(query) ||
              supplier.phone.toLowerCase().contains(query) ||
              supplier.taxId.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final feedback = await widget.controller.load();
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
      if (_selected == null && widget.controller.suppliers.isNotEmpty) {
        _selected = widget.controller.suppliers.first;
      }
    });
  }

  Future<void> _select(MgwsSupplier supplier) async {
    setState(() => _selected = supplier);
    final feedback = await widget.controller.get(supplier.id.toString());
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _selected = widget.controller.lastSupplier ?? supplier;
    });
  }

  Future<void> _addSupplier() async {
    final saved = await showInventorySupplierForm(
      context,
      controller: widget.controller,
    );
    if (saved == true) await _load();
  }

  Future<void> _editSupplier(MgwsSupplier supplier) async {
    final saved = await showInventorySupplierForm(
      context,
      controller: widget.controller,
      supplier: supplier,
    );
    if (saved == true) await _load();
  }

  Future<void> _deactivateSupplier(MgwsSupplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.inventoryDisattivaFornitore),
        content: Text(
          context.l10n.inventoryDeactivateSupplierConfirm(supplier.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.inventoryDisattiva),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final feedback = await widget.controller.delete(supplier.id.toString());
    if (!mounted) return;
    setState(() => _feedback = feedback);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Il pannello e' una sezione intera della home: come le altre pagine sta
    // sullo sfondo del tema, non dentro una Card che ne prenderebbe il grigio.
    return Scaffold(
      key: const ValueKey('inventory-suppliers-panel'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final small = constraints.maxWidth < 800;
          return small ? _mobile() : _desktop();
        },
      ),
    );
  }

  Widget _desktop() => Row(
    children: [
      Expanded(
        flex: 3,
        child: Column(
          children: [
            _toolbar(),
            Expanded(child: _list()),
          ],
        ),
      ),
      VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
      Expanded(
        flex: 2,
        child: _selected == null
            ? const _SupplierEmptyDetail()
            : _SupplierDetail(
                supplier: _selected!,
                feedback: _feedback,
                onEdit: () => _editSupplier(_selected!),
                onDeactivate: () => _deactivateSupplier(_selected!),
              ),
      ),
    ],
  );

  Widget _mobile() => Column(
    children: [
      _toolbar(),
      Expanded(child: _list()),
      if (_selected != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: _SupplierDetail(
            supplier: _selected!,
            feedback: _feedback,
            onEdit: () => _editSupplier(_selected!),
            onDeactivate: () => _deactivateSupplier(_selected!),
          ),
        ),
    ],
  );

  Widget _toolbar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.inventoryCercaFornitoreHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              foregroundColor: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('inventory-supplier-add'),
            onPressed: _addSupplier,
            icon: const Icon(Icons.add_business),
            label: Text(context.l10n.inventoryAggiungiFornitore),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_feedback != null && !_feedback!.success) {
      return _ErrorState(
        message: _feedback!.message(context.l10n),
        onRetry: _load,
      );
    }
    final suppliers = _filteredSuppliers;
    if (suppliers.isEmpty) {
      return _EmptyState(message: context.l10n.inventoryNoSupplierFound);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        return _SupplierListItem(
          supplier: supplier,
          selected: _selected?.id == supplier.id,
          onTap: () => _select(supplier),
        );
      },
    );
  }
}

class _SupplierListItem extends StatelessWidget {
  const _SupplierListItem({
    required this.supplier,
    required this.selected,
    required this.onTap,
  });

  final MgwsSupplier supplier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      elevation: selected ? 3 : 1,
      color: selected
          ? theme.primaryColor.withValues(alpha: 0.08)
          : theme.cardColor,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: supplier.active
              ? theme.primaryColor.withValues(alpha: 0.15)
              : colors.warningColor.withValues(alpha: 0.15),
          child: Icon(
            Icons.local_shipping_outlined,
            color: supplier.active ? theme.primaryColor : colors.warningColor,
          ),
        ),
        title: Text(
          supplier.name.isEmpty
              ? context.l10n.inventorySupplierRef(supplier.id)
              : supplier.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (supplier.email.isNotEmpty) supplier.email,
            if (supplier.phone.isNotEmpty) supplier.phone,
          ].join(' · '),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Chip(
          label: Text(
            supplier.active
                ? context.l10n.inventoryAttivo
                : context.l10n.inventoryInactive,
          ),
          side: BorderSide(
            color: supplier.active ? colors.successColor : colors.warningColor,
          ),
        ),
      ),
    );
  }
}

class _SupplierDetail extends StatelessWidget {
  const _SupplierDetail({
    required this.supplier,
    required this.feedback,
    required this.onEdit,
    required this.onDeactivate,
  });

  final MgwsSupplier supplier;
  final InventoryActionFeedback? feedback;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 32,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.l10n.inventorySupplierRecord(supplier.id),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: context.l10n.inventoryVatNumber,
                value: supplier.taxId,
              ),
              _InfoChip(label: 'Email', value: supplier.email),
              _InfoChip(
                label: context.l10n.inventoryPhone,
                value: supplier.phone,
              ),
              _InfoChip(
                label: context.l10n.inventoryPayment,
                value: supplier.paymentTermsDays == 0
                    ? ''
                    : context.l10n.inventoryDaysValue(
                        supplier.paymentTermsDays,
                      ),
              ),
              _InfoChip(
                label: 'Lead time',
                value: supplier.leadTimeDays == 0
                    ? ''
                    : context.l10n.inventoryDaysValue(supplier.leadTimeDays),
              ),
            ],
          ),
          if (supplier.iban.isNotEmpty || supplier.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            if (supplier.iban.isNotEmpty) _detailLine('IBAN', supplier.iban),
            if (supplier.notes.isNotEmpty)
              _detailLine(context.l10n.inventoryNotes, supplier.notes),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.l10n.inventoryModifica),
              ),
              OutlinedButton.icon(
                onPressed: supplier.active ? onDeactivate : null,
                icon: const Icon(Icons.block_outlined),
                label: Text(context.l10n.inventoryDisattiva),
              ),
            ],
          ),
          if (feedback != null) ...[
            const SizedBox(height: 20),
            _Feedback(feedback: feedback!),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

/// Apre il form anagrafica fornitore e restituisce `true` se e' stato salvato.
///
/// Lo stesso dialogo serve la schermata Fornitori e la card ordine di
/// Inventario: due form per gli stessi campi diventerebbero due criteri
/// diversi alla prima divergenza.
Future<bool?> showInventorySupplierForm(
  BuildContext context, {
  required InventorySupplierController controller,
  MgwsSupplier? supplier,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _SupplierFormDialog(controller: controller, supplier: supplier),
  );
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({required this.controller, this.supplier});

  final InventorySupplierController controller;
  final MgwsSupplier? supplier;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _nameController = TextEditingController();
  final _taxController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _ibanController = TextEditingController();
  final _leadTimeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _active = true;
  bool _saving = false;
  InventoryActionFeedback? _feedback;

  bool get _editing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    if (supplier == null) return;
    _nameController.text = supplier.name;
    _taxController.text = supplier.taxId;
    _emailController.text = supplier.email;
    _phoneController.text = supplier.phone;
    _paymentTermsController.text = supplier.paymentTermsDays == 0
        ? ''
        : supplier.paymentTermsDays.toString();
    _ibanController.text = supplier.iban;
    _leadTimeController.text = supplier.leadTimeDays == 0
        ? ''
        : supplier.leadTimeDays.toString();
    _notesController.text = supplier.notes;
    _active = supplier.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _paymentTermsController.dispose();
    _ibanController.dispose();
    _leadTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InventorySupplierForm _form() => InventorySupplierForm(
    nameText: _nameController.text,
    taxIdText: _taxController.text,
    emailText: _emailController.text,
    phoneText: _phoneController.text,
    notesText: _notesController.text,
    paymentTermsDaysText: _paymentTermsController.text,
    ibanText: _ibanController.text,
    leadTimeDaysText: _leadTimeController.text,
    active: _active,
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final feedback = _editing
        ? await widget.controller.update(
            supplierIdText: widget.supplier!.id.toString(),
            form: _form(),
          )
        : await widget.controller.create(_form());
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _saving = false;
    });
    if (feedback.success && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _editing
            ? context.l10n.inventoryEditSupplier
            : context.l10n.inventoryAggiungiFornitore,
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field(
                _nameController,
                context.l10n.inventorySupplierNameRequiredLabel,
              ),
              _field(_taxController, context.l10n.inventoryVatTax),
              _field(_emailController, 'Email'),
              _field(_phoneController, context.l10n.inventoryPhone),
              _field(
                _paymentTermsController,
                context.l10n.inventoryPaymentDays,
              ),
              _field(_ibanController, 'IBAN', width: 452),
              _field(_leadTimeController, context.l10n.inventoryLeadTimeDays),
              _field(
                _notesController,
                context.l10n.inventoryNotes,
                width: 452,
                maxLines: 3,
              ),
              SizedBox(
                width: 220,
                child: SwitchListTile(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: Text(context.l10n.inventoryAttivo),
                ),
              ),
              if (_feedback != null)
                SizedBox(width: 452, child: _Feedback(feedback: _feedback!)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        FilledButton.icon(
          key: const ValueKey('inventory-supplier-save-dialog'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _editing
                ? context.l10n.commonSave
                : context.l10n.inventoryCreateSupplier,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 220,
    int maxLines = 1,
    bool enabled = true,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      context.l10n.commonLabelValue(label, value.isEmpty ? '-' : value),
    ),
  );
}

class _SupplierEmptyDetail extends StatelessWidget {
  const _SupplierEmptyDetail();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_shipping_outlined, size: 64),
        SizedBox(height: 16),
        Text(context.l10n.inventorySelezionaFornitore),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: context.colors.errorColorStatus,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.inventoryRiprova),
        ),
      ],
    ),
  );
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.feedback});
  final InventoryActionFeedback feedback;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.message(context.l10n),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
          for (final detail in feedback.details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(detail(context.l10n)),
            ),
        ],
      ),
    );
  }
}
