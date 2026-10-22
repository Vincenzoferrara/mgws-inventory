import '../class_products.dart';
import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../login/mgws/connection/mgws_connection.dart';
import '../../login/mgws/query/query_mgws_inventory.dart';
import '../../l10n/extensions.dart';

class ProductMgwsStockInput {
  const ProductMgwsStockInput({
    required this.stockText,
    required this.reasonText,
    this.siteIdText = '',
  });

  final String stockText;
  final String reasonText;

  /// Sede in cui il totale viene scritto, come testo del campo.
  ///
  /// Facoltativa perche' la rotta pretende la sede solo su un negozio con piu'
  /// di una sede: sotto quella soglia il totale del prodotto e il totale della
  /// sede sono lo stesso numero, e chiederne uno non aggiungerebbe nulla.
  /// Lasciata vuota su un negozio con piu' sedi, la rotta risponde con un errore
  /// e il prodotto resta salvato senza stock: e' preferibile a uno stock scritto
  /// nella sede sbagliata, che nessuno saprebbe piu' di quale fosse.
  final String siteIdText;
}

class ProductMgwsStockFeedback {
  const ProductMgwsStockFeedback({
    required this.success,
    required this.message,
    this.details = const [],
  });

  final bool success;
  final String message;
  final List<String> details;
}

String? validateProductMgwsStock(
  AppLocalizations l10n, {
  required bool enabled,
  String? value,
}) {
  if (!enabled) return null;
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return l10n.productsMgwsStockRequired;
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return l10n.productsMgwsStockNonNegativeInteger;
  }
  return null;
}

String? validateProductMgwsReason(
  AppLocalizations l10n, {
  required bool enabled,
  String? value,
}) {
  if (!enabled) return null;
  if ((value ?? '').trim().isEmpty) return l10n.productsMgwsReasonRequired;
  return null;
}

/// Controller per la creazione e gestione dei prodotti
/// Usa PlatformManager per supporto multi-piattaforma
class ProdottiCreaController {
  // Cache per evitare chiamate ripetute
  List<CategoriaProdotto>? _categoriesCache;
  List<TagProdotto>? _tagsCache;
  List<MarcaProdotto>? _brandsCache;

  ProdottiCreaController({
    MgwsInventoryGateway? inventoryGateway,
    MgwsConnection? mgwsConnection,
  }) : _inventoryGateway = inventoryGateway ?? QueryMgwsInventory(),
       _availability = mgwsConnection ?? MgwsConnection.instance;

  final MgwsInventoryGateway _inventoryGateway;
  final MgwsConnection _availability;

  // =======================================================
  // == METODI PRINCIPALI                                 ==
  // =======================================================

  /// Ottiene un singolo prodotto per ID
  Future<ProdottoGlobal> getProductById(int productId) async {
    return await PlatformManager.prodotti.getProductById(productId);
  }

  /// Carica dal server la versione piu aggiornata del prodotto da modificare.
  /// Usa l'ID come fonte primaria e `codiceProdotto` come fallback operativo.
  Future<ProdottoGlobal> getFreshProductForEdit({
    int? productId,
    String? codiceProdotto,
  }) async {
    final normalizedId = productId ?? 0;
    if (normalizedId > 0) {
      try {
        return await getProductById(normalizedId);
      } catch (_) {
        // Fallback sotto: se l'ID non e piu risolvibile, prova il codice.
      }
    }

    final normalizedCode = codiceProdotto?.trim() ?? '';
    if (normalizedCode.isNotEmpty) {
      final product = await PlatformManager.prodotti
          .findProductByCodiceProdottoExact(normalizedCode);
      if (product != null) return product;
    }

    throw Exception(
      'Prodotto non trovato sul server. ID: ${normalizedId > 0 ? normalizedId : '-'}, codice prodotto: ${normalizedCode.isEmpty ? '-' : normalizedCode}',
    );
  }

  /// Ottiene tutte le varianti di un prodotto
  Future<List<VarianteProductGlobal>> getAllVarianti(
    int productId, {
    List<AttributoVariante>? attributiProdotto,
    bool logRawAttributeMapping = false,
  }) async {
    return await PlatformManager.varianti.getAllVariations(
      productId,
      attributiProdotto: attributiProdotto,
      logRawAttributeMapping: logRawAttributeMapping,
      debugLogSource: 'PCREA',
    );
  }

  /// Ottiene tutte le categorie con cache
  Future<List<CategoriaProdotto>> getCategories({
    bool forceRefresh = false,
  }) async {
    if (_categoriesCache == null || forceRefresh) {
      _categoriesCache = await PlatformManager.categorie.getCategories(
        perPage: 100,
      );
    }
    return _categoriesCache!;
  }

  /// Ottiene tutti i tag con cache
  Future<List<TagProdotto>> getTags({bool forceRefresh = false}) async {
    if (_tagsCache == null || forceRefresh) {
      _tagsCache = await PlatformManager.tag.getTags(perPage: 100);
    }
    return _tagsCache!;
  }

  /// Ottiene tutti i marchi con cache
  Future<List<MarcaProdotto>> getBrands({bool forceRefresh = false}) async {
    if (_brandsCache == null || forceRefresh) {
      _brandsCache = await PlatformManager.marchi.getBrands(perPage: 100);
    }
    return _brandsCache!;
  }

