import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../notification/notification_service.dart';
import '../../reuse_class/gui/notification_recap_dialog.dart';
import '../../reuse_class/image_url_resolver.dart';
import '../../settings/app_settings.dart';
import '../../theme/theme.dart';
import '../class_prodotti.dart';
import '../../reuse_class/class_formtter.dart';
import '../prodotti_crea/prodotti_crea.gui.dart';
import 'prodotti_gestisci.code.dart';
import '../../traduzioni/estensioni.dart';

const double _kDetailGap = 16;
const double _kDetailCardRadius = 18;
const double _kDetailPanePadding = 16;
const double _kDetailCardPadding = 20;

List<String> _collectDistinctImageUrls(Iterable<String?> urls) {
  final seen = <String>{};
  final ordered = <String>[];
  for (final rawUrl in urls) {
    final url = (resolveImageUrl(rawUrl) ?? '').trim();
    if (url.isEmpty || seen.contains(url)) continue;
    seen.add(url);
    ordered.add(url);
  }
  return ordered;
}

String _stripHtmlTags(String value) {
  final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Future<void> _openImageViewer(
  BuildContext context,
  String? imageUrl, {
  required String title,
  List<String>? imageUrls,
}) async {
  final safeUrl = (resolveImageUrl(imageUrl) ?? '').trim();
  final images = _collectDistinctImageUrls(imageUrls ?? [safeUrl]);
  if (images.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (_) => _ImageGalleryViewer(
      title: title,
      images: images,
      initialIndex: images.indexOf(safeUrl).clamp(0, images.length - 1),
    ),
  );
}

class _ImageGalleryViewer extends StatefulWidget {
  final String title;
  final List<String> images;
  final int initialIndex;

  const _ImageGalleryViewer({
    required this.title,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late int _imageIndex = widget.initialIndex;

  void _showImageAt(int index) {
    if (index < 0 || index >= widget.images.length) return;
    setState(() => _imageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final canGoBack = _imageIndex > 0;
    final canGoForward = _imageIndex < widget.images.length - 1;
    final viewer = Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 20,
              isCompact ? 8 : 16,
              isCompact ? 4 : 12,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.images.length > 1
                        ? '${widget.title} · ${_imageIndex + 1}/${widget.images.length}'
                        : widget.title,
                    maxLines: isCompact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: context.l10n.prodottiChiudiImmagine,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: Container(
                    color: theme.colorScheme.surface,
                    alignment: Alignment.center,
                    child: Image.network(
                      widget.images[_imageIndex],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.cardColor,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.images.length > 1) ...[
                Positioned(
                  left: isCompact ? 6 : 12,
                  child: _GalleryNavigationButton(
                    icon: Icons.chevron_left,
                    tooltip: context.l10n.prodottiFotoPrecedente,
                    enabled: canGoBack,
                    onPressed: () => _showImageAt(_imageIndex - 1),
                  ),
                ),
                Positioned(
                  right: isCompact ? 6 : 12,
                  child: _GalleryNavigationButton(
                    icon: Icons.chevron_right,
                    tooltip: context.l10n.prodottiFotoSuccessiva,
                    enabled: canGoForward,
                    onPressed: () => _showImageAt(_imageIndex + 1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (isCompact) {
      return Dialog.fullscreen(child: viewer);
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: viewer,
      ),
    );
  }
}

class _GalleryNavigationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _GalleryNavigationButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.scrim.withValues(alpha: enabled ? 0.58 : 0.22),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        color: Colors.white,
        disabledColor: Colors.white54,
        iconSize: 32,
        icon: Icon(icon),
      ),
    );
  }
}

class ProdottoDettagliView extends StatefulWidget {
  final ProdottoGlobal prodotto;
  final VarianteProductGlobal? varianteSelezionata;
  final ValueChanged<VarianteProductGlobal?>? onVarianteSelezionata;
  final bool showCloseButton;
  final VoidCallback? onProductDeleted;
  final VoidCallback? onVariantDeleted;
  final bool requiresDeleteConfirmation;
  final ProdottiGestioneController? controller;
  final bool modalitaSelezioneCassa;
  final Set<int> variantiSelezionateCassa;
  final void Function(VarianteProductGlobal variante, bool selected)?
  onVarianteCassaChecked;

  /// In modalità cassa: il prodotto semplice è stato selezionato per l'aggiunta.
  final bool prodottoSempliceSelezionatoCassa;
  final ValueChanged<bool>? onProdottoSempliceCassaChecked;
  final bool variantsLoading;
  final Future<void> Function()? onReload;
  final String shortcutToggleEdit;
  final String shortcutSave;
  final String shortcutEscape;

  const ProdottoDettagliView({
    super.key,
    required this.prodotto,
    this.varianteSelezionata,
    this.onVarianteSelezionata,
    this.showCloseButton = false,
    this.onProductDeleted,
    this.onVariantDeleted,
    this.requiresDeleteConfirmation = true,
    this.controller,
    this.modalitaSelezioneCassa = false,
    this.variantiSelezionateCassa = const <int>{},
    this.onVarianteCassaChecked,
    this.prodottoSempliceSelezionatoCassa = false,
    this.onProdottoSempliceCassaChecked,
    this.variantsLoading = false,
    this.onReload,
    this.shortcutToggleEdit = 'Ctrl+E',
    this.shortcutSave = 'Ctrl+S',
    this.shortcutEscape = 'Esc',
  });

  @override
  State<ProdottoDettagliView> createState() => _ProdottoDettagliViewState();
}

class _ProdottoDettagliViewState extends State<ProdottoDettagliView> {
  late VarianteProductGlobal? _varianteSelezionata;
  String? _selectedGalleryImageUrl;
  Map<String, String> _filtriVariantiAttivi = <String, String>{};
  List<VarianteProductGlobal> _variantiFiltrate = <VarianteProductGlobal>[];
  Set<int> _variantiSelezionateCassa = <int>{};
  bool _filtraSoloInStock = false;
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _bulkDelete = false;
  List<String> _selectedCategoryNames = <String>[];
  List<String> _selectedTagNames = <String>[];
  String? _selectedStatus;
  List<String> _baseCategoryNames = <String>[];
  List<String> _baseTagNames = <String>[];
  String? _baseStatus;
  final Map<int, TextEditingController> _variantPriceCtrls =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _variantQtyCtrls =
      <int, TextEditingController>{};
  final Map<int, double> _variantBasePrice = <int, double>{};
  final Map<int, int> _variantBaseQty = <int, int>{};
  final _shortcutFocusNode = FocusNode(debugLabel: 'ProdottoDettagliShortcuts');

  ProdottiGestioneController? get _controller => widget.controller;
  bool get _isMultiEdit =>
      (_controller?.selectedProductsCount ?? 0) > 1 && _isEditMode;

  /// Prodotto semplice = nessun ID variante dichiarato da WooCommerce e
  /// varianti non in caricamento (per non mostrare il checkbox durante il
  /// fetch delle varianti di un prodotto variabile).
  bool get _isProdottoSemplice =>
      !widget.variantsLoading &&
      (widget.prodotto.variations == null ||
          widget.prodotto.variations!.isEmpty);

  @override
  void initState() {
    super.initState();
    _varianteSelezionata = widget.varianteSelezionata;
    _variantiSelezionateCassa = Set<int>.from(widget.variantiSelezionateCassa);
    _syncFromController();
    _syncEditStateFromProduct();
    _applicaFiltriVarianti();
  }

  @override
  void didUpdateWidget(covariant ProdottoDettagliView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.prodotto, widget.prodotto) ||
        oldWidget.prodotto.id != widget.prodotto.id ||
        oldWidget.varianteSelezionata?.id != widget.varianteSelezionata?.id) {
      _varianteSelezionata = widget.varianteSelezionata;
      _syncFromController();
      _syncEditStateFromProduct();
      _applicaFiltriVarianti();
    }
    if (oldWidget.variantiSelezionateCassa != widget.variantiSelezionateCassa) {
      _variantiSelezionateCassa = Set<int>.from(
        widget.variantiSelezionateCassa,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _variantPriceCtrls.values) {
      controller.dispose();
    }
    for (final controller in _variantQtyCtrls.values) {
      controller.dispose();
    }
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final controller = _controller;
    if (controller == null) return;
    _filtriVariantiAttivi = Map<String, String>.from(
      controller.filtriVariantiAttivi,
    );
    _filtraSoloInStock = controller.filtraSoloInStock;
    _selectedGalleryImageUrl = null;
  }

  void _syncEditStateFromProduct() {
    final isMulti = (_controller?.selectedProductsCount ?? 0) > 1;
    final prodotto = widget.prodotto;

    _baseCategoryNames = QuickEditSelectionUtils.categoryNamesFromProduct(
      prodotto,
    );
    _baseTagNames = QuickEditSelectionUtils.tagNamesFromProduct(prodotto);
    _baseStatus = prodotto.status;

    _selectedCategoryNames = isMulti
        ? <String>[]
        : List<String>.from(_baseCategoryNames);
    _selectedTagNames = isMulti ? <String>[] : List<String>.from(_baseTagNames);
    _selectedStatus = isMulti ? null : _baseStatus;
    _bulkDelete = false;

    for (final controller in _variantPriceCtrls.values) {
      controller.dispose();
    }
    for (final controller in _variantQtyCtrls.values) {
      controller.dispose();
    }
    _variantPriceCtrls.clear();
    _variantQtyCtrls.clear();
    _variantBasePrice.clear();
    _variantBaseQty.clear();

    for (final variante
        in prodotto.varianti ?? const <VarianteProductGlobal>[]) {
      _variantPriceCtrls[variante.id] = TextEditingController(
        text: variante.prezzo.toStringAsFixed(2),
      );
      _variantQtyCtrls[variante.id] = TextEditingController(
        text: variante.quantita.toString(),
      );
      _variantBasePrice[variante.id] = variante.prezzo;
      _variantBaseQty[variante.id] = variante.quantita;
    }
  }

  bool get _hasPendingChanges {
    final isMulti = (_controller?.selectedProductsCount ?? 0) > 1;
    if (_bulkDelete) return true;
    if (_selectedStatus != (_baseStatus ?? '')) return true;
    if (!QuickEditSelectionUtils.hasSameNames(
      _selectedCategoryNames,
      _baseCategoryNames,
    )) {
      return true;
    }
    if (!QuickEditSelectionUtils.hasSameNames(
      _selectedTagNames,
      _baseTagNames,
    )) {
      return true;
    }
    if (isMulti) return false;

    for (final entry in _variantBasePrice.entries) {
      final current = double.tryParse(
        (_variantPriceCtrls[entry.key]?.text ?? '').replaceAll(',', '.'),
      );
      if (current != null && current != entry.value) return true;
    }
    for (final entry in _variantBaseQty.entries) {
      final current = int.tryParse(
        (_variantQtyCtrls[entry.key]?.text ?? '').trim(),
      );
      if (current != null && current != entry.value) return true;
    }
    return false;
  }

  Future<void> _confirmCancelEdit() async {
    if (!_hasPendingChanges) {
      setState(() => _isEditMode = false);
      _syncEditStateFromProduct();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.prodottiConfermaAnnullaModifiche),
        content: const Text(
          'Le modifiche non salvate andranno perse. Vuoi continuare?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.prodottiAnnullaModifiche),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isEditMode = false;
      _syncEditStateFromProduct();
    });
  }

  Future<void> _saveAll() async {
    final controller = _controller;
    final prodotto = widget.prodotto;
    if (controller == null || prodotto.id == null || prodotto.id! <= 0) return;

    final isMulti = controller.selectedProductsCount > 1;
    if (isMulti && !controller.hasSelectedProducts) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_gestisci',
        'Nessun prodotto selezionato per la modifica multipla.',
      );
      return;
    }

    if (!isMulti) {
      controller.clearBulkSelection();
      controller.toggleProductBulkSelection(prodotto);
    }

    if (!_hasPendingChanges) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_gestisci',
        'Nessuna modifica da salvare.',
      );
      return;
    }

    try {
      final categoriesChanged = !QuickEditSelectionUtils.hasSameNames(
        _selectedCategoryNames,
        _baseCategoryNames,
      );
      final tagsChanged = !QuickEditSelectionUtils.hasSameNames(
        _selectedTagNames,
        _baseTagNames,
      );
      final normalizedStatus = (_selectedStatus ?? '').trim().toLowerCase();
      final baseStatus = (_baseStatus ?? '').trim().toLowerCase();
      final statusChanged =
          normalizedStatus.isNotEmpty && normalizedStatus != baseStatus;

      final recapChanges = <String>[
        if (categoriesChanged)
          'Categorie: ${_selectedCategoryNames.join(', ')}',
        if (tagsChanged) 'Tag: ${_selectedTagNames.join(', ')}',
        if (statusChanged) 'Stato: $normalizedStatus',
        if (isMulti && _bulkDelete)
          'Eliminazione dei ${controller.selectedProductsCount} prodotti selezionati',
        if (!isMulti && !categoriesChanged && !tagsChanged && !statusChanged)
          'Prezzi o quantità delle varianti',
      ];
      final confirmed = await NotificationRecapDialog.edit(
        context,
        changes: recapChanges,
        affectedItemsCount: isMulti ? controller.selectedProductsCount : 1,
        isDestructive: isMulti && _bulkDelete,
      );
      if (!confirmed || !mounted) return;

      setState(() => _isSaving = true);

      var categoryResult = const BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: 'Nessuna modifica categorie.',
      );
      if (categoriesChanged) {
        final categories = await controller.resolveCategoryNames(
          categoryNames: _selectedCategoryNames,
        );
        categoryResult = await controller.bulkUpdateSelectedProductCategories(
          categorie: categories,
          replaceExisting: false,
        );
      }

      var tagResult = const BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: 'Nessuna modifica tag.',
      );
      if (tagsChanged) {
        final tags = await controller.resolveTagNames(
          tagNames: _selectedTagNames,
        );
        tagResult = await controller.bulkUpdateSelectedProductTags(
          tags: tags,
          replaceExisting: false,
        );
      }

      var statusResult = const BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: 'Nessuna modifica stato.',
      );
      if (statusChanged) {
        statusResult = await controller.bulkUpdateSelectedProductsStatus(
          status: normalizedStatus,
        );
      }

      var deleteResult = const BulkCategoryUpdateResult(
        successCount: 0,
        failedCount: 0,
        message: 'Nessuna eliminazione.',
      );
      if (isMulti && _bulkDelete) {
        final settings = AppSettings();
        await settings.init();
        deleteResult = await controller.deleteSelectedProducts(
          force: settings.forceDelete,
        );
      }

      var variantResult = const QuickVariantSaveResult(
        updated: 0,
        failed: 0,
        message: 'Nessuna modifica varianti.',
      );
      if (!isMulti) {
        final edits = <int, QuickVariantEdit>{};
        for (final variante
            in prodotto.varianti ?? const <VarianteProductGlobal>[]) {
          final newPrice = double.tryParse(
            (_variantPriceCtrls[variante.id]?.text ?? '').replaceAll(',', '.'),
          );
          final newQty = int.tryParse(
            (_variantQtyCtrls[variante.id]?.text ?? '').trim(),
          );
          if (newPrice != null && newQty != null) {
            if (newPrice != variante.prezzo || newQty != variante.quantita) {
              edits[variante.id] = QuickVariantEdit(
                nome: variante.nome,
                attributi: variante.attributi,
                barcodeInterno: variante.barcodeInterno,
                prezzo: newPrice,
                prezzoScontato: variante.prezzoScontato,
                quantita: newQty,
                immagineUrl: variante.immagineUrl,
                immaginiAggiuntive: variante.immaginiAggiuntive,
                peso: variante.peso,
                dimensioni: variante.dimensioni,
                attiva: newQty > 0,
              );
            }
          }
        }
        if (edits.isNotEmpty) {
          variantResult = await controller.saveVariantQuickEdits(
            productId: prodotto.id!,
            edits: edits,
          );
        }
      }

      if (!mounted) return;
      final hasErrors =
          categoryResult.failedCount > 0 ||
          tagResult.failedCount > 0 ||
          statusResult.failedCount > 0 ||
          deleteResult.failedCount > 0 ||
          variantResult.failed > 0;
      NotificationService.instance.messageBar(
        hasErrors ? 'warning' : 'successo',
        'prodotti_gestisci',
        '${categoryResult.message} ${tagResult.message} ${statusResult.message} ${deleteResult.message} ${variantResult.message}',
      );

      controller.clearBulkSelection();
      await widget.onReload?.call();
      widget.onProductDeleted?.call();
      if (!mounted) return;
      setState(() {
        _isEditMode = false;
        _syncEditStateFromProduct();
      });
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.messageBar(
        'errore',
        'prodotti_gestisci',
        'Errore salvataggio rapido: $e',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  KeyEventResult _handleShortcutKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_matchesShortcut(event, widget.shortcutToggleEdit)) {
      if (_isSaving) return KeyEventResult.handled;
      if (_isEditMode) {
        Future<void>(_confirmCancelEdit);
      } else {
        setState(() => _isEditMode = true);
      }
      return KeyEventResult.handled;
    }
    if (_matchesShortcut(event, widget.shortcutSave)) {
      if (_isEditMode && !_isSaving) Future<void>(_saveAll);
      return KeyEventResult.handled;
    }
    if (_matchesShortcut(event, widget.shortcutEscape)) {
      if (_isEditMode && !_isSaving) Future<void>(_confirmCancelEdit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _matchesShortcut(KeyEvent event, String shortcut) {
    final parts = shortcut
        .toLowerCase()
        .split('+')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (parts.isEmpty) return false;

    final wantsCtrl = parts.remove('ctrl') || parts.remove('control');
    final wantsAlt = parts.remove('alt');
    final wantsShift = parts.remove('shift');
    final wantsMeta = parts.remove('meta') || parts.remove('cmd');
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed != wantsCtrl ||
        keyboard.isAltPressed != wantsAlt ||
        keyboard.isShiftPressed != wantsShift ||
        keyboard.isMetaPressed != wantsMeta ||
        parts.length != 1) {
      return false;
    }
    return _shortcutKeyName(event.logicalKey) == parts.single;
  }

  String _shortcutKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) return 'esc';
    if (key == LogicalKeyboardKey.delete) return 'delete';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    final label = key.keyLabel.toLowerCase();
    if (label.length == 1) return label;
    return (key.debugName ?? '').toLowerCase().replaceAll(' ', '');
  }

  void _selezionaVariante(VarianteProductGlobal? variante) {
    setState(() {
      _varianteSelezionata = variante;
      _selectedGalleryImageUrl = null;
    });
    _controller?.selezionaVariante(variante);
    widget.onVarianteSelezionata?.call(variante);
  }

  void _toggleVarianteCassa(VarianteProductGlobal variante, bool selected) {
    setState(() {
      if (selected) {
        _variantiSelezionateCassa.add(variante.id);
      } else {
        _variantiSelezionateCassa.remove(variante.id);
      }
    });
    widget.onVarianteCassaChecked?.call(variante, selected);
  }

  String _getCurrentImageUrl() {
    if (_varianteSelezionata?.immagineUrl != null &&
        _varianteSelezionata!.immagineUrl!.trim().isNotEmpty) {
      return resolveImageUrl(_varianteSelezionata!.immagineUrl) ?? '';
    }
    return resolveImageUrl(widget.prodotto.immagineUrl) ?? '';
  }

  Map<String, List<AttributoVariante>> _getOpzioniFiltroDisponibili() {
    final opzioniUniche = <String, Map<String, AttributoVariante>>{};
    final varianti =
        widget.prodotto.varianti ?? const <VarianteProductGlobal>[];

    for (final variante in varianti) {
      // Con il filtro disponibilità attivo, non proporre attributi che
      // appartengono esclusivamente a varianti esaurite.
      if (_filtraSoloInStock && variante.quantita <= 0) continue;
      for (final attributo in variante.attributi) {
        opzioniUniche[attributo.nome] ??= <String, AttributoVariante>{};
        opzioniUniche[attributo.nome]![attributo.opzione] = attributo;
      }
    }

    final risultato = <String, List<AttributoVariante>>{};
    opzioniUniche.forEach((nomeAttributo, mappaOpzioni) {
      risultato[nomeAttributo] = mappaOpzioni.values.toList();
    });
    return risultato;
  }

  /// Restituisce le opzioni per cui non esiste alcuna variante con quantità
  /// positiva. Un'opzione rimane disponibile se almeno una sua variante lo è.
  Map<String, Set<String>> _getOpzioniFiltroEsaurite() {
    final disponibilita = <String, Map<String, bool>>{};

    for (final variante
        in widget.prodotto.varianti ?? const <VarianteProductGlobal>[]) {
      for (final attributo in variante.attributi) {
        final opzioniAttributo = disponibilita.putIfAbsent(
          attributo.nome,
          () => <String, bool>{},
        );
        opzioniAttributo[attributo.opzione] =
            (opzioniAttributo[attributo.opzione] ?? false) ||
            variante.quantita > 0;
      }
    }

    return disponibilita.map(
      (nomeAttributo, opzioni) => MapEntry(
        nomeAttributo,
        opzioni.entries
            .where((opzione) => !opzione.value)
            .map((opzione) => opzione.key)
            .toSet(),
      ),
    );
  }

  void _setFiltroVariante(String nomeAttributo, String opzione) {
    _controller?.setFiltroVariante(nomeAttributo, opzione);
    setState(() {
      if (_filtriVariantiAttivi[nomeAttributo] == opzione) {
        _filtriVariantiAttivi.remove(nomeAttributo);
      } else {
        _filtriVariantiAttivi[nomeAttributo] = opzione;
      }
      _applicaFiltriVarianti();
    });
  }

  void _cancellaFiltriVarianti() {
    _controller?.cancellaFiltriVarianti();
    setState(() {
      _filtriVariantiAttivi.clear();
      _applicaFiltriVarianti();
    });
  }

  void _applicaFiltriVarianti() {
    final varianti =
        widget.prodotto.varianti ?? const <VarianteProductGlobal>[];
    var filtered = varianti.where((variante) {
      for (final entry in _filtriVariantiAttivi.entries) {
        final haAttributoCorretto = variante.attributi.any(
          (attributo) =>
              attributo.nome == entry.key && attributo.opzione == entry.value,
        );
        if (!haAttributoCorretto) return false;
      }
      return true;
    }).toList();

    if (_filtraSoloInStock) {
      filtered = filtered.where((v) => v.quantita > 0).toList();
    }

    _variantiFiltrate = filtered;
    if (_varianteSelezionata != null &&
        !_variantiFiltrate.any((v) => v.id == _varianteSelezionata!.id)) {
      _varianteSelezionata = null;
    }
  }

  Future<void> _handleAction(_DettaglioAction action) async {
    switch (action) {
      case _DettaglioAction.crea:
        final created = await openProductEditor(context);
        if (created == true) {
          await widget.onReload?.call();
        }
        break;
      case _DettaglioAction.modifica:
        final updated = await openProductEditor(
          context,
          prodottoIdDaModificare: widget.prodotto.id,
          codiceProdotto: widget.prodotto.codiceProdotto,
        );
        if (updated == true) {
          await widget.onReload?.call();
        }
        break;
      case _DettaglioAction.modificaInMassa:
        if (!_isSaving && (_controller?.selectedProductsCount ?? 0) > 1) {
          setState(() => _isEditMode = true);
        }
        break;
      case _DettaglioAction.elimina:
        final controller = _controller;
        if (controller == null) return;
        final confirmed = !widget.requiresDeleteConfirmation
            ? true
            : await NotificationRecapDialog.delete(
                context,
                items: [widget.prodotto],
                itemLabel: (product) => product.nome ?? 'Prodotto senza nome',
                isDestructive: true,
              );

        if (!confirmed) return;
        final productId = widget.prodotto.id ?? 0;
        if (productId <= 0) return;
        final removed = await controller.eliminaProdotto(productId);
        if (!mounted) return;
        NotificationService.instance.messageBar(
          removed ? 'successo' : 'errore',
          'prodotti_gestisci',
          removed
              ? 'Prodotto eliminato con successo.'
              : 'Eliminazione prodotto non riuscita.',
        );
        if (removed) {
          widget.onProductDeleted?.call();
          await widget.onReload?.call();
          if (widget.showCloseButton && mounted) {
            Navigator.of(context).maybePop();
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final description = _stripHtmlTags(widget.prodotto.descrizioneBreve ?? '');
    final prezzoInfo = ProdottoUtils.getPricingInfo(widget.prodotto);
    final productStatusColor = switch (widget.prodotto.status
        .trim()
        .toLowerCase()) {
      'publish' => customColors.successColor,
      'draft' || 'pending' => customColors.warningColor,
      'private' => theme.colorScheme.secondary,
      _ => theme.primaryColor,
    };
    final currentImage = _getCurrentImageUrl();
    final galleryImages = _collectDistinctImageUrls([
      currentImage,
      ...widget.prodotto.tutteLeImmagini,
    ]);
    final displayedImage = galleryImages.contains(_selectedGalleryImageUrl)
        ? _selectedGalleryImageUrl!
        : currentImage;

    final body = Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: _handleShortcutKey,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            0,
            _kDetailPanePadding,
            _kDetailPanePadding,
            88,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.prodotto.nome ?? '',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DettaglioHeader(
                          onAction: _handleAction,
                          showBulkEdit:
                              (_controller?.selectedProductsCount ?? 0) > 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: ProdottoUtils.getStatusLabel(
                            context.l10n,
                            widget.prodotto.status,
                          ),
                          color: productStatusColor,
                        ),
                        _StatusPill(
                          label: ClassFormtter.getDisponibilitaText(
                            widget.prodotto.inStock,
                          ),
                          color: widget.prodotto.inStock
                              ? customColors.stockAvailable
                              : customColors.stockUnavailable,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _kDetailGap),
              _DettaglioHero(
                prodotto: widget.prodotto,
                currentImage: displayedImage,
                galleryImages: galleryImages,
                onSelectImage: (imageUrl) {
                  setState(() {
                    _selectedGalleryImageUrl = imageUrl;
                  });
                },
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: _kDetailGap),
                _PaneCard(
                  tinted: true,
                  child: Text(description, style: theme.textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: _kDetailGap),
              _ReadonlyInfoCard(
                prodotto: widget.prodotto,
                prezzoInfo: prezzoInfo,
              ),
              const SizedBox(height: 0),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _VariantFiltersCard(
                  opzioniFiltro: _getOpzioniFiltroDisponibili(),
                  opzioniEsaurite: _getOpzioniFiltroEsaurite(),
                  filtriAttivi: _filtriVariantiAttivi,
                  filtraSoloInStock: _filtraSoloInStock,
                  onFilterSelected: _setFiltroVariante,
                  onClearFilters: _cancellaFiltriVarianti,
                  onToggleStockOnly: (value) {
                    setState(() {
                      _filtraSoloInStock = value;
                      _controller?.setFiltraSoloInStock(value);
                      _applicaFiltriVarianti();
                    });
                  },
                ),
              ),
              const SizedBox(height: 0),
              if (widget.variantsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Caricamento varianti...',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (widget.modalitaSelezioneCassa &&
                  _isProdottoSemplice &&
                  widget.onProdottoSempliceCassaChecked != null) ...[
                _PaneCard(
                  child: CheckboxListTile(
                    value: widget.prodottoSempliceSelezionatoCassa,
                    onChanged: (value) => widget.onProdottoSempliceCassaChecked
                        ?.call(value ?? false),
                    title: Text(context.l10n.prodottiAggiungiAllaCassa),
                    subtitle: const Text(
                      'Prodotto semplice: viene aggiunto senza varianti.',
                    ),
                    secondary: const Icon(Icons.add_shopping_cart),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: _kDetailGap),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _VariantsListCard(
                  varianti: _variantiFiltrate,
                  selectedVarianteId: _varianteSelezionata?.id,
                  onSelect: _selezionaVariante,
                  modalitaSelezioneCassa: widget.modalitaSelezioneCassa,
                  variantiSelezionateCassa: _variantiSelezionateCassa,
                  onVarianteCassaChecked: _toggleVarianteCassa,
                  isEditMode: _isEditMode && !_isMultiEdit,
                  variantPriceCtrls: _variantPriceCtrls,
                  variantQtyCtrls: _variantQtyCtrls,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.showCloseButton) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.prodotto.nome ?? 'Dettaglio prodotto'),
        ),
        body: body,
      );
    }

    return body;
  }
}

