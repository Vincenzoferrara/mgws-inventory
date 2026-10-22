// inventory_add_products.gui.dart
//
// Pannello "Aggiungi prodotto": unico punto in cui si inseriscono pezzi in
// magazzino.
//
// La modalita' scelta in testa decide solo la documentazione:
//  - [InventoryAddMode.simple] carica e basta
//  - [InventoryAddMode.order] chiede il fornitore e mette a confronto pezzi
//    inseriti e pezzi convalidati prima di confermare

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../products/product_list/product_picker.dart';
import '../settings/inventory_quick_load_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory_add_products.code.dart';
import 'inventory_product_section.gui.dart';
import 'inventory_quick_load.code.dart';
import 'inventory_quick_load_catalog.code.dart';
import 'inventory_quick_load_widgets.gui.dart';
import 'inventory_restock_feedback.code.dart';
import 'inventory_suppliers.code.dart';
import 'inventory_suppliers.gui.dart';

typedef InventoryAddProductsBarcodeLauncher =
    Future<String?> Function(BuildContext context);

/// Numero di documento proposto per l'ordine, calcolato sull'orario corrente.
///
/// Serve a non costringere l'operatore a inventare un codice a mano: resta
/// comunque modificabile nel campo.
String inventoryAddProductsDocumentNumber([DateTime? now]) {
  final value = now ?? DateTime.now();
  String two(int number) => number.toString().padLeft(2, '0');
  final day = '${value.year}${two(value.month)}${two(value.day)}';
  final time = '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  return 'AGG-$day-$time';
}

/// "3 righe · 12 pezzi": due numeri e le due parole che li descrivono.
///
/// Le parole sono le stesse in tutto il modulo, quindi stanno nelle traduzioni
/// e la coppia resta leggibile anche in inglese.
String _righeEPezzi(BuildContext context, int righe, int pezzi) =>
    '${righe} ${context.l10n.inventoryParolaRighe} · '
    '${pezzi} ${context.l10n.inventoryParolaPezzi}';

class InventoryAddProductsPanel extends StatefulWidget {
  const InventoryAddProductsPanel({
    super.key,
    this.controller,
    this.supplierController,
    this.catalogController,
    this.settings,
    this.barcodeLauncher,
    this.detailsController,
    this.siteController,
  });

  final InventoryAddProductsController? controller;
  final InventorySupplierController? supplierController;
  final InventoryQuickLoadCatalogController? catalogController;
  final InventoryQuickLoadSettings? settings;
  final InventoryAddProductsBarcodeLauncher? barcodeLauncher;

  /// Dettagli del movimento, di proprieta' della pagina: il pannello li legge
  /// per costruire il piano e non li tocca.
  final TextEditingController? detailsController;

  /// Sede del movimento, di proprieta' della pagina: il campo sta sopra i
  /// dettagli e vale per tutti i moduli che la usano. Il pannello la legge per
  /// costruire il piano e per caricare i magazzini della sede, e non la
  /// scrive: se la pagina la cambia, il pannello ricarica da solo.
  final TextEditingController? siteController;

  @override
  State<InventoryAddProductsPanel> createState() =>
      _InventoryAddProductsPanelState();
}

class _InventoryAddProductsPanelState extends State<InventoryAddProductsPanel> {
  static const _uuid = Uuid();

  late final InventoryAddProductsController _controller;
  late final InventorySupplierController _supplierController;
  late final InventoryQuickLoadCatalogController _catalogController;
  late final InventoryQuickLoadSettings _settings;
  late final QueryMgwsInventory _mgwsInventory;
  late final bool _ownsCatalog;

  final _documentController = TextEditingController(
    text: inventoryAddProductsDocumentNumber(),
  );

  InventoryAddMode _mode = InventoryAddMode.simple;
  MgwsSupplier? _supplier;
  bool _validated = false;
  List<InventoryQuickLoadLineDraft> _lines = const [];
  String? _warehouse;
  String? _room;
  List<MgwsInventoryWarehouse> _warehouses = const [];
  InventoryActionFeedback? _feedback;
  bool _suppliersLoading = false;

  /// Esito dell'ultimo caricamento fornitori, per non confondere "nessuno
  /// registrato" con "lettura fallita".
  InventoryActionFeedback? _suppliersFeedback;
  bool _masterLoading = false;