  /// Ottiene tutti gli attributi con cache
  Future<List<dynamic>> getAttributes({bool forceRefresh = false}) async {
    return await PlatformManager.attributi.getAttributes();
  }

  /// Ottiene i termini di un attributo specifico
  Future<List<dynamic>> getAttributeTerms(
    int attributeId, {
    bool forceRefresh = false,
  }) async {
    return await PlatformManager.attributi.getAttributeTerms(attributeId);
  }

  /// Crea un nuovo prodotto
  Future<ProdottoGlobal> creaProdotto(ProdottoGlobal prodotto) async {
    try {
      // Usa PlatformManager per creare il prodotto
      return await PlatformManager.prodotti.createProduct(prodotto);
    } catch (e) {
      throw Exception('Errore durante la creazione del prodotto: $e');
    }
  }

  /// Aggiorna un prodotto esistente
  Future<ProdottoGlobal> aggiornaProdotto(ProdottoGlobal prodotto) async {
    try {
      // Usa PlatformManager per aggiornare il prodotto
      return await PlatformManager.prodotti.updateProduct(prodotto);
    } catch (e) {
      throw Exception('Errore durante l\'aggiornamento del prodotto: $e');
    }
  }

  // =======================================================
  // == GESTIONE VARIANTI E ATTRIBUTI                     ==
  // =======================================================

  /// Crea o aggiorna un prodotto completo con le sue varianti
  /// Il backend si occuperà di gestire categorie, tag, attributi e varianti
  Future<ProdottoGlobal> salvaProductoConVarianti(
    ProdottoGlobal prodotto,
  ) async {
    try {
      // Il backend gestisce tutto: creazione categorie/tag/attributi/varianti
      if ((prodotto.id ?? 0) == 0) {
        // Crea prodotto nuovo
        return await creaProdotto(prodotto);
      } else {
        // Aggiorna prodotto esistente
        return await aggiornaProdotto(prodotto);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ProductMgwsStockFeedback> reconcileMgwsStockAfterSave({
    required AppLocalizations l10n,
    required ProdottoGlobal savedProduct,
    required ProductMgwsStockInput input,
  }) async {
    final productId = savedProduct.id ?? 0;
    if (productId <= 0) {
      return ProductMgwsStockFeedback(
        success: false,
        message: l10n.productsMgwsStockMissingProductId,
      );
    }

    final correctStock = int.tryParse(input.stockText.trim());
    if (correctStock == null || correctStock < 0) {
      return ProductMgwsStockFeedback(
        success: false,
        message: l10n.productsMgwsStockInvalidValue,
      );
    }

    final reason = input.reasonText.trim();
    if (reason.isEmpty) {
      return ProductMgwsStockFeedback(
        success: false,
        message: l10n.productsMgwsStockReasonRequired,
      );
    }

    // La sede viaggia quando e' stata dichiarata e resta zero altrimenti: e' la
    // rotta a decidere se senza di lei il totale e' ambiguo, e questa schermata
    // non fa delle ipotesi sul negozio in cui sta girando. Su un negozio con una
    // sola sede lo zero e' corretto, su uno con piu' sedi la rotta risponde e il
    // prodotto resta salvato senza stock.
    final siteId = int.tryParse(input.siteIdText.trim()) ?? 0;
    if (siteId < 0) {
      return ProductMgwsStockFeedback(
        success: false,
        message: l10n.productsMgwsStockInvalidSite,
      );
    }

    if (!await _availability.ensureConnected()) {
      return ProductMgwsStockFeedback(
        success: false,
        message: l10n.productsMgwsStockBackendUnavailable,
      );
    }

    try {
      final result = await _inventoryGateway.reconcileStock(
        productId: productId,
        correctStock: correctStock,
        siteId: siteId,
        reason: reason,
      );
      final delta = result.delta == null
          ? ''
          : ' (${l10n.productsMgwsStockDelta} ${result.delta! > 0 ? '+' : ''}${result.delta})';
      // Il numero che e' tornato indietro appartiene a una sede, e il messaggio
      // lo dice: su un negozio con piu' sedi due totali con lo stesso valore non
      // sono la stessa cosa, e l'operatore deve sapere quale ha appena scritto.
      // Il nome della sede viene dalla risposta, non da una ipotesi fatta qui.
      final sede = (result.siteId ?? 0) > 0
          ? ' (${l10n.productsMgwsStockSite} ${result.siteId})'
          : '';
      if (!result.success || result.errors.isNotEmpty) {
        return ProductMgwsStockFeedback(
          success: false,
          message:
              '${l10n.productsMgwsStockNotRegistered}: ${result.message}$delta',
          details: result.errors,
        );
      }
      return ProductMgwsStockFeedback(
        success: true,
        message:
            '${l10n.productsMgwsStockRegistered}$sede: ${result.message}$delta',
        details: result.errors,
      );
    } catch (e) {
      return ProductMgwsStockFeedback(
        success: false,
        message: '${l10n.productsMgwsStockNotRegistered}: $e',
      );
    }
  }

  /// Pulisce la cache
  void clearCache() {
    _categoriesCache = null;
    _tagsCache = null;
    _brandsCache = null;
  }
}

// Extension per gestire valori null nelle liste
extension ListExtensions<T> on List<T>? {
  T? get firstOrNull {
    if (this == null || this!.isEmpty) return null;
    return this!.first;
  }
}
