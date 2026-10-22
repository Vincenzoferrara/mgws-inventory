import '../login/mgws/query/query_mgws_inventory.dart';
import '../login/mgws/connection/mgws_connection.dart';
import 'inventory_restock_feedback.code.dart';

export 'inventory_add_products.code.dart';
export 'inventory_counts.code.dart';
export 'inventory_move.code.dart';
export 'inventory_movement_key.code.dart' show newInventoryMovementKey;
export 'inventory_movements.code.dart';
export 'inventory_purchase_orders.code.dart';
export 'inventory_quick_load.code.dart';
export 'inventory_quick_load_catalog.code.dart';
export 'inventory_receipts.code.dart';
export 'inventory_reorder.code.dart';
export 'inventory_restock_feedback.code.dart';
export 'inventory_adjustment.code.dart';
export 'inventory_suppliers.code.dart';

/// Testo libero che finisce sul movimento MGWS.
///
/// Usato da Aggiungi e Rettifica, che hanno un solo campo libero sul backend: il
/// motivo. I dettagli che l'operatore scrive una volta sola a pagina non hanno
/// un campo proprio su quelle rotte, quindi viaggiano agganciati al motivo
/// invece di restare sulla schermata e sparire.
///
/// Il campo Dettaglio della pagina inventario e' il testo operativo unico che
/// sostituisce i vecchi campi motivo dei singoli moduli.
String inventoryMovementText(String reason, String details) {
  final head = reason.trim();
  final tail = details.trim();
  if (head.isEmpty) return tail;
  if (tail.isEmpty) return head;
  return '$head - $tail';
}

class InventoryController {
  InventoryController({
    MgwsInventoryGateway? gateway,
    MgwsConnection? mgwsConnection,
  }) : gateway = gateway ?? QueryMgwsInventory(),
       _availability = mgwsConnection ?? MgwsConnection.instance;

  final MgwsInventoryGateway gateway;
  final MgwsConnection _availability;

  List<Map<String, dynamic>> stockRows = const [];
  InventoryActionFeedback? lastFeedback;
  MgwsStockSyncResult? lastSyncResult;
  MgwsReconcileResult? lastReconcileResult;
  MgwsRfidScanResult? lastRfidResult;
  MgwsMoveResult? lastMoveResult;
  bool? isMgwsAvailable;
  bool isCheckingAvailability = false;
  bool isLoadingStock = false;
  bool isSyncing = false;
  bool isReconciling = false;
  bool isMoving = false;
  bool isResolvingRfid = false;

  /// Verifica esplicita del backend, richiesta dall'utente.
  ///
  /// Colpisce la rete invece di usare lo stato in cache: l'utente ha premuto
  /// "verifica", quindi vuole il dato fresco. Le azioni del modulo usano invece
  /// `ensureConnected`.
  Future<InventoryActionFeedback> checkMgwsReadiness() async {
    isCheckingAvailability = true;
    try {
      final available = await _availability.verify();
      isMgwsAvailable = available;
      return _remember(
        InventoryActionFeedback(
          success: available,
          message: available
              ? 'Backend MGWS disponibile'
              : 'Backend MGWS richiesto: accedi o configura il backend MGWS',
        ),
      );
    } finally {
      isCheckingAvailability = false;
    }
  }

  Future<InventoryActionFeedback> loadStock({String? productIdText}) async {
    if (!await _availability.ensureConnected()) return _mgwsUnavailable();
    isLoadingStock = true;
    try {
      final productId = _optionalProductId(productIdText ?? '');
      stockRows = productId == null
          ? await gateway.getAllStock()
          : [await gateway.getProductStock(productId)];
      return _remember(
        InventoryActionFeedback(
          success: true,
          message: stockRows.isEmpty
              ? 'Nessuna riga stock disponibile'
              : 'Stock caricato: ${stockRows.length} righe',
        ),
      );
    } catch (e) {
      return _remember(
        InventoryActionFeedback(
          success: false,
          message: 'Errore caricamento stock MGWS: $e',
        ),
      );
    } finally {
      isLoadingStock = false;
    }
  }

  Future<InventoryActionFeedback> syncWooToMgws({
    required String productIdText,
    required String wooStockText,
  }) async {
    final productId = InventoryInputParser.parseProductId(productIdText);
    if (productId == null) return _validationError('product_id non valido');
    final wooStock = InventoryInputParser.parseStock(wooStockText);
    if (wooStock == null) return _validationError('woo_stock non valido');
    if (!await _availability.ensureConnected()) return _mgwsUnavailable();

    isSyncing = true;
    try {
      final result = await gateway.syncWooStockToMgws(
        productId: productId,
        wooStock: wooStock,
        syncType: 'manual',
      );
      lastSyncResult = result;
      return _remember(
        InventoryActionFeedback(
          success: result.success,
          message: _stockMessage(
            'Sync Woo -> MGWS',
            result.message,
            result.delta,
          ),
          details: result.errors,
        ),
      );
    } catch (e) {
      return _remember(
        InventoryActionFeedback(
          success: false,
          message: 'Errore sync MGWS: $e',
        ),
      );
    } finally {
      isSyncing = false;
    }
  }

