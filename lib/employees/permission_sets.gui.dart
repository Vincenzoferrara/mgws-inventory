import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_permission_sets.dart';
import '../l10n/extensions.dart';
import 'employee_hr.code.dart';

/// Schermata dei set di permessi MGWS.
///
/// Un set e' un template di capability applicato come ruolo WordPress
/// `mgws_{slug}`. La schermata e' di sola lettura se l'utente non ha
/// `mgws_roles_manage`; il server e' comunque l'autorita' finale.
class PermissionSetsScreen extends StatefulWidget {
  const PermissionSetsScreen({super.key});

  @override
  State<PermissionSetsScreen> createState() => _PermissionSetsScreenState();
}

class _PermissionSetsScreenState extends State<PermissionSetsScreen> {
  final QueryMgwsPermissionSets _api = QueryMgwsPermissionSets();

  bool _isLoading = true;
  bool _forbidden = false;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _catalog = <Map<String, dynamic>>[];
  bool _canManage = false;

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
      final itemsRaw = data['items'];
      final catalogRaw = data['catalog'];
      if (!mounted) return;
      setState(() {
        _items = itemsRaw is List
            ? itemsRaw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        _catalog = catalogRaw is List
            ? catalogRaw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        _canManage = data['can_manage'] == true;
        _isLoading = false;
      });
    } on PermissionSetsException catch (error) {
      if (!mounted) return;
      setState(() {
        _forbidden = error.nonAutorizzato;
        _error = error.nonAutorizzato
            ? context.l10n.permissionSetsForbidden
            : error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.permissionSetsLoadError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _PermissionSetEditorDialog(catalog: _catalog, l10n: context.l10n),
    );
    if (result == null) return;
    try {
      await _api.create(
        slug: result['slug'] as String,
        label: result['label'] as String,
        capabilities: (result['capabilities'] as List).cast<String>(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsCreated)),
      );
      await _load();
    } on PermissionSetsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsSaveError(error))),
      );
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PermissionSetEditorDialog(
        catalog: _catalog,
        existing: item,
        l10n: context.l10n,
      ),
    );
    if (result == null) return;
    try {
      await _api.update(
        id: (item['id'] as num).toInt(),
        capabilities: (result['capabilities'] as List).cast<String>(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsUpdated)),
      );
      await _load();
    } on PermissionSetsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsSaveError(error))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final label = nomeSetPermessi(context.l10n, item);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.permissionSetsDelete),
        content: Text(context.l10n.permissionSetsDeleteConfirm(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.permissionSetsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.delete((item['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsDeleted)),
      );
      await _load();
    } on PermissionSetsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.permissionSetsSaveError(error))),
      );
    }
  }

  String _capabilityLabel(String key) {
    switch (key) {
      case 'read':
        return context.l10n.capRead;
      case 'edit_products':
        return context.l10n.capEditProducts;
      case 'edit_shop_orders':
        return context.l10n.capEditShopOrders;
      case 'mgws_stock_read':
        return context.l10n.capMgwsStockRead;
      case 'mgws_stock_move':
        return context.l10n.capMgwsStockMove;
      case 'mgws_order_accept':
        return context.l10n.capMgwsOrderAccept;
      case 'mgws_supplier_manage':
        return context.l10n.capMgwsSupplierManage;
      case 'mgws_purchase_approve':
        return context.l10n.capMgwsPurchaseApprove;
      case 'mgws_manage_employees':
        return context.l10n.capMgwsManageEmployees;
      case 'mgws_manage_user_permissions':
        return context.l10n.capMgwsManageUserPermissions;
      case 'mgws_manage_credentials':
        return context.l10n.capMgwsManageCredentials;
      case 'mgws_reports_read':
        return context.l10n.capMgwsReportsRead;
      case 'mgws_costs_read':
        return context.l10n.capMgwsCostsRead;
      case 'mgws_costs_manage':
        return context.l10n.capMgwsCostsManage;
      case 'mgws_roles_read':
        return context.l10n.capMgwsRolesRead;
      case 'mgws_roles_manage':
        return context.l10n.capMgwsRolesManage;
      case 'mgws_lots_manage':
        return context.l10n.capMgwsLotsManage;
      case 'mgws_transfers_manage':
        return context.l10n.capMgwsTransfersManage;
      case 'mgws_price_lists_manage':
        return context.l10n.capMgwsPriceListsManage;
      case 'mgws_approval_rules_manage':
        return context.l10n.capMgwsApprovalRulesManage;
      case 'mgws_returns_manage':
        return context.l10n.capMgwsReturnsManage;
      case 'mgws_stock_reset_manage':
        return context.l10n.capMgwsStockResetManage;
      case 'mgws_count_schedules_manage':
        return context.l10n.capMgwsCountSchedulesManage;
      case 'mgws_kits_manage':
        return context.l10n.capMgwsKitsManage;
      case 'mgws_reservations_manage':
        return context.l10n.capMgwsReservationsManage;
      case 'mgws_shipments_manage':
        return context.l10n.capMgwsShipmentsManage;
      case 'mgws_product_barcodes_manage':
        return context.l10n.capMgwsProductBarcodesManage;
      case 'mgws_supplier_prices_manage':
        return context.l10n.capMgwsSupplierPricesManage;
      case 'mgws_documents_manage':
        return context.l10n.capMgwsDocumentsManage;
      case 'mgws_payments_manage':
        return context.l10n.capMgwsPaymentsManage;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.permissionSetsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_forbidden) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.permissionSetsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.permissionSetsForbidden),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.permissionSetsTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: Text(context.l10n.employeesRetry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.permissionSetsTitle)),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _create,
              tooltip: context.l10n.permissionSetsNew,
              child: const Icon(Icons.add),
            )
          : null,
      body: _items.isEmpty
          ? Center(child: Text(context.l10n.permissionSetsEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final inUse = item['in_use'] == true;
                final caps =
                    (item['capabilities'] as List?)
                        ?.map((value) => value.toString())
                        .toList() ??
                    <String>[];
                final userCount = (item['user_count'] as num?)?.toInt() ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomeSetPermessi(context.l10n, item),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (inUse)
                              Tooltip(
                                message: context.l10n.permissionSetsInUse(
                                  userCount,
                                ),
                                child: const Icon(Icons.lock_outline),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (item['slug'] ?? '').toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: caps
                              .map(
                                (cap) => Chip(
                                  label: Text(_capabilityLabel(cap)),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.permissionSetsInUse(userCount),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_canManage) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: inUse ? null : () => _edit(item),
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(context.l10n.permissionSetsEdit),
                              ),
                              TextButton.icon(
                                onPressed: inUse ? null : () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(context.l10n.permissionSetsDelete),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Dialog di creazione/modifica di un set.
class _PermissionSetEditorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> catalog;
  final Map<String, dynamic>? existing;
  final dynamic l10n;

  const _PermissionSetEditorDialog({
    required this.catalog,
    required this.l10n,
    this.existing,
  });

  @override
  State<_PermissionSetEditorDialog> createState() =>
      _PermissionSetEditorDialogState();
}

class _PermissionSetEditorDialogState
    extends State<_PermissionSetEditorDialog> {
  late final TextEditingController _slugController;
  late final TextEditingController _labelController;
  final Set<String> _selected = <String>{};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _inUse => widget.existing?['in_use'] == true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _slugController = TextEditingController(
      text: (existing?['slug'] ?? '').toString(),
    );
    _labelController = TextEditingController(
      text: (existing?['label'] ?? '').toString(),
    );
    final caps = existing?['capabilities'];
    if (caps is List) {
      _selected.addAll(caps.map((value) => value.toString()));
    }
  }

  @override
  void dispose() {
    _slugController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, dynamic>>> _groupedCatalog() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in widget.catalog) {
      final area = (entry['area'] ?? 'other').toString();
      grouped.putIfAbsent(area, () => <Map<String, dynamic>>[]).add(entry);
    }
    return grouped;
  }

  Future<void> _save() async {
    final slug = _slugController.text.trim();
    final label = _labelController.text.trim();
    if (!_isEdit && slug.isEmpty) {
      _showError(widget.l10n.permissionSetsSlugInvalid);
      return;
    }
    if (label.isEmpty) {
      _showError(widget.l10n.permissionSetsLabelRequired);
      return;
    }
    if (_selected.isEmpty) {
      _showError(widget.l10n.permissionSetsAtLeastOneCapability);
      return;
    }
    if (_inUse) {
      _showError(
        widget.l10n.permissionSetsInUseDetail(
          (widget.existing?['user_count'] as num?)?.toInt() ?? 0,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop(<String, dynamic>{
      'slug': slug,
      'label': label,
      'capabilities': _selected.toList()..sort(),
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _areaLabel(String area) {
    switch (area) {
      case 'wordpress':
        return 'WordPress';
      case 'stock':
        return 'Stock';
      case 'orders':
        return 'Orders';
      case 'suppliers':
        return 'Suppliers';
      case 'purchasing':
        return 'Purchasing';
      case 'people':
        return 'People';
      case 'reports':
        return 'Reports';
      case 'costs':
        return 'Costs';
      case 'roles':
        return 'Roles';
      case 'lots':
        return 'Lots';
      case 'transfers':
        return 'Transfers';
      case 'price_lists':
        return 'Price lists';
      case 'approvals':
        return 'Approvals';
      case 'returns':
        return 'Returns';
      case 'kits':
        return 'Kits';
      case 'products':
        return 'Products';
      case 'documents':
        return 'Documents';
      default:
        return area;
    }
  }

  String _capabilityLabel(String key) {
    // Mirror of the mapping in PermissionSetsScreen, kept local to avoid
    // passing context.l10n through the dialog tree.
    switch (key) {
      case 'read':
        return widget.l10n.capRead;
      case 'edit_products':
        return widget.l10n.capEditProducts;
      case 'edit_shop_orders':
        return widget.l10n.capEditShopOrders;
      case 'mgws_stock_read':
        return widget.l10n.capMgwsStockRead;
      case 'mgws_stock_move':
        return widget.l10n.capMgwsStockMove;
      case 'mgws_order_accept':
        return widget.l10n.capMgwsOrderAccept;
      case 'mgws_supplier_manage':
        return widget.l10n.capMgwsSupplierManage;
      case 'mgws_purchase_approve':
        return widget.l10n.capMgwsPurchaseApprove;
      case 'mgws_manage_employees':
        return widget.l10n.capMgwsManageEmployees;
      case 'mgws_manage_user_permissions':
        return widget.l10n.capMgwsManageUserPermissions;
      case 'mgws_manage_credentials':
        return widget.l10n.capMgwsManageCredentials;
      case 'mgws_reports_read':
        return widget.l10n.capMgwsReportsRead;
      case 'mgws_costs_read':
        return widget.l10n.capMgwsCostsRead;
      case 'mgws_costs_manage':
        return widget.l10n.capMgwsCostsManage;
      case 'mgws_roles_read':
        return widget.l10n.capMgwsRolesRead;
      case 'mgws_roles_manage':
        return widget.l10n.capMgwsRolesManage;
      case 'mgws_lots_manage':
        return widget.l10n.capMgwsLotsManage;
      case 'mgws_transfers_manage':
        return widget.l10n.capMgwsTransfersManage;
      case 'mgws_price_lists_manage':
        return widget.l10n.capMgwsPriceListsManage;
      case 'mgws_approval_rules_manage':
        return widget.l10n.capMgwsApprovalRulesManage;
      case 'mgws_returns_manage':
        return widget.l10n.capMgwsReturnsManage;
      case 'mgws_stock_reset_manage':
        return widget.l10n.capMgwsStockResetManage;
      case 'mgws_count_schedules_manage':
        return widget.l10n.capMgwsCountSchedulesManage;
      case 'mgws_kits_manage':
        return widget.l10n.capMgwsKitsManage;
      case 'mgws_reservations_manage':
        return widget.l10n.capMgwsReservationsManage;
      case 'mgws_shipments_manage':
        return widget.l10n.capMgwsShipmentsManage;
      case 'mgws_product_barcodes_manage':
        return widget.l10n.capMgwsProductBarcodesManage;
      case 'mgws_supplier_prices_manage':
        return widget.l10n.capMgwsSupplierPricesManage;
      case 'mgws_documents_manage':
        return widget.l10n.capMgwsDocumentsManage;
      case 'mgws_payments_manage':
        return widget.l10n.capMgwsPaymentsManage;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedCatalog();
    return AlertDialog(
      title: Text(
        _isEdit
            ? context.l10n.permissionSetsEdit
            : context.l10n.permissionSetsNew,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_inUse)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.l10n.permissionSetsInUse(
                      (widget.existing?['user_count'] as num?)?.toInt() ?? 0,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextField(
                controller: _slugController,
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: context.l10n.permissionSetsSlug,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelController,
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: context.l10n.permissionSetsLabel,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.permissionSetsCapabilities,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final area in grouped.keys) ...[
                Text(
                  _areaLabel(area),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...grouped[area]!.map((entry) {
                  final cap = (entry['capability'] ?? '').toString();
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_capabilityLabel(cap)),
                    value: _selected.contains(cap),
                    onChanged: (_inUse || _saving)
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(cap);
                              } else {
                                _selected.remove(cap);
                              }
                            });
                          },
                  );
                }),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: (_inUse || _saving) ? null : _save,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}
