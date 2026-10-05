import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../class_prodotti.dart';
import '../../theme/theme.dart';
import '../../settings/app_settings.dart';
import '../../settings/prodotti_image_settings.dart';
import '../../login/jwt_api/class_prodotti.dart' as woo_models;
import '../../ai/ai_service.dart';
import '../../log_viewer/app_logger.dart';
import '../../notification/notification_service.dart';
import '../../reuse_class/gui/searchable_checkbox_dialog.dart';
import '../../reuse_class/gui/notification_recap_dialog.dart';
import '../../reuse_class/datagridview/datagridview_cache.dart';
import '../../reuse_class/image_url_resolver.dart';
import '../../reuse_class/barcode/barcode_generator.dart';
import '../../traduzioni/estensioni.dart';
import 'prodotti_crea.code.dart';
import 'variant_combinations.dart';
import 'widgets/media_selector_dialog.dart';

Future<bool?> openProductEditor(
  BuildContext context, {
  int? prodottoIdDaModificare,
  String? codiceProdotto,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ProdottiCreaPage(
        prodottoIdDaModificare: prodottoIdDaModificare,
        codiceProdotto: codiceProdotto,
      ),
    ),
  );
}

class ProdottiCreaPage extends StatefulWidget {
  final int? prodottoIdDaModificare;
  final String? codiceProdotto;
  final ProdottiCreaController? controller;

  const ProdottiCreaPage({
    super.key,
    this.prodottoIdDaModificare,
    this.codiceProdotto,
    this.controller,
  });

  @override
  State<ProdottiCreaPage> createState() => _ProdottiCreaPageState();
}

enum ProductTypeSelection { simple, variable }

const List<String> _productStatusOptions = <String>[
  'draft',
  'publish',
  'private',
  'pending',
];