  Future<InventoryActionFeedback> reconcileStock({
    required String productIdText,
    required String correctStockText,
    required String siteIdText,
    required String reasonText,

    /// Stessa chiave su tutte le righe di una rettifica: e' cio' che tiene
    /// insieme i prodotti corretti nella stessa operazione.
    String? movementKey,
  }) async {
    final productId = InventoryInputParser.parseProductId(productIdText);
    if (productId == null) return _validationError('product_id non valido');
    final correctStock = InventoryInputParser.parseStock(correctStockText);
    if (correctStock == null)
      return _validationError('correct_stock non valido');
    // La sede non si deduce dal prodotto ne' dal magazzino: e' il perimetro
    // dentro cui il totale viene riscritto, e senza il perimetro il numero
    // correggerebbe un posto diverso da quello che l'operatore sta guardando.
    final siteId = InventoryInputParser.parseOptionalPositiveInt(siteIdText);
    if (siteId == null) return _validationError('site_id non valido');
    final reason = reasonText.trim();
    if (reason.isEmpty) return _validationError('reason richiesto');
    if (!await _availability.ensureConnected()) return _mgwsUnavailable();

    isReconciling = true;
    try {
      final result = await gateway.reconcileStock(
        productId: productId,
        correctStock: correctStock,
        siteId: siteId,
        reason: reason,
        movementKey: movementKey,
      );
      lastReconcileResult = result;
      return _remember(
        InventoryActionFeedback(
          success: result.success,
          message: _stockMessage(
            'Reconcile stock',
            result.message,
            result.delta,
          ),
          details: result.errors,
        ),
      );
    } catch (e) {
      return _remember(
        InventoryActionFeedback(
          success: false,
          message: 'Errore reconcile MGWS: $e',
        ),
      );
    } finally {
      isReconciling = false;
    }
  }

  /// Sposta pezzi da una sede/magazzino a un altro.
  ///
  /// Lo stock totale del prodotto non cambia: e il magazzino di partenza che
  /// perde i pezzi e quello di arrivo che li guadagna. Per questo lo
  /// spostamento non passa per [reconcileStock], che altererebbe il totale.
  Future<InventoryActionFeedback> moveStock({
    required String productIdText,
    required String fromSiteIdText,
    required String fromWarehouseIdText,
    required String toSiteIdText,
    required String toWarehouseIdText,
    required String quantityText,
    required String reasonText,
    String note = '',
    String? movementKey,
  }) async {
    final productId = InventoryInputParser.parseProductId(productIdText);
    if (productId == null) return _validationError('product_id non valido');
    final fromSiteId = InventoryInputParser.parsePositiveInt(fromSiteIdText);
    if (fromSiteId == null)
      return _validationError('Sede di partenza non valida');
    // Il magazzino puo' non essere specificato: vuol dire "quello di default
    // della sede", quindi il campo vuoto vale 0 e non un errore.
    final fromWarehouseId =
        InventoryInputParser.parseOptionalNonNegativeInt(fromWarehouseIdText) ??
        0;
    final toSiteId = InventoryInputParser.parsePositiveInt(toSiteIdText);
    if (toSiteId == null)
      return _validationError('Sede di destinazione non valida');
    final toWarehouseId =
        InventoryInputParser.parseOptionalNonNegativeInt(toWarehouseIdText) ??
        0;
    final quantity = InventoryInputParser.parsePositiveInt(quantityText);
    if (quantity == null)
      return _validationError('Quantita da spostare non valida');
    final reason = reasonText.trim();
    if (reason.isEmpty) return _validationError('motivo richiesto');
    if (fromSiteId == toSiteId && fromWarehouseId == toWarehouseId) {
      return _validationError('Origine e destinazione sono la stessa');
    }
    if (!await _availability.ensureConnected()) return _mgwsUnavailable();

    isMoving = true;
    try {
      final result = await gateway.moveStock(
        productId: productId,
        fromSiteId: fromSiteId,
        fromWarehouseId: fromWarehouseId,
        toSiteId: toSiteId,
        toWarehouseId: toWarehouseId,
        quantity: quantity,
        reason: reason,
        note: note,
        movementKey: movementKey,
      );
      lastMoveResult = result;
      return _remember(
        InventoryActionFeedback(
          success: result.success,
          message: result.message,
          details: result.errors,
        ),
      );
    } catch (e) {
      return _remember(
        InventoryActionFeedback(
          success: false,
          message: 'Errore spostamento MGWS: $e',
        ),
      );
    } finally {
      isMoving = false;
    }
  }

  Future<InventoryActionFeedback> resolveRfidScan(String rawTags) async {
    final tags = InventoryInputParser.parseTags(rawTags);
    if (tags.isEmpty) return _validationError('Inserisci almeno un tag RFID');
    if (!await _availability.ensureConnected()) return _mgwsUnavailable();

    isResolvingRfid = true;
    try {
      final result = await gateway.resolveRfidScan(tagIds: tags);
      lastRfidResult = result;
      final suffix = result.isResolveOnly ? 'Nessuna quantita aggiornata.' : '';
      return _remember(
        InventoryActionFeedback(
          success: result.success,
          message:
              'RFID resolve-only: ${result.resolved.length} risolti, '
              '${result.unresolved.length} non risolti. $suffix',
          details: [...result.errors, ...result.unresolved],
        ),
      );
    } catch (e) {
      return _remember(
        InventoryActionFeedback(
          success: false,
          message: 'Errore RFID MGWS: $e',
        ),
      );
    } finally {
      isResolvingRfid = false;
    }
  }

  int? _optionalProductId(String value) {
    if (value.trim().isEmpty) return null;
    return InventoryInputParser.parseProductId(value);
  }

  InventoryActionFeedback _validationError(String message) {
    return _remember(InventoryActionFeedback(success: false, message: message));
  }

  InventoryActionFeedback _mgwsUnavailable() {
    return _remember(
      const InventoryActionFeedback(
        success: false,
        message: 'Backend MGWS non disponibile',
      ),
    );
  }

  InventoryActionFeedback _remember(InventoryActionFeedback feedback) {
    lastFeedback = feedback;
    return feedback;
  }

  String _stockMessage(String action, String message, int? delta) {
    if (delta == null) return '$action: $message';
    final sign = delta > 0 ? '+' : '';
    return '$action: $message (delta $sign$delta)';
  }
}
