// inventory_move.gui.dart
//
// Pannello "Sposta": trasferisce pezzi da una sede/magazzino a un altro.
//
// La scelta dei prodotti e' la stessa sezione di Aggiungi e Rettifica: si
// scansiona il barcode o si prende dal catalogo. Poi ogni prodotto ha la sua
// rotta, perche' due prodotti possono stare in magazzini diversi.
//
// Punto chiave: lo spostamento NON cambia lo stock totale. Il magazzino di
// partenza perde i pezzi, quello di arrivo li guadagna, e il pannello lo
// dice sempre prima di confermare.

import 'package:flutter/material.dart';

import '../products/product_list/product_picker.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview.gui.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory_move.code.dart';
import 'inventory_module.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_product_section.gui.dart';
import 'inventory_quick_load.code.dart';
import 'inventory_quick_load_catalog.code.dart';
import 'inventory_restock_feedback.code.dart';
import 'inventory_adjustment.code.dart';

class InventoryMovePanel extends StatefulWidget {
  const InventoryMovePanel({
    super.key,
    this.controller,
    this.catalogController,
    this.barcodeLauncher,
    this.detailsController,
    this.seed,
  });

  final InventoryMoveController? controller;
  final InventoryQuickLoadCatalogController? catalogController;
  final InventoryProductSectionBarcodeLauncher? barcodeLauncher;

  /// Dettagli del movimento, di proprieta' della pagina: il pannello li legge
  /// per costruire il piano e non li tocca.
  final TextEditingController? detailsController;

  /// Spostamento del ledger da riaprire, se l'operatore e' arrivato qui da
  /// "Modifica".
  final InventoryPanelSeed? seed;

  @override
  State<InventoryMovePanel> createState() => _InventoryMovePanelState();
}

/// Stato di una riga di spostamento: rotta e pezzi di un solo prodotto.
class _MoveRow {
  _MoveRow({
    required this.productId,
    required this.variationId,
    required this.label,
    this.imageUrl,
    this.barcodeInterno,
  });

  final int productId;
  final int variationId;
  final String label;
  final String? imageUrl;
  final String? barcodeInterno;

  InventoryStockSnapshot? snapshot;

  /// Indice nell'elenco [availableLevels] del magazzino di partenza.
  int? sourceIndex;
  final toSiteController = TextEditingController();
  final toWarehouseController = TextEditingController();

  /// Un solo controller per la quantita': il campo viene ricostruito a ogni
  /// build della sezione, quindi crearlo qui dentro perderebbe il cursore a
  /// meta' digitazione e accumulerebbe controller morti.
  final quantityController = TextEditingController();
  int quantity = 1;
  bool loading = false;
  bool showLocations = false;
  String? loadError;

  String get key => '$productId:$variationId';

  List<InventoryStockLevel> get availableLevels =>
      snapshot?.levels.where((level) => level.qty > 0).toList() ??
      const <InventoryStockLevel>[];

  InventoryStockLevel? get source {
    final levels = availableLevels;
    final index = sourceIndex;
    if (index == null || index < 0 || index >= levels.length) return null;
    return levels[index];
  }

  void dispose() {
    toSiteController.dispose();
    toWarehouseController.dispose();
    quantityController.dispose();
  }

  /// Scrive [quantity] nel campo. Serve solo quando la quantita' cambia fuori
  /// dal campo stesso (tasti +, cambio di magazzino), cosi' testo e stato non
  /// si contraddicono.
  void syncQuantityField() {
    final text = '$quantity';
    if (quantityController.text == text) return;
    quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Riparte dal primo magazzino con pezzi: altrimenti la selezione
  /// punterebbe a una riga che non esiste piu'.
  void resetRoute() {
    sourceIndex = availableLevels.isEmpty ? null : 0;
    quantity = 1;
    syncQuantityField();
  }

  InventoryQuickLoadLineDraft toLine() {
    return InventoryQuickLoadLineDraft(
      productId: productId,
      variationId: variationId,
      label: label,
      imageUrl: imageUrl,
      barcodeInterno: barcodeInterno,
      quantity: quantity,
      idempotencyKey: key,
    );
  }

  InventoryMoveLine toPlanLine() {
    return InventoryMoveLine(
      productId: productId,
      variationId: variationId,
      label: label,
      snapshot: snapshot,
      source: source,
      destinationSiteIdText: toSiteController.text,
      destinationWarehouseIdText: toWarehouseController.text,
      quantity: quantity,
    );
  }
}

class _InventoryMovePanelState extends State<InventoryMovePanel> {
  late final InventoryMoveController _controller;
  late final InventoryQuickLoadCatalogController? _catalogController;

