import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../products/class_products.dart';
import '../reuse_class/datagridview/datagridview_image_preview.dart';
import 'inventory_quick_load.code.dart';
import 'inventory_quick_load_catalog.code.dart';
import '../l10n/extensions.dart';

Future<List<InventoryQuickLoadLineDraft>?> showInventoryQuickLoadPicker(
  BuildContext context, {
  List<InventoryQuickLoadLineDraft> initialLines = const [],
  InventoryQuickLoadCatalogController? controller,
}) {
  return showDialog<List<InventoryQuickLoadLineDraft>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => InventoryQuickLoadPickerDialog(
      initialLines: initialLines,
      controller: controller,
    ),
  );
}

class InventoryQuickLoadPickerDialog extends StatefulWidget {
  const InventoryQuickLoadPickerDialog({
    super.key,
    this.initialLines = const [],
    this.controller,
  });

  final List<InventoryQuickLoadLineDraft> initialLines;
  final InventoryQuickLoadCatalogController? controller;

  @override
  State<InventoryQuickLoadPickerDialog> createState() =>
      _InventoryQuickLoadPickerDialogState();
}

class _InventoryQuickLoadPickerDialogState
    extends State<InventoryQuickLoadPickerDialog> {
  static const _uuid = Uuid();
  late final InventoryQuickLoadCatalogController _controller;
  late final bool _ownsController;
  final Map<String, InventoryQuickLoadLineDraft> _selected = {};
  final Map<int, List<VarianteProductGlobal>> _variants = {};
  final Set<int> _loadingVariants = <int>{};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? InventoryQuickLoadCatalogController();
    _selected.addEntries(
      widget.initialLines.map((line) => MapEntry(line.key, line)),
    );
    _controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.products.isEmpty) _controller.load();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toggleLine(InventoryQuickLoadLineDraft line, bool selected) {
    setState(() {
      if (selected) {
        _selected[line.key] = line;
      } else {
        _selected.remove(line.key);
      }
    });
  }

  void _changeQuantity(InventoryQuickLoadLineDraft line, int quantity) {
    if (quantity <= 0) return;
    setState(() => _selected[line.key] = line.copyWith(quantity: quantity));
  }

  String? _barcode(Map<String, dynamic>? metadata) {
    final value = metadata?['barcode']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  InventoryQuickLoadLineDraft _productLine(ProdottoGlobal product) {
    return InventoryQuickLoadLineDraft(
      productId: product.id ?? 0,
      variationId: 0,
      label: product.nome?.trim().isNotEmpty == true
          ? product.nome!.trim()
          : 'Prodotto #${product.id ?? 0}',
      barcodeInterno: product.barcodeInterno,
      barcode: _barcode(product.metadatiCustom),
      imageUrl: product.immagineUrl,
      quantity: 1,
      idempotencyKey: _uuid.v4(),
    );
  }

  InventoryQuickLoadLineDraft _variantLine(
    ProdottoGlobal product,
    VarianteProductGlobal variant,
  ) {
    final productLabel = product.nome?.trim().isNotEmpty == true
        ? product.nome!.trim()
        : 'Prodotto #${product.id ?? 0}';
    return InventoryQuickLoadLineDraft(
      productId: product.id ?? 0,
      variationId: variant.id,
      label: '$productLabel · ${inventoryVariationLabel(variant)}',
      barcodeInterno: variant.barcodeInterno,
      barcode: _barcode(variant.metadatiCustom),
      imageUrl: variant.immagineUrl ?? product.immagineUrl,
      quantity: 1,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<void> _loadVariants(ProdottoGlobal product) async {
    final productId = product.id;
    if (productId == null ||
        productId <= 0 ||
        _variants.containsKey(productId) ||
        _loadingVariants.contains(productId)) {
      return;
    }
    setState(() => _loadingVariants.add(productId));
    final variants = await _controller.loadVariants(product);
    if (!mounted) return;
    setState(() {
      _loadingVariants.remove(productId);
      _variants[productId] = variants;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: media.width < 760 ? media.width - 32 : 920,
        height: media.height < 820 ? media.height - 32 : 760,
        child: Column(
          children: [
            _buildHeader(),
            if (_controller.isLoading)
              const LinearProgressIndicator(minHeight: 3),
            if (_controller.errorMessage case final warning?)
              MaterialBanner(
                content: Text(warning),
                leading: const Icon(Icons.warning_amber_rounded),
                actions: [
                  TextButton(
                    onPressed: () => _controller.load(forceRefresh: true),
                    child: Text(context.l10n.inventoryRiprova),
                  ),
                ],
              ),
            Expanded(child: _buildCatalog()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleziona prodotti e varianti',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _controller.isLoading
                      ? '${_controller.loadedProducts} prodotti caricati finora'
                      : '${_controller.products.length} prodotti disponibili',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.inventoryTooltipChiudi,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            key: const ValueKey('quick-load-product-search'),
            onChanged: _controller.search,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: context.l10n.inventoryCercaHint,
            ),
          ),
        ),
        Expanded(
          child: _controller.products.isEmpty && _controller.isLoading
              ? Center(child: CircularProgressIndicator())
              : _controller.products.isEmpty
              ? Center(child: Text(context.l10n.inventoryNessunProdottoTrovato))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _controller.products.length,
                  itemBuilder: (context, index) {
                    final product = _controller.products[index];
                    return _controller.isVariable(product)
                        ? _buildVariableProduct(product)
                        : _buildSimpleProduct(product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSimpleProduct(ProdottoGlobal product) {
    final baseLine = _productLine(product);
    final selectedLine = _selected[baseLine.key];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        key: ValueKey('quick-load-product-${product.id}'),
        value: selectedLine != null,
        onChanged: product.id == null || product.id! <= 0
            ? null
            : (value) => _toggleLine(baseLine, value ?? false),
        title: Text(baseLine.label),
        subtitle: Text(
          _subtitle(product.barcodeInterno, product.quantitaTotale),
        ),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DataGridViewImagePreview(
              key: ValueKey('quick-load-product-image-${product.id}'),
              imageUrl: product.immagineUrl,
              semanticLabel: 'Copertina ${baseLine.label}',
              size: 48,
            ),
            if (selectedLine != null) ...[
              const SizedBox(width: 8),
              _QuantityStepper(
                line: selectedLine,
                onChanged: (value) => _changeQuantity(selectedLine, value),
              ),
            ],
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildVariableProduct(ProdottoGlobal product) {
    final productId = product.id ?? 0;
    final variants = _variants[productId] ?? product.varianti;
    final loading = _loadingVariants.contains(productId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: ValueKey('quick-load-variable-product-$productId'),
        leading: DataGridViewImagePreview(
          key: ValueKey('quick-load-product-image-$productId'),
          imageUrl: product.immagineUrl,
          semanticLabel: 'Copertina ${product.nome ?? 'prodotto'}',
          size: 48,
        ),
        title: Text(product.nome ?? 'Prodotto #$productId'),
        subtitle: Text(
          '${_subtitle(product.barcodeInterno, product.quantitaTotaleVarianti)} · Seleziona una variante',
        ),
        onExpansionChanged: (expanded) {
          if (expanded) _loadVariants(product);
        },
        children: [
          if (loading)
            Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else if (variants == null)
            const SizedBox.shrink()
          else if (variants.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(context.l10n.inventoryNessunaVariante),
            )
          else
            for (final variant in variants) _buildVariant(product, variant),
        ],
      ),
    );
  }

  Widget _buildVariant(ProdottoGlobal product, VarianteProductGlobal variant) {
    final baseLine = _variantLine(product, variant);
    final selectedLine = _selected[baseLine.key];
    return CheckboxListTile(
      key: ValueKey('quick-load-variant-${variant.id}'),
      value: selectedLine != null,
      onChanged: variant.id <= 0
          ? null
          : (value) => _toggleLine(baseLine, value ?? false),
      title: Text(inventoryVariationLabel(variant)),
      subtitle: Text(_subtitle(variant.barcodeInterno, variant.quantita)),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DataGridViewImagePreview(
            key: ValueKey('quick-load-variant-image-${variant.id}'),
            imageUrl: variant.immagineUrl ?? product.immagineUrl,
            semanticLabel: 'Copertina ${inventoryVariationLabel(variant)}',
            size: 42,
          ),
          if (selectedLine != null) ...[
            const SizedBox(width: 8),
            _QuantityStepper(
              line: selectedLine,
              onChanged: (value) => _changeQuantity(selectedLine, value),
            ),
          ],
        ],
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildFooter() {
    final selectedCount = _selected.length;
    final totalQuantity = _selected.values.fold<int>(
      0,
      (sum, line) => sum + line.quantity,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedCount righe · $totalQuantity pezzi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonAnnulla),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('quick-load-confirm-products'),
              onPressed: selectedCount == 0
                  ? null
                  : () => Navigator.of(context).pop(_selected.values.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.check),
              label: Text(context.l10n.inventoryUsaSelezione('$selectedCount')),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(String? barcodeInterno, int? stock) {
    final barcodeNormalizzato = barcodeInterno?.trim();
    return '${barcodeNormalizzato?.isNotEmpty == true ? 'Barcode interno $barcodeNormalizzato' : 'Barcode interno non disponibile'} · Stock ${stock ?? 0}';
  }
}

class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({required this.line, required this.onChanged});

  final InventoryQuickLoadLineDraft line;
  final ValueChanged<int> onChanged;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.line.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text) == widget.line.quantity) return;
    _controller.value = TextEditingValue(
      text: widget.line.quantity.toString(),
      selection: TextSelection.collapsed(
        offset: widget.line.quantity.toString().length,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('quick-load-minus-${widget.line.key}'),
            tooltip: context.l10n.inventoryTooltipRiduciQuantita,
            visualDensity: VisualDensity.compact,
            onPressed: widget.line.quantity <= 1
                ? null
                : () => widget.onChanged(widget.line.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 34,
            child: TextFormField(
              key: ValueKey('quick-load-quantity-${widget.line.key}'),
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 0) widget.onChanged(parsed);
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('quick-load-plus-${widget.line.key}'),
            tooltip: context.l10n.inventoryTooltipAumentaQuantita,
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.onChanged(widget.line.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