enum _DettaglioAction { crea, modifica, modificaInMassa, elimina }

class _PaneCard extends StatelessWidget {
  final Widget child;
  final bool tinted;
  final EdgeInsetsGeometry padding;
  final bool showBorder;
  final double borderRadius;

  const _PaneCard({
    required this.child,
    this.tinted = false,
    this.padding = const EdgeInsets.all(_kDetailCardPadding),
    this.showBorder = true,
    this.borderRadius = _kDetailCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tinted
            ? customColors.variantSelectedBackground.withValues(alpha: 0.55)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: theme.dividerColor.withValues(alpha: 0.42))
            : null,
      ),
      child: child,
    );
  }
}

class _DettaglioHeader extends StatelessWidget {
  final Future<void> Function(_DettaglioAction action) onAction;
  final bool showBulkEdit;

  const _DettaglioHeader({required this.onAction, required this.showBulkEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_DettaglioAction>(
      tooltip: context.l10n.prodottiAzioniProdotto,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DettaglioAction.crea,
          child: Row(
            children: [
              Icon(Icons.add_circle_outline),
              SizedBox(width: 8),
              Text(context.l10n.commonNew),
            ],
          ),
        ),
        PopupMenuItem(
          value: _DettaglioAction.modifica,
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 8),
              Text(context.l10n.prodottiModifica),
            ],
          ),
        ),
        if (showBulkEdit)
          PopupMenuItem(
            value: _DettaglioAction.modificaInMassa,
            child: Row(
              children: [
                Icon(Icons.edit_note_outlined),
                SizedBox(width: 8),
                Text(context.l10n.prodottiModificaInMassa),
              ],
            ),
          ),
        PopupMenuItem(
          value: _DettaglioAction.elimina,
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 8),
              Text(context.l10n.commonDelete),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.18)),
        ),
        child: Icon(Icons.more_vert_rounded, color: theme.primaryColor),
      ),
    );
  }
}

