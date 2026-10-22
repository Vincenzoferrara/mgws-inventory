import 'package:flutter/material.dart';

import '../login/gui/login.code.dart';
import '../login/mgws/query/query_mgws_inventory.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';
import 'inventory_counts_forms.gui.dart';
import 'inventory_counts_grids.gui.dart';

class InventoryCountPanel extends StatefulWidget {
  InventoryCountPanel({super.key, InventoryCountSessionController? controller})
    : controller = controller ?? InventoryCountSessionController();

  final InventoryCountSessionController controller;

  @override
  State<InventoryCountPanel> createState() => _InventoryCountPanelState();
}

class _InventoryCountPanelState extends State<InventoryCountPanel> {
  final _filterSiteController = TextEditingController();
  final _filterWarehouseController = TextEditingController();
  final _siteController = TextEditingController();
  final _warehouseController = TextEditingController();
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();
  final _sessionController = TextEditingController();
  final _productController = TextEditingController();
  final _variationController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _tagController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController(text: 'physical_count');
  InventoryActionFeedback? _feedback;
  MgwsCountSession? _selected;
  List<MgwsCountLine> _lines = const [];
  bool _loading = true;
  bool _busy = false;

  bool get _posted => _selected?.status.toLowerCase() == 'posted';
  List<MgwsCountLine> get _discrepancies => [
    for (final line in _lines)
      if (line.discrepancyQuantity != 0) line,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOperatorSite());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
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
    for (final controller in [
      _filterSiteController,
      _filterWarehouseController,
      _siteController,
      _warehouseController,
      _documentController,
      _notesController,
      _sessionController,
      _productController,
      _variationController,
      _barcodeController,
      _tagController,
      _quantityController,
      _reasonController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final feedback = await widget.controller.loadSessions(
      siteIdText: _filterSiteController.text,
      warehouseIdText: _filterWarehouseController.text,
    );
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
      if (_selected == null && widget.controller.sessions.isNotEmpty) {
        _select(widget.controller.sessions.first);
      }
    });
  }

  void _select(MgwsCountSession session) {
    _selected = session;
    _lines = session.lines;
    _sessionController.text = session.id.toString();
    _siteController.text = session.siteId.toString();
    _warehouseController.text = session.warehouseId.toString();
    _documentController.text = session.documentNumber;
    _notesController.text = session.notes;
  }

  Future<void> _create() async {
    await _run(() => widget.controller.create(_sessionForm()));
    final session = widget.controller.activeSession;
    if (session != null) setState(() => _select(session));
  }

  Future<void> _saveLine() async {
    if (_posted) {
      setState(() {
        _feedback = const InventoryActionFeedback(
          success: false,
          message: 'Sessione di conteggio gia registrata',
        );
      });
      return;
    }
    await _run(() => widget.controller.saveLine(_lineForm()));
    final line = widget.controller.lastCountLine;
    if (line != null && widget.controller.lastFeedback?.success == true) {
      setState(() => _lines = _upsertLine(_lines, line));
    }
  }

  Future<void> _approve() async {
    await _run(() => widget.controller.approve(_sessionController.text));
    final session = widget.controller.activeSession;
    if (session != null) setState(() => _select(session));
  }

  Future<void> _run(Future<InventoryActionFeedback> Function() action) async {
    setState(() => _busy = true);
    final feedback = await action();
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _busy = false;
    });
  }

  InventoryCountSessionForm _sessionForm() => InventoryCountSessionForm(
    siteIdText: _siteController.text,
    warehouseIdText: _warehouseController.text,
    documentNumberText: _documentController.text,
    notesText: _notesController.text,
  );

  InventoryCountLineForm _lineForm() => InventoryCountLineForm(
    sessionIdText: _sessionController.text,
    productIdText: _productController.text,
    variationIdText: _variationController.text,
    barcodeText: _barcodeController.text,
    tagText: _tagController.text,
    physicalQuantityText: _quantityController.text,
    warehouseIdText: _warehouseController.text,
    reasonCodeText: _reasonController.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-count-panel'),
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
                  Icons.inventory,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Inventario fisico MGWS',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Conta fisica stock-neutral fino ad approvazione: barcode e tag sono risolti da MGWS.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InventoryCountFilters(
                siteController: _filterSiteController,
                warehouseController: _filterWarehouseController,
                loading: _loading,
                onRefresh: _loadSessions,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (widget.controller.sessions.isEmpty)
                const InventoryCountEmptyState()
              else
                SizedBox(
                  height: 210,
                  child: InventoryCountSessionsGrid(
                    sessions: widget.controller.sessions,
                    selected: _selected,
                    onSelected: (session) => setState(() => _select(session)),
                  ),
                ),
              const SizedBox(height: 12),
              InventoryCountSessionFields(
                siteController: _siteController,
                warehouseController: _warehouseController,
                documentController: _documentController,
                notesController: _notesController,
                busy: _busy,
                hasSelection: _selected != null,
                posted: _posted,
                onCreate: _create,
                onApprove: _approve,
              ),
              const SizedBox(height: 12),
              InventoryCountLineFields(
                sessionController: _sessionController,
                productController: _productController,
                variationController: _variationController,
                barcodeController: _barcodeController,
                tagController: _tagController,
                quantityController: _quantityController,
                reasonController: _reasonController,
                busy: _busy,
                onSave: _saveLine,
              ),
              const SizedBox(height: 12),
              if (_posted) const InventoryCountReadOnlyBanner(),
              if (_posted) const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: InventoryCountLinesGrid(lines: _lines),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.inventoryDiscrepanze,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: InventoryCountLinesGrid(lines: _discrepancies),
              ),
              const SizedBox(height: 12),
              if (_feedback != null)
                InventoryCountFeedbackPanel(feedback: _feedback!),
            ],
          ),
        ),
      ),
    );
  }
}

List<MgwsCountLine> _upsertLine(List<MgwsCountLine> lines, MgwsCountLine line) {
  final next = [
    for (final current in lines)
      if (current.id != line.id) current,
  ];
  return [...next, line];
}
