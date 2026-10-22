import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../login/gui/login.code.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import 'inventory.code.dart';
import '../l10n/extensions.dart';

class InventoryReceiptPanel extends StatefulWidget {
  InventoryReceiptPanel({
    super.key,
    InventoryReceiptController? controller,
    InventoryPurchaseOrderController? purchaseOrderController,
  }) : controller = controller ?? InventoryReceiptController(),
       purchaseOrderController =
           purchaseOrderController ?? InventoryPurchaseOrderController();

  final InventoryReceiptController controller;
  final InventoryPurchaseOrderController purchaseOrderController;

  @override
  State<InventoryReceiptPanel> createState() => _InventoryReceiptPanelState();
}

class _InventoryReceiptPanelState extends State<InventoryReceiptPanel> {
  final _siteController = TextEditingController();
  final _purchaseOrderController = TextEditingController();
  final _receiptController = TextEditingController();
  final _documentController = TextEditingController();
  final _idempotencyController = TextEditingController();
  final _notesController = TextEditingController();
  final _scanController = TextEditingController();
  final _lineController = TextEditingController();
  final _orderedController = TextEditingController();
  final _receivedController = TextEditingController();
  final _rejectedController = TextEditingController(text: '0');
  final _backorderController = TextEditingController(text: '0');
  final _reasonController = TextEditingController();
  final _mgwsInventory = QueryMgwsInventory();
  InventoryActionFeedback? _feedback;
  MgwsPurchaseOrder? _selectedOrder;
  MgwsPurchaseOrderLine? _selectedLine;
  MgwsReceipt? _selectedReceipt;
  bool _loadingOrders = true;
  bool _loadingReceipts = true;
  bool _busy = false;
  bool _masterLoading = false;
  bool _qcHold = false;
  bool _pendingVerification = false;
  List<MgwsInventorySite> _sites = const [];

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
      setState(() => _siteController.text = siteId.toString());
    }
  }

  @override
  void dispose() {
    _siteController.dispose();
    _purchaseOrderController.dispose();
    _receiptController.dispose();
    _documentController.dispose();
    _idempotencyController.dispose();
    _notesController.dispose();
    _scanController.dispose();
    _lineController.dispose();
    _orderedController.dispose();
    _receivedController.dispose();
    _rejectedController.dispose();
    _backorderController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingOrders = true;
      _loadingReceipts = true;
    });
    final orderFeedback = await widget.purchaseOrderController.load(
      const InventoryPurchaseOrderListForm(),
    );
    final receiptFeedback = await widget.controller.load(
      const InventoryReceiptListForm(),
    );
    if (!mounted) return;
    setState(() {
      _loadingOrders = false;
      _loadingReceipts = false;
      _feedback = receiptFeedback.success ? orderFeedback : receiptFeedback;
      if (_selectedOrder == null &&
          widget.purchaseOrderController.purchaseOrders.isNotEmpty) {
        _selectOrder(widget.purchaseOrderController.purchaseOrders.first);
      }
      if (_selectedReceipt == null && widget.controller.receipts.isNotEmpty) {
        _selectReceipt(widget.controller.receipts.first);
      }
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => _masterLoading = true);
    final sites = await _mgwsInventory.listSites();
    if (!mounted) return;
    setState(() {
      if (sites.success && sites.data != null) _sites = sites.data!;
      _masterLoading = false;
    });
  }

  void _selectOrder(MgwsPurchaseOrder order) {
    _selectedOrder = order;
    _purchaseOrderController.text = order.id.toString();
    _siteController.text = order.siteId.toString();
    _documentController.text = 'DDT-${order.documentNumber}';
    _idempotencyController.text = 'receipt-${order.id}-${order.documentNumber}';
    _selectedLine = order.lines.isEmpty ? null : order.lines.first;
    _fillLine(_selectedLine);
  }

  void _selectReceipt(MgwsReceipt receipt) {
    _selectedReceipt = receipt;
    _receiptController.text = receipt.id.toString();
    _pendingVerification = receipt.status == 'pending_verification';
  }

  void _fillLine(MgwsPurchaseOrderLine? line) {
    final remaining = line == null
        ? 0
        : math.max(
            line.orderedQuantity -
                line.receivedQuantity -
                line.cancelledQuantity,
            0,
          );
    _lineController.text = line?.id.toString() ?? '';
    _orderedController.text = remaining == 0 ? '' : remaining.toString();
    _receivedController.text = remaining == 0 ? '' : remaining.toString();
    _rejectedController.text = '0';
    _backorderController.text = '0';
    _reasonController.text = '';
    _qcHold = false;
    _pendingVerification = false;
  }

  void _resolveScan() {
    final order = _selectedOrder;
    final scan = _scanController.text.trim().toLowerCase();
    if (order == null) {
      _setLocalFeedback('Seleziona un ordine fornitore prima dello scan');
      return;
    }
    if (scan.isEmpty) {
      _setLocalFeedback(
        'Inserisci barcode, barcode interno o ID riga da risolvere',
      );
      return;
    }
    for (final line in order.lines) {
      final tokens = [
        line.id.toString(),
        line.productId.toString(),
        line.variationId.toString(),
        line.barcodeFornitore,
        line.barcode,
      ].map((value) => value.toLowerCase());
      if (tokens.contains(scan)) {
        setState(() {
          _selectedLine = line;
          _fillLine(line);
          _feedback = InventoryActionFeedback(
            success: true,
            message: 'Riga ordine risolta da scan',
            details: ['Prodotto #${line.productId}', 'Riga ordine #${line.id}'],
          );
        });
        return;
      }
    }
    _setLocalFeedback('Scan non risolto sulle righe ordine selezionate');
  }

  void _setLocalFeedback(String message) {
    setState(() {
      _feedback = InventoryActionFeedback(success: false, message: message);
    });
  }

  InventoryReceiptForm _form() => InventoryReceiptForm(
    siteIdText: _siteController.text,
    purchaseOrderIdText: _purchaseOrderController.text,
    documentNumberText: _documentController.text,
    idempotencyKeyText: _idempotencyController.text,
    notesText: _notesController.text,
    statusText: _pendingVerification ? 'pending_verification' : '',
    lines: [
      InventoryReceiptLineForm(
        purchaseOrderLineIdText: _lineController.text,
        expectedQuantityText: _orderedController.text,
        receivedQuantityText: _receivedController.text,
        rejectedQuantityText: _rejectedController.text,
        backorderQuantityText: _backorderController.text,
        reasonCodeText: _reasonController.text,
        qcHold: _qcHold,
      ),
    ],
  );

  Future<void> _createReceipt() async {
    await _run(() => widget.controller.create(_form()));
  }

  Future<void> _convalida() async {
    await _run(() => widget.controller.convalida(_receiptController.text));
  }

  Future<void> _run(Future<InventoryActionFeedback> Function() action) async {
    setState(() => _busy = true);
    final feedback = await action();
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _busy = false;
      final receipt = widget.controller.lastReceipt;
      if (receipt != null) {
        _selectReceipt(receipt);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-receipt-panel'),
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
                  Icons.fact_check,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Ricezione / Convalida',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Ricevi DDT su ordine fornitore e applica stock solo con convalida MGWS finale.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _actions(),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              _contextGrids(colors),
              const SizedBox(height: 12),
              _receiptFields(),
              const SizedBox(height: 12),
              _lineFields(),
              const SizedBox(height: 12),
              _summary(colors),
              const SizedBox(height: 12),
              if (_feedback != null) _ReceiptFeedback(feedback: _feedback!),
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
        key: const ValueKey('inventory-receipt-refresh'),
        onPressed: _busy ? null : _load,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.inventoryAggiornaContesto),
      ),
      OutlinedButton.icon(
        key: const ValueKey('inventory-receipt-scan-resolve'),
        onPressed: _busy ? null : _resolveScan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: Text(context.l10n.inventoryRisolviRigaScan),
      ),
      ElevatedButton.icon(
        key: const ValueKey('inventory-receipt-create'),
        onPressed: _busy ? null : _createReceipt,
        icon: const Icon(Icons.playlist_add_check),
        label: Text(context.l10n.inventoryCreaRicezione),
      ),
      OutlinedButton.icon(
        key: const ValueKey('inventory-receipt-convalida'),
        onPressed: _busy ? null : _convalida,
        icon: const Icon(Icons.verified_outlined),
        label: Text(context.l10n.inventoryApprovaCaricaStock),
      ),
    ],
  );

  Widget _contextGrids(AppColorExtension colors) {
    final orders = widget.purchaseOrderController.purchaseOrders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadingOrders)
          const Center(child: CircularProgressIndicator())
        else if (orders.isEmpty)
          _empty(colors, 'Nessun ordine fornitore disponibile per ricezione.')
        else
          SizedBox(height: 170, child: _orderGrid()),
        const SizedBox(height: 12),
        if (_selectedOrder != null)
          SizedBox(height: 160, child: _lineGrid())
        else
          _empty(colors, 'Seleziona un ordine per vedere le righe ricevivili.'),
        const SizedBox(height: 12),
        if (_loadingReceipts)
          const Center(child: LinearProgressIndicator())
        else if (widget.controller.receipts.isEmpty)
          _empty(colors, 'Nessuna ricezione MGWS trovata.')
        else
          SizedBox(height: 150, child: _receiptGrid()),
      ],
    );
  }

  Widget _orderGrid() => DataGridView<MgwsPurchaseOrder>(
    columns: const [
      DataGridViewColumn(id: 'doc', label: 'Ordine', width: 150),
      DataGridViewColumn(id: 'supplier', label: 'Fornitore', width: 120),
      DataGridViewColumn(id: 'status', label: 'Stato', width: 110),
      DataGridViewColumn(id: 'lines', label: 'Righe', width: 80, numeric: true),
    ],
    rows: [
      for (final order in widget.purchaseOrderController.purchaseOrders)
        _orderRow(order),
    ],
    selectedRowId: _selectedOrder?.id.toString(),
    onRowSelected: (order) => setState(() => _selectOrder(order)),
    onRowDoubleTap: (order) => setState(() => _selectOrder(order)),
  );

  DataGridViewRowData<MgwsPurchaseOrder> _orderRow(MgwsPurchaseOrder order) {
    return DataGridViewRowData(
      id: order.id.toString(),
      value: order,
      cells: {
        'doc': Text(order.documentNumber),
        'supplier': Text('#${order.supplierId}'),
        'status': Text(order.status),
        'lines': Text('${order.lines.length}'),
      },
    );
  }

  Widget _lineGrid() => DataGridView<MgwsPurchaseOrderLine>(
    columns: const [
      DataGridViewColumn(id: 'line', label: 'Riga', width: 70, numeric: true),
      DataGridViewColumn(id: 'scan', label: 'Scan', width: 170),
      DataGridViewColumn(
        id: 'ordered',
        label: 'Ordinata',
        width: 100,
        numeric: true,
      ),
      DataGridViewColumn(
        id: 'received',
        label: 'Gia ricevuta',
        width: 120,
        numeric: true,
      ),
    ],
    rows: [
      for (final line in _selectedOrder?.lines ?? const []) _lineRow(line),
    ],
    selectedRowId: _selectedLine?.id.toString(),
    onRowSelected: (line) => setState(() {
      _selectedLine = line;
      _fillLine(line);
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
        'scan': Text(
          line.barcode.isEmpty ? line.barcodeFornitore : line.barcode,
        ),
        'ordered': Text('${line.orderedQuantity}'),
        'received': Text('${line.receivedQuantity}'),
      },
    );
  }

  Widget _receiptGrid() => DataGridView<MgwsReceipt>(
    columns: const [
      DataGridViewColumn(
        id: 'id',
        label: 'Ricezione',
        width: 110,
        numeric: true,
      ),
      DataGridViewColumn(id: 'doc', label: 'Documento', width: 150),
      DataGridViewColumn(id: 'status', label: 'Stato', width: 120),
      DataGridViewColumn(id: 'lines', label: 'Righe', width: 80, numeric: true),
    ],
    rows: [
      for (final receipt in widget.controller.receipts) _receiptRow(receipt),
    ],
    selectedRowId: _selectedReceipt?.id.toString(),
    onRowSelected: (receipt) => setState(() => _selectReceipt(receipt)),
  );

  DataGridViewRowData<MgwsReceipt> _receiptRow(MgwsReceipt receipt) {
    return DataGridViewRowData(
      id: receipt.id.toString(),
      value: receipt,
      cells: {
        'id': Text('#${receipt.id}'),
        'doc': Text(receipt.documentNumber),
        'status': Chip(
          label: Text(receipt.status),
          side: BorderSide(color: _receiptTone(receipt.status)),
        ),
        'lines': Text('${receipt.lines.length}'),
      },
    );
  }

  Widget _receiptFields() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _siteField(),
      _field(
        _purchaseOrderController,
        'Purchase order ID *',
        'inventory-receipt-po-field',
      ),
      _field(_receiptController, 'Receipt ID', 'inventory-receipt-id-field'),
      _field(
        _documentController,
        'DDT / documento *',
        'inventory-receipt-document-field',
      ),
      _field(
        _idempotencyController,
        'Idempotency key',
        'inventory-receipt-idempotency-field',
      ),
      _field(
        _notesController,
        'Note ricezione',
        'inventory-receipt-notes-field',
      ),
      _field(
        _scanController,
        'Scan barcode, barcode interno o ID riga',
        'inventory-receipt-scan-field',
      ),
      SizedBox(
        width: 260,
        child: CheckboxListTile(
          key: const ValueKey('inventory-receipt-pending-verification-field'),
          value: _pendingVerification,
          onChanged: (value) =>
              setState(() => _pendingVerification = value ?? false),
          title: Text(context.l10n.inventoryRichiedeVerificaManager),
          subtitle: Text(context.l10n.inventoryNonCaricaStockFinche),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );

  Widget _siteField() {
    final current = int.tryParse(_siteController.text.trim());
    if (_sites.isEmpty) {
      return _field(_siteController, 'Sede *', 'inventory-receipt-site-field');
    }
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<int>(
        key: const ValueKey('inventory-receipt-site-field'),
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
        onChanged: (value) =>
            setState(() => _siteController.text = value?.toString() ?? ''),
      ),
    );
  }

  Widget _lineFields() => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      _field(
        _lineController,
        'Riga ordine ID *',
        'inventory-receipt-line-id-field',
      ),
      _field(
        _orderedController,
        'Quantita ordinata *',
        'inventory-receipt-ordered-field',
      ),
      _field(
        _receivedController,
        'Quantita ricevuta *',
        'inventory-receipt-received-field',
      ),
      _field(
        _rejectedController,
        'Quantita scartata',
        'inventory-receipt-rejected-field',
      ),
      _field(
        _backorderController,
        'Quantita backorder',
        'inventory-receipt-backorder-field',
      ),
      SizedBox(
        width: 210,
        child: CheckboxListTile(
          key: const ValueKey('inventory-receipt-qc-hold-field'),
          value: _qcHold,
          onChanged: (value) => setState(() => _qcHold = value ?? false),
          title: Text(context.l10n.inventoryQCHold),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      _field(
        _reasonController,
        'Motivo QC/scarto/backorder',
        'inventory-receipt-reason-field',
      ),
    ],
  );

  Widget _summary(AppColorExtension colors) {
    final receipt = widget.controller.lastReceipt ?? _selectedReceipt;
    if (receipt == null) {
      return _empty(
        colors,
        'Convalida/post summary: nessuna ricezione selezionata o creata.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.priceBackground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Convalida/post summary: ricezione #${receipt.id} ${receipt.status}, '
        '${receipt.lines.length} righe, stock applicato solo dopo convalida MGWS.',
      ),
    );
  }

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

  Widget _empty(AppColorExtension colors, String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.priceBackground.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message),
  );

  Color _receiptTone(String status) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    return status == 'posted'
        ? colors.successColor
        : status == 'pending_verification'
        ? colors.warningColor
        : status == 'cancelled'
        ? colors.errorColorStatus
        : colors.subtitleColor;
  }
}

class _ReceiptFeedback extends StatelessWidget {
  const _ReceiptFeedback({required this.feedback});
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