  /// true = un pezzo senza chiedere, false = l'operatore dice quanti sono.
  bool _autoAdd = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InventoryAddProductsController();
    _supplierController =
        widget.supplierController ?? InventorySupplierController();
    _ownsCatalog = widget.catalogController == null;
    _catalogController =
        widget.catalogController ?? InventoryQuickLoadCatalogController();
    _mgwsInventory = QueryMgwsInventory();
    _settings = widget.settings ?? inventoryQuickLoadSettings;
    // La sede e' della pagina: quando cambia, i magazzini vanno ricaricati
    // perche' la lista e' quella della sede dichiarata.
    widget.siteController?.addListener(_onSiteChanged);
    _loadSettings();
    _loadMasterData();
  }

  @override
  void dispose() {
    widget.siteController?.removeListener(_onSiteChanged);
    _documentController.dispose();
    if (_ownsCatalog) _catalogController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _settings.init();
    if (!mounted) return;
    setState(() {
      _warehouse = _settings.defaultWarehouse;
      _room = _settings.defaultRoom;
    });
  }

  /// Sede letta dal campo della pagina, o zero se non e' ancora una sede.
  int get _currentSiteId =>
      int.tryParse(widget.siteController?.text.trim() ?? '') ?? 0;

  /// Sede per cui sono stati caricati i magazzini in lista.
  ///
  /// Serve a non ricaricare i magazzini per ogni tasto premuto nel campo
  /// sede: finche' la sede dichiarata non cambia davvero, la lista resta
  /// quella.
  int _warehousesLoadedForSite = 0;

  void _onSiteChanged() {
    if (_currentSiteId == _warehousesLoadedForSite) return;
    unawaited(_reloadWarehouses(_currentSiteId));
  }

  Future<void> _reloadWarehouses(int siteId) async {
    setState(() {
      _warehouse = null;
      _warehouses = const [];
      _feedback = null;
      _masterLoading = true;
    });
    final warehouses = await _mgwsInventory.listWarehouses(
      siteId: siteId > 0 ? siteId : null,
    );
    if (!mounted) return;
    setState(() {
      if (warehouses.success && warehouses.data != null) {
        _warehouses = warehouses.data!;
      }
      _masterLoading = false;
    });
    _warehousesLoadedForSite = siteId;
  }

  Future<void> _loadMasterData() async {
    setState(() => _masterLoading = true);
    final warehouses = await _mgwsInventory.listWarehouses(
      siteId: _currentSiteId > 0 ? _currentSiteId : null,
    );
    if (!mounted) return;
    setState(() {
      if (warehouses.success && warehouses.data != null) {
        _warehouses = warehouses.data!;
      }
      _masterLoading = false;
    });
    _warehousesLoadedForSite = _currentSiteId;
  }

  // ── Modalita' e fornitore ────────────────────────────────────────────

  void _setMode(InventoryAddMode mode) {
    setState(() {
      _mode = mode;
      if (mode != InventoryAddMode.order) _validated = false;
      _feedback = null;
    });
    if (mode == InventoryAddMode.order) _ensureSuppliers();
  }

  /// Carica l'anagrafica fornitori solo quando serve davvero: la modalita'
  /// semplice non usa ordini e non deve pagare una chiamata MGWS.
  ///
  /// Tiene il risultato del caricamento perche' "nessun fornitore
  /// registrato" e "lettura fallita" si risolvono in modi opposti: il primo
  /// compilando un form, il secondo riprovando. Un messaggio unico per i due
  /// casi manderebbe a controllare una connessione che invece funziona.
  Future<void> _ensureSuppliers({bool force = false}) async {
    if (_suppliersLoading) return;
    if (!force && _supplierController.suppliers.isNotEmpty) return;
    setState(() => _suppliersLoading = true);
    final feedback = await _supplierController.load();
    if (!mounted) return;
    setState(() {
      _suppliersLoading = false;
      _suppliersFeedback = feedback;
    });
  }

  /// Crea un fornitore da qui e lo sceglie subito.
  ///
  /// Senza questo l'operatore che non ha ancora registrato fornitori resta
  /// fermo: la modalita' ordine non parte e l'unica uscita e' abbandonare
  /// l'ordine. Il fornitore appena creato e' per definizione quello giusto,
  /// quindi selezionarlo evita un secondo passaggio.
  Future<void> _addSupplierInline() async {
    final saved = await showInventorySupplierForm(
      context,
      controller: _supplierController,
    );
    if (saved != true || !mounted) return;
    final created = _supplierController.lastSupplier;
    if (created == null) return;
    setState(() {
      _supplier = created;
      _suppliersFeedback = null;
    });
  }

  // ── Prodotti e quantita' ────────────────────────────────────────────

  /// "Aggiungi prodotto esistente": apre lo stesso selettore che usa la cassa,
  /// cosi' l'operatore impara una schermata sola e non due.
  ///
  /// La spunta vale anche qui: con la spunta spuntata ogni prodotto scelto
  /// entra con un pezzo, senza spunta l'operatore dice quanti sono.
  Future<void> _openExistingProducts() async {
    final selected = await openProdottoPicker(context);
    if (!mounted || selected == null || selected.isEmpty) return;
    final units = expandSelectedProducts(selected);
    final incoming = <InventoryQuickLoadLineDraft>[];
    for (final unita in units) {
      if (!unita.isValid) continue;
      final quantity = await _quantityFor(unita.label);
      // Annullare la richiesta quantita' su un prodotto non deve far fallire
      // gli altri: si salta questa riga e si va avanti.
      if (quantity == null) continue;
      incoming.add(
        InventoryQuickLoadLineDraft(
          productId: unita.productId,
          variationId: unita.variationId,
          label: unita.label,
          quantity: quantity,
          idempotencyKey: _uuid.v4(),
          barcodeInterno: unita.barcodeInterno.isEmpty
              ? null
              : unita.barcodeInterno,
          imageUrl: unita.imageUrl,
        ),
      );
    }
    if (!mounted) return;
    _mergeLines(incoming);
  }

  /// Quanto mettere per [label]. Con la spunta "aggiungi automaticamente" e'
  /// uno e basta; senza, si chiede: nessuna quantita' viene indovinata.
  /// Null se l'operatore annulla.
  Future<int?> _quantityFor(String label) async {
    if (_autoAdd) return 1;
    return showInventoryQuantityPrompt(context: context, label: label);
  }

  /// Aggiunge righe a quelle gia' presenti sommando le quantita' quando lo
  /// stesso prodotto (o la stessa variante) e' gia' in lista. Aggiungere due
  /// volte lo stesso barcode deve dare 2 pezzi, non due righe da 1.
  void _mergeLines(List<InventoryQuickLoadLineDraft> incoming) {
    if (incoming.isEmpty) return;
    setState(() {
      final merged = List<InventoryQuickLoadLineDraft>.of(_lines);
      for (final line in incoming) {
        final index = merged.indexWhere(
          (item) =>
              item.productId == line.productId &&
              item.variationId == line.variationId,
        );
        if (index < 0) {
          merged.add(line);
        } else {
          merged[index] = merged[index].copyWith(
            quantity: merged[index].quantity + line.quantity,
          );
        }
      }
      _lines = List<InventoryQuickLoadLineDraft>.unmodifiable(merged);
      _feedback = null;
    });
  }

  /// Barcode: come in cassa, il campo risolve il prodotto e lo aggiunge.
  ///
  /// La spunta decide cosa succede dopo. Con la correzione rapida un pezzo e
  /// si continua a scansionare. Senza, la riga entra in lista ma l'operatore
  /// deve indicarne la quantita' prima di confermare: niente da scegliere a
  /// caso, quindi niente stimo.
  ///
  /// Risponde true quando il prodotto e' entrato: e' il segnale che la sezione
  /// condivisa usa per svuotare il campo, cosi' un barcode gia' letto non resta
  /// scritto e non invites a raddoppiare i pezzi.
  Future<bool> _addScannedBarcode(String code) async {
    final match = await _catalogController.ricercaPerBarcode(code);
    if (!mounted) return false;
    if (match == null) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryBarcodeNonTrovatoCatalogo(code),
        ),
      );
      return false;
    }
    if (match.productId <= 0) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryProdottoSenzaIdValido(match.label),
        ),
      );
      return false;
    }
    final quantity = await _quantityFor(match.label);
    if (!mounted || quantity == null) return false;
    _mergeLines([
      match.toLine(idempotencyKey: _uuid.v4()).copyWith(quantity: quantity),
    ]);
    return true;
  }

  void _changeQuantity(InventoryQuickLoadLineDraft line, int quantity) {
    if (quantity <= 0) return;
    setState(() {
      _lines = List<InventoryQuickLoadLineDraft>.unmodifiable([
        for (final item in _lines)
          if (item.key == line.key) item.copyWith(quantity: quantity) else item,
      ]);
      _feedback = null;
    });
  }

  void _removeLine(String key) {
    setState(() {
      _lines = List<InventoryQuickLoadLineDraft>.unmodifiable(
        _lines.where((line) => line.key != key),
      );
      _feedback = null;
    });
  }

  // ── Piano e invio ───────────────────────────────────────────────────

  InventoryAddProductsPlan _plan() {
    return InventoryAddProductsPlan(
      mode: _mode,
      supplier: _supplier,
      validated: _validated,
      siteIdText: widget.siteController?.text ?? '',
      documentNumberText: _documentController.text,
      lines: _lines,
      // I dettagli sono uno solo per tutta la pagina e Aggiungi ha il campo
      // `note` dedicato sul backend: ci vanno dentro come arrivano.
      note: widget.detailsController?.text ?? '',
      warehouseId: _settings.warehouseEnabled
          ? int.tryParse(_warehouse ?? '')
          : null,
      room: _settings.roomEnabled ? _room : null,
    );
  }

  Future<void> _submit() async {
    final plan = _plan();
    final parsed = plan.parse();
    if (parsed case InventoryFormInvalid(:final message)) {
      _showFeedback(InventoryActionFeedback(success: false, message: message));
      return;
    }
    final confirmed = await showInventoryAddProductsConfirmDialog(
      context: context,
      plan: plan,
    );
    if (confirmed != true || !mounted) return;
    final feedback = await _controller.submit(context.l10n, plan);
    if (!mounted) return;
    final retryable = _controller.retryableLines;
    setState(() {
      _feedback = feedback;
      _lines = retryable.isEmpty
          ? const <InventoryQuickLoadLineDraft>[]
          : retryable;
      if (feedback.success) {
        _validated = false;
        _documentController.text = inventoryAddProductsDocumentNumber();
      }
    });
    _snack(feedback.message(context.l10n), success: feedback.success);
  }

  void _showFeedback(InventoryActionFeedback feedback) {
    setState(() => _feedback = feedback);
  }

  void _snack(String message, {required bool success}) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? colors.successColor
            : colors.errorColorStatus,
      ),
    );
  }

  // ── Interfaccia ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-add-products-panel'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.playlist_add_check,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                context.l10n.inventoryAggiungiTitolo,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                context.l10n.inventoryAggiungiSottotitolo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.subtitleColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildModeCard(),
            const SizedBox(height: 10),
            if (_mode == InventoryAddMode.order) ...[
              _buildOrderCard(),
              const SizedBox(height: 10),
            ],
            // La card di posizione serve solo se le impostazioni hanno
            // qualcosa da far scegliere: i dettagli stanno a pagina, quindi
            // una card vuota non avrebbe piu' niente dentro.
            if (_showLocationCard) ...[
              _buildLocationCard(),
              const SizedBox(height: 10),
            ],
            _buildSelectionCard(),
            const SizedBox(height: 10),
            InventoryAddProductsDeltaPanel(plan: _plan()),
            if (_feedback != null) ...[
              const SizedBox(height: 10),
              _buildFeedback(colors),
            ],
            const SizedBox(height: 12),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard() {
    return InventorySectionCard(
      icon: Icons.tune,
      title: context.l10n.inventorySezioneModalitaAggiunta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<InventoryAddMode>(
            key: ValueKey('inventory-add-mode-${_mode.name}'),
            initialValue: _mode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.inventoryEtichettaModalita,
              prefixIcon: const Icon(Icons.playlist_add_check),
            ),
            items: [
              for (final mode in InventoryAddMode.values)
                DropdownMenuItem<InventoryAddMode>(
                  value: mode,
                  child: Text(inventoryAddModeLabel(context.l10n, mode)),
                ),
            ],
            onChanged: (value) {
              if (value != null) _setMode(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            inventoryAddModeDescription(context.l10n, _mode),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Cosa mostrare quando non c'e' un fornitore da scegliere.
  ///
  /// I due casi hanno cause e rimedi opposti, quindi non possono stare sotto
  /// lo stesso testo: se la lettura e' fallita il rimedio e' riprovare, se
  /// l'anagrafica e' vuota il rimedio e' registrarne uno. Confonderli
  /// costringerebbe l'operatore a uscire dall'ordine in entrambi i casi.
  Widget _buildNoSuppliers(AppColorExtension colors) {
    final failed = _suppliersFeedback != null && !_suppliersFeedback!.success;
    return Container(
      key: const ValueKey('inventory-add-no-suppliers'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.priceBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failed
                ? context.l10n.inventoryFornitoriLetturaFallita(
                    _suppliersFeedback!.message(context.l10n),
                  )
                : context.l10n.inventoryFornitoriNessunoRegistrato,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('inventory-add-supplier-empty-action'),
              onPressed: failed
                  ? () => _ensureSuppliers(force: true)
                  : _addSupplierInline,
              icon: Icon(
                failed ? Icons.refresh : Icons.person_add_alt,
                size: 18,
              ),
              label: Text(
                failed
                    ? context.l10n.inventoryRiprova
                    : context.l10n.inventoryAggiungiFornitore,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard() {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final suppliers = _supplierController.suppliers;
    return InventorySectionCard(
      icon: Icons.storefront_outlined,
      title: context.l10n.inventorySezioneFornitoreConvalida,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fornitore e numero documento stanno sulla stessa riga quando
          // c'e' spazio: l'ordine si riconosce dalla coppia, non da uno dei
          // due. Senza spazio si impilano, come stanno su un telefono.
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final supplierArea = _suppliersLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  : suppliers.isEmpty
                  ? _buildNoSuppliers(colors)
                  : DropdownButtonFormField<MgwsSupplier>(
                      key: ValueKey(
                        'inventory-add-supplier-${_supplier?.id ?? 0}-${suppliers.length}',
                      ),
                      initialValue: _supplier,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .inventoryEtichettaFornitoreObbligatorio,
                        prefixIcon: const Icon(Icons.local_shipping_outlined),
                      ),
                      items: [
                        for (final supplier in suppliers)
                          DropdownMenuItem<MgwsSupplier>(
                            value: supplier,
                            child: Text(
                              supplier.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _supplier = value;
                        _feedback = null;
                      }),
                    );
              final documentField = TextField(
                key: const ValueKey('inventory-add-document-field'),
                controller: _documentController,
                decoration: InputDecoration(
                  labelText: context
                      .l10n
                      .inventoryEtichettaNumeroDocumentoObbligatorio,
                  prefixIcon: const Icon(Icons.numbers),
                ),
              );
              if (wide && suppliers.isNotEmpty && !_suppliersLoading) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: supplierArea),
                    const SizedBox(width: 12),
                    SizedBox(width: 260, child: documentField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  supplierArea,
                  const SizedBox(height: 12),
                  documentField,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _ValidatedCheckbox(
            value: _validated,
            supplierLabel: _supplier == null
                ? context.l10n.inventoryFornitoreScelto
                : _supplier!.name,
            onChanged: (value) => setState(() {
              _validated = value;
              _feedback = null;
            }),
          ),
        ],
      ),
    );
  }

  bool get _showLocationCard =>
      _settings.warehouseEnabled || _settings.roomEnabled;

  /// Numera le sezioni in base a quelle davvero mostrate: fornitore e
  /// posizione compaiono solo in certi casi, e un numero fisso saltava da
  /// "1." a "3." quando una delle due era nascosta. Le traduzioni restano le
  /// stesse; qui si sostituisce solo il numero iniziale.
  String _titoloPasso(int numero, String titolo) =>
      titolo.replaceFirst(RegExp(r'^\d+\.\s*'), '$numero. ');

  int get _passoPosizione => _mode == InventoryAddMode.order ? 3 : 2;

  int get _passoProdotti => _passoPosizione + (_showLocationCard ? 1 : 0);

  Widget _buildLocationCard() {
    return InventorySectionCard(
      icon: Icons.location_on_outlined,
      title: _titoloPasso(
        _passoPosizione,
        context.l10n.inventorySezionePosizione2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 540
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_settings.warehouseEnabled)
                SizedBox(
                  width: width,
                  child: _warehouses.isEmpty
                      ? InventoryQuickLoadSelector(
                          keyName: 'inventory-add-warehouse-field',
                          label: context.l10n.inventoryEtichettaMagazzino,
                          icon: Icons.warehouse_outlined,
                          value: _warehouse,
                          options: _settings.warehouseOptions,
                          onChanged: (value) =>
                              setState(() => _warehouse = value),
                        )
                      : DropdownButtonFormField<String>(
                          key: const ValueKey('inventory-add-warehouse-field'),
                          initialValue:
                              _warehouses.any(
                                (warehouse) =>
                                    warehouse.id.toString() == _warehouse,
                              )
                              ? _warehouse
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.inventoryEtichettaMagazzino,
                            prefixIcon: const Icon(Icons.warehouse_outlined),
                            suffixIcon: _masterLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox.square(
                                      dimension: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          items: [
                            for (final warehouse in _warehouses)
                              DropdownMenuItem<String>(
                                value: warehouse.id.toString(),
                                child: Text(warehouse.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _warehouse = value),
                        ),
                ),
              if (_settings.roomEnabled)
                SizedBox(
                  width: width,
                  child: InventoryQuickLoadSelector(
                    keyName: 'inventory-add-room-field',
                    label: context.l10n.inventoryEtichettaStanza,
                    icon: Icons.meeting_room_outlined,
                    value: _room,
                    options: _settings.roomOptions,
                    onChanged: (value) => setState(() => _room = value),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectionCard() {
    return InventoryProductSection(
      icon: Icons.inventory_2_outlined,
      title: _titoloPasso(
        _passoProdotti,
        context.l10n.inventorySezioneProdotti3,
      ),
      keyPrefix: 'inventory-add',
      lines: _lines,
      autoAdd: _autoAdd,
      onAutoAddChanged: (value) => setState(() => _autoAdd = value),
      onBarcodeEntered: _addScannedBarcode,
      onPickExisting: _openExistingProducts,
      onRemoveLine: _removeLine,
      busy: _controller.isSubmitting,
      barcodeLauncher: widget.barcodeLauncher,
      emptyHint: context.l10n.inventoryAggiungiVuotoProdotti,
      trailingBuilder: (context, line) => InventoryInlineQuantity(
        quantity: line.quantity,
        onChanged: (quantity) => _changeQuantity(line, quantity),
      ),
    );
  }

  Widget _buildFeedback(AppColorExtension colors) {
    final feedback = _feedback!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      key: const ValueKey('inventory-add-feedback'),
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
            feedback.message(context.l10n),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final step in _controller.lastSteps)
            Text('· $step', style: Theme.of(context).textTheme.bodySmall),
          for (final detail in feedback.details)
            Text(
              detail(context.l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final plan = _plan();
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        if (_lines.isNotEmpty)
          Text(
            _righeEPezzi(context, plan.lineCount, plan.enteredQuantity),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-add-submit'),
          onPressed: _controller.isSubmitting ? null : _submit,
          icon: _controller.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  plan.isOrder ? Icons.assignment : Icons.playlist_add_check,
                ),
          label: Text(
            _controller.isSubmitting
                ? context.l10n.inventoryInvioInCorso
                : plan.isOrder
                ? plan.validated
                      ? context.l10n.inventoryConvalidaOrdineECarica
                      : context.l10n.inventorySalvaBozzaOrdineECarica
                : context.l10n.inventoryControllaECarica,
          ),
        ),
      ],
    );
  }
}

/// Spunta di convalida con l'anteprima inseriti / convalidati / differenza.
class InventoryAddProductsDeltaPanel extends StatelessWidget {
  const InventoryAddProductsDeltaPanel({super.key, required this.plan});

  final InventoryAddProductsPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final pending = plan.difference;
    final deltaTone = plan.validated
        ? colors.successColor
        : colors.warningColor;
    return Container(
      key: const ValueKey('inventory-add-delta'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // In modalità Semplice non c'è niente da convalidare: il titolo e
          // le voci sulla convalida (sempre 0, "nessuna differenza") non
          // dicevano nulla, restano righe e pezzi inseriti.
          Text(
            plan.isOrder
                ? context.l10n.inventoryTitoloInseritiControConvalida
                : context.l10n.inventoryTitoloRiepilogoCarico,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeltaChip(
                icon: Icons.list_alt,
                label: context.l10n.inventoryEtichettaRighe(plan.lineCount),
              ),
              _DeltaChip(
                key: const ValueKey('inventory-add-entered'),
                icon: Icons.edit_note,
                label: context.l10n.inventoryEtichettaInseriti(
                  plan.enteredQuantity,
                ),
                tone: colors.successColor,
              ),
              if (plan.isOrder) ...[
                _DeltaChip(
                  key: const ValueKey('inventory-add-validated'),
                  icon: Icons.verified_outlined,
                  label: context.l10n.inventoryEtichettaConvalidati(
                    plan.validatedQuantity,
                  ),
                  tone: deltaTone,
                ),
                _DeltaChip(
                  key: const ValueKey('inventory-add-difference'),
                  icon: pending == 0 ? Icons.check_circle : Icons.difference,
                  label: pending == 0
                      ? context.l10n.inventoryNessunaDifferenza
                      : context.l10n.inventoryEtichettaDifferenza(pending),
                  tone: pending == 0
                      ? colors.successColor
                      : colors.warningColor,
                ),
              ],
            ],
          ),
          if (!plan.isOrder) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.inventoryNotaModalitaSemplice,
              style: theme.textTheme.bodySmall,
            ),
          ] else if (!plan.validated) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.inventoryNotaSenzaConvalida(pending),
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.inventoryNotaConConvalida,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone,
  });

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    // Senza un tono esplicito la voce è informativa: nel primario (rosso in
    // questo tema) "Righe: 0" sembrava un errore.
    final color = tone ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ValidatedCheckbox extends StatelessWidget {
  const _ValidatedCheckbox({
    required this.value,
    required this.supplierLabel,
    required this.onChanged,
  });

  final bool value;
  final String supplierLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    final tone = value ? colors.successColor : colors.subtitleColor;
    return InkWell(
      key: const ValueKey('inventory-add-validated'),
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? colors.successColor.withValues(alpha: 0.08)
              : colors.priceBackground.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? colors.successColor.withValues(alpha: 0.40)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.inventoryConvalida,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.l10n.inventoryConvalidaDescrizione(supplierLabel),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riepilogo prima dell'invio: cosa entra in magazzino e, se scelto, a
/// quale ordine e con quanta merce ancora da convalidare.
Future<bool?> showInventoryAddProductsConfirmDialog({
  required BuildContext context,
  required InventoryAddProductsPlan plan,
}) {
  final listHeight = (plan.lineCount * 56.0).clamp(56.0, 260.0);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        plan.isOrder
            ? context.l10n.inventoryConfermaTitoloOrdineECarico
            : context.l10n.inventoryConfermaTitoloCarico,
      ),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _righeEPezzi(context, plan.lineCount, plan.enteredQuantity),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${context.l10n.inventoryEtichettaMotivo} ${context.l10n.inventoryStockInReason}',
            ),
            if (plan.warehouseId != null || (plan.room ?? '').isNotEmpty)
              Text(
                '${context.l10n.inventoryEtichettaPosizione} '
                '${[if (plan.warehouseId != null) '${context.l10n.inventoryAbbreviazioneMagazzino} ${plan.warehouseId}', if ((plan.room ?? '').isNotEmpty) '${context.l10n.inventoryEtichettaStanza} ${plan.room}'].join(' · ')}',
              ),
            if (plan.note.trim().isNotEmpty)
              Text('${context.l10n.inventoryLabelDettagli}: ${plan.note}'),
            if (plan.isOrder) ...[
              const SizedBox(height: 8),
              Text(
                '${context.l10n.inventoryEtichettaFornitore} ${plan.supplierLabel}',
              ),
              Text(
                '${context.l10n.inventoryEtichettaDocumento} '
                '${plan.documentNumberText.trim()}',
              ),
              Text(
                '${context.l10n.inventoryEtichettaConvalida} '
                '${plan.validated ? context.l10n.inventoryConvalidaStatoOrdered : context.l10n.inventoryConvalidaStatoBozza}',
              ),
              Text(
                '${context.l10n.inventoryConvalidatiSu(plan.validatedQuantity)} '
                '${context.l10n.inventoryPezziSuTotale(plan.enteredQuantity)} '
                '${context.l10n.inventoryDifferenzaTraParentesi(plan.difference)}',
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.isOrder
                        ? context.l10n.inventoryNotaConfermaOrdine
                        : context.l10n.inventoryNotaConfermaCarico,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SizedBox(
              height: listHeight,
              child: ListView.separated(
                itemCount: plan.lineCount,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final line = plan.lines[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.label),
                    subtitle: line.barcodeInterno?.trim().isNotEmpty == true
                        ? Text(
                            context.l10n.inventoryBarcodeValore(
                              line.barcodeInterno!,
                            ),
                          )
                        : null,
                    trailing: Text('× ${line.quantity}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-add-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.check),
          label: Text(
            plan.isOrder
                ? context.l10n.inventoryConfermaOrdine
                : context.l10n.inventoryConfermaCarico,
          ),
        ),
      ],
    ),
  );
}
