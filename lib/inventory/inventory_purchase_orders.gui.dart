import 'package:flutter/material.dart';

import '../login/gui/login.code.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import 'inventory.code.dart';
import '../l10n/extensions.dart';

class InventoryPurchaseOrderPanel extends StatefulWidget {
  InventoryPurchaseOrderPanel({
    super.key,
    InventoryPurchaseOrderController? controller,
  }) : controller = controller ?? InventoryPurchaseOrderController();

  final InventoryPurchaseOrderController controller;

  @override
  State<InventoryPurchaseOrderPanel> createState() =>
      _InventoryPurchaseOrderPanelState();
}

class _InventoryPurchaseOrderPanelState
    extends State<InventoryPurchaseOrderPanel> {
  final _siteController = TextEditingController();
  final _supplierController = TextEditingController();
  final _documentController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _expectedController = TextEditingController();
  final _currencyController = TextEditingController(text: 'EUR');
  final _notesController = TextEditingController();
  final _lineProductController = TextEditingController();
  final _lineVariationController = TextEditingController();
  final _lineQuantityController = TextEditingController();
  final _lineCostController = TextEditingController();
  final _mgwsInventory = QueryMgwsInventory();
  InventoryActionFeedback? _feedback;
  MgwsPurchaseOrder? _selected;
  MgwsPurchaseOrderLine? _selectedLine;
  List<MgwsInventorySite> _sites = const [];
  List<MgwsInventoryWarehouse> _warehouses = const [];
  bool _loading = true;
  bool _masterLoading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOperatorSite());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMasterData());
  }

  Future<void> _loadOperatorSite() async {
    final profile = await loginCode.currentUserProfile();
    if (!mounted) return;
    final siteId = profile?.defaultSiteId ?? 0;
    if (siteId > 0 && _siteController.text.trim().isEmpty) {
      _siteController.text = siteId.toString();
      await _loadMasterData();
    }
  }

  @override
  void dispose() {
    _siteController.dispose();
    _supplierController.dispose();
    _documentController.dispose();
    _warehouseController.dispose();
    _expectedController.dispose();
    _currencyController.dispose();
    _notesController.dispose();
    _lineProductController.dispose();
    _lineVariationController.dispose();
    _lineQuantityController.dispose();
    _lineCostController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final feedback = await widget.controller.load(
      const InventoryPurchaseOrderListForm(),
    );
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
      if (_selected == null && widget.controller.purchaseOrders.isNotEmpty) {
        _select(widget.controller.purchaseOrders.first);
      }
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => _masterLoading = true);
    final sites = await _mgwsInventory.listSites();
    final siteId = int.tryParse(_siteController.text.trim()) ?? 0;
    final warehouses = await _mgwsInventory.listWarehouses(
      siteId: siteId > 0 ? siteId : null,
    );
    if (!mounted) return;
    setState(() {
      if (sites.success && sites.data != null) _sites = sites.data!;
      if (warehouses.success && warehouses.data != null) {
        _warehouses = warehouses.data!;
      }
      _masterLoading = false;
    });
  }

  Future<void> _changeSite(int siteId) async {
    setState(() {
      _siteController.text = siteId.toString();
      _warehouseController.clear();
      _warehouses = const [];
      _masterLoading = true;
    });
    final warehouses = await _mgwsInventory.listWarehouses(siteId: siteId);
    if (!mounted) return;
    setState(() {
      if (warehouses.success && warehouses.data != null) {
        _warehouses = warehouses.data!;
      }
      _masterLoading = false;
    });
  }

  void _select(MgwsPurchaseOrder order) {
    _selected = order;
    _siteController.text = order.siteId.toString();
    _supplierController.text = order.supplierId.toString();
    _documentController.text = order.documentNumber;
    _warehouseController.text = order.warehouseId.toString();
    _expectedController.text = order.expectedAtGmt ?? '';
    _currencyController.text = order.currency;
    _notesController.text = order.notes;
    _selectedLine = order.lines.isEmpty ? null : order.lines.first;
    _fillLine(_selectedLine, order.id);
  }

  Future<void> _loadDetail(MgwsPurchaseOrder order) async {
    final feedback = await widget.controller.get(order.id.toString());
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      if (widget.controller.lastPurchaseOrder != null) {
        _select(widget.controller.lastPurchaseOrder!);
      }
    });
  }

  void _selectFromGrid(MgwsPurchaseOrder order) {
    setState(() => _select(order));
    _loadDetail(order);
  }

  void _fillLine(MgwsPurchaseOrderLine? line, int orderId) {
    _lineProductController.text = line?.productId.toString() ?? '';
    _lineVariationController.text = line?.variationId.toString() ?? '';
    _lineQuantityController.text = line?.orderedQuantity.toString() ?? '';
    _lineCostController.text = line?.unitCost ?? '';
  }

  InventoryPurchaseOrderForm _form() => InventoryPurchaseOrderForm(
    siteIdText: _siteController.text,
    supplierIdText: _supplierController.text,
    documentNumberText: _documentController.text,
    warehouseIdText: _warehouseController.text,
    expectedAtGmtText: _expectedController.text,
    currencyText: _currencyController.text,
    notesText: _notesController.text,
  );

  Future<void> _createDraft() async {
    await _run(() => widget.controller.createDraft(_form()));
  }

  Future<void> _updateDraft() async {
    final selected = _selected;
    if (selected == null) return;
    await _run(
      () => widget.controller.updateDraft(
        purchaseOrderIdText: selected.id.toString(),
        form: _form(),
      ),
    );
  }

  Future<void> _saveLine() async {
    final selected = _selected;
    if (selected == null) return;
    await _run(
      () => widget.controller.saveLine(
        InventoryPurchaseOrderLineForm(
          purchaseOrderIdText: selected.id.toString(),
          productIdText: _lineProductController.text,
          variationIdText: _lineVariationController.text,
          orderedQuantityText: _lineQuantityController.text,
          unitCostText: _lineCostController.text,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final selected = _selected;
    if (selected == null) return;
    await _run(() => widget.controller.cancel(selected.id.toString()));
  }

  Future<void> _verify() async {
    final selected = _selected;
    if (selected == null) return;
    await _run(() => widget.controller.verify(selected.id.toString()));
  }

  Future<void> _run(Future<InventoryActionFeedback> Function() action) async {
    setState(() => _busy = true);
    final feedback = await action();
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _busy = false;
      if (widget.controller.lastPurchaseOrder != null) {
        _select(widget.controller.lastPurchaseOrder!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-purchase-orders-panel'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.assignment,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Ordini fornitore',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Bozze, righe varianti e stati ordine MGWS; la ricezione resta nel workflow dedicato.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _actions(),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (widget.controller.purchaseOrders.isEmpty)
                _empty(colors)
              else
                SizedBox(height: 230, child: _orderGrid()),
              const SizedBox(height: 12),
              _headerForm(),
              const SizedBox(height: 12),
              if (_selected != null) SizedBox(height: 190, child: _lineGrid()),
              const SizedBox(height: 12),
              _lineForm(),
              const SizedBox(height: 12),
              if (_feedback != null) _PoFeedback(feedback: _feedback!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      OutlinedButton.icon(
        onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.inventoryAggiornaOrdini),
      ),
      ElevatedButton.icon(
        key: const ValueKey('inventory-po-create'),
        onPressed: _busy ? null : _createDraft,
        icon: const Icon(Icons.note_add_outlined),
        label: Text(context.l10n.inventoryCreaBozza),
      ),
      OutlinedButton.icon(
        key: const ValueKey('inventory-po-update-save'),
        onPressed: _selected == null || _busy ? null : _updateDraft,
        icon: const Icon(Icons.save_outlined),
        label: Text(context.l10n.inventorySalvaBozza),
      ),
      OutlinedButton.icon(
        key: const ValueKey('inventory-po-status-cancel'),
        onPressed: _selected == null || _busy ? null : _cancel,
        icon: const Icon(Icons.cancel_outlined),
        label: Text(context.l10n.inventoryAnnullaOrdine),
      ),
      FilledButton.icon(
        key: const ValueKey('inventory-po-verify'),
        onPressed: _selected == null || _busy ? null : _verify,
        icon: const Icon(Icons.verified_outlined),
        label: Text(context.l10n.inventoryVerificaApprova),
      ),
    ],
  );

  Widget _orderGrid() => DataGridView<MgwsPurchaseOrder>(
    columns: const [
      DataGridViewColumn(id: 'doc', label: 'Documento', width: 150),
      DataGridViewColumn(id: 'supplier', label: 'Fornitore', width: 120),
      DataGridViewColumn(id: 'status', label: 'Stato', width: 110),
      DataGridViewColumn(id: 'expected', label: 'Previsto', width: 190),
      DataGridViewColumn(id: 'lines', label: 'Righe', width: 80, numeric: true),
    ],
    rows: [
      for (final order in widget.controller.purchaseOrders) _orderRow(order),
    ],
    selectedRowId: _selected?.id.toString(),
    onRowSelected: _selectFromGrid,
    onRowDoubleTap: _selectFromGrid,
  );

  DataGridViewRowData<MgwsPurchaseOrder> _orderRow(MgwsPurchaseOrder order) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final tone = order.status == 'draft' || order.status == 'pending'
        ? colors.warningColor
        : order.status == 'cancelled'
        ? colors.errorColorStatus
        : colors.successColor;
    return DataGridViewRowData(
      id: order.id.toString(),
      value: order,
      cells: {
        'doc': Text(order.documentNumber),
        'supplier': Text('#${order.supplierId}'),
        'status': Chip(
          label: Text(order.status),
          side: BorderSide(color: tone),
        ),
        'expected': Text(order.expectedAtGmt ?? '-'),
        'lines': Text('${order.lines.length}'),
      },
    );
  }

  Widget _headerForm() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _siteField(),
      _field(
        _supplierController,
        'Supplier ID *',
        'inventory-po-supplier-field',
      ),
      _field(_documentController, 'Documento *', 'inventory-po-document-field'),
      _warehouseField(),
      _field(
        _expectedController,
        'Data prevista',
        'inventory-po-expected-field',
      ),
      _field(_currencyController, 'Valuta', 'inventory-po-currency-field'),
      _field(_notesController, 'Note', 'inventory-po-notes-field'),
    ],
  );

  Widget _siteField() {
    final current = int.tryParse(_siteController.text.trim());
    if (_sites.isEmpty) {
      return _field(_siteController, 'Sede *', 'inventory-po-site-field');
    }
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<int>(
        key: const ValueKey('inventory-po-site-field'),
        initialValue: _sites.any((site) => site.id == current) ? current : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.l10n.inventoryLabelSede,
          suffixIcon: _masterLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        items: [
          for (final site in _sites)
            DropdownMenuItem<int>(value: site.id, child: Text(site.name)),
        ],
        onChanged: (value) {
          if (value != null) _changeSite(value);
        },
      ),
    );
  }

  Widget _warehouseField() {
    final current = int.tryParse(_warehouseController.text.trim());
    if (_warehouses.isEmpty) {
      return _field(
        _warehouseController,
        'Magazzino ID',
        'inventory-po-warehouse-field',
      );
    }
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<int>(
        key: const ValueKey('inventory-po-warehouse-field'),
        initialValue: _warehouses.any((w) => w.id == current) ? current : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.l10n.inventoryEtichettaMagazzino,
        ),
        items: [
          for (final warehouse in _warehouses)
            DropdownMenuItem<int>(
              value: warehouse.id,
              child: Text(warehouse.name),
            ),
        ],
        onChanged: (value) =>
            setState(() => _warehouseController.text = value?.toString() ?? ''),
      ),
    );
  }

  Widget _lineGrid() => DataGridView<MgwsPurchaseOrderLine>(
    columns: const [
      DataGridViewColumn(id: 'line', label: 'Riga', width: 80, numeric: true),
      DataGridViewColumn(id: 'product', label: 'Prodotto/Variante', width: 220),
      DataGridViewColumn(id: 'qty', label: 'Qta', width: 90, numeric: true),
      DataGridViewColumn(
        id: 'received',
        label: 'Ricevuto',
        width: 100,
        numeric: true,
      ),
      DataGridViewColumn(id: 'cost', label: 'Costo', width: 100, numeric: true),
      DataGridViewColumn(id: 'effect', label: 'Effetto stock', width: 160),
    ],
    rows: [for (final line in _selected?.lines ?? const []) _lineRow(line)],
    selectedRowId: _selectedLine?.id.toString(),
    onRowSelected: (line) => setState(() {
      _selectedLine = line;
      _fillLine(line, line.purchaseOrderId);
    }),
  );

  DataGridViewRowData<MgwsPurchaseOrderLine> _lineRow(
    MgwsPurchaseOrderLine line,
  ) {
    return DataGridViewRowData(
      id: line.id.toString(),
      value: line,
      cells: {
        'line': Text('${line.lineNumber}'),
        'product': Text(
          'Prodotto #${line.productId} / Variante ${line.variationId}',
        ),
        'qty': Text('${line.orderedQuantity}'),
        'received': Text('${line.receivedQuantity}'),
        'cost': Text(line.unitCost),
        'effect': Text(line.stockEffect),
      },
    );
  }

  Widget _lineForm() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _field(
        _lineProductController,
        '${context.l10n.inventoryEtichettaProductId} *',
        'inventory-po-line-product-field',
      ),
      _field(
        _lineVariationController,
        context.l10n.inventoryEtichettaVariationId,
        'inventory-po-line-variation-field',
      ),
      _field(
        _lineQuantityController,
        'Quantita *',
        'inventory-po-line-quantity-field',
      ),
      _field(_lineCostController, 'Costo *', 'inventory-po-line-cost-field'),
      ElevatedButton.icon(
        key: const ValueKey('inventory-po-line-save'),
        onPressed: _selected == null || _busy ? null : _saveLine,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(context.l10n.inventorySalvaRiga),
      ),
    ],
  );

  Widget _field(TextEditingController controller, String label, String key) {
    return SizedBox(
      width: 210,
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _empty(AppColorExtension colors) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.priceBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(context.l10n.inventoryNessunOrdineFornitore),
  );
}

class _PoFeedback extends StatelessWidget {
  const _PoFeedback({required this.feedback});
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
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.message,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final detail in feedback.details)
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