class _ProdottiCreaPageState extends State<ProdottiCreaPage>
    with TickerProviderStateMixin {
  // Form e Controllers
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _codiceProdottoController = TextEditingController();
  final _barcodeInternoController = TextEditingController();
  final _barcodeProduttoreController = TextEditingController();
  final _prezzoNormaleController = TextEditingController();
  final _prezzoScontatoController = TextEditingController();
  final _descrizioneBreveController = TextEditingController();
  final _descrizioneCompletaController = TextEditingController();
  final _immagineUrlController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _pesoController = TextEditingController();
  final _quantitaController = TextEditingController();
  final _quickVarianteBarcodeInternoController = TextEditingController();
  final _quickVarianteBarcodeController = TextEditingController();
  final _quickVarianteQuantitaController = TextEditingController(text: '0');
  final _quickVarianteTagliaController = TextEditingController();
  final _quickVarianteColoreController = TextEditingController();
  final _mgwsStockController = TextEditingController();

  /// Sede in cui il totale di stock appena salvato viene scritto.
  ///
  /// Vuota e libera perche' questa schermata non conosce il profilo dell'utente
  /// e non sa se il negozio ha piu' sedi. Lasciarla vuota e' un caso lecito: la
  /// rotta accetta l'assenza di sede solo su un negozio con una sola sede, dove
  /// il totale del prodotto e il totale della sede coincidono. Su un negozio con
  /// piu' sedi la rotta risponde che la sede serve, e il prodotto resta salvato
  /// senza stock, che e' uno stato che l'operatore puo' vedere e correggere.
  final _mgwsSiteController = TextEditingController();
  final _mgwsReasonController = TextEditingController();

  // Animazioni
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Stato della UI
  bool _inStock = true;
  bool _hasPrezzoScontato = false;
  ProductTypeSelection? _productType;
  String _productStatus = 'draft';
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isUpdatingExisting = false;
  String? _initializationError;
  int _currentStep = 0;
  int? _selectedVarianteIndex;
  double _saveProgress = 0.0;
  String _saveProgressLabel = '';
  bool _mgwsInventoryEnabled = false;
  String? _mgwsInventoryFeedbackText;
  bool? _mgwsInventoryFeedbackSuccess;
  bool _defaultMgwsReasonInitialized = false;
  final List<FocusNode> _barcodeFocusNodes = [];
  final Map<int, String> _barcodePreviousValues = {};
  final List<TextEditingController> _barcodeControllers = [];

  // Stato IA
  bool _isGeneratingShortDesc = false;
  bool _isGeneratingLongDesc = false;
  bool _isGeneratingCategories = false;
  bool _isGeneratingTags = false;

  // Dati
  List<VarianteTemp> _varianti = [];
  List<AttributoVariante> _attributiProdottoEsistenti = [];
  List<AttributoProdottoSelezionato> _attributiProdottoSelezionati = [];
  List<String> _categorieSelezionate = [];
  List<String> _tags = [];
  ProdottoGlobal? _prodottoOriginale;
  final ProductImageUiConfig _mainImageConfig = ProductImageUiConfig();
  final ProductImageUiConfig _defaultImageConfig = ProductImageUiConfig();
  List<String> _mainImageSetUrls = [];
  final Map<String, woo_models.MediaFile> _mainImageMetadata = {};
  final Map<String, _ImagePixelSize> _resolvedImagePixelSizes = {};
  final Set<String> _failedImagePixelSizeUrls = {};
  final Set<String> _loadingImagePixelSizeUrls = {};
  final Set<String> _selectedImageUrls = {};
  bool _showImageDimensionWarnings = true;
  int _imageWarningThresholdWidth = 720;
  int _imageWarningThresholdHeight = 1080;

  // Autocompletamento
  List<String> _suggerimentiCategoria = [];
  List<String> _suggerimentiMarca = [];
  List<String> _suggerimentiAttributi = [];
  Map<String, List<String>> _suggerimentiOpzioni = {};

  // Servizi
  ProdottiCreaController? _prodottiController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Inizializzazione ritardata per evitare dipendenze circolari
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inizializzaPagina();
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultMgwsReasonInitialized &&
        _mgwsReasonController.text.trim().isEmpty) {
      _mgwsReasonController.text = _defaultMgwsInventoryReason();
      _defaultMgwsReasonInitialized = true;
    }
  }

  Future<void> _inizializzaPagina() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      // Inizializza il controller (usa PlatformManager internamente)
      _prodottiController = widget.controller ?? ProdottiCreaController();
      await Future.wait([
        _caricaDatiAutocompletamento(),
        _caricaImpostazioniImmaginiDefault(),
      ]);

      final prodottoId = widget.prodottoIdDaModificare ?? 0;
      final codiceProdotto = widget.codiceProdotto?.trim() ?? '';
      if (prodottoId > 0 || codiceProdotto.isNotEmpty) {
        final prodottoFresco = await _prodottiController!
            .getFreshProductForEdit(
              productId: prodottoId > 0 ? prodottoId : null,
              codiceProdotto: codiceProdotto.isEmpty ? null : codiceProdotto,
            );
        await _caricaDatiProdottoEsistente(prodottoFresco);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializationError = '${context.l10n.productsFormInitFailed}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _caricaDatiAutocompletamento() async {
    if (_prodottiController == null) return;

    try {
      log.d('PCREA_AUTOCOMPLETE_START');
      await Future.wait([
        _prodottiController!
            .getAttributes()
            .then((attributes) async {
              _suggerimentiAttributi = attributes
                  .map((a) => a.name as String? ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList();
              for (final attr in attributes) {
                try {
                  if (attr.id != null && attr.name != null) {
                    final terms = await _prodottiController!.getAttributeTerms(
                      attr.id!,
                    );
                    _suggerimentiOpzioni[attr.name!] = terms
                        .map((t) => t.name as String? ?? '')
                        .where((n) => n.isNotEmpty)
                        .toList();
                  }
                } catch (e) {
                  log.d('Errore caricamento termini per ${attr.name}: $e');
                }
              }
            })
            .catchError((e) {
              log.d('Errore caricamento attributi: $e');
              log.e('PCREA_AUTOCOMPLETE_ATTRIBUTES_FAIL $e');
              return null;
            }),

        _prodottiController!
            .getCategories()
            .then((categories) {
              _suggerimentiCategoria = categories.map((c) => c.nome).toList();
            })
            .catchError((e) {
              log.d('Errore caricamento categorie: $e');
              log.e('PCREA_AUTOCOMPLETE_CATEGORIES_FAIL $e');
              return null;
            }),

        _prodottiController!
            .getBrands()
            .then((brands) {
              _suggerimentiMarca = brands.map((b) => b.nome).toSet().toList();
            })
            .catchError((e) {
              log.d('Errore caricamento marchi: $e');
              log.e('PCREA_AUTOCOMPLETE_BRANDS_FAIL $e');
              return null;
            }),
      ]);
      log.d('PCREA_AUTOCOMPLETE_DONE');
    } catch (e) {
      log.d('Errore generale caricamento dati: $e');
      log.e('PCREA_AUTOCOMPLETE_FAIL $e');
    }
  }

  Future<void> _caricaImpostazioniImmaginiDefault() async {
    final settings = ProductImageWarningSettings();
    await settings.init();

    if (!mounted) return;

    setState(() {
      _showImageDimensionWarnings = settings.warningsEnabled;
      _imageWarningThresholdWidth = settings.thresholdWidth;
      _imageWarningThresholdHeight = settings.thresholdHeight;
    });
  }

  void _applyDefaultImageConfig(ProductImageUiConfig target) {
    target.isSetMode = false;
  }

  ProductImageUiConfig _newImageConfigFromDefaults() {
    final config = ProductImageUiConfig();
    _applyDefaultImageConfig(config);
    return config;
  }

  Future<void> _caricaDatiProdottoEsistente(ProdottoGlobal prodotto) async {
    final int productId = prodotto.id ?? 0;
    log.d(
      'PCREA_LOAD_EXISTING_START productId=$productId sku=${prodotto.barcodeInterno}',
    );

    List<VarianteProductGlobal> variantiServer = prodotto.varianti ?? [];
    if (productId > 0 && _prodottiController != null) {
      try {
        final ricaricate = await _prodottiController!.getAllVarianti(
          productId,
          attributiProdotto: prodotto.attributi,
          logRawAttributeMapping: true,
        );
        log.d(
          'PCREA_LOAD_EXISTING_VARIANTS productId=$productId count=${ricaricate.length}',
        );
        // Protezione: se il server risponde ma con attributi vuoti mentre il
        // prodotto passato da "gestisci" aveva varianti con attributi validi,
        // non sovrascrivere con dati degradati.
        final ricaricateDegradate =
            ricaricate.isNotEmpty &&
            ricaricate.every((v) => v.attributi.isEmpty) &&
            variantiServer.any((v) => v.attributi.isNotEmpty);
        if (!ricaricateDegradate) {
          variantiServer = ricaricate;
        } else {
          log.w(
            'PCREA_LOAD_EXISTING_VARIANTS_DEGRADED productId=$productId keep=${variantiServer.length}',
          );
        }
      } catch (e) {
        log.e(
          'PCREA_LOAD_EXISTING_VARIANTS_FAIL productId=$productId error=$e',
        );
      }
    }

    if (!mounted) return;

    for (final attributo in _attributiProdottoSelezionati) {
      attributo.dispose();
    }

    setState(() {
      _isUpdatingExisting = true;
      _prodottoOriginale = prodotto.copyWith(varianti: variantiServer);
      _nomeController.text = prodotto.nome ?? '';
      _codiceProdottoController.text = prodotto.codiceProdotto ?? '';
      _barcodeInternoController.text = prodotto.barcodeInterno ?? '';
      _barcodeProduttoreController.text = prodotto.barcodeProduttore ?? '';
      _prezzoNormaleController.text = (prodotto.prezzoNormale ?? 0).toString();
      _prezzoScontatoController.text =
          prodotto.prezzoScontato?.toString() ?? '';
      _hasPrezzoScontato = prodotto.prezzoScontato != null;
      _productType = (variantiServer.isNotEmpty || prodotto.isVariabile)
          ? ProductTypeSelection.variable
          : ProductTypeSelection.simple;
      _descrizioneBreveController.text = prodotto.descrizioneBreve ?? '';
      _descrizioneCompletaController.text = prodotto.descrizioneCompleta ?? '';
      _immagineUrlController.text = prodotto.immagineUrl ?? '';
      _categorieSelezionate =
          prodotto.categoria?.map((c) => c.nome).toList() ?? [];
      _categoriaController.text = _categorieSelezionate.join(', ');
      _marcaController.text = prodotto.marca ?? '';
      _pesoController.text = prodotto.peso ?? '';
      _quantitaController.text = (prodotto.quantitaTotale ?? 0).toString();
      _inStock = prodotto.inStock;
      _mgwsInventoryEnabled = false;
      _mgwsStockController.clear();
      _mgwsSiteController.clear();
      _mgwsReasonController.text = _defaultMgwsInventoryReason();
      _mgwsInventoryFeedbackText = null;
      _mgwsInventoryFeedbackSuccess = null;
      _productStatus = _normalizeProductStatus(prodotto.status);
      _tags = prodotto.tag?.map((t) => t.nome).toList() ?? [];
      _applyDefaultImageConfig(_mainImageConfig);
      _mainImageSetUrls = List<String>.from(prodotto.immaginiAggiuntive ?? []);
      _mainImageConfig.isSetMode = _mainImageSetUrls.isNotEmpty;
      _mainImageMetadata.clear();
      _resolvedImagePixelSizes.clear();
      _failedImagePixelSizeUrls.clear();
      _loadingImagePixelSizeUrls.clear();
      _selectedImageUrls.clear();
      _varianti = variantiServer
          .map(
            (v) =>
                VarianteTemp.fromVarianteProductGlobal(v, _defaultImageConfig),
          )
          .toList();
      _attributiProdottoEsistenti = _collectProductAttributes(
        prodotto: prodotto,
        varianti: _varianti,
      );
      // In modifica le varianti esistenti restano disponibili, ma il
      // compositore parte vuoto: gli attributi da aggiungere sono una scelta
      // esplicita dell'utente e non vengono precompilati da quelli esistenti.
      _attributiProdottoSelezionati = [];
      _syncBarcodeFocusNodes();
      _selectedVarianteIndex = _varianti.isEmpty ? null : 0;
    });

    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      context.l10n.productsDataLoadedForEdit(prodotto.nome ?? ''),
    );
    log.d('PCREA_LOAD_EXISTING_DONE productId=$productId');
  }

  void _resetForm() {
    setState(() {
      _isUpdatingExisting = false;
      _prodottoOriginale = null;
      _currentStep = 0;
      _formKey.currentState?.reset();
      _nomeController.clear();
      _codiceProdottoController.clear();
      _barcodeInternoController.clear();
      _barcodeProduttoreController.clear();
      _prezzoNormaleController.clear();
      _prezzoScontatoController.clear();
      _descrizioneBreveController.clear();
      _descrizioneCompletaController.clear();
      _immagineUrlController.clear();
      _categoriaController.clear();
      _categorieSelezionate = [];
      _marcaController.clear();
      _pesoController.clear();
      _quantitaController.clear();
      _quickVarianteBarcodeInternoController.clear();
      _quickVarianteBarcodeController.clear();
      _quickVarianteQuantitaController.text = '0';
      _quickVarianteTagliaController.clear();
      _quickVarianteColoreController.clear();
      _mgwsStockController.clear();
      _mgwsSiteController.clear();
      _mgwsReasonController.text = _defaultMgwsInventoryReason();
      _mgwsInventoryEnabled = false;
      _mgwsInventoryFeedbackText = null;
      _mgwsInventoryFeedbackSuccess = null;
      for (final attributo in _attributiProdottoSelezionati) {
        attributo.dispose();
      }
      _attributiProdottoSelezionati = [];
      _attributiProdottoEsistenti = [];
      _varianti.clear();
      _syncBarcodeFocusNodes();
      _selectedVarianteIndex = null;
      _tags.clear();
      _applyDefaultImageConfig(_mainImageConfig);
      _mainImageSetUrls = [];
      _mainImageMetadata.clear();
      _resolvedImagePixelSizes.clear();
      _failedImagePixelSizeUrls.clear();
      _loadingImagePixelSizeUrls.clear();
      _selectedImageUrls.clear();
      _inStock = true;
      _hasPrezzoScontato = false;
      _productType = null;
      _productStatus = 'draft';
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nomeController.dispose();
    _codiceProdottoController.dispose();
    _barcodeInternoController.dispose();
    _barcodeProduttoreController.dispose();
    _prezzoNormaleController.dispose();
    _prezzoScontatoController.dispose();
    _descrizioneBreveController.dispose();
    _descrizioneCompletaController.dispose();
    _immagineUrlController.dispose();
    _categoriaController.dispose();
    _marcaController.dispose();
    _pesoController.dispose();
    _quantitaController.dispose();
    _quickVarianteBarcodeInternoController.dispose();
    _quickVarianteBarcodeController.dispose();
    _quickVarianteQuantitaController.dispose();
    _quickVarianteTagliaController.dispose();
    _quickVarianteColoreController.dispose();
    _mgwsStockController.dispose();
    _mgwsSiteController.dispose();
    _mgwsReasonController.dispose();
    for (final attributo in _attributiProdottoSelezionati) {
      attributo.dispose();
    }
    for (final node in _barcodeFocusNodes) {
      node.dispose();
    }
    for (final controller in _barcodeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        // Aggiunge il tema per la selezione del testo (cursore e highlight)
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primaryColor,
          selectionColor: primaryColor.withValues(alpha: 0.3),
          selectionHandleColor: primaryColor,
        ),
        // cardTheme: CardTheme(
        //   elevation: 6,
        //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        //   shadowColor: Colors.black26,
        // ),
      ),
      child: Scaffold(
        body: _buildBody(),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).extension<AppColorExtension>()?.gradientStart ??
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).extension<AppColorExtension>()?.gradientEnd ??
                Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isInitializing)
            _buildLoadingSliver()
          else if (_initializationError != null)
            _buildErrorSliver()
          else
            _buildContentSliver(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isUpdatingExisting
                ? context.l10n.productsEditTitle
                : context.l10n.productsNewTitle,
            key: ValueKey(_isUpdatingExisting),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isUpdatingExisting)
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: context.l10n.productsTooltipCreateNew,
            onPressed: _resetForm,
          ),
        if (_prodottiController != null)
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            tooltip: context.l10n.productsTooltipSaveProduct,
            onPressed: _isLoading ? null : _salvaProdotto,
          ),
      ],
    );
  }

  Widget _buildLoadingSliver() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.commonLoading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.productsPreparingProductsUi,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.productsOfflineMode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _initializationError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(context.l10n.commonBack),
                      ),
                      FilledButton.icon(
                        onPressed: _inizializzaPagina,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.employeesRetry),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _initializationError = null;
                            _prodottiController = null;
                          });
                        },
                        icon: const Icon(Icons.edit),
                        label: Text(context.l10n.productsContinueOffline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isUpdatingExisting) _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildStepperContent(),
                  if (_isLoading) ...[
                    const SizedBox(height: 12),
                    _buildSaveProgressSection(),
                  ],
                  // Spazio di rispetto per il FAB "Salva Prodotto": su
                  // smartphone coprirebbe l'ultimo campo del form.
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.productsEditMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.l10n.productsEditModeDetails(
                      '${_prodottoOriginale?.id}',
                      '${_prodottoOriginale?.barcodeInterno}',
                    ),
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

  Widget _buildStepperContent() {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
      ),
      child: Stepper(
        // La Stepper verticale usa internamente una ListView. In questa pagina
        // pero' lo scroll principale e' gia' il CustomScrollView esterno: se la
        // ListView interna resta scrollabile, su smartphone intercetta il drag e
        // la pagina sembra non scorrere. Disattiviamo quindi lo scroll interno e
        // lasciamo scorrere tutta la pagina come un unico form.
        physics: const NeverScrollableScrollPhysics(),
        currentStep: _currentStep,
        onStepTapped: (step) {
          if (step > 0 && !_ensureProductTypeSelected()) return;
          setState(() => _currentStep = step);
        },
        onStepContinue: () {
          if (_currentStep == 0 && !_ensureProductTypeSelected()) return;
          if (_currentStep < 4) {
            setState(() => _currentStep += 1);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (details.stepIndex < 4)
                FilledButton.icon(
                  onPressed: details.onStepContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(context.l10n.commonNext),
                ),
              if (details.stepIndex > 0) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: Text(context.l10n.commonBack),
                ),
              ],
            ],
          );
        },
        steps: [
          Step(
            title: Text(context.l10n.productsStepBaseInfo),
            content: _buildInformazioniGenerali(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(context.l10n.productsStepPricesAndStock),
            content: _buildPrezziEStock(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(context.l10n.productsStepImages),
            content: _buildImmagini(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(context.l10n.productsStepDetails),
            content: _buildDettagli(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(context.l10n.productsStepVariants),
            content: _buildVarianti(),
            isActive: _currentStep >= 4,
            state: _currentStep == 4 ? StepState.indexed : StepState.disabled,
          ),
        ],
      ),
    );
  }

  bool _ensureProductTypeSelected() {
    if (_productType != null) return true;
    NotificationService.instance.messageBar(
      'warning',
      'prodotti_crea',
      context.l10n.productsSelectTypeFirst,
    );
    if (_currentStep != 0) {
      setState(() => _currentStep = 0);
    }
    return false;
  }

  Widget _buildInformazioniGenerali() {
    final canEditProductFields = _productType != null;
    // Sezioni barcode: visibili solo per prodotti Semplice (punto 9)
    final _barcodeSection = _productType == ProductTypeSelection.simple
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSmartTextFormField(
                  controller: _barcodeInternoController,
                  label: 'Barcode',
                  icon: Icons.qr_code,
                  validator: (v) => (v == null || v.isEmpty)
                      ? context.l10n.productsRequiredField
                      : null,
                  required: true,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildGeneraBarcodeButton(
                  onPressed: _generaBarcodePrincipale,
                ),
              ),
            ],
          )
        : SizedBox.shrink();

    final _barcodeProduttoreSection =
        _productType == ProductTypeSelection.simple
        ? _buildSmartTextFormField(
            controller: _barcodeProduttoreController,
            label: context.l10n.productsBarcodeManufacturer,
            icon: Icons.qr_code_2,
          )
        : SizedBox.shrink();

    return Column(
      children: [
        _buildProductTypeField(),
        const SizedBox(height: 16),
        AbsorbPointer(
          absorbing: !canEditProductFields,
          child: Opacity(
            opacity: canEditProductFields ? 1 : 0.45,
            child: Column(
              children: [
                if (!canEditProductFields) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(context.l10n.productsSelectTypeFirst),
                      subtitle: Text(
                        context.l10n.productsFieldsUnlockAfterTypeChoice,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildSmartTextFormField(
                  controller: _nomeController,
                  label: context.l10n.productsNameLabel,
                  icon: Icons.inventory,
                  validator: (v) => (v == null || v.isEmpty)
                      ? context.l10n.productsRequiredField
                      : null,
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildSmartTextFormField(
                  controller: _codiceProdottoController,
                  label: context.l10n.productsProductCode,
                  icon: Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 16),
                _barcodeSection,
                if (_productType == ProductTypeSelection.simple) ...[
                  const SizedBox(height: 16),
                  _barcodeProduttoreSection,
                ],
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildCategorieField()),
                    const SizedBox(width: 8),
                    _buildAIButton(
                      isLoading: _isGeneratingCategories,
                      tooltip: context.l10n.productsSuggestCategories,
                      onPressed: _generateCategories,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tags con pulsante IA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTagsField()),
                    const SizedBox(width: 8),
                    _buildAIButton(
                      isLoading: _isGeneratingTags,
                      tooltip: context.l10n.productsSuggestTags,
                      onPressed: _generateTags,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Descrizione Breve con pulsante IA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSmartTextFormField(
                        controller: _descrizioneBreveController,
                        label: context.l10n.productsShortDescription,
                        icon: Icons.short_text,
                        maxLines: 3,
                        validator: (v) => (v == null || v.isEmpty)
                            ? context.l10n.productsRequiredField
                            : null,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAIButton(
                      isLoading: _isGeneratingShortDesc,
                      tooltip: context.l10n.productsGenerateWithAi,
                      onPressed: _generateShortDescription,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Descrizione Completa con pulsante IA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSmartTextFormField(
                        controller: _descrizioneCompletaController,
                        label: context.l10n.productsFullDescription,
                        icon: Icons.article,
                        maxLines: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildAIButton(
                      isLoading: _isGeneratingLongDesc,
                      tooltip: context.l10n.productsGenerateWithAi,
                      onPressed: _generateLongDescription,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMarchioField(),
                const SizedBox(height: 16),
                _buildProductStatusField(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductTypeField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.category_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<ProductTypeSelection>(
                initialValue: _productType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.productsTypeRequired,
                  isDense: true,
                ),
                validator: (value) =>
                    value == null ? context.l10n.productsRequiredField : null,
                items: [
                  DropdownMenuItem(
                    value: ProductTypeSelection.simple,
                    child: Text(context.l10n.productsTypeSimple),
                  ),
                  DropdownMenuItem(
                    value: ProductTypeSelection.variable,
                    child: Text(context.l10n.productsTypeWithVariants),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _productType = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStatusField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _productStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.productsStatusRequired,
                  isDense: true,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? context.l10n.productsRequiredField
                    : null,
                items: _productStatusOptions
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(_statusLabel(context, status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _productStatus = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrezziEStock() {
    return Column(
      children: [
        _buildSmartTextFormField(
          controller: _prezzoNormaleController,
          label: context.l10n.productsNormalPrice,
          icon: Icons.euro,
          suffix: '€',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => (v == null || v.isEmpty)
              ? context.l10n.productsRequiredField
              : null,
          required: true,
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: Text(context.l10n.productsSalePrice),
            subtitle: Text(context.l10n.productsEnableSalePriceHint),
            value: _hasPrezzoScontato,
            onChanged: (value) => setState(() => _hasPrezzoScontato = value),
            secondary: const Icon(Icons.local_offer),
          ),
        ),
        if (_hasPrezzoScontato) ...[
          const SizedBox(height: 16),
          _buildSmartTextFormField(
            controller: _prezzoScontatoController,
            label: context.l10n.productsSalePrice,
            icon: Icons.local_offer,
            suffix: '€',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
        const SizedBox(height: 16),
        if (_productType == ProductTypeSelection.simple)
          Row(
            children: [
              Expanded(
                child: _buildSmartTextFormField(
                  controller: _quantitaController,
                  label: context.l10n.commonQuantity,
                  icon: Icons.inventory_2,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final customColors = Theme.of(
                      context,
                    ).extension<AppColorExtension>()!;
                    return Card(
                      child: SwitchListTile(
                        title: Text(context.l10n.productsAvailable),
                        value: _inStock,
                        onChanged: (value) => setState(() => _inStock = value),
                        secondary: Icon(
                          _inStock ? Icons.check_circle : Icons.cancel,
                          color: _inStock
                              ? customColors.successColor
                              : customColors.errorColorStatus,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.productsStockPerVariant),
              subtitle: Text(context.l10n.productsStockPerVariantHint),
            ),
          ),
        const SizedBox(height: 16),
        _buildMgwsInventorySection(),
      ],
    );
  }

  Widget _buildMgwsInventorySection() {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>();
    final feedbackSuccess = _mgwsInventoryFeedbackSuccess ?? false;
    final feedbackColor = feedbackSuccess
        ? customColors?.successColor ?? theme.colorScheme.primary
        : customColors?.warningColor ?? theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('productMgwsInventoryEnabledSwitch'),
              contentPadding: EdgeInsets.zero,
              value: _mgwsInventoryEnabled,
              onChanged: _setMgwsInventoryEnabled,
              secondary: Icon(
                Icons.warehouse_outlined,
                color: _mgwsInventoryEnabled ? theme.primaryColor : null,
              ),
              title: Text(
                context.l10n.productsMgwsInventory,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(context.l10n.productsMgwsInventorySubtitle),
            ),
            Text(
              context.l10n.productsMgwsInventoryDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            if (_mgwsInventoryEnabled) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSmartTextFormField(
                      controller: _mgwsStockController,
                      fieldKey: const ValueKey('productMgwsStockField'),
                      label: context.l10n.productsMgwsTotalStock,
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateMgwsStock,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Facoltativa qui, obbligatoria in fatto su un negozio con piu'
                  // sedi: li' il totale del prodotto e il totale di una sede sono
                  // due numeri diversi, e senza sapere quale dei due si sta
                  // scrivendo il campo non ha un significato.
                  Expanded(
                    child: _buildSmartTextFormField(
                      controller: _mgwsSiteController,
                      fieldKey: const ValueKey('productMgwsSiteField'),
                      label: context.l10n.productsMgwsSite,
                      icon: Icons.storefront_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateMgwsSite,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSmartTextFormField(
                      controller: _mgwsReasonController,
                      fieldKey: const ValueKey('productMgwsReasonField'),
                      label: context.l10n.productsMgwsReasonLabel,
                      icon: Icons.fact_check_outlined,
                      validator: _validateMgwsReason,
                      required: true,
                    ),
                  ),
                ],
              ),
            ],
            if (_mgwsInventoryFeedbackText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: feedbackColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: feedbackColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      feedbackSuccess
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      color: feedbackColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mgwsInventoryFeedbackText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setMgwsInventoryEnabled(bool value) {
    setState(() {
      _mgwsInventoryEnabled = value;
      _mgwsInventoryFeedbackText = null;
      _mgwsInventoryFeedbackSuccess = null;
      if (value && _mgwsReasonController.text.trim().isEmpty) {
        _mgwsReasonController.text = _defaultMgwsInventoryReason();
      }
    });
  }

  String _defaultMgwsInventoryReason() {
    return _isUpdatingExisting
        ? context.l10n.productsMgwsDefaultReasonAdjustment
        : context.l10n.productsMgwsDefaultReasonInitialStock;
  }

  String? _validateMgwsStock(String? value) {
    return validateProductMgwsStock(
      context.l10n,
      enabled: _mgwsInventoryEnabled,
      value: value,
    );
  }

  /// Sede facoltativa: accetta vuoto e accetta un intero positivo.
  ///
  /// Non e' un campo che l'app puo' rendere obbligatorio, perche' non sa se il
  /// negozio ha piu' di una sede. Su un negozio con una sola sede il vuoto e' la
  /// risposta giusta e la rotta la accetta; su uno con piu' sedi il vuoto produce
  /// un errore che arriva all'operatore insieme al fatto che il prodotto e'
  /// comunque salvato.
  String? _validateMgwsSite(String? value) {
    if (!_mgwsInventoryEnabled) return null;
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return context.l10n.productsMgwsSitePositiveInteger;
    }
    return null;
  }

  String? _validateMgwsReason(String? value) {
    return validateProductMgwsReason(
      context.l10n,
      enabled: _mgwsInventoryEnabled,
      value: value,
    );
  }

  ProductMgwsStockInput _buildMgwsStockInput() {
    return ProductMgwsStockInput(
      stockText: _mgwsStockController.text,
      reasonText: _mgwsReasonController.text,
      siteIdText: _mgwsSiteController.text,
    );
  }

  Widget _buildImmagini() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildImageSelector()],
    );
  }

  Widget _buildDettagli() {
    return Column(
      children: [
        if (_productType == ProductTypeSelection.simple)
          _buildSmartTextFormField(
            controller: _pesoController,
            label: context.l10n.productsWeightKg,
            icon: Icons.scale,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.scale_outlined),
              title: Text(context.l10n.productsWeightPerVariant),
              subtitle: Text(context.l10n.productsWeightPerVariantHint),
            ),
          ),
      ],
    );
  }

  Widget _buildVarianti() {
    if (_productType == ProductTypeSelection.simple) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 40),
              const SizedBox(height: 10),
              Text(
                context.l10n.productsSimpleProductSelected,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.productsSimpleProductSelectedHint,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _aggiungiAttributoProdotto,
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.productsAddAttribute),
                    ),
                    OutlinedButton.icon(
                      onPressed: _generaVariantiDaAttributi,
                      icon: const Icon(Icons.auto_awesome_motion),
                      label: Text(context.l10n.productsGenerateVariants),
                    ),
                  ],
                );
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.productsProductVariants,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.l10n.productsVariantsConfigured(
                        '${_varianti.length}',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.subtitleColor,
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 12), actions],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildInserimentoRapidoVariante(),
        const SizedBox(height: 12),
        _buildAttributiProdottoComposer(),
        const SizedBox(height: 16),
        if (_varianti.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory,
                    size: 48,
                    color: context.colors.neutralColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.productsNoVariants,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.productsNoVariantsHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildTabellaVariantiGerarchica(),
      ],
    );
  }

  Widget _buildTabellaVariantiGerarchica() {
    final allIndexes = List<int>.generate(_varianti.length, (index) => index);
    final primaryAttribute = _preferredGroupingAttribute(allIndexes);
    if (primaryAttribute == null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildUngroupedVariantGridHeader(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                context.l10n.productsVariantsWithoutAttributesHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _buildVariantBlockRows(indexes: allIndexes),
          ],
        ),
      );
    }

    final secondaryAttribute = _preferredGroupingAttribute(
      allIndexes,
      excluding: primaryAttribute,
    );
    final primaryGroups = _groupVariantIndexesByAttribute(primaryAttribute);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildVariantGridHeader(
            primaryAttribute: primaryAttribute,
            secondaryAttribute: secondaryAttribute ?? 'Sottogruppo',
          ),
          const Divider(height: 1),
          ...primaryGroups.entries.map(
            (entry) => _buildPrimaryVariantBlock(
              primaryAttribute: primaryAttribute,
              primaryValue: entry.key,
              indexes: entry.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantGridHeader({
    String? primaryAttribute,
    String? secondaryAttribute,
  }) {
    final primaryLabel = primaryAttribute ?? context.l10n.productsAttribute;
    final secondaryLabel = secondaryAttribute ?? context.l10n.productsSubgroup;
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              context.l10n.productsVariantsGroupedByAttribute,
              style: style,
            ),
          );
        }
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: Center(child: Text(primaryLabel, style: style)),
              ),
              SizedBox(
                width: 200,
                child: Center(child: Text(secondaryLabel, style: style)),
              ),
              Expanded(
                child: Text(context.l10n.productsVariants, style: style),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUngroupedVariantGridHeader() {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold);
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(context.l10n.productsVariants, style: style),
    );
  }

  Widget _buildPrimaryVariantBlock({
    required String primaryAttribute,
    required String primaryValue,
    required List<int> indexes,
  }) {
    final secondaryAttribute = _preferredGroupingAttribute(
      indexes,
      excluding: primaryAttribute,
    );
    final secondaryGroups = secondaryAttribute == null
        ? <String, List<int>>{'Senza valore': indexes}
        : _groupVariantIndexesByAttribute(secondaryAttribute, indexes: indexes);

    // The non-positioned content determines the height. The positioned cell
    // fills that exact height, including expanded variant details, without
    // IntrinsicHeight measuring ExpansionTile descendants.
    return LayoutBuilder(
      builder: (context, constraints) {
        final secondaryBlocks = secondaryGroups.entries
            .map(
              (entry) => _buildSecondaryVariantBlock(
                attributeName: secondaryAttribute,
                value: entry.key,
                indexes: entry.value,
              ),
            )
            .toList();
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMergedAttributeCell(
                title: context.l10n.prodottiAttributoValore(
                  primaryAttribute,
                  primaryValue,
                ),
                count: indexes.length,
                isPrimary: true,
              ),
              ...secondaryBlocks,
            ],
          );
        }
        return Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 220,
              child: _buildMergedAttributeCell(
                title: context.l10n.prodottiAttributoValore(
                  primaryAttribute,
                  primaryValue,
                ),
                count: indexes.length,
                isPrimary: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: secondaryBlocks,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryVariantBlock({
    required String? attributeName,
    required String value,
    required List<int> indexes,
  }) {
    final title = attributeName == null ? value : '$attributeName: $value';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMergedAttributeCell(title: title, count: indexes.length),
              _buildVariantBlockRows(indexes: indexes),
            ],
          );
        }
        return Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 200,
              child: _buildMergedAttributeCell(
                title: title,
                count: indexes.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 200),
              child: _buildVariantBlockRows(indexes: indexes),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMergedAttributeCell({
    required String title,
    required int count,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border(
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            count == 1
                ? context.l10n.productsVariantCountOne('$count')
                : context.l10n.productsVariantCountMany('$count'),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantBlockRows({required List<int> indexes}) {
    return Column(children: indexes.map(_buildVariantCatalogRow).toList());
  }

  Widget _buildVariantCatalogRow(int index) {
    final variante = _varianti[index];
    final hasDiscount =
        variante.prezzoScontato != null && variante.prezzoScontato! > 0;
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    Widget property(String label, String value, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    return Container(
      key: ValueKey(variante.uiKey),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) setState(() => _selectedVarianteIndex = index);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final image = SizedBox(
              width: 52,
              height: 52,
              child: _buildVarianteImageThumb(index, variante),
            );
            final barcodeInterno = property(
              context.l10n.productsInternalBarcode,
              variante.barcodeInterno.isEmpty ? '—' : variante.barcodeInterno,
              flex: 2,
            );
            final barcodeFornitore = property(
              context.l10n.productsSupplierBarcode,
              variante.barcodeFornitore.isEmpty
                  ? '—'
                  : variante.barcodeFornitore,
              flex: 2,
            );
            final price = property(
              context.l10n.commonPrice,
              '€ ${variante.prezzo.toStringAsFixed(2)}',
            );
            final discount = property(
              context.l10n.productsDiscount,
              hasDiscount
                  ? '€ ${variante.prezzoScontato!.toStringAsFixed(2)}'
                  : '—',
            );
            final quantity = property(
              context.l10n.commonQuantity,
              '${variante.quantita}',
            );

            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image,
                      const SizedBox(width: 8),
                      barcodeInterno,
                      barcodeFornitore,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [price, discount, quantity]),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                image,
                const SizedBox(width: 8),
                barcodeInterno,
                barcodeFornitore,
                price,
                discount,
                quantity,
              ],
            );
          },
        ),
        children: [_buildVarianteDetails(index)],
      ),
    );
  }

  Map<String, List<int>> _groupVariantIndexesByAttribute(
    String attributeName, {
    List<int>? indexes,
  }) {
    final groups = <String, List<int>>{};
    for (final index
        in indexes ?? List<int>.generate(_varianti.length, (i) => i)) {
      final value = _attributeValue(_varianti[index], attributeName);
      groups.putIfAbsent(value ?? 'Senza valore', () => <int>[]).add(index);
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map<String, List<int>>.fromEntries(sortedEntries);
  }

  String? _preferredGroupingAttribute(List<int> indexes, {String? excluding}) {
    final counts = <String, int>{};
    final displayNames = <String, String>{};
    for (final index in indexes) {
      for (final attribute in _varianti[index].attributi) {
        final name = attribute.nome.trim();
        if (name.isEmpty || attribute.opzione.trim().isEmpty) continue;
        final normalized = name.toLowerCase();
        if (normalized == excluding?.toLowerCase()) continue;
        counts[normalized] = (counts[normalized] ?? 0) + 1;
        displayNames.putIfAbsent(normalized, () => name);
      }
    }
    if (counts.isEmpty) return null;

    const preferredOrder = ['colore', 'color', 'taglia', 'size'];
    for (final preferred in preferredOrder) {
      if (counts.containsKey(preferred)) return displayNames[preferred];
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final countComparison = counts[b]!.compareTo(counts[a]!);
        return countComparison != 0 ? countComparison : a.compareTo(b);
      });
    return displayNames[names.first];
  }

  String? _attributeValue(VarianteTemp variante, String attributeName) {
    for (final attribute in variante.attributi) {
      if (attribute.nome.trim().toLowerCase() == attributeName.toLowerCase()) {
        final value = attribute.opzione.trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  Widget _buildInserimentoRapidoVariante() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.productsQuickVariantEntry,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.productsQuickVariantEntryHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      child: _buildSmartTextFormField(
                        controller: _quickVarianteBarcodeInternoController,
                        label: context.l10n.productsVariantBarcode,
                        icon: Icons.qr_code,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildGeneraBarcodeButton(
                      onPressed: _generaBarcodeVarianteRapida,
                    ),
                  ],
                ),
                SizedBox(
                  width: 180,
                  child: _buildSmartTextFormField(
                    controller: _quickVarianteBarcodeController,
                    label: context.l10n.productsProductCode,
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: _buildSmartTextFormField(
                    controller: _quickVarianteQuantitaController,
                    label: context.l10n.commonQuantity,
                    icon: Icons.inventory_2_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _buildSmartTextFormField(
                    controller: _quickVarianteTagliaController,
                    label: context.l10n.productsSizeLabel,
                    icon: Icons.straighten,
                    suggestions: _suggerimentiOpzioni['Taglia'],
                    enableCreateOption: true,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _buildSmartTextFormField(
                    controller: _quickVarianteColoreController,
                    label: context.l10n.productsColorLabel,
                    icon: Icons.palette_outlined,
                    suggestions: _suggerimentiOpzioni['Colore'],
                    enableCreateOption: true,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _aggiungiVarianteRapida,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.productsAddVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributiProdottoComposer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attributi del prodotto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Seleziona o scrivi nome attributo e scegli più valori. Il campo valori mostra i selezionati separati da virgola.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            if (_attributiProdottoSelezionati.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 32,
                      color: context.colors.neutralColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nessun attributo configurato',
                      style: TextStyle(color: context.colors.subtitleColor),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(
                _attributiProdottoSelezionati.length,
                (index) => _buildAttributoProdottoRow(index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarianteDetails(int index) {
    final variante = _varianti[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Dettagli variante #${index + 1}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            _buildVarianteActionsMenu(index),
          ],
        ),
        const SizedBox(height: 10),
        _buildVarianteImagesStrip(index),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                focusNode: _barcodeFocusNodeFor(index),
                controller: _barcodeControllerFor(index),
                onChanged: (value) => _onBarcodeChanged(index, value),
                decoration: InputDecoration(
                  labelText: context.l10n.prodottiBarcode,
                  isDense: true,
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _generaBarcodeVariante(index),
              icon: const Icon(Icons.auto_fix_high, size: 20),
              tooltip: context.l10n.prodottiGeneraBarcodeAuto,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextFormField(
                initialValue: variante.codiceProdotto,
                onChanged: (value) => variante.codiceProdotto = value,
                decoration: InputDecoration(
                  labelText: context.l10n.productsProductCode,
                  isDense: true,
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: TextFormField(
                initialValue: variante.quantita.toString(),
                onChanged: (value) =>
                    variante.quantita = int.tryParse(value) ?? 0,
                decoration: InputDecoration(
                  labelText: context.l10n.prodottiQuantita,
                  isDense: true,
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: variante.barcodeFornitore,
          onChanged: (value) => variante.barcodeFornitore = value,
          decoration: InputDecoration(
            labelText: context.l10n.productsBarcodeManufacturer,
            isDense: true,
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: variante.prezzo.toString(),
                onChanged: (value) =>
                    variante.prezzo = double.tryParse(value) ?? 0.0,
                decoration: InputDecoration(
                  labelText: context.l10n.commonPrice,
                  prefixIcon: Icon(Icons.euro),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: variante.peso ?? '',
                onChanged: (value) =>
                    variante.peso = value.trim().isEmpty ? null : value.trim(),
                decoration: InputDecoration(
                  labelText: context.l10n.productsWeightKg,
                  prefixIcon: Icon(Icons.scale),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAttributiVariante(variante, index),
      ],
    );
  }

  Widget _buildVarianteActionsMenu(int index) {
    return PopupMenuButton(
      tooltip: context.l10n.prodottiAzioniVariante,
      icon: const Icon(Icons.more_horiz),
      itemBuilder: (context) => [
        if (index > 0)
          PopupMenuItem(
            onTap: () => _spostaVariante(index, -1),
            child: Text(context.l10n.prodottiSpostaSu),
          ),
        if (index < _varianti.length - 1)
          PopupMenuItem(
            onTap: () => _spostaVariante(index, 1),
            child: Text(context.l10n.prodottiSpostaGiu),
          ),
        PopupMenuItem(
          onTap: () => _duplicaVariante(index),
          child: Text(context.l10n.prodottiDuplica),
        ),
        PopupMenuItem(
          onTap: () => _rimuoviVariante(index),
          child: Text(context.l10n.commonDelete),
        ),
      ],
    );
  }

  Widget _buildVarianteImageThumb(int varianteIndex, VarianteTemp variante) {
    final urls = _variantImageUrls(variante);
    final imageUrl = urls.isEmpty ? null : resolveImageUrl(urls.first);

    return InkWell(
      onTap: () => _aggiungiImmaginiVariante(varianteIndex),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.add_a_photo_outlined)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      cacheHeight: 144,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
            if (urls.length > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.scrim.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      '${urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarianteImagesStrip(int varianteIndex) {
    final variante = _varianti[varianteIndex];
    final urls = _variantImageUrls(variante);
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Foto variante',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _aggiungiImmaginiVariante(varianteIndex),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(context.l10n.prodottiAggiungiFoto),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (urls.isEmpty)
              Text(
                'Nessuna foto associata alla variante.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final url in urls)
                    _buildVariantImageTile(
                      varianteIndex,
                      url,
                      url == urls.first,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantImageTile(int varianteIndex, String url, bool isMain) {
    final resolved = resolveImageUrl(url) ?? url;
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _apriImmagine(url),
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    resolved,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 96,
                      height: 96,
                      color: Theme.of(context).colorScheme.outlineVariant,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                if (isMain)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.tierGold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.star, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton.filledTonal(
                    tooltip: context.l10n.prodottiRimuoviFoto,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: () =>
                        _rimuoviImmagineVariante(varianteIndex, url),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _shortImageName(url),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  List<String> _variantImageUrls(VarianteTemp variante) {
    final urls = <String>[];
    for (final url in variante.imageSetUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty && !urls.contains(clean)) urls.add(clean);
    }
    final single = variante.immagineUrl?.trim();
    if (urls.isEmpty && single != null && single.isNotEmpty) urls.add(single);
    return urls;
  }

  Future<void> _aggiungiImmaginiVariante(int varianteIndex) async {
    final selectedMedia = await showMediaSelectorMulti(
      context,
      showDimensionWarnings: _showImageDimensionWarnings,
      warningThresholdWidth: _imageWarningThresholdWidth,
      warningThresholdHeight: _imageWarningThresholdHeight,
    );
    if (selectedMedia == null || selectedMedia.isEmpty || !mounted) return;
    setState(() {
      final variante = _varianti[varianteIndex];
      final urls = _variantImageUrls(variante);
      final imageIdsByUrl = _variantNativeImageIdsByUrl(variante);
      for (final media in selectedMedia) {
        if (!urls.contains(media.url)) urls.add(media.url);
        if (media.id > 0) imageIdsByUrl[media.url] = media.id;
      }
      variante.imageSetUrls = urls;
      variante.immagineUrl = urls.isEmpty ? null : urls.first;
      _setVariantNativeImageIdsByUrl(variante, imageIdsByUrl);
    });
  }

  void _rimuoviImmagineVariante(int varianteIndex, String url) {
    setState(() {
      final variante = _varianti[varianteIndex];
      final urls = _variantImageUrls(variante)..remove(url);
      final imageIdsByUrl = _variantNativeImageIdsByUrl(variante)..remove(url);
      variante.imageSetUrls = urls;
      variante.immagineUrl = urls.isEmpty ? null : urls.first;
      _setVariantNativeImageIdsByUrl(variante, imageIdsByUrl);
    });
  }

  Map<String, int> _variantNativeImageIdsByUrl(VarianteTemp variante) {
    final raw = variante.metadatiCustom?['_woo_image_ids_by_url'];
    if (raw is! Map) return <String, int>{};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final url = entry.key?.toString().trim() ?? '';
      final id = entry.value is int
          ? entry.value as int
          : int.tryParse(entry.value?.toString() ?? '');
      if (url.isNotEmpty && id != null && id > 0) result[url] = id;
    }
    return result;
  }

  void _setVariantNativeImageIdsByUrl(
    VarianteTemp variante,
    Map<String, int> imageIdsByUrl,
  ) {
    variante.metadatiCustom = <String, dynamic>{
      ...?variante.metadatiCustom,
      '_woo_image_ids_by_url': imageIdsByUrl,
    };
  }

  Widget _buildAttributiVariante(VarianteTemp variante, int varianteIndex) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attributi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Variante #${varianteIndex + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (variante.attributi.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 32,
                        color: context.colors.neutralColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nessun attributo definito',
                        style: TextStyle(color: context.colors.subtitleColor),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(
                variante.attributi.length,
                (attrIndex) => _buildAttributoItem(
                  variante.attributi[attrIndex],
                  varianteIndex,
                  attrIndex,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributoItem(
    AttributoVariante attributo,
    int varianteIndex,
    int attrIndex,
  ) {
    return Container(
      key: ValueKey(
        'variante-${varianteIndex}-attr-$attrIndex-${attributo.nome}-${attributo.opzione}',
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.l10n.prodottiNomeAttributo,
                isDense: true,
                prefixIcon: Icon(Icons.tune),
              ),
              child: Text(attributo.nome.isEmpty ? '—' : attributo.nome),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.l10n.prodottoOpzione,
                isDense: true,
                prefixIcon: Icon(Icons.format_list_bulleted),
              ),
              child: Text(attributo.opzione.isEmpty ? '—' : attributo.opzione),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    final rows = _productImageRows();
    final selectedRows = rows
        .where((row) => _selectedImageUrls.contains(row.url))
        .toList(growable: false);
    final selectedGalleryRows = selectedRows
        .where((row) => !row.isMain)
        .toList();
    final selectedMain = selectedRows.any((row) => row.isMain);
    final canPromoteSelected = selectedGalleryRows.length == 1 && !selectedMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductImagesToolbar(
          rows: rows,
          selectedCount: selectedRows.length,
          canPromoteSelected: canPromoteSelected,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: rows.isEmpty
                ? _buildEmptyImagesState()
                : Column(
                    children: [
                      _buildProductImagesGridHeader(rows),
                      const Divider(height: 1),
                      for (final row in rows) _buildProductImageGridRow(row),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  List<_ProductImageRow> _productImageRows() {
    final rows = <_ProductImageRow>[];
    final mainUrl = _immagineUrlController.text.trim();
    if (mainUrl.isNotEmpty) {
      rows.add(_ProductImageRow(url: mainUrl, isMain: true));
    }
    rows.addAll(
      _mainImageSetUrls
          .where((url) => url.trim().isNotEmpty && url.trim() != mainUrl)
          .map((url) => _ProductImageRow(url: url.trim(), isMain: false)),
    );
    _selectedImageUrls.removeWhere((url) => !rows.any((row) => row.url == url));
    return rows;
  }

  Widget _buildProductImagesToolbar({
    required List<_ProductImageRow> rows,
    required int selectedCount,
    required bool canPromoteSelected,
  }) {
    final theme = Theme.of(context);
    final hasSelection = selectedCount > 0;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Immagini prodotto',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Una sola copertina. Le immagini possono essere selezionate anche cliccando sulla riga.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _buildImagesCounterChip(
              'Totale',
              rows.length,
              Icons.image_outlined,
            ),
            _buildImagesCounterChip(
              'Selezionate',
              selectedCount,
              Icons.check_box_outlined,
            ),
            FilledButton.icon(
              onPressed: _aggiungiImmaginiProdotto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(context.l10n.prodottiAggiungiImmagini),
            ),
            if (hasSelection) ...[
              OutlinedButton.icon(
                onPressed: _eliminaImmaginiSelezionate,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.prodottiEliminaSelezionate),
              ),
              OutlinedButton.icon(
                onPressed: _deselezionaImmagini,
                icon: const Icon(Icons.clear_all),
                label: Text(context.l10n.prodottiDeseleziona),
              ),
              OutlinedButton.icon(
                onPressed: canPromoteSelected
                    ? () => _promuoviImmagineGallery(_selectedImageUrls.first)
                    : null,
                icon: const Icon(Icons.star_outline),
                label: Text(context.l10n.prodottiImpostaCopertina),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagesCounterChip(String label, int value, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(context.l10n.prodottiEtichettaValore(label, value)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyImagesState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 56,
              color: context.colors.subtitleColor,
            ),
            const SizedBox(height: 10),
            Text(
              'Nessuna immagine selezionata',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Aggiungi una o più immagini dalla libreria media.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _aggiungiImmaginiProdotto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(context.l10n.prodottiAggiungiImmagini),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImagesGridHeader(List<_ProductImageRow> rows) {
    final selectedCount = rows
        .where((row) => _selectedImageUrls.contains(row.url))
        .length;
    final allSelected = rows.isNotEmpty && selectedCount == rows.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: selectedCount == 0 ? false : (allSelected ? true : null),
              tristate: selectedCount > 0 && !allSelected,
              onChanged: (_) => _toggleSelezioneTutteImmagini(rows),
            ),
          ),
          SizedBox(width: 86, child: Text(context.l10n.prodottiAnteprima)),
          SizedBox(width: 220, child: Text(context.l10n.prodottoUso)),
          Expanded(flex: 3, child: Text(context.l10n.commonName)),
          Expanded(
            flex: 2,
            child: Text(context.l10n.prodottoVerificaDimensioni),
          ),
          SizedBox(width: 280, child: Text(context.l10n.prodottiAzioni)),
        ],
      ),
    );
  }

  Widget _buildProductImageGridRow(_ProductImageRow row) {
    final metadata = _mainImageMetadata[row.url];
    final resolvedUrl = resolveImageUrl(row.url) ?? row.url;
    final isSelected = _selectedImageUrls.contains(row.url);
    final galleryIndex = row.isMain ? -1 : _mainImageSetUrls.indexOf(row.url);
    final customColors = Theme.of(context).extension<AppColorExtension>();
    final rowColor = row.isMain
        ? context.colors.tierGold.withValues(alpha: isSelected ? 0.22 : 0.10)
        : isSelected
        ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
        : Colors.transparent;

    return InkWell(
      onTap: () => _toggleSelezioneImmagine(row.url),
      child: Container(
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
            ),
            left: row.isMain
                ? BorderSide(color: context.colors.tierGold, width: 4)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelezioneImmagine(row.url),
              ),
            ),
            SizedBox(
              width: 86,
              child: InkWell(
                onTap: () => _apriImmagine(row.url),
                borderRadius: BorderRadius.circular(10),
                child: _buildImagePreviewCell(resolvedUrl, row.isMain),
              ),
            ),
            SizedBox(width: 220, child: _buildImageUsageBadges(row)),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  metadata?.title?.trim().isNotEmpty == true
                      ? metadata!.title!
                      : _shortImageName(row.url),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _buildImageDimensionStatus(row.url, metadata),
            ),
            SizedBox(
              width: 280,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: context.l10n.prodottiApriAnteprima,
                    onPressed: () => _apriImmagine(row.url),
                    icon: const Icon(Icons.open_in_full),
                  ),
                  if (!row.isMain)
                    OutlinedButton.icon(
                      onPressed: () => _promuoviImmagineGallery(row.url),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: Text(context.l10n.prodottiCopertina),
                    ),
                  if (!row.isMain) ...[
                    IconButton(
                      tooltip: context.l10n.prodottiSpostaSu,
                      onPressed: galleryIndex > 0
                          ? () => _spostaImmagineGallery(
                              galleryIndex,
                              galleryIndex - 1,
                            )
                          : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: context.l10n.prodottiSpostaGiu,
                      onPressed:
                          galleryIndex >= 0 &&
                              galleryIndex < _mainImageSetUrls.length - 1
                          ? () => _spostaImmagineGallery(
                              galleryIndex,
                              galleryIndex + 1,
                            )
                          : null,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                  PopupMenuButton<String>(
                    tooltip: context.l10n.prodottiAltreAzioni,
                    onSelected: (value) {
                      switch (value) {
                        case 'copy':
                          _copiaUrlImmagine(row.url);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'copy',
                        child: Text(context.l10n.prodottiCopiaUrl),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: row.isMain
                        ? 'Rimuovi copertina'
                        : 'Rimuovi immagine',
                    onPressed: () => row.isMain
                        ? _rimuoviImmaginePrincipale()
                        : _rimuoviImmagineGallery(row.url),
                    icon: Icon(
                      Icons.delete_outline,
                      color: customColors?.errorColorStatus,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUsageBadges(_ProductImageRow row) {
    final usages = _variantUsageLabelsForImage(row.url);
    final badges = <Widget>[];
    if (row.isMain) {
      final roleColor = context.colors.tierGold;
      badges.add(
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.star, size: 16),
          label: Text(context.l10n.prodottiCopertina),
          backgroundColor: roleColor.withValues(alpha: 0.12),
          side: BorderSide(color: roleColor.withValues(alpha: 0.45)),
        ),
      );
    }

    if (usages.isEmpty && badges.isEmpty) return const Text('—');

    if (usages.isNotEmpty) {
      final tooltip = usages.join('\n');
      badges.add(
        Tooltip(
          message: tooltip,
          child: Chip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.account_tree_outlined, size: 16),
            label: Text(
              usages.length == 1
                  ? usages.first
                  : 'Usata in ${usages.length} varianti',
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: context.colors.infoColor.withValues(alpha: 0.10),
            side: BorderSide(
              color: context.colors.infoColor.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 6, runSpacing: 4, children: badges),
    );
  }

  List<String> _variantUsageLabelsForImage(String imageUrl) {
    final normalized = imageUrl.trim();
    if (normalized.isEmpty) return const <String>[];
    final labels = <String>[];
    for (var index = 0; index < _varianti.length; index++) {
      final variante = _varianti[index];
      final urls = _variantImageUrls(
        variante,
      ).map((url) => url.trim()).toList();
      if (!urls.contains(normalized)) continue;
      final isVariantCover = urls.isNotEmpty && urls.first == normalized;
      final attributeLabel = variante.attributi
          .map((attr) => attr.opzione.trim())
          .where((value) => value.isNotEmpty)
          .join(' / ');
      final prefix = isVariantCover ? 'Copertina variante' : 'Variante';
      labels.add(
        attributeLabel.isEmpty
            ? '$prefix #${index + 1}'
            : '$prefix #${index + 1}: $attributeLabel',
      );
    }
    return labels;
  }

  Widget _buildImagePreviewCell(String url, bool isMain) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 72,
              height: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        if (isMain)
          Positioned(
            right: 4,
            top: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.tierGold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.star, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageDimensionStatus(
    String url,
    woo_models.MediaFile? metadata,
  ) {
    final cachedSize = _resolvedImagePixelSizes[url];
    final width = metadata?.width ?? cachedSize?.width;
    final height = metadata?.height ?? cachedSize?.height;

    if (_failedImagePixelSizeUrls.contains(url)) {
      return _buildImageDimensionStatusLabel(
        label: 'Non verificabile',
        color: context.colors.errorColorStatus,
        tooltip:
            'Immagine non caricabile o timeout durante la lettura dimensioni.',
      );
    }

    if (width == null || height == null) {
      _ensureImagePixelSize(url);
      return _buildImageDimensionStatusLabel(
        label: 'Verifica in corso',
        color: context.colors.neutralColor,
        tooltip: context.l10n.prodottiLetturaDimensioni,
      );
    }

    if (!_showImageDimensionWarnings ||
        (_imageWarningThresholdWidth <= 0 &&
            _imageWarningThresholdHeight <= 0)) {
      return _buildImageDimensionStatusLabel(
        label: 'Nessuna specifica',
        color: context.colors.neutralColor,
        tooltip: context.l10n.prodottiNessunaSogliaPixel,
      );
    }

    final isOversized = isProductImageOverWarningThreshold(
      width: width,
      height: height,
      warningsEnabled: _showImageDimensionWarnings,
      thresholdWidth: _imageWarningThresholdWidth,
      thresholdHeight: _imageWarningThresholdHeight,
    );
    return _buildImageDimensionStatusLabel(
      label: isOversized ? 'Fuori specifica' : 'Conforme',
      color: isOversized
          ? context.colors.warningColor
          : context.colors.successColor,
      tooltip: isOversized
          ? 'Fuori specifica: immagine $width × $height px, soglia $_imageWarningThresholdWidth × $_imageWarningThresholdHeight px.'
          : 'Conforme: immagine $width × $height px, soglia $_imageWarningThresholdWidth × $_imageWarningThresholdHeight px.',
    );
  }

  Widget _buildImageDimensionStatusLabel({
    required String label,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _ensureImagePixelSize(String url) {
    if (url.trim().isEmpty ||
        _resolvedImagePixelSizes.containsKey(url) ||
        _loadingImagePixelSizeUrls.contains(url) ||
        _failedImagePixelSizeUrls.contains(url)) {
      return;
    }
    _loadingImagePixelSizeUrls.add(url);
    final resolved = resolveImageUrl(url) ?? url;
    final image = NetworkImage(resolved);
    final stream = image.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!mounted) return;
        setState(() {
          _loadingImagePixelSizeUrls.remove(url);
          _failedImagePixelSizeUrls.remove(url);
          _resolvedImagePixelSizes[url] = _ImagePixelSize(
            width: info.image.width,
            height: info.image.height,
          );
        });
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (!mounted) return;
        setState(() {
          _loadingImagePixelSizeUrls.remove(url);
          _failedImagePixelSizeUrls.add(url);
        });
      },
    );
    stream.addListener(listener);
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_resolvedImagePixelSizes.containsKey(url) ||
          _failedImagePixelSizeUrls.contains(url)) {
        return;
      }
      setState(() {
        _loadingImagePixelSizeUrls.remove(url);
        _failedImagePixelSizeUrls.add(url);
      });
    });
  }

  String _shortImageName(String url) {
    final clean = url.split('?').first;
    final name = clean.split('/').where((part) => part.isNotEmpty).lastOrNull;
    if (name == null || name.isEmpty) return url;
    return name;
  }

  Future<void> _aggiungiImmaginiProdotto() async {
    final selectedMedia = await showMediaSelectorMulti(
      context,
      showDimensionWarnings: _showImageDimensionWarnings,
      warningThresholdWidth: _imageWarningThresholdWidth,
      warningThresholdHeight: _imageWarningThresholdHeight,
    );
    if (selectedMedia == null || selectedMedia.isEmpty || !mounted) return;
    setState(() {
      for (final media in selectedMedia) {
        _mainImageMetadata[media.url] = media;
        _failedImagePixelSizeUrls.remove(media.url);
        _loadingImagePixelSizeUrls.remove(media.url);
        if (_immagineUrlController.text.trim().isEmpty) {
          _immagineUrlController.text = media.url;
          continue;
        }
        if (_immagineUrlController.text.trim() == media.url) continue;
        if (!_mainImageSetUrls.contains(media.url)) {
          _mainImageSetUrls.add(media.url);
        }
      }
    });
  }

  void _toggleSelezioneImmagine(String url) {
    setState(() {
      if (_selectedImageUrls.contains(url)) {
        _selectedImageUrls.remove(url);
      } else {
        _selectedImageUrls.add(url);
      }
    });
  }

  void _toggleSelezioneTutteImmagini(List<_ProductImageRow> rows) {
    setState(() {
      final allSelected = rows.every(
        (row) => _selectedImageUrls.contains(row.url),
      );
      if (allSelected) {
        for (final row in rows) {
          _selectedImageUrls.remove(row.url);
        }
      } else {
        for (final row in rows) {
          _selectedImageUrls.add(row.url);
        }
      }
    });
  }

  void _deselezionaImmagini() {
    setState(_selectedImageUrls.clear);
  }

  void _eliminaImmaginiSelezionate() {
    if (_selectedImageUrls.isEmpty) return;
    setState(() {
      final selected = Set<String>.from(_selectedImageUrls);
      final oldMain = _immagineUrlController.text.trim();
      _mainImageSetUrls.removeWhere(selected.contains);
      if (selected.contains(oldMain)) {
        if (_mainImageSetUrls.isNotEmpty) {
          _immagineUrlController.text = _mainImageSetUrls.removeAt(0);
        } else {
          _immagineUrlController.clear();
        }
      }
      for (final url in selected) {
        _mainImageMetadata.remove(url);
        _resolvedImagePixelSizes.remove(url);
        _failedImagePixelSizeUrls.remove(url);
        _loadingImagePixelSizeUrls.remove(url);
      }
      _selectedImageUrls.clear();
    });
  }

  void _copiaUrlImmagine(String url) {
    Clipboard.setData(ClipboardData(text: url));
    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'URL immagine copiato negli appunti.',
    );
  }

  void _spostaImmagineGallery(int from, int to) {
    if (from < 0 || to < 0) return;
    if (from >= _mainImageSetUrls.length || to >= _mainImageSetUrls.length)
      return;
    setState(() {
      final item = _mainImageSetUrls.removeAt(from);
      _mainImageSetUrls.insert(to, item);
    });
  }

  void _promuoviImmagineGallery(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    setState(() {
      final oldMain = _immagineUrlController.text.trim();
      _mainImageSetUrls.remove(cleanUrl);
      _immagineUrlController.text = cleanUrl;
      if (oldMain.isNotEmpty && oldMain != cleanUrl) {
        _mainImageSetUrls.insert(0, oldMain);
      }
    });
  }

  Future<void> _apriImmagine(String url) async {
    final resolved = resolveImageUrl(url) ?? url;
    if (resolved.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        resolved,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Icon(Icons.broken_image, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _rimuoviImmaginePrincipale() {
    setState(() {
      final oldMain = _immagineUrlController.text.trim();
      if (oldMain.isNotEmpty) {
        _mainImageMetadata.remove(oldMain);
      }
      if (_mainImageSetUrls.isNotEmpty) {
        final promoted = _mainImageSetUrls.removeAt(0);
        _immagineUrlController.text = promoted;
      } else {
        _immagineUrlController.clear();
      }
    });
  }

  void _rimuoviImmagineGallery(String url) {
    setState(() {
      _mainImageSetUrls.remove(url);
      _mainImageMetadata.remove(url);
    });
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.prodottiTags,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: context.l10n.prodottiAggiungiTag,
                          prefixIcon: Icon(Icons.tag),
                          suffixIcon: Icon(Icons.add),
                        ),
                        onFieldSubmitted: (value) {
                          if (value.trim().isNotEmpty &&
                              !_tags.contains(value.trim())) {
                            setState(() => _tags.add(value.trim()));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _saveProgressLabel.isEmpty
                  ? 'Salvataggio in corso...'
                  : _saveProgressLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _saveProgress),
          ],
        ),
      ),
    );
  }

  void _updateSaveProgress(double value, String label) {
    if (!mounted) return;
    setState(() {
      _saveProgress = value.clamp(0.0, 1.0);
      _saveProgressLabel = label;
    });
  }

  Widget _buildSmartTextFormField({
    Key? fieldKey,
    TextEditingController? controller,
    String? initialValue,
    required String label,
    IconData? icon,
    List<String>? suggestions,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? suffix,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    bool required = false,
    bool enableCreateOption = false,
    void Function(String)? onCreateOption,
    String createOptionText = '+ Crea nuovo',
  }) {
    // Se non è fornito un controller, usa initialValue direttamente (senza controller)
    // Questo evita problemi con il testo che si scrive al contrario

    if (suggestions != null || enableCreateOption) {
      final sourceSuggestions = suggestions ?? const <String>[];
      String lastAutocompleteQuery = '';
      // Con autocompletamento
      return Autocomplete<String>(
        displayStringForOption: (option) {
          if (enableCreateOption && option == createOptionText) {
            return lastAutocompleteQuery;
          }
          return option;
        },
        initialValue: TextEditingValue(text: initialValue ?? ''),
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) return const Iterable.empty();
          final query = textEditingValue.text.trim();
          lastAutocompleteQuery = query;
          final filtered = sourceSuggestions.where(
            (option) => option.toLowerCase().contains(query.toLowerCase()),
          );

          final exactExists = sourceSuggestions.any(
            (option) => option.toLowerCase() == query.toLowerCase(),
          );

          if (enableCreateOption && query.isNotEmpty && !exactExists) {
            return <String>[...filtered, createOptionText];
          }

          return filtered;
        },
        onSelected: (selection) {
          if (enableCreateOption && selection == createOptionText) {
            final created = lastAutocompleteQuery.trim();
            if (created.isEmpty) {
              return;
            }
            // Esegue l'azione di creazione senza sostituire il testo digitato
            if (controller != null && controller.text != created) {
              controller.text = created;
              controller.selection = TextSelection.collapsed(
                offset: created.length,
              );
            }
            onCreateOption?.call(created);
            onChanged?.call(created);
            return;
          }
          if (controller != null && controller.text != selection) {
            controller.text = selection;
            controller.selection = TextSelection.collapsed(
              offset: selection.length,
            );
          }
          onChanged?.call(selection);
        },
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          // Con autocomplete, usa sempre il controller interno per non rompere il filtering.
          final seedText = controller?.text ?? initialValue ?? '';
          if (fieldController.text.isEmpty && seedText.isNotEmpty) {
            fieldController.text = seedText;
            fieldController.selection = TextSelection.collapsed(
              offset: seedText.length,
            );
          }

          return TextFormField(
            key: fieldKey,
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              prefixIcon: icon != null ? Icon(icon) : null,
              suffixText: suffix,
            ),
            validator: validator,
            onChanged: (value) {
              if (controller != null && controller.text != value) {
                controller.text = value;
                controller.selection = TextSelection.collapsed(
                  offset: value.length,
                );
              }
              onChanged?.call(value);
            },
            onFieldSubmitted: (value) {
              final created = value.trim();
              final alreadyExists = sourceSuggestions.any(
                (option) => option.toLowerCase() == created.toLowerCase(),
              );
              if (!enableCreateOption || created.isEmpty || alreadyExists) {
                return;
              }

              if (controller != null && controller.text != created) {
                controller.text = created;
                controller.selection = TextSelection.collapsed(
                  offset: created.length,
                );
              }
              onCreateOption?.call(created);
              onChanged?.call(created);
              focusNode.unfocus();
            },
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
          );
        },
      );
    }

    // Senza autocompletamento - usa initialValue direttamente
    return TextFormField(
      key: fieldKey,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixText: suffix,
      ),
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildCategorieField() {
    return TextFormField(
      controller: _categoriaController,
      readOnly: true,
      onTap: _apriSelettoreCategorie,
      validator: (value) =>
          _categorieSelezionate.isEmpty ? 'Campo obbligatorio' : null,
      decoration: InputDecoration(
        labelText: context.l10n.prodottiCategorieObbligatorie,
        prefixIcon: Icon(Icons.category),
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
    );
  }

  Widget _buildMarchioField() {
    return DropdownSearch<String>(
      selectedItem: _marcaController.text.trim().isEmpty
          ? null
          : _marcaController.text.trim(),
      items: (filter, _) async {
        final query = filter.trim();
        final items = _suggerimentiMarca.toSet().toList()..sort();
        final filtered = query.isEmpty
            ? items
            : items
                  .where(
                    (item) => item.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
        final exists = items.any(
          (item) => item.toLowerCase() == query.toLowerCase(),
        );
        if (query.isNotEmpty && !exists) {
          filtered.add(_brandCreateOptionLabel(query));
        }
        return filtered;
      },
      compareFn: (item1, item2) => item1 == item2,
      onSelected: (value) {
        if (value == null) return;
        final createdValue = _extractCreatedBrandValue(value);
        setState(() {
          _marcaController.text = createdValue ?? value;
          final normalized = _marcaController.text.trim();
          if (normalized.isNotEmpty &&
              !_suggerimentiMarca.any(
                (item) => item.toLowerCase() == normalized.toLowerCase(),
              )) {
            _suggerimentiMarca.add(normalized);
            _suggerimentiMarca.sort();
          }
        });
      },
      decoratorProps: DropDownDecoratorProps(
        decoration: InputDecoration(
          labelText: context.l10n.prodottiMarchio,
          prefixIcon: Icon(Icons.branding_watermark_outlined),
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        fit: FlexFit.loose,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: context.l10n.prodottiCercaMarchio,
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      suffixProps: DropdownSuffixProps(
        clearButtonProps: ClearButtonProps(
          isVisible: _marcaController.text.trim().isNotEmpty,
        ),
      ),
      onClear: () {
        setState(() {
          _marcaController.clear();
        });
      },
    );
  }

  Future<void> _apriSelettoreCategorie() async {
    final selected = await SearchableCheckboxDialog.show(
      context,
      title: context.l10n.prodottiCategorieProdotto,
      inputLabel: 'Filtra o nuova categoria',
      input_list: _suggerimentiCategoria,
      preselected_list: _categorieSelezionate,
    );

    if (selected == null || !mounted) return;

    setState(() {
      _categorieSelezionate = List<String>.from(selected)..sort();
      _categoriaController.text = _categorieSelezionate.join(', ');
      for (final categoria in _categorieSelezionate) {
        if (!_suggerimentiCategoria.any(
          (item) => item.toLowerCase() == categoria.toLowerCase(),
        )) {
          _suggerimentiCategoria.add(categoria);
        }
      }
      _suggerimentiCategoria.sort();
    });
  }

  String _brandCreateOptionLabel(String value) => '+ CREA: $value';

  String? _extractCreatedBrandValue(String value) {
    if (!value.startsWith('+ CREA: ')) return null;
    final created = value.substring('+ CREA: '.length).trim();
    return created.isEmpty ? null : created;
  }

  Widget _buildFloatingActionButton() {
    if (_prodottiController == null) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _isLoading ? null : _salvaProdotto,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(_isUpdatingExisting ? Icons.update : Icons.save),
      label: Text(_isUpdatingExisting ? 'Aggiorna' : 'Salva Prodotto'),
      backgroundColor: _isLoading
          ? context.colors.neutralColor
          : Theme.of(context).primaryColor,
    );
  }

  void _syncBarcodeFocusNodes() {
    while (_barcodeFocusNodes.length < _varianti.length) {
      _barcodeFocusNodes.add(FocusNode());
    }
    while (_barcodeFocusNodes.length > _varianti.length) {
      _barcodeFocusNodes.removeLast().dispose();
    }
    _syncBarcodeControllers();
  }

  void _syncBarcodeControllers() {
    while (_barcodeControllers.length < _varianti.length) {
      _barcodeControllers.add(TextEditingController());
    }
    while (_barcodeControllers.length > _varianti.length) {
      _barcodeControllers.removeLast().dispose();
    }
  }

  FocusNode _barcodeFocusNodeFor(int index) {
    _syncBarcodeFocusNodes();
    return _barcodeFocusNodes[index];
  }

  TextEditingController _barcodeControllerFor(int index) {
    _syncBarcodeControllers();
    // Allinea il controller alla sorgente di verita (il campo della
    // variante): vale sia al caricamento di un prodotto esistente sia dopo
    // operazioni come generazione o modifica della lista varianti.
    final varianteValue = _varianti[index].barcodeInterno;
    if (_barcodeControllers[index].text != varianteValue) {
      _barcodeControllers[index].text = varianteValue;
    }
    return _barcodeControllers[index];
  }

  /// Raccoglie i barcode gia in uso nel modulo, escludendo [escluso]
  /// (il valore corrente del campo su cui si sta generando).
  Set<String> _barcodeInUso({String? escluso}) {
    final usati = <String>{};
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) usati.add(text);
    }

    add(_barcodeInternoController.text);
    add(_quickVarianteBarcodeInternoController.text);
    for (final variante in _varianti) {
      add(variante.barcodeInterno);
    }

    final escl = escluso?.trim() ?? '';
    if (escl.isNotEmpty) usati.remove(escl);
    return usati;
  }

  void _generaBarcodePrincipale() {
    final value = BarcodeGenerator.generaCode128(
      esclusi: _barcodeInUso(escluso: _barcodeInternoController.text),
    );
    if (value == null) {
      NotificationService.instance.messageBar(
        'error',
        'prodotti_crea',
        'Impossibile generare un barcode unico.',
      );
      return;
    }

    setState(() {
      _barcodeInternoController.text = value;
      _barcodeInternoController.selection = TextSelection.collapsed(
        offset: value.length,
      );
    });
    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'Barcode generato: $value',
    );
  }

  void _generaBarcodeVariante(int index) {
    if (index < 0 || index >= _varianti.length) return;
    final value = BarcodeGenerator.generaCode128(
      esclusi: _barcodeInUso(escluso: _varianti[index].barcodeInterno),
    );
    if (value == null) {
      NotificationService.instance.messageBar(
        'error',
        'prodotti_crea',
        'Impossibile generare un barcode unico per la variante.',
      );
      return;
    }

    setState(() {
      _varianti[index].barcodeInterno = value;
      final controller = _barcodeControllerFor(index);
      controller.text = value;
      controller.selection = TextSelection.collapsed(offset: value.length);
    });
    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'Barcode variante generato: $value',
    );
  }

  void _generaBarcodeVarianteRapida() {
    final value = BarcodeGenerator.generaCode128(
      esclusi: _barcodeInUso(
        escluso: _quickVarianteBarcodeInternoController.text,
      ),
    );
    if (value == null) {
      NotificationService.instance.messageBar(
        'error',
        'prodotti_crea',
        'Impossibile generare un barcode unico per la variante.',
      );
      return;
    }

    setState(() {
      _quickVarianteBarcodeInternoController.text = value;
      _quickVarianteBarcodeInternoController.selection =
          TextSelection.collapsed(offset: value.length);
    });
    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'Barcode variante generato: $value',
    );
  }

  void _onBarcodeChanged(int varianteIndex, String value) {
    _varianti[varianteIndex].barcodeInterno = value;

    final previous = _barcodePreviousValues[varianteIndex] ?? '';
    _barcodePreviousValues[varianteIndex] = value;
    final jump = value.length - previous.length;

    final looksLikeScannerShot =
        value.isNotEmpty &&
        (previous.isEmpty && value.length >= 6 || jump >= 4);
    if (!looksLikeScannerShot) return;

    final next = varianteIndex + 1;
    if (next >= _varianti.length) return;

    setState(() {
      _selectedVarianteIndex = next;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_barcodeFocusNodeFor(next));
    });
  }

  Widget _buildAttributoProdottoRow(int index) {
    final attributo = _attributiProdottoSelezionati[index];
    final attrKey = attributo.nome.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildSmartTextFormField(
              controller: attributo.nomeController,
              label: 'Nome Attributo',
              icon: Icons.tune,
              suggestions: _suggerimentiAttributi,
              enableCreateOption: true,
              createOptionText: '+ CREA NUOVO',
              onCreateOption: (value) {
                final normalized = value.trim();
                if (normalized.isEmpty) return;
                setState(() {
                  if (!_suggerimentiAttributi.any(
                    (s) => s.toLowerCase() == normalized.toLowerCase(),
                  )) {
                    _suggerimentiAttributi.add(normalized);
                    _suggerimentiAttributi.sort();
                  }
                  attributo.nomeController.text = normalized;
                });
              },
              onChanged: (value) {
                setState(() {
                  attributo.nomeController.text = value;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: attributo.valoriController,
              readOnly: true,
              onTap: () => _apriSelettoreValoriAttributo(index),
              decoration: InputDecoration(
                labelText: context.l10n.prodottiValori,
                prefixIcon: Icon(Icons.checklist),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: context.l10n.prodottiRimuoviAttributo,
            onPressed: () => _rimuoviAttributoProdotto(index),
            icon: const Icon(Icons.delete_outline),
          ),
          if (attrKey.isNotEmpty)
            IconButton(
              tooltip: context.l10n.prodottiScegliValori,
              onPressed: () => _apriSelettoreValoriAttributo(index),
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
            ),
        ],
      ),
    );
  }

  void _aggiungiAttributoProdotto() {
    setState(() {
      _attributiProdottoSelezionati.add(AttributoProdottoSelezionato());
    });
  }

  void _rimuoviAttributoProdotto(int index) {
    setState(() {
      _attributiProdottoSelezionati[index].dispose();
      _attributiProdottoSelezionati.removeAt(index);
    });
  }

  Future<void> _apriSelettoreValoriAttributo(int index) async {
    final attributo = _attributiProdottoSelezionati[index];
    final attrName = attributo.nome.trim();

    final selected = await SearchableCheckboxDialog.show(
      context,
      title: attrName.isEmpty ? 'Valori attributo' : 'Valori $attrName',
      inputLabel: 'Filtra o nuovo valore',
      input_list: _suggerimentiOpzioni[attrName] ?? const <String>[],
      preselected_list: attributo.valori,
    );

    if (selected == null || !mounted) return;

    setState(() {
      attributo.setValori(selected);
      if (attrName.isNotEmpty) {
        final options = _suggerimentiOpzioni.putIfAbsent(
          attrName,
          () => <String>[],
        );
        for (final value in selected) {
          if (!options.any((s) => s.toLowerCase() == value.toLowerCase())) {
            options.add(value);
          }
        }
        options.sort();
      }
    });
  }

  void _aggiungiVarianteRapida() {
    final taglia = _quickVarianteTagliaController.text.trim();
    final colore = _quickVarianteColoreController.text.trim();
    if (taglia.isEmpty && colore.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'Inserisci almeno taglia o colore per la variante rapida.',
      );
      return;
    }

    final attributi = <AttributoVariante>[
      if (taglia.isNotEmpty) AttributoVariante(nome: 'Taglia', opzione: taglia),
      if (colore.isNotEmpty) AttributoVariante(nome: 'Colore', opzione: colore),
    ];
    final comboKey = VariantCombinations.key(attributi);
    if (_varianti.any(
      (variante) => VariantCombinations.key(variante.attributi) == comboKey,
    )) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'La variante ${_buildAttributeSummary(attributi)} è già presente.',
      );
      return;
    }

    setState(() {
      _varianti.add(
        VarianteTemp(
          nome: 'Variante ${_varianti.length + 1}',
          codiceProdotto: _quickVarianteBarcodeController.text.trim(),
          barcodeInterno: _quickVarianteBarcodeInternoController.text.trim(),
          barcode: '',
          prezzo: double.tryParse(_prezzoNormaleController.text) ?? 0.0,
          quantita: int.tryParse(_quickVarianteQuantitaController.text) ?? 0,
          peso: _pesoController.text.trim().isEmpty
              ? null
              : _pesoController.text.trim(),
          imageConfig: _newImageConfigFromDefaults(),
          attributi: attributi,
        ),
      );
      _syncBarcodeFocusNodes();
      _selectedVarianteIndex = _varianti.length - 1;
      _quickVarianteBarcodeInternoController.clear();
      _quickVarianteBarcodeController.clear();
      _quickVarianteQuantitaController.text = '0';
      _quickVarianteTagliaController.clear();
      _quickVarianteColoreController.clear();
    });

    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'Variante ${_buildAttributeSummary(attributi)} aggiunta.',
    );
  }

  String _buildAttributeSummary(List<AttributoVariante> attributes) {
    return attributes.map((attr) => '${attr.nome}: ${attr.opzione}').join(', ');
  }

  void _generaVariantiDaAttributi() {
    final attributiValidi = _buildAttributiProdottoValidi();
    if (attributiValidi.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'Aggiungi almeno un attributo con uno o più valori.',
      );
      return;
    }

    final combinazioni = VariantCombinations.generate(attributiValidi);
    if (combinazioni.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'Nessuna combinazione generata.',
      );
      return;
    }

    final chiaviEsistenti = _varianti
        .map((variante) => VariantCombinations.key(variante.attributi))
        .where((chiave) => chiave.isNotEmpty)
        .toSet();
    final combinazioniNuove = <List<AttributoVariante>>[];

    for (final combinazione in combinazioni) {
      final chiave = VariantCombinations.key(combinazione);
      if (chiave.isEmpty || !chiaviEsistenti.add(chiave)) continue;
      combinazioniNuove.add(combinazione);
    }

    if (combinazioniNuove.isEmpty) {
      NotificationService.instance.messageBar(
        'successo',
        'prodotti_crea',
        'Tutte le combinazioni generate sono già associate al prodotto.',
      );
      return;
    }

    setState(() {
      final firstNewVariantIndex = _varianti.length;
      _varianti.addAll(
        combinazioniNuove.asMap().entries.map((entry) {
          final index = entry.key;
          final attributi = entry.value;
          return VarianteTemp(
            nome: 'Variante ${firstNewVariantIndex + index + 1}',
            barcodeInterno: '',
            barcode: '',
            prezzo: double.tryParse(_prezzoNormaleController.text) ?? 0.0,
            quantita: 0,
            peso: _pesoController.text.trim().isEmpty
                ? null
                : _pesoController.text.trim(),
            imageConfig: _newImageConfigFromDefaults(),
            attributi: attributi,
          );
        }),
      );
      _syncBarcodeFocusNodes();
      _selectedVarianteIndex = firstNewVariantIndex;
      for (final attributo in _attributiProdottoSelezionati) {
        attributo.dispose();
      }
      _attributiProdottoSelezionati = [];
    });

    NotificationService.instance.messageBar(
      'successo',
      'prodotti_crea',
      'Generate ${combinazioniNuove.length} nuove varianti.',
    );
  }

  void _duplicaVariante(int index) {
    final variante = _varianti[index];
    setState(() {
      _varianti.insert(
        index + 1,
        VarianteTemp(
          nome: '${variante.nome} (Copia)',
          codiceProdotto: variante.codiceProdotto.trim().isEmpty
              ? ''
              : '${variante.codiceProdotto}_copy',
          barcodeInterno: '${variante.barcodeInterno}_copy',
          barcodeFornitore: variante.barcodeFornitore,
          barcode: variante.barcode,
          prezzo: variante.prezzo,
          quantita: variante.quantita,
          peso: variante.peso,
          immagineUrl: variante.immagineUrl,
          imageSetUrls: List<String>.from(variante.imageSetUrls),
          imageConfig: variante.imageConfig.copy(),
          metadatiCustom: variante.metadatiCustom == null
              ? null
              : Map<String, dynamic>.from(variante.metadatiCustom!),
          attributi: variante.attributi
              .map(
                (attr) => AttributoVariante(
                  nome: attr.nome,
                  opzione: attr.opzione,
                  valore: attr.valore,
                ),
              )
              .toList(),
        ),
      );
      _syncBarcodeFocusNodes();
    });
  }

  void _spostaVariante(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _varianti.length) return;

    setState(() {
      final item = _varianti.removeAt(index);
      _varianti.insert(newIndex, item);
      _syncBarcodeFocusNodes();
      _selectedVarianteIndex = newIndex;
    });
  }

  void _rimuoviVariante(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.prodottiConfermaEliminazione),
        content: Text(
          'Sei sicuro di voler eliminare la variante "${_varianti[index].nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _varianti.removeAt(index);
                _syncBarcodeFocusNodes();
                if (_varianti.isEmpty) {
                  _selectedVarianteIndex = null;
                } else if (_selectedVarianteIndex != null) {
                  if (_selectedVarianteIndex == index) {
                    _selectedVarianteIndex = 0;
                  } else if (_selectedVarianteIndex! > index) {
                    _selectedVarianteIndex = _selectedVarianteIndex! - 1;
                  }
                }
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).extension<AppColorExtension>()!.errorColorStatus,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  // Widget pulsante generazione barcode
  Widget _buildGeneraBarcodeButton({required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_fix_high),
      tooltip: context.l10n.prodottiGeneraBarcodeAuto,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        foregroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  // Widget pulsante IA
  Widget _buildAIButton({
    required bool isLoading,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IconButton(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).primaryColor,
                ),
              )
            : Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  // Metodi per generazione IA
  Future<void> _generateShortDescription() async {
    if (_nomeController.text.trim().isEmpty) {
      _showAIError('Inserisci prima il nome del prodotto');
      return;
    }

    setState(() => _isGeneratingShortDesc = true);
    try {
      final settings = AppSettings();
      await settings.init();
      final aiService = AIService(settings);

      final description = await aiService.generateProductDescription(
        productName: _nomeController.text.trim(),
        category: _categoriaController.text.trim().isNotEmpty
            ? _categoriaController.text.trim()
            : null,
        price: _prezzoNormaleController.text.trim().isNotEmpty
            ? _prezzoNormaleController.text.trim()
            : null,
        barcodeInterno: _barcodeInternoController.text.trim().isNotEmpty
            ? _barcodeInternoController.text.trim()
            : null,
        shortDescription: true,
      );

      setState(() {
        _descrizioneBreveController.text = description;
      });
    } catch (e) {
      _showAIError(e.toString());
    } finally {
      setState(() => _isGeneratingShortDesc = false);
    }
  }

  Future<void> _generateLongDescription() async {
    if (_nomeController.text.trim().isEmpty) {
      _showAIError('Inserisci prima il nome del prodotto');
      return;
    }

    setState(() => _isGeneratingLongDesc = true);
    try {
      final settings = AppSettings();
      await settings.init();
      final aiService = AIService(settings);

      final description = await aiService.generateProductDescription(
        productName: _nomeController.text.trim(),
        category: _categoriaController.text.trim().isNotEmpty
            ? _categoriaController.text.trim()
            : null,
        price: _prezzoNormaleController.text.trim().isNotEmpty
            ? _prezzoNormaleController.text.trim()
            : null,
        barcodeInterno: _barcodeInternoController.text.trim().isNotEmpty
            ? _barcodeInternoController.text.trim()
            : null,
        shortDescription: false,
      );

      setState(() {
        _descrizioneCompletaController.text = description;
      });
    } catch (e) {
      _showAIError(e.toString());
    } finally {
      setState(() => _isGeneratingLongDesc = false);
    }
  }

  Future<void> _generateCategories() async {
    if (_nomeController.text.trim().isEmpty) {
      _showAIError('Inserisci prima il nome del prodotto');
      return;
    }

    setState(() => _isGeneratingCategories = true);
    try {
      final settings = AppSettings();
      await settings.init();
      final aiService = AIService(settings);

      final categories = await aiService.suggestCategories(
        productName: _nomeController.text.trim(),
        description: _descrizioneBreveController.text.trim().isNotEmpty
            ? _descrizioneBreveController.text.trim()
            : null,
      );

      if (categories.isNotEmpty) {
        // Mostra dialog per selezione categorie
        if (mounted) {
          final selected = await SearchableCheckboxDialog.show(
            context,
            title: context.l10n.prodottiCategorieSuggerite,
            inputLabel: 'Filtra o nuova categoria',
            input_list: categories,
            preselected_list: _categorieSelezionate,
          );

          if (selected != null && selected.isNotEmpty) {
            setState(() {
              _categorieSelezionate = List<String>.from(selected)..sort();
              _categoriaController.text = _categorieSelezionate.join(', ');
              for (final categoria in _categorieSelezionate) {
                if (!_suggerimentiCategoria.any(
                  (item) => item.toLowerCase() == categoria.toLowerCase(),
                )) {
                  _suggerimentiCategoria.add(categoria);
                }
              }
              _suggerimentiCategoria.sort();
            });
          }
        }
      }
    } catch (e) {
      _showAIError(e.toString());
    } finally {
      setState(() => _isGeneratingCategories = false);
    }
  }

  Future<void> _generateTags() async {
    if (_nomeController.text.trim().isEmpty) {
      _showAIError('Inserisci prima il nome del prodotto');
      return;
    }

    setState(() => _isGeneratingTags = true);
    try {
      final settings = AppSettings();
      await settings.init();
      final aiService = AIService(settings);

      final suggestedTags = await aiService.suggestTags(
        productName: _nomeController.text.trim(),
        description: _descrizioneBreveController.text.trim().isNotEmpty
            ? _descrizioneBreveController.text.trim()
            : null,
        category: _categoriaController.text.trim().isNotEmpty
            ? _categoriaController.text.trim()
            : null,
      );

      if (suggestedTags.isNotEmpty && mounted) {
        // Mostra dialog per selezione tag
        final selectedTags = await SearchableCheckboxDialog.show(
          context,
          title: context.l10n.prodottiTagSuggeriti,
          inputLabel: 'Filtra o nuovo tag',
          input_list: suggestedTags,
          preselected_list: _tags,
        );

        if (selectedTags != null && selectedTags.isNotEmpty) {
          setState(() {
            for (final tag in selectedTags) {
              if (!_tags.contains(tag)) {
                _tags.add(tag);
              }
            }
          });
        }
      }
    } catch (e) {
      _showAIError(e.toString());
    } finally {
      setState(() => _isGeneratingTags = false);
    }
  }

  void _showAIError(String message) {
    if (!mounted) return;
    NotificationService.instance.messageBar('errore', 'prodotti_crea', message);
  }

  void _salvaProdotto() async {
    if (!_ensureProductTypeSelected()) return;

    if (_prodottiController == null) {
      NotificationService.instance.messageBar(
        'errore',
        'prodotti_crea',
        'Impossibile salvare in modalità offline',
      );
      return;
    }

    final prodottoPreparato = _creaProdottoDaForm();
    final formValid = _formKey.currentState!.validate();
    final validationError = _validateVariantiBeforeSave();

    if (_isUpdatingExisting) {
      final blockingMissing = _buildBlockingMissingFields(
        formValid: formValid,
        validationError: validationError,
      );
      final confirmed = await NotificationRecapDialog.edit(
        context,
        changes: _buildModifiedFieldList(prodottoPreparato),
        missingFields: _buildMissingFieldWarnings(),
        blockingMissingFields: blockingMissing,
        affectedItemsCount: 1,
      );
      if (!confirmed || !mounted || blockingMissing.isNotEmpty) return;
    } else if (!formValid) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'Controlla i campi obbligatori',
      );
      return;
    }

    if (!_isUpdatingExisting &&
        _productType == ProductTypeSelection.variable &&
        _varianti.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        'Aggiungi almeno una variante per il prodotto variabile.',
      );
      return;
    }

    if (!_isUpdatingExisting && validationError != null) {
      NotificationService.instance.messageBar(
        'warning',
        'prodotti_crea',
        validationError,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _saveProgress = 0.05;
      _saveProgressLabel = 'Validazione dati...';
    });

    try {
      _updateSaveProgress(0.2, 'Preparazione payload...');
      final prodotto = prodottoPreparato;
      log.d(
        'PCREA_SAVE_START mode=${_isUpdatingExisting ? 'update' : 'create'} productId=${prodotto.id} sku=${prodotto.barcodeInterno} expectedVariants=${prodotto.varianti?.length ?? 0}',
      );

      // Usa salvaProductoConVarianti per gestire sia il prodotto che le varianti
      _updateSaveProgress(0.45, 'Salvataggio prodotto e varianti...');
      final savedProduct = await _prodottiController!.salvaProductoConVarianti(
        prodotto,
      );
      final savedProductId = savedProduct.id ?? prodotto.id ?? 0;
      if (savedProductId > 0) {
        DataGridViewCache.markProductsDirty();
        DataGridViewCache.removeVariants(savedProductId);
      } else {
        DataGridViewCache.clearAll();
      }
      log.d(
        'PCREA_SAVE_DONE savedProductId=${savedProduct.id} sku=${savedProduct.barcodeInterno}',
      );

      ProductMgwsStockFeedback? mgwsFeedback;
      if (_mgwsInventoryEnabled) {
        _updateSaveProgress(0.65, 'Registrazione stock MGWS...');
        mgwsFeedback = await _prodottiController!.reconcileMgwsStockAfterSave(
          l10n: context.l10n,
          savedProduct: savedProduct,
          input: _buildMgwsStockInput(),
        );
        if (mounted) {
          setState(() {
            _mgwsInventoryFeedbackText = mgwsFeedback!.message;
            _mgwsInventoryFeedbackSuccess = mgwsFeedback.success;
          });
        }
        log.d(
          'PCREA_MGWS_RECONCILE_DONE success=${mgwsFeedback.success} productId=${savedProduct.id}',
        );
      }

      final verify = await _verificaPersistenzaProdotto(
        expected: prodotto,
        saved: savedProduct,
      );
      _updateSaveProgress(1.0, 'Completato');

      if (mounted) {
        final isFullSuccess = verify.productExists && verify.variantsComplete;
        final mgwsOk = mgwsFeedback?.success ?? true;
        final message = [
          _buildVerifyMessage(verify),
          if (mgwsFeedback != null) mgwsFeedback.message,
          if (mgwsFeedback != null && mgwsFeedback.details.isNotEmpty)
            mgwsFeedback.details.join(' '),
        ].join(' ');
        NotificationService.instance.messageBar(
          isFullSuccess && mgwsOk ? 'successo' : 'partial',
          'prodotti_crea',
          message,
        );
        if (isFullSuccess && mgwsOk) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      _updateSaveProgress(1.0, 'Errore durante il salvataggio');
      if (mounted) {
        final errorMessage = e.toString();
        NotificationService.instance.messageBar(
          'errore',
          'prodotti_crea',
          errorMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateVariantiBeforeSave() {
    if (_productType == ProductTypeSelection.simple) {
      return null;
    }

    if (_varianti.isEmpty) {
      return 'Aggiungi almeno una variante.';
    }

    final seenComboKeys = <String>{};
    final barcodeInterniVisti = <String>{};

    for (int vIndex = 0; vIndex < _varianti.length; vIndex++) {
      final variante = _varianti[vIndex];
      int validAttributePairs = 0;

      for (int aIndex = 0; aIndex < variante.attributi.length; aIndex++) {
        final attr = variante.attributi[aIndex];
        final nome = attr.nome.trim();
        final opzione = attr.opzione.trim();

        if (nome.isEmpty && opzione.isEmpty) continue;
        if (nome.isEmpty && opzione.isNotEmpty) {
          return 'Variante ${vIndex + 1}, attributo ${aIndex + 1}: nome attributo mancante.';
        }
        if (nome.isNotEmpty && opzione.isEmpty) {
          return 'Variante ${vIndex + 1}, attributo ${aIndex + 1}: valore mancante.';
        }
        validAttributePairs++;
      }

      if (validAttributePairs == 0) {
        return 'Variante ${vIndex + 1}: aggiungi almeno un attributo valido oppure rimuovi la variante.';
      }

      final comboKey = VariantCombinations.key(variante.attributi);
      if (comboKey.isNotEmpty) {
        if (seenComboKeys.contains(comboKey)) {
          return 'Variante ${vIndex + 1}: questa combinazione esiste già.';
        }
        seenComboKeys.add(comboKey);
      }

      final barcodeInternoNormalizzato = variante.barcodeInterno
          .trim()
          .toLowerCase();
      if (barcodeInternoNormalizzato.isNotEmpty) {
        if (barcodeInterniVisti.contains(barcodeInternoNormalizzato)) {
          return 'Variante ${vIndex + 1}: Barcode interno duplicato (${variante.barcodeInterno.trim()}).';
        }
        barcodeInterniVisti.add(barcodeInternoNormalizzato);
      }
    }
    return null;
  }

  Future<_PcreaVerifyResult> _verificaPersistenzaProdotto({
    required ProdottoGlobal expected,
    required ProdottoGlobal saved,
  }) async {
    final requestedVariants =
        expected.varianti ?? const <VarianteProductGlobal>[];
    final savedProductId = saved.id ?? 0;

    if (_prodottiController == null || savedProductId <= 0) {
      log.e(
        'PCREA_VERIFY_FAIL reason=invalid-controller-or-product-id savedProductId=$savedProductId',
      );
      return const _PcreaVerifyResult(
        productExists: false,
        variantsComplete: false,
        expectedVariants: 0,
        foundVariants: 0,
        barcodeInterniMancanti: <String>[],
      );
    }

    log.d(
      'PCREA_VERIFY_START productId=$savedProductId expectedVariants=${requestedVariants.length}',
    );

    bool productExists = false;
    try {
      final productFromServer = await _prodottiController!.getProductById(
        savedProductId,
      );
      productExists = (productFromServer.id ?? 0) > 0;
      log.d(
        'PCREA_VERIFY_PRODUCT_EXISTS productId=$savedProductId exists=$productExists',
      );
    } catch (e) {
      log.e(
        'PCREA_VERIFY_PRODUCT_EXISTS_FAIL productId=$savedProductId error=$e',
      );
      productExists = false;
    }

    List<VarianteProductGlobal> serverVariants =
        const <VarianteProductGlobal>[];
    try {
      serverVariants = await _prodottiController!.getAllVarianti(
        savedProductId,
      );
      log.d(
        'PCREA_VERIFY_VARIANTS_EXISTS productId=$savedProductId expected=${requestedVariants.length} found=${serverVariants.length}',
      );
    } catch (e) {
      log.e(
        'PCREA_VERIFY_VARIANTS_EXISTS_FAIL productId=$savedProductId error=$e',
      );
    }

    final barcodeInterniAttesi = requestedVariants
        .map((v) => (v.barcodeInterno).trim().toLowerCase())
        .where((barcodeInterno) => barcodeInterno.isNotEmpty)
        .toSet();

    final barcodeInterniTrovati = serverVariants
        .map((v) => (v.barcodeInterno).trim().toLowerCase())
        .where((barcodeInterno) => barcodeInterno.isNotEmpty)
        .toSet();

    final barcodeInterniMancanti =
        barcodeInterniAttesi
            .where(
              (barcodeInterno) =>
                  !barcodeInterniTrovati.contains(barcodeInterno),
            )
            .toList()
          ..sort();

    final variantsComplete = requestedVariants.isEmpty
        ? true
        : (barcodeInterniMancanti.isEmpty &&
              serverVariants.length >= requestedVariants.length);

    if (barcodeInterniMancanti.isNotEmpty) {
      log.e(
        'PCREA_VERIFY_MISSING_VARIANTS productId=$savedProductId barcodeInterniMancanti=${barcodeInterniMancanti.join(',')}',
      );
    }

    return _PcreaVerifyResult(
      productExists: productExists,
      variantsComplete: variantsComplete,
      expectedVariants: requestedVariants.length,
      foundVariants: serverVariants.length,
      barcodeInterniMancanti: barcodeInterniMancanti,
    );
  }

  String _buildVerifyMessage(_PcreaVerifyResult verify) {
    final action = _isUpdatingExisting ? 'aggiornato' : 'creato';
    if (verify.productExists && verify.variantsComplete) {
      return 'Prodotto $action e verificato (${verify.foundVariants}/${verify.expectedVariants} varianti trovate).';
    }
    if (!verify.productExists) {
      return 'Salvataggio eseguito ma verifica fallita: prodotto non trovato lato server.';
    }
    if (verify.barcodeInterniMancanti.isEmpty) {
      return 'Prodotto salvato, ma verifica varianti incompleta (${verify.foundVariants}/${verify.expectedVariants}).';
    }
    return 'Prodotto salvato, ma mancano ${verify.barcodeInterniMancanti.length} varianti: ${verify.barcodeInterniMancanti.join(', ')}';
  }

  List<String> _buildModifiedFieldList(ProdottoGlobal current) {
    final original = _prodottoOriginale;
    if (original == null) return const <String>[];

    final changes = <String>[];

    void addText(String label, String? before, String? after) {
      final oldValue = before?.trim() ?? '';
      final newValue = after?.trim() ?? '';
      if (oldValue == newValue) return;
      changes.add('$label: ${newValue.isEmpty ? 'vuoto' : newValue}');
    }

    void addNumber(String label, num? before, num? after) {
      if ((before ?? 0) == (after ?? 0)) return;
      changes.add('$label: ${after ?? 0}');
    }

    String joinNames<T>(Iterable<T>? values, String Function(T item) label) {
      final labels =
          (values ?? <T>[])
              .map(label)
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return labels.join(', ');
    }

    addText(
      context.l10n.prodottiFiltroNomeProdotto,
      original.nome,
      current.nome,
    );
    addText(
      context.l10n.productsProductCode,
      original.codiceProdotto,
      current.codiceProdotto,
    );
    addText(
      context.l10n.productsInternalBarcode,
      original.barcodeInterno,
      current.barcodeInterno,
    );
    addText(
      context.l10n.productsBarcodeManufacturer,
      original.barcodeProduttore,
      current.barcodeProduttore,
    );
    addText(
      context.l10n.prodottiFiltroCampo_descrizioneBreve,
      original.descrizioneBreve,
      current.descrizioneBreve,
    );
    addText(
      context.l10n.prodottiFiltroCampo_descrizioneCompleta,
      original.descrizioneCompleta,
      current.descrizioneCompleta,
    );
    addText(context.l10n.prodottiMarchio, original.marca, current.marca);
    addText(
      context.l10n.prodottiProductStatus,
      _statusLabel(context, original.status),
      _statusLabel(context, current.status),
    );
    addText(
      context.l10n.prodottiCopertina,
      original.immagineUrl,
      current.immagineUrl,
    );
    addText(
      context.l10n.prodottiGallery,
      (original.immaginiAggiuntive ?? const <String>[]).join(', '),
      (current.immaginiAggiuntive ?? const <String>[]).join(', '),
    );
    addText(
      context.l10n.prodottiCategories,
      joinNames(original.categoria, (item) => item.nome),
      joinNames(current.categoria, (item) => item.nome),
    );
    addText(
      context.l10n.prodottiFiltroCampo_tag,
      joinNames(original.tag, (item) => item.nome),
      joinNames(current.tag, (item) => item.nome),
    );

    if (_productType == ProductTypeSelection.simple) {
      addNumber(
        context.l10n.commonPrice,
        original.prezzoNormale,
        current.prezzoNormale,
      );
      addNumber(
        context.l10n.prodottiDiscountedPrice,
        original.prezzoScontato,
        current.prezzoScontato,
      );
      addText(context.l10n.prodottiWeight, original.peso, current.peso);
      addNumber(
        context.l10n.prodottiQuantita,
        original.quantitaTotale,
        current.quantitaTotale,
      );
    }

    final originalVariants =
        original.varianti ?? const <VarianteProductGlobal>[];
    final currentVariants = current.varianti ?? const <VarianteProductGlobal>[];
    if (originalVariants.length != currentVariants.length) {
      changes.add('Varianti: ${currentVariants.length}');
    }

    final originalByKey = <String, VarianteProductGlobal>{
      for (final variante in originalVariants)
        _variantCompareKey(variante): variante,
    };
    for (var index = 0; index < currentVariants.length; index++) {
      final variant = currentVariants[index];
      final originalVariant = originalByKey[_variantCompareKey(variant)];
      final label = _variantRecapLabel(variant, index);
      if (originalVariant == null) {
        changes.add('$label: nuova variante');
        continue;
      }
      if (originalVariant.codiceProdotto != variant.codiceProdotto) {
        changes.add(
          '$label codice prodotto: ${variant.codiceProdotto.isEmpty ? 'vuoto' : variant.codiceProdotto}',
        );
      }
      if (originalVariant.barcodeInterno != variant.barcodeInterno) {
        changes.add(
          '$label barcode interno: ${variant.barcodeInterno.isEmpty ? 'vuoto' : variant.barcodeInterno}',
        );
      }
      if (originalVariant.prezzo != variant.prezzo) {
        changes.add('$label prezzo: ${variant.prezzo}');
      }
      if (originalVariant.prezzoScontato != variant.prezzoScontato) {
        changes.add(
          '$label prezzo scontato: ${variant.prezzoScontato ?? 'vuoto'}',
        );
      }
      if (originalVariant.quantita != variant.quantita) {
        changes.add('$label quantità: ${variant.quantita}');
      }
      final originalImages = _variantProductGlobalImageUrls(originalVariant);
      final currentImages = _variantProductGlobalImageUrls(variant);
      if (originalImages.join(',') != currentImages.join(',')) {
        changes.add(
          '$label immagini: ${currentImages.isEmpty ? 'vuote' : currentImages.join(', ')}',
        );
      }
    }

    return changes;
  }

  List<String> _buildBlockingMissingFields({
    required bool formValid,
    String? validationError,
  }) {
    final fields = <String>[];
    if (_nomeController.text.trim().isEmpty) fields.add('Nome prodotto');
    if (_productType == null) fields.add('Tipo prodotto');
    if (!formValid && fields.isEmpty) {
      fields.add('Controlla i campi obbligatori evidenziati');
    }
    if (validationError != null) fields.add(validationError);
    return fields;
  }

  List<String> _buildMissingFieldWarnings() {
    final fields = <String>[];
    if (_codiceProdottoController.text.trim().isEmpty) {
      fields.add('Codice prodotto');
    }
    if (_productType == ProductTypeSelection.simple &&
        _barcodeInternoController.text.trim().isEmpty) {
      fields.add('Barcode interno');
    }
    if (_categorieSelezionate.isEmpty) fields.add('Categorie');
    if (_tags.isEmpty) fields.add('Tag');
    if (_descrizioneBreveController.text.trim().isEmpty) {
      fields.add('Descrizione breve');
    }
    if (_descrizioneCompletaController.text.trim().isEmpty) {
      fields.add('Descrizione completa');
    }
    if (_marcaController.text.trim().isEmpty) fields.add('Marchio');
    if (_immagineUrlController.text.trim().isEmpty) fields.add('Copertina');
    if (_productType == ProductTypeSelection.simple &&
        _pesoController.text.trim().isEmpty) {
      fields.add('Peso');
    }
    return fields;
  }

  String _variantCompareKey(VarianteProductGlobal variante) {
    if (variante.id > 0) return 'id:${variante.id}';
    return VariantCombinations.key(variante.attributi);
  }

  String _variantRecapLabel(VarianteProductGlobal variante, int index) {
    final attrs = variante.attributi
        .map((attr) => attr.opzione.trim())
        .where((value) => value.isNotEmpty)
        .join(' / ');
    return attrs.isEmpty ? 'Variante #${index + 1}' : 'Variante $attrs';
  }

  List<String> _variantProductGlobalImageUrls(VarianteProductGlobal variante) {
    final urls = <String>[];
    final main = variante.immagineUrl?.trim();
    if (main != null && main.isNotEmpty) urls.add(main);
    for (final url in variante.immaginiAggiuntive) {
      final clean = url.trim();
      if (clean.isNotEmpty && !urls.contains(clean)) urls.add(clean);
    }
    return urls;
  }

  ProdottoGlobal _creaProdottoDaForm() {
    final isVariable = _productType == ProductTypeSelection.variable;
    final productStatus = _normalizeProductStatus(_productStatus);
    final attributiProdotto = _buildAttributiProdottoDaSalvare();
    final categorie =
        _categorieSelezionate
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final variantiPulite = _varianti
        .map((temp) {
          final attributiPuliti = temp.attributi
              .map(
                (a) =>
                    a.copyWith(nome: a.nome.trim(), opzione: a.opzione.trim()),
              )
              .where((a) => a.nome.isNotEmpty && a.opzione.isNotEmpty)
              .toList();
          return temp.toVarianteProductGlobal(
            attributiOverride: attributiPuliti,
          );
        })
        .where((v) => v.attributi.isNotEmpty)
        .toList();

    return ProdottoGlobal(
      id: _prodottoOriginale?.id ?? 0,
      nome: _nomeController.text.trim(),
      codiceProdotto: _codiceProdottoController.text.trim().isEmpty
          ? null
          : _codiceProdottoController.text.trim(),
      barcodeInterno: isVariable ? '' : _barcodeInternoController.text.trim(),
      barcodeProduttore:
          isVariable || _barcodeProduttoreController.text.trim().isEmpty
          ? null
          : _barcodeProduttoreController.text.trim(),
      prezzoNormale: double.tryParse(_prezzoNormaleController.text) ?? 0.0,
      prezzoScontato: _hasPrezzoScontato
          ? double.tryParse(_prezzoScontatoController.text)
          : null,
      descrizioneBreve: _descrizioneBreveController.text.trim(),
      descrizioneCompleta: _descrizioneCompletaController.text.trim().isEmpty
          ? null
          : _descrizioneCompletaController.text.trim(),
      immagineUrl: _immagineUrlController.text.trim(),
      immaginiAggiuntive: List<String>.from(_mainImageSetUrls),
      categoria: categorie
          .map(
            (categoria) => CategoriaProdotto(
              id: 0,
              nome: categoria,
              slug: categoria.toLowerCase().replaceAll(' ', '-'),
            ),
          )
          .toList(),
      peso: isVariable
          ? null
          : (_pesoController.text.trim().isEmpty
                ? null
                : _pesoController.text.trim()),
      quantitaTotale: isVariable
          ? 0
          : (int.tryParse(_quantitaController.text) ?? 0),
      inStock: isVariable ? false : _inStock,
      marca: _marcaController.text.trim().isEmpty
          ? null
          : _marcaController.text.trim(),
      attributi: isVariable ? attributiProdotto : [],
      varianti: isVariable ? variantiPulite : [],
      tag: _tags
          .map(
            (tagName) => TagProdotto(
              id: 0, // Il backend gestirà l'ID
              nome: tagName,
              slug: tagName.toLowerCase().replaceAll(' ', '-'),
            ),
          )
          .toList(),
      status: productStatus,
    );
  }

  String _normalizeProductStatus(String? status) {
    final normalized = status?.trim().toLowerCase() ?? 'draft';
    return _productStatusOptions.contains(normalized) ? normalized : 'draft';
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'publish':
        return context.l10n.prodottiStatusPubblico;
      case 'private':
        return context.l10n.prodottiStatusPrivato;
      case 'pending':
        return context.l10n.prodottiStatusInRevisione;
      case 'draft':
      default:
        return context.l10n.prodottiStatusBozza;
    }
  }

  List<AttributoVariante> _buildAttributiProdottoValidi() {
    final result = <AttributoVariante>[];

    for (final item in _attributiProdottoSelezionati) {
      final nome = item.nome.trim();
      if (nome.isEmpty) continue;

      final valori =
          item.valori
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      for (final valore in valori) {
        result.add(AttributoVariante(nome: nome, opzione: valore));
      }
    }

    return result;
  }

  List<AttributoVariante> _buildAttributiProdottoDaSalvare() {
    final unique = <String, AttributoVariante>{};

    void addAll(Iterable<AttributoVariante> attributes) {
      for (final attribute in attributes) {
        final nome = attribute.nome.trim();
        final opzione = attribute.opzione.trim();
        if (nome.isEmpty || opzione.isEmpty) continue;
        final key = '${nome.toLowerCase()}=${opzione.toLowerCase()}';
        unique[key] = attribute.copyWith(nome: nome, opzione: opzione);
      }
    }

    addAll(_attributiProdottoEsistenti);
    addAll(_buildAttributiProdottoValidi());
    for (final variante in _varianti) {
      addAll(variante.attributi);
    }

    return unique.values.toList()..sort(
      (a, b) => '${a.nome.toLowerCase()}=${a.opzione.toLowerCase()}'.compareTo(
        '${b.nome.toLowerCase()}=${b.opzione.toLowerCase()}',
      ),
    );
  }

  List<AttributoVariante> _collectProductAttributes({
    required ProdottoGlobal prodotto,
    required List<VarianteTemp> varianti,
  }) {
    final attributes = <AttributoVariante>[
      ...?prodotto.attributi,
      for (final variante in varianti) ...variante.attributi,
    ];
    final unique = <String, AttributoVariante>{};
    for (final attribute in attributes) {
      final nome = attribute.nome.trim();
      final opzione = attribute.opzione.trim();
      if (nome.isEmpty || opzione.isEmpty) continue;
      unique['${nome.toLowerCase()}=${opzione.toLowerCase()}'] = attribute
          .copyWith(nome: nome, opzione: opzione);
    }
    return unique.values.toList();
  }
}

class _PcreaVerifyResult {
  final bool productExists;
  final bool variantsComplete;
  final int expectedVariants;
  final int foundVariants;
  final List<String> barcodeInterniMancanti;

  const _PcreaVerifyResult({
    required this.productExists,
    required this.variantsComplete,
    required this.expectedVariants,
    required this.foundVariants,
    required this.barcodeInterniMancanti,
  });
}

class ProductImageUiConfig {
  bool isSetMode;

  ProductImageUiConfig({this.isSetMode = false});

  void reset() {
    isSetMode = false;
  }

  ProductImageUiConfig copy() {
    return ProductImageUiConfig(isSetMode: isSetMode);
  }
}

class _ProductImageRow {
  final String url;
  final bool isMain;

  const _ProductImageRow({required this.url, required this.isMain});
}

class _ImagePixelSize {
  final int width;
  final int height;

  const _ImagePixelSize({required this.width, required this.height});
}

// Classe helper per gestire le varianti temporanee durante l'editing
class VarianteTemp {
  final Object uiKey = Object();
  int? id;
  String nome;
  String codiceProdotto;
  String barcodeInterno;
  String barcodeFornitore;
  String barcode;
  double prezzo;
  double? prezzoScontato;
  int quantita;
  String? peso;
  String? immagineUrl;
  List<String> imageSetUrls;
  ProductImageUiConfig imageConfig;
  List<AttributoVariante> attributi;
  Map<String, dynamic>? metadatiCustom;

  VarianteTemp({
    this.id,
    required this.nome,
    this.codiceProdotto = '',
    required this.barcodeInterno,
    this.barcodeFornitore = '',
    required this.barcode,
    required this.prezzo,
    this.prezzoScontato,
    required this.quantita,
    this.peso,
    this.immagineUrl,
    List<String>? imageSetUrls,
    ProductImageUiConfig? imageConfig,
    List<AttributoVariante>? attributi,
    this.metadatiCustom,
  }) : imageSetUrls = imageSetUrls ?? [],
       imageConfig = imageConfig ?? ProductImageUiConfig(),
       attributi = attributi ?? [];

  static VarianteTemp fromVarianteProductGlobal(
    VarianteProductGlobal variante,
    ProductImageUiConfig? defaultImageConfig,
  ) {
    return VarianteTemp(
      id: variante.id,
      nome: variante.nome,
      codiceProdotto: variante.codiceProdotto,
      barcodeInterno: variante.barcodeInterno,
      barcodeFornitore:
          (variante.metadatiCustom?['barcode_manufacturer'] ??
                  variante.metadatiCustom?['barcode_produttore'] ??
                  variante.metadatiCustom?['barcode'] ??
                  variante.metadatiCustom?['supplier_sku'] ??
                  '')
              .toString(),
      barcode: '',
      prezzo: variante.prezzo,
      prezzoScontato: variante.prezzoScontato,
      quantita: variante.quantita,
      peso: variante.peso,
      immagineUrl: variante.immagineUrl,
      imageSetUrls: _imageUrlsFromProductGlobal(variante),
      imageConfig: defaultImageConfig?.copy() ?? ProductImageUiConfig(),
      attributi: List.from(variante.attributi),
      metadatiCustom: variante.metadatiCustom == null
          ? null
          : Map<String, dynamic>.from(variante.metadatiCustom!),
    );
  }

  static List<String> _imageUrlsFromProductGlobal(
    VarianteProductGlobal variante,
  ) {
    final urls = <String>[];
    final single = variante.immagineUrl?.trim();
    if (single != null && single.isNotEmpty) urls.add(single);
    for (final url in variante.immaginiAggiuntive) {
      final clean = url.trim();
      if (clean.isNotEmpty && !urls.contains(clean)) urls.add(clean);
    }
    return urls;
  }

  VarianteProductGlobal toVarianteProductGlobal({
    List<AttributoVariante>? attributiOverride,
  }) {
    final distinctImages = immaginiDistinte;
    return VarianteProductGlobal(
      id: id ?? 0,
      nome: nome,
      codiceProdotto: codiceProdotto,
      barcodeInterno: barcodeInterno,
      metadatiCustom: <String, dynamic>{
        ...?metadatiCustom,
        if (barcodeFornitore.trim().isNotEmpty)
          'barcode_manufacturer': barcodeFornitore.trim(),
      },
      prezzo: prezzo,
      prezzoScontato: prezzoScontato,
      quantita: quantita,
      peso: peso,
      immagineUrl: distinctImages.isNotEmpty ? distinctImages.first : null,
      immaginiAggiuntive: distinctImages.skip(1).toList(growable: false),
      attributi: attributiOverride ?? attributi,
    );
  }

  List<String> get immaginiDistinte {
    final urls = <String>[];
    for (final url in imageSetUrls) {
      final clean = url.trim();
      if (clean.isNotEmpty && !urls.contains(clean)) urls.add(clean);
    }
    final single = immagineUrl?.trim();
    if (single != null && single.isNotEmpty && !urls.contains(single)) {
      urls.insert(0, single);
    }
    return urls;
  }
}

class AttributoProdottoSelezionato {
  final TextEditingController nomeController;
  final TextEditingController valoriController;
  List<String> valori;

  AttributoProdottoSelezionato({String nome = '', List<String>? valori})
    : nomeController = TextEditingController(text: nome),
      valoriController = TextEditingController(
        text: (valori ?? const <String>[]).join(', '),
      ),
      valori = List<String>.from(valori ?? const <String>[]);

  String get nome => nomeController.text.trim();

  void setValori(List<String> newValues) {
    valori =
        newValues
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    valoriController.text = valori.join(', ');
  }

  void dispose() {
    nomeController.dispose();
    valoriController.dispose();
  }
}