class _DettaglioHero extends StatefulWidget {
  final ProdottoGlobal prodotto;
  final String currentImage;
  final List<String> galleryImages;
  final ValueChanged<String> onSelectImage;

  const _DettaglioHero({
    required this.prodotto,
    required this.currentImage,
    required this.galleryImages,
    required this.onSelectImage,
  });

  @override
  State<_DettaglioHero> createState() => _DettaglioHeroState();
}

class _DettaglioHeroState extends State<_DettaglioHero> {
  final ScrollController _galleryScrollController = ScrollController();

  @override
  void dispose() {
    _galleryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PaneCard(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageHeight = (constraints.maxWidth * 0.75).clamp(
                    220.0,
                    360.0,
                  );
                  return SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.16),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: theme.colorScheme.surface,
                                child: widget.currentImage.trim().isEmpty
                                    ? _ImagePlaceholder(height: imageHeight)
                                    : Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Image.network(
                                          widget.currentImage,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              _ImagePlaceholder(
                                                height: imageHeight,
                                              ),
                                        ),
                                      ),
                              ),
                            ),
                            if (widget.currentImage.trim().isNotEmpty)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: FilledButton.icon(
                                  onPressed: () => _openImageViewer(
                                    context,
                                    widget.currentImage,
                                    title:
                                        widget.prodotto.nome ??
                                        'Immagine prodotto',
                                    imageUrls: widget.galleryImages,
                                  ),
                                  icon: const Icon(
                                    Icons.zoom_out_map,
                                    size: 18,
                                  ),
                                  label: Text(context.l10n.prodottiApri),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.galleryImages.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Foto prodotto',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 86,
                  child: Scrollbar(
                    controller: _galleryScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: ListView.separated(
                      controller: _galleryScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: widget.galleryImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final imageUrl = widget.galleryImages[index];
                        return _ImageThumbnail(
                          imageUrl: imageUrl,
                          isActive: imageUrl == widget.currentImage,
                          onTap: () => widget.onSelectImage(imageUrl),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scorri la barra per vedere tutte le foto. Tocca una miniatura per cambiare immagine.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadonlyInfoCard extends StatelessWidget {
  final ProdottoGlobal prodotto;
  final ProdottoPricingInfo prezzoInfo;

  const _ReadonlyInfoCard({required this.prodotto, required this.prezzoInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return _PaneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.info_outline,
            title: context.l10n.prodottiInformazioniProdotto,
          ),
          const SizedBox(height: _kDetailGap),
          _InfoRow(label: 'ID', value: '${prodotto.id ?? '-'}'),
          _InfoRow(
            label: 'Codice articolo / SKU',
            value: prodotto.codiceProdotto ?? '-',
          ),
          _InfoRow(label: 'Barcode', value: prodotto.barcodeInterno ?? '-'),
          _InfoRow(
            label: 'Barcode produttore',
            value: prodotto.barcodeProduttore ?? '-',
          ),
          // Categorie con chip
          _InfoRowWithChips(
            label: 'Categoria',
            items: prodotto.categoria?.map((c) => c.nome).toList() ?? [],
            color: customColors.stockAvailable,
            icon: Icons.category_outlined,
            emptyText: 'Nessuna categoria',
          ),
          // Tag con chip
          _InfoRowWithChips(
            label: 'Tag',
            items: prodotto.tag?.map((t) => t.nome).toList() ?? [],
            color: theme.primaryColor,
            icon: Icons.tag,
            emptyText: 'Nessun tag',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InlineInfoField(
                  label: 'Stato',
                  value: ProdottoUtils.getStatusLabel(
                    context.l10n,
                    prodotto.status,
                  ),
                  valueColor: prodotto.status.trim().toLowerCase() == 'draft'
                      ? customColors.warningColor
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineInfoField(
                  label: 'Disponibilità',
                  value: ClassFormtter.getDisponibilitaText(prodotto.inStock),
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Su smartphone (~85px per colonna) i tre campi sarebbero
              // illeggibili: impila in verticale sotto i 360px.
              final prezzoFields = <Widget>[
                _InlineInfoField(
                  label: 'Prezzo',
                  value: prezzoInfo.prezzoLabel,
                ),
                _InlineInfoField(
                  label: 'Sconto',
                  value: prezzoInfo.scontoLabel,
                ),
                _InlineInfoField(
                  label: '%',
                  value: prezzoInfo.percentualeScontoLabel,
                ),
              ];
              if (constraints.maxWidth < 360) {
                return Column(
                  children: [
                    for (var i = 0; i < prezzoFields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      prezzoFields[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < prezzoFields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: prezzoFields[i]),
                  ],
                ],
              );
            },
          ),
          _InfoRow(label: 'Marca', value: prodotto.marca ?? '-'),
        ],
      ),
    );
  }
}

class _VariantFiltersCard extends StatelessWidget {
  final Map<String, List<AttributoVariante>> opzioniFiltro;
  final Map<String, Set<String>> opzioniEsaurite;
  final Map<String, String> filtriAttivi;
  final bool filtraSoloInStock;
  final void Function(String nomeAttributo, String opzione) onFilterSelected;
  final VoidCallback onClearFilters;
  final ValueChanged<bool> onToggleStockOnly;

  const _VariantFiltersCard({
    required this.opzioniFiltro,
    required this.opzioniEsaurite,
    required this.filtriAttivi,
    required this.filtraSoloInStock,
    required this.onFilterSelected,
    required this.onClearFilters,
    required this.onToggleStockOnly,
  });

  @override
  Widget build(BuildContext context) {
    if (opzioniFiltro.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return _PaneCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      borderRadius: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.filter_alt_outlined,
                  title: context.l10n.prodottiFiltraVarianti,
                ),
              ),
              if (filtriAttivi.isNotEmpty)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: Text(context.l10n.sharedPulisci),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...opzioniFiltro.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 16,
                        color: customColors.subtitleColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: customColors.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((opzione) {
                      final selected =
                          filtriAttivi[entry.key] == opzione.opzione;
                      final esaurita =
                          opzioniEsaurite[entry.key]?.contains(
                            opzione.opzione,
                          ) ??
                          false;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: FilterChip(
                          label: Text(opzione.opzione),
                          selected: selected,
                          onSelected: (_) =>
                              onFilterSelected(entry.key, opzione.opzione),
                          selectedColor: theme.primaryColor,
                          backgroundColor: esaurita
                              ? customColors.stockUnavailable.withValues(
                                  alpha: 0.16,
                                )
                              : theme.colorScheme.surface,
                          checkmarkColor: theme.colorScheme.onPrimary,
                          side: BorderSide(
                            color: selected
                                ? theme.primaryColor
                                : (esaurita
                                      ? customColors.stockUnavailable
                                            .withValues(alpha: 0.6)
                                      : theme.dividerColor.withValues(
                                          alpha: 0.4,
                                        )),
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : (esaurita
                                      ? customColors.stockUnavailable
                                      : theme.textTheme.bodyMedium?.color),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
          const SizedBox(height: 4),
          CheckboxListTile(
            value: filtraSoloInStock,
            onChanged: (value) => onToggleStockOnly(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.l10n.prodottiMostraSoloDisponibili),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }
}

// Kept temporarily for the existing quick-edit controls; the entry point is
// now the product actions menu.
// ignore: unused_element
class _QuickEditCard extends StatelessWidget {
  final bool isEditMode;
  final bool isSaving;
  final bool isMultiEdit;
  final bool bulkDelete;
  final List<String> selectedCategoryNames;
  final List<String> selectedTagNames;
  final String? selectedStatus;
  final VoidCallback onToggleEdit;
  final Future<void> Function() onCancelEdit;
  final Future<void> Function() onSaveAll;
  final ValueChanged<bool> onBulkDeleteChanged;
  final Future<void> Function() onOpenCategoryPicker;
  final Future<void> Function() onOpenTagPicker;
  final ValueChanged<String?> onStatusChanged;

  const _QuickEditCard({
    required this.isEditMode,
    required this.isSaving,
    required this.isMultiEdit,
    required this.bulkDelete,
    required this.selectedCategoryNames,
    required this.selectedTagNames,
    required this.selectedStatus,
    required this.onToggleEdit,
    required this.onCancelEdit,
    required this.onSaveAll,
    required this.onBulkDeleteChanged,
    required this.onOpenCategoryPicker,
    required this.onOpenTagPicker,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PaneCard(
      tinted: true,
      padding: const EdgeInsets.all(_kDetailPanePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.edit_note_outlined,
            title: isMultiEdit ? 'Modifica in massa' : 'Modifica rapida',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: (isSaving || isEditMode) ? null : onToggleEdit,
                icon: Icon(isEditMode ? Icons.lock_open : Icons.edit),
                label: Text(isEditMode ? 'Modifica attiva' : 'Modifica rapida'),
              ),
              if (isEditMode)
                OutlinedButton(
                  onPressed: isSaving ? null : onCancelEdit,
                  child: Text(context.l10n.commonAnnulla),
                ),
              if (isEditMode)
                FilledButton.icon(
                  onPressed: isSaving ? null : onSaveAll,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(context.l10n.prodottiSalvaTutto),
                ),
            ],
          ),
          if (isEditMode) ...[
            const SizedBox(height: 16),
            if (isMultiEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Modalita multi-select: sono editabili categorie, tag, stato ed eliminazione.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onOpenCategoryPicker,
                  icon: const Icon(Icons.category_outlined),
                  label: Text(
                    selectedCategoryNames.isEmpty
                        ? 'Categorie'
                        : 'Categorie (${selectedCategoryNames.length})',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onOpenTagPicker,
                  icon: const Icon(Icons.tag),
                  label: Text(
                    selectedTagNames.isEmpty
                        ? 'Tag'
                        : 'Tag (${selectedTagNames.length})',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: (selectedStatus ?? '').trim().isEmpty
                        ? null
                        : selectedStatus,
                    decoration: InputDecoration(
                      labelText: context.l10n.prodottiStato,
                      isDense: true,
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'publish',
                        child: Text(context.l10n.prodottiPubblico),
                      ),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text(context.l10n.prodottiPrivato),
                      ),
                      DropdownMenuItem(
                        value: 'draft',
                        child: Text(context.l10n.prodottiBozza),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(context.l10n.prodottiInRevisione),
                      ),
                    ],
                    onChanged: isSaving ? null : onStatusChanged,
                  ),
                ),
              ],
            ),
            if (isMultiEdit) ...[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: bulkDelete,
                onChanged: isSaving ? null : onBulkDeleteChanged,
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.prodottiEliminaSelezionati),
                subtitle: const Text(
                  'Usa soft/hard delete in base alle impostazioni.',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _VariantsListCard extends StatelessWidget {
  final List<VarianteProductGlobal> varianti;
  final int? selectedVarianteId;
  final ValueChanged<VarianteProductGlobal> onSelect;
  final bool modalitaSelezioneCassa;
  final Set<int> variantiSelezionateCassa;
  final void Function(VarianteProductGlobal variante, bool selected)?
  onVarianteCassaChecked;
  final bool isEditMode;
  final Map<int, TextEditingController> variantPriceCtrls;
  final Map<int, TextEditingController> variantQtyCtrls;

  const _VariantsListCard({
    required this.varianti,
    required this.selectedVarianteId,
    required this.onSelect,
    this.modalitaSelezioneCassa = false,
    this.variantiSelezionateCassa = const <int>{},
    this.onVarianteCassaChecked,
    required this.isEditMode,
    required this.variantPriceCtrls,
    required this.variantQtyCtrls,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return _PaneCard(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.palette,
            title: context.l10n.prodottiVariantiDisponibili,
            trailing: _StatusPill(
              label: '${varianti.length}',
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (varianti.isEmpty)
            modalitaSelezioneCassa
                ? Text(
                    'Questo prodotto non ha varianti: selezionalo con il '
                    'pulsante qui sopra per aggiungerlo alla cassa.',
                    style: theme.textTheme.bodyMedium,
                  )
                : Text(
                    'Nessuna variante trovata.',
                    style: theme.textTheme.bodyMedium,
                  )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: varianti.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final variante = varianti[index];
                final isSelected = variante.id == selectedVarianteId;
                final isCheckedForCassa = variantiSelezionateCassa.contains(
                  variante.id,
                );
                final isOutOfStock = variante.quantita < 1;
                return InkWell(
                  onTap: () => onSelect(variante),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? (isOutOfStock
                                ? customColors.stockUnavailable.withValues(
                                    alpha: 0.24,
                                  )
                                : customColors.variantSelectedBackground)
                          : (isOutOfStock
                                ? customColors.stockUnavailable.withValues(
                                    alpha: 0.14,
                                  )
                                : theme.colorScheme.surfaceContainerLowest
                                      .withValues(alpha: 0.72)),
                      border: Border.all(
                        color: isOutOfStock
                            ? customColors.stockUnavailable.withValues(
                                alpha: isSelected ? 0.8 : 0.5,
                              )
                            : (isSelected
                                  ? theme.colorScheme.outlineVariant
                                  : theme.colorScheme.outlineVariant.withValues(
                                      alpha: 0.55,
                                    )),
                        width: isSelected ? 0.8 : 0.6,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (modalitaSelezioneCassa) ...[
                              Checkbox(
                                value: isCheckedForCassa,
                                onChanged: (value) => onVarianteCassaChecked
                                    ?.call(variante, value ?? false),
                              ),
                              const SizedBox(width: 0),
                            ],
                            if ((variante.immagineUrl ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              _ImageThumbnail(
                                imageUrl: variante.immagineUrl!,
                                isActive: isSelected,
                                onTap: () => _openImageViewer(
                                  context,
                                  variante.immagineUrl,
                                  title: variante.nomeVisualizzabile,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variante.nomeVisualizzabile,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isOutOfStock
                                          ? customColors.stockUnavailable
                                          : (isSelected
                                                ? theme.colorScheme.onSurface
                                                : null),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Barcode interno: ${variante.barcodeInterno}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (variante.attributi.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      variante.attributi
                                          .map(
                                            (item) =>
                                                '${item.nome}: ${item.opzione}',
                                          )
                                          .join(' • '),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isEditMode) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: variantPriceCtrls[variante.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: context.l10n.commonPrice,
                                    prefixIcon: Icon(Icons.euro),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: variantQtyCtrls[variante.id],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.commonQuantity,
                                    prefixIcon: Icon(
                                      Icons.inventory_2_outlined,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _VariantPriceLabel(variante: variante),
                            _StatusPill(
                              label: isOutOfStock ? 'Esaurito' : 'Disponibile',
                              color: isOutOfStock
                                  ? customColors.stockUnavailable
                                  : customColors.stockAvailable,
                            ),
                            Text(
                              'Qty ${variante.quantita}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VariantPriceLabel extends StatelessWidget {
  final VarianteProductGlobal variante;

  const _VariantPriceLabel({required this.variante});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prezzoScontato = variante.prezzoScontato;
    final hasSconto =
        prezzoScontato != null && prezzoScontato != variante.prezzo;

    if (!hasSconto) {
      return Text(
        ClassFormtter.formatPrezzo(variante.prezzo),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ClassFormtter.formatPrezzo(prezzoScontato),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ClassFormtter.formatPrezzo(variante.prezzo),
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                ),
              ),
              child: SelectableText(value, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo compatto usato nelle righe con più informazioni affiancate.
/// L'altezza fissa mantiene label e valore perfettamente allineati.
class _InlineInfoField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InlineInfoField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 42,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Nelle due colonne del dettaglio mobile lo spazio può essere
            // inferiore alla larghezza storica dell'etichetta.
            final labelWidth = (constraints.maxWidth * 0.4).clamp(28.0, 88.0);
            return Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    '$label:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SelectableText(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: valueColor,
                        fontWeight: valueColor == null ? null : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRowWithChips extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  final IconData icon;
  final String emptyText;

  const _InfoRowWithChips({
    required this.label,
    required this.items,
    required this.color,
    required this.icon,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      emptyText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              item,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imageUrl;
  final bool isActive;
  final VoidCallback onTap;

  const _ImageThumbnail({
    required this.imageUrl,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.45),
            width: isActive ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.network(
            resolveImageUrl(imageUrl) ?? '',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const _ImagePlaceholder(height: 74),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double height;

  const _ImagePlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      color: theme.primaryColor.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: theme.primaryColor.withValues(alpha: 0.55),
        size: 36,
      ),
    );
  }
}