  final _rows = <_MoveRow>[];

  bool _autoAdd = true;
  bool _ready = false;
  int? _appliedSeedStamp;
  InventoryActionFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InventoryMoveController();
    _catalogController = widget.catalogController;
    final seeded = _controller.lastSnapshot;
    if (seeded != null && seeded.productId > 0) {
      _rows.add(
        _MoveRow(
          productId: seeded.productId,
          variationId: seeded.variationId,
          label: seeded.label,
        )..snapshot = seeded,
      );
    }
    _ready = true;
    _applySeed(widget.seed);
  }

  @override
  void didUpdateWidget(InventoryMovePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySeed(widget.seed);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Scelta dei prodotti ───────────────────────────────────────────

  /// Riapre uno spostamento del ledger in questo pannello.
  ///
  /// Le righe esistenti vengono sostituite, non accodate: se l'operatore sta
  /// preparando uno spostamento e ne riapre un altro, tenere le due liste
  /// insieme produrrebbe un invio che non corrisponde a nessuna delle due
  /// operazioni.
  ///
  /// Per ogni prodotto il semo porta la rotta originale, e il pannello la
  /// rimette com'era: lo stesso magazzino di partenza, lo stesso di arrivo, gli
  /// stessi pezzi. Il magazzino di partenza pero' viene cercato fra le
  /// ubicazioni *di adesso*, non acritamente: nel frattempo puo' essere stato
  /// svuotato o riempito, e una riga che punta a un indice sparito mostrerebbe
  /// una partenza diversa da quella che l'operatore sta correggendo.
  ///
  /// Se un prodotto non ha piu' pezzi nel magazzino da cui era partito, la sua
  /// riga resta in lista ma senza magazzino di partenza: si vede che qualcosa
  /// non torna, invece di sparire e lasciare l'operatore a domandarsi perche'
  /// quel codice e' sparito dal piano.
  ///
  /// Il seme si applica una volta sola, riconosciuto dall'impronta: riaprire due
  /// volte lo stesso movimento non deve raddoppiare i prodotti, e tornare su
  /// questo modulo dopo un altro non deve ricaricare il vecchio.
  Future<void> _applySeed(InventoryPanelSeed? seed) async {
    if (seed == null || seed.module != InventoryModule.move) return;
    if (_appliedSeedStamp == seed.stamp) return;
    _appliedSeedStamp = seed.stamp;

    final previous = List<_MoveRow>.of(_rows);
    final seeded = <_MoveRow>[];
    // Le righe senza rotta non entrano, ma il prodotto a cui appartengono
    // resta in elenco: si accoppiano qui perche' a valle serve sapere da quale
    // magazzino ripartire, e un indice non basterebbe dato che i due elenchi
    // possono avere lunghezze diverse.
    final origins = <InventoryMovementProduct>[];
    for (final product in seed.products) {
      if (!product.hasRoute) continue;
      origins.add(product);
      seeded.add(
        _MoveRow(
            productId: product.productId,
            variationId: product.variationId,
            label: context.l10n.inventoryProdottoNumero(
              product.productId.toString(),
            ),
          )
          ..toSiteController.text = '${product.siteTo}'
          ..toWarehouseController.text = '${product.warehouseTo}'
          ..quantity = product.quantity
          ..syncQuantityField(),
      );
    }
    _rows
      ..clear()
      ..addAll(seeded);
    widget.detailsController?.text = seed.reason;
    _feedback = null;
    if (_ready) setState(() {});
    for (final row in previous) {
      row.dispose();
    }
    for (var i = 0; i < seeded.length; i++) {
      await _loadSnapshot(seeded[i]);
      if (!mounted) return;
      _pointToOrigin(seeded[i], origins[i]);
    }
  }

  /// Sceglie fra le ubicazioni di adesso quella da cui partiva lo spostamento.
  ///
  /// Non si puo' riusare l'indice salvato dal seme: le ubicazioni cambiano
  /// ordine quando il magazzino si svuota o si riempie, e un indice punta a una
  /// riga qualsiasi. Si cerca quindi per sede e magazzino, che non cambiano.
  void _pointToOrigin(_MoveRow row, InventoryMovementProduct product) {
    setState(() {
      final levels = row.availableLevels;
      final index = levels.indexWhere(
        (level) =>
            level.warehouseId == product.warehouseFrom &&
            level.siteId == product.siteFrom,
      );
      row.sourceIndex = index < 0 ? null : index;
      if (row.sourceIndex != null) {
        final available = levels[row.sourceIndex!].qty;
        if (row.quantity > available) {
          row.loadError = available <= 0
              ? context.l10n.inventorySpostaMagazzinoPartenzaVuoto
              : context.l10n.inventorySpostaPezziResidui(available);
          row.quantity = available <= 0 ? 1 : available;
          row.syncQuantityField();
        }
      }
      _feedback = null;
    });
  }

  Future<_MoveRow?> _resolve(String code) async {
    // Stessa ricerca della cassa: un EAN (anche di variante) diventa il suo
    // prodotto e la sua variante. Il codice non va mai letto come id: MGWS
    // risponderebbe "prodotto non trovato" per un numero che id non e'.
    final catalog = _catalogController;
    final match = catalog != null
        ? await catalog.ricercaPerBarcode(code)
        : await inventoryMatchFromBackend(code);
    if (!mounted) return null;
    final productId = match?.productId ?? 0;
    if (match == null || productId <= 0) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryBarcodeNonRiconosciuto,
        ),
      );
      return null;
    }
    if (_rows.any((row) => row.key == '$productId:${match.variationId}')) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryProdottoGiaInLista(match.label),
        ),
      );
      return null;
    }
    final row = _MoveRow(
      productId: productId,
      variationId: match.variationId,
      label: match.label,
      imageUrl: match.imageUrl,
      barcodeInterno: match.barcodeInterno.isEmpty
          ? null
          : match.barcodeInterno,
    );
    setState(() {
      _rows.add(row);
      _feedback = null;
    });
    await _loadSnapshot(row);
    return row;
  }

  /// Legge lo stock MGWS: senza le ubicazioni non si sa da dove partire.
  Future<void> _loadSnapshot(_MoveRow row) async {
    setState(() => row.loading = true);
    final feedback = await _controller.loadStock(
      '${row.productId}',
      variationId: row.variationId,
    );
    if (!mounted) return;
    setState(() {
      row.loading = false;
      if (feedback.success) {
        row.snapshot = _controller.lastSnapshot;
        row.loadError = null;
        row.resetRoute();
      } else {
        row.loadError = feedback.message(context.l10n);
        row.sourceIndex = null;
      }
      _feedback = feedback.success ? null : feedback;
    });
  }

  Future<void> _openExistingProducts() async {
    final selected = await openProdottoPicker(context);
    if (!mounted || selected == null || selected.isEmpty) return;
    for (final unita in expandSelectedProducts(selected)) {
      if (!unita.isValid) continue;
      if (_rows.any(
        (row) =>
            row.productId == unita.productId &&
            row.variationId == unita.variationId,
      )) {
        continue;
      }
      final row = _MoveRow(
        productId: unita.productId,
        variationId: unita.variationId,
        label: unita.label,
        imageUrl: unita.imageUrl,
        barcodeInterno: unita.barcodeInterno.isEmpty
            ? null
            : unita.barcodeInterno,
      );
      setState(() {
        _rows.add(row);
        _feedback = null;
      });
      await _loadSnapshot(row);
      if (!mounted) return;
    }
  }

  void _removeRow(String key) {
    setState(() {
      final index = _rows.indexWhere((row) => row.key == key);
      if (index < 0) return;
      _rows.removeAt(index).dispose();
      _feedback = null;
    });
  }

  // ── Rotta e pezzi ────────────────────────────────────────────────

  void _setSource(_MoveRow row, int? index) {
    setState(() {
      row.sourceIndex = index;
      final available = row.availableLevels.isEmpty
          ? 0
          : row.availableLevels[row.sourceIndex ?? 0].qty;
      // Non si promettono piu' pezzi di quanti ce ne sono davvero nel
      // magazzino da cui si parte.
      row.quantity = row.quantity.clamp(1, available <= 0 ? 1 : available);
      row.syncQuantityField();
      _feedback = null;
    });
  }

  void _step(_MoveRow row, int step) {
    final available = row.source?.qty ?? 0;
    final next = row.quantity + step;
    setState(() {
      row.quantity = next.clamp(1, available <= 0 ? 1 : available);
      row.syncQuantityField();
      _feedback = null;
    });
  }

  void _setQuantity(_MoveRow row, String value) {
    setState(() {
      row.quantity = int.tryParse(value.trim()) ?? 0;
      _feedback = null;
    });
  }

  void _setAutoAdd(bool value) {
    setState(() {
      _autoAdd = value;
      _feedback = null;
      if (!value) {
        for (final row in _rows) {
          row.quantity = 1;
          row.syncQuantityField();
        }
      }
    });
  }

  // ── Piano e invio ────────────────────────────────────────────────

  InventoryMovePlan _plan() {
    return InventoryMovePlan(
      lines: [for (final row in _rows) row.toPlanLine()],
      details: widget.detailsController?.text ?? '',
    );
  }

  Future<void> _submit() async {
    final plan = _plan();
    final parsed = plan.parse(l10n: context.l10n);
    if (parsed case InventoryFormInvalid(:final message)) {
      _showFeedback(InventoryActionFeedback(success: false, message: message));
      return;
    }
    final confirmed = await showInventoryMoveConfirmDialog(
      context: context,
      plan: plan,
    );
    if (confirmed != true || !mounted) return;
    final feedback = await _controller.submit(context.l10n, plan);
    if (!mounted) return;
    if (feedback.success) {
      setState(() {
        _feedback = feedback;
        for (final row in _rows) {
          row.dispose();
        }
        _rows.clear();
      });
      return;
    }
    setState(() => _feedback = feedback);
    // Lo stock e' cambiato sotto i piedi: correggere sul numero vecchio
    // sposterebbe merce due volte.
    for (final row in _rows) {
      if (row.snapshot != null) await _loadSnapshot(row);
      if (!mounted) return;
    }
  }

  void _showFeedback(InventoryActionFeedback feedback) {
    setState(() => _feedback = feedback);
  }

  // ── Interfaccia ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-move-panel'),
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
              leading: Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
              title: Text(
                context.l10n.inventorySpostaTitolo,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                context.l10n.inventorySpostaSottotitolo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.subtitleColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            InventoryProductSection(
              title: context.l10n.inventorySezioneProdottiDaSpostare,
              keyPrefix: 'inventory-move',
              lines: [for (final row in _rows) row.toLine()],
              autoAdd: _autoAdd,
              onAutoAddChanged: _setAutoAdd,
              autoAddLabel: context.l10n.inventorySpostaAutoAddUnPezzo,
              askQuantityLabel: context.l10n.inventorySpostaChiediPezzi,
              onBarcodeEntered: (code) async => await _resolve(code) != null,
              onPickExisting: _openExistingProducts,
              onRemoveLine: _removeRow,
              busy: _controller.isSubmitting,
              barcodeLauncher: widget.barcodeLauncher,
              emptyHint: context.l10n.inventorySpostaVuotoProdotti,
              trailingBuilder: (context, line) {
                final row = _rowFor(line.key);
                return row == null ? const SizedBox.shrink() : _buildRow(row);
              },
            ),
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

  _MoveRow? _rowFor(String key) {
    for (final row in _rows) {
      if (row.key == key) return row;
    }
    return null;
  }

  /// Rotta del singolo prodotto: da dove parte, dove arriva, quanti pezzi.
  Widget _buildRow(_MoveRow row) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final levels = row.availableLevels;
    final line = row.toPlanLine();
    if (row.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (row.loadError != null || row.snapshot == null) {
      return Text(
        row.loadError == null
            ? context.l10n.inventorySpostaStockNonDisponibile
            : context.l10n.inventorySpostaStockNonCaricato(row.loadError!),
        key: ValueKey('inventory-move-load-error-${row.key}'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.errorColorStatus,
        ),
      );
    }
    if (levels.isEmpty) {
      return Text(
        context.l10n.inventorySpostaNessunaUbicazione,
        key: ValueKey('inventory-move-no-source-${row.key}'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.errorColorStatus,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('inventory-move-source-${row.key}'),
          initialValue: row.source == null ? null : levels.indexOf(row.source!),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n.inventoryEtichettaMagazzinoPartenza,
            isDense: true,
            prefixIcon: const Icon(Icons.upload_outlined),
          ),
          items: [
            for (var i = 0; i < levels.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  '${context.l10n.inventoryEtichettaSedeBreve} '
                  '${levels[i].siteId} · '
                  '${context.l10n.inventoryEtichettaMagazzino} '
                  '${levels[i].warehouseId} · '
                  '${levels[i].qty} ${context.l10n.inventoryParolaPezzi}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _controller.isSubmitting
              ? null
              : (value) => _setSource(row, value),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 420;
            final width = wide
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: TextField(
                    key: ValueKey('inventory-move-to-site-${row.key}'),
                    controller: row.toSiteController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.inventoryEtichettaSedeArrivo,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _feedback = null),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: TextField(
                    key: ValueKey('inventory-move-to-warehouse-${row.key}'),
                    controller: row.toWarehouseController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context
                          .l10n
                          .inventoryEtichettaMagazzinoArrivoObbligatorio,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _feedback = null),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: ValueKey('inventory-move-quantity-minus-${row.key}'),
              onPressed: _controller.isSubmitting || row.quantity <= 1
                  ? null
                  : () => _step(row, -1),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('1'),
            ),
            OutlinedButton.icon(
              key: ValueKey('inventory-move-quantity-plus-${row.key}'),
              onPressed:
                  _controller.isSubmitting ||
                      row.quantity >= line.availableInSource
                  ? null
                  : () => _step(row, 1),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('1'),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                key: ValueKey('inventory-move-quantity-field-${row.key}'),
                controller: row.quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.inventoryEtichettaPezzi,
                  isDense: true,
                ),
                onChanged: (value) => _setQuantity(row, value),
              ),
            ),
            Text(
              context.l10n.inventoryDisponibili(line.availableInSource),
              style: theme.textTheme.titleSmall,
            ),
            TextButton(
              onPressed: _controller.isSubmitting
                  ? null
                  : () => setState(() {
                      row.showLocations = !row.showLocations;
                    }),
              child: Text(
                row.showLocations
                    ? context.l10n.inventoryNascondiUbicazioni
                    : context.l10n.inventoryDoveSiTrova,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRowPreview(row, line, colors),
        if (row.showLocations) ...[
          const SizedBox(height: 8),
          SizedBox(height: 180, child: _buildLocations(row)),
        ],
      ],
    );
  }

  /// Riepilogo della riga: dice dove vanno e da dove vengono i pezzi, e
  /// ricorda che il totale non cambia. E la riga che evita il doppio
  /// spostamento involontario.
  Widget _buildRowPreview(
    _MoveRow row,
    InventoryMoveLine line,
    AppColorExtension colors,
  ) {
    final theme = Theme.of(context);
    final tooMany =
        line.quantity > line.availableInSource || line.quantity <= 0;
    final tone = tooMany ? colors.errorColorStatus : colors.successColor;
    final source = line.source;
    final destination = line.destinationSiteId;
    final String summary;
    if (source == null || destination == null) {
      summary = context.l10n.inventorySpostaScegliPartenzaEArrivo;
    } else {
      final total = line.snapshot?.currentStock ?? 0;
      summary =
          '${context.l10n.inventoryEtichettaSedeBreve} ${source.siteId}/'
          '${context.l10n.inventoryAbbreviazioneMagazzino} ${source.warehouseId} '
          '${source.qty} -> ${line.remainingInSource}  ·  '
          '${context.l10n.inventoryEtichettaSedeBreve} $destination/'
          '${context.l10n.inventoryAbbreviazioneMagazzino} '
          '${line.destinationWarehouseId} +${line.quantity}  ·  '
          '${context.l10n.inventoryTotaleInvariato(total)}';
    }
    return Container(
      key: ValueKey('inventory-move-preview-${row.key}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            tooMany ? Icons.error_outline : Icons.swap_vert,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tooMany
                  ? line.quantity <= 0
                        ? context.l10n.inventorySpostaIndicaPezzi
                        : context.l10n.inventorySpostaPezziDisponibili(
                            line.availableInSource,
                          )
                  : summary,
              style: theme.textTheme.titleSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocations(_MoveRow row) {
    final levels = row.snapshot?.levels ?? const <InventoryStockLevel>[];
    final source = row.source;
    return DataGridView<InventoryStockLevel>(
      framed: false,
      columns: [
        DataGridViewColumn(
          id: 'location',
          label: context.l10n.inventoryEtichettaUbicazione,
          flexible: true,
        ),
        DataGridViewColumn(
          id: 'warehouse',
          label: context.l10n.inventoryEtichettaMagazzino,
          width: 110,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'site',
          label: context.l10n.inventoryEtichettaSedeBreve,
          width: 90,
          numeric: true,
        ),
        DataGridViewColumn(
          id: 'qty',
          label: context.l10n.inventoryEtichettaPezzi,
          width: 100,
          numeric: true,
        ),
      ],
      rows: [
        for (final level in levels)
          DataGridViewRowData(
            id: '${level.siteId}-${level.warehouseId}-${level.locationKey}',
            value: level,
            cells: {
              'location': Text(
                level.locationLabel(context.l10n),
                style: source != null && level == source
                    ? const TextStyle(fontWeight: FontWeight.w800)
                    : null,
              ),
              'warehouse': Text('${level.warehouseId}'),
              'site': Text('${level.siteId}'),
              'qty': Text('${level.qty}'),
            },
          ),
      ],
    );
  }

  Widget _buildFeedback(AppColorExtension colors) {
    final feedback = _feedback!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      key: const ValueKey('inventory-move-feedback'),
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
    final busy = _rows.any((row) => row.loading);
    final ready = !busy && plan.canSubmit && !_controller.isSubmitting;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        if (plan.lineCount > 0)
          Text(
            ready
                ? '${context.l10n.inventorySpostaRiepilogoInvio(plan.totalQuantity)}'
                      ' ${context.l10n.inventoryParolaProdotti(plan.lineCount)}'
                : context.l10n.inventorySpostaServonoPartenzaArrivoPezzi,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-move-submit'),
          onPressed: ready ? _submit : null,
          icon: _controller.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.swap_horiz),
          label: Text(
            _controller.isSubmitting
                ? context.l10n.inventorySpostaInCorso
                : context.l10n.inventorySpostaPezzi,
          ),
        ),
      ],
    );
  }
}

/// Riepilogo dello spostamento prima dell'invio, una riga per prodotto.
///
/// Ripete che il totale non cambia, cosi l'operatore puo fermarsi se ha scelto
/// male la direzione.
Future<bool?> showInventoryMoveConfirmDialog({
  required BuildContext context,
  required InventoryMovePlan plan,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        context.l10n.inventoryConfermaSpostamentoTitolo(plan.lineCount),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in plan.lines) ...[
                Text(
                  line.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (line.source != null)
                  Text(
                    '${context.l10n.inventoryEtichettaPartenza}: '
                    '${context.l10n.inventoryEtichettaSedeBreve} ${line.source!.siteId} '
                    '${context.l10n.inventoryEtichettaMagazzino} ${line.source!.warehouseId} '
                    '(${line.source!.qty} ${context.l10n.inventoryParolaPezzi})',
                  ),
                Text(
                  '${context.l10n.inventoryEtichettaArrivo}: '
                  '${context.l10n.inventoryEtichettaSedeBreve} ${line.destinationSiteId} '
                  '${context.l10n.inventoryEtichettaMagazzino} ${line.destinationWarehouseId}',
                ),
                Text(
                  '${context.l10n.inventoryEtichettaPezziSpostati} ${line.quantity} · '
                  '${context.l10n.inventoryEtichettaTotaleProdotto} '
                  '${line.snapshot?.currentStock ?? 0} '
                  '${context.l10n.inventoryParolaInvariato}',
                ),
                const SizedBox(height: 8),
              ],
              if (plan.details.trim().isNotEmpty)
                Text(
                  '${context.l10n.inventoryEtichettaDettaglio}: ${plan.details.trim()}',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          key: const ValueKey('inventory-move-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.inventoryConfermaSpostamento),
        ),
      ],
    ),
  );
}
