import '../../../log_viewer/app_logger.dart';
import '../connection/mgws_auth.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';
import 'query_mgws_inventory_models.dart';

export 'query_mgws_inventory_models.dart';

class QueryMgwsInventory implements MgwsInventoryGateway, MgwsRestockGateway {
  QueryMgwsInventory({
    MgwsInventoryTransport? transport,
    MgwsConnection? mgwsConnection,
  }) : _transport = transport ?? _QueryMgwsInventoryTransport(),
       _availability = mgwsConnection ?? MgwsConnection.instance;

  final QueryMgwsBase _base = QueryMgwsBase();
  final AppLogger _log = AppLogger();
  final MgwsInventoryTransport _transport;
  final MgwsConnection _availability;

  static const String _inventoryPath = '/wp-json/mgws/v1/inventory';

  static String supplierPath(int supplierId) =>
      '$_inventoryPath/suppliers/${Uri.encodeComponent(supplierId.toString())}';
  static String reorderRulePath(int ruleId) =>
      '$_inventoryPath/reorder-rules/${Uri.encodeComponent(ruleId.toString())}';
  static String purchaseOrderPath(int purchaseOrderId) =>
      '$_inventoryPath/purchase-orders/${Uri.encodeComponent(purchaseOrderId.toString())}';
  static String receiptPath(int receiptId) =>
      '$_inventoryPath/receipts/${Uri.encodeComponent(receiptId.toString())}';
  static String movementPath(int movementId) =>
      '$_inventoryPath/movements/${Uri.encodeComponent(movementId.toString())}';
  static String countSessionPath(int sessionId) =>
      '$_inventoryPath/count-sessions/${Uri.encodeComponent(sessionId.toString())}';

  static String encodedQueryPath(String path, Map<String, Object?> query) {
    final parameters = <String, String>{};
    for (final entry in query.entries) {
      if (entry.value != null) parameters[entry.key] = entry.value.toString();
    }
    return Uri(path: path, queryParameters: parameters).toString();
  }

  static Map<String, dynamic> parseMapResponse(Object? raw) {
    return MgwsInventoryParser.parseMapResponse(raw);
  }

  static Map<String, dynamic> parsePayloadResponse(Object? raw) {
    return MgwsInventoryParser.parsePayloadResponse(raw);
  }

  static List<Map<String, dynamic>> parseStockListResponse(Object? raw) {
    return MgwsInventoryParser.parseStockListResponse(raw);
  }

  static int? parseIntValue(Object? value) {
    return MgwsInventoryParser.parseIntValue(value);
  }

  static bool parseSuccess(Map<String, dynamic> data, int? statusCode) {
    return MgwsInventoryParser.parseSuccess(data, statusCode);
  }

  static String parseMessage(Map<String, dynamic> data, String fallback) {
    return MgwsInventoryParser.parseMessage(data, fallback);
  }

  static List<String> parseErrors(Map<String, dynamic> data, String message) {
    return MgwsInventoryParser.parseErrors(data, message);
  }

  static List<MgwsResolvedTag> parseResolvedTags(Object? raw) {
    return MgwsInventoryParser.parseResolvedTags(raw);
  }

  static List<String> parseUnresolvedTags(Object? raw) {
    return MgwsInventoryParser.parseUnresolvedTags(raw);
  }

  @override
  Future<bool> isInventoryServiceAvailable() async {
    try {
      final response = await _base.get('/wp-json/mgws/v1/inventory/status');
      return MgwsAuth.isServiceUsable(response);
    } catch (e) {
      _log.w('MGWS inventory non disponibile: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getProductStock(int productId) async {
    if (!await _availability.ensureConnected())
      return const <String, dynamic>{};
    final response = await _base.get(
      '/wp-json/mgws/v1/inventory/stock/product/$productId',
    );
    return parseMapResponse(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllStock() async {
    if (!await _availability.ensureConnected()) {
      return const <Map<String, dynamic>>[];
    }
    final response = await _base.get('/wp-json/mgws/v1/inventory/stock/all');
    return parseStockListResponse(response.data);
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    if (!await _availability.ensureConnected())
      return const <String, dynamic>{};
    final response = await _base.get('/wp-json/mgws/v1/inventory/statistics');
    return parseMapResponse(response.data);
  }

  @override
  Future<List<Map<String, dynamic>>> getLowStockItems() async {
    if (!await _availability.ensureConnected()) {
      return const <Map<String, dynamic>>[];
    }
    final response = await _base.get('/wp-json/mgws/v1/inventory/low-stock');
    return parseStockListResponse(response.data);
  }

  @override
  Future<MgwsStockSyncResult> syncWooStockToMgws({
    required int productId,
    required int wooStock,
    required String syncType,
  }) async {
    if (!await _availability.ensureConnected()) {
      return const MgwsStockSyncResult(
        success: false,
        message: 'Backend MGWS non disponibile',
        errors: ['Backend MGWS non disponibile'],
      );
    }
    final response = await _base.post(
      '/wp-json/mgws/v1/inventory/stock/sync',
      data: {
        'product_id': productId,
        'woo_stock': wooStock,
        'sync_type': syncType,
      },
    );
    return MgwsStockSyncResult.fromResponse(
      response.data,
      statusCode: response.statusCode,
    );
  }

  @override
  Future<MgwsReconcileResult> reconcileStock({
    required int productId,
    required int correctStock,
    required int siteId,
    required String reason,
    String? movementKey,
  }) async {
    if (!await _availability.ensureConnected()) {
      return const MgwsReconcileResult(
        success: false,
        message: 'Backend MGWS non disponibile',
        errors: ['Backend MGWS non disponibile'],
      );
    }
    // `site_id` non e' facoltativo: dichiara su quale sede il totale viene
    // riscritto. Senza, il backend non accetterebbe la richiesta, ed e' giusto che
    // non la accetti: un totale senza perimetro puo' correggere la sede sbagliata
    // mentre l'operatore crede di aver corretto quella giusta.
    final response = await _base.put(
      '/wp-json/mgws/v1/inventory/stock/reconcile',
      data: _query({
        'product_id': productId,
        'correct_stock': correctStock,
        'site_id': siteId,
        'reason': reason,
        'movement_key': movementKey,
      }),
    );
    return MgwsReconcileResult.fromResponse(
      response.data,
      statusCode: response.statusCode,
    );
  }

  @override
  Future<MgwsRfidScanResult> resolveRfidScan({
    required List<String> tagIds,
  }) async {
    if (!await _availability.ensureConnected()) {
      return const MgwsRfidScanResult(
        success: false,
        message: 'Backend MGWS non disponibile',
        errors: ['Backend MGWS non disponibile'],
        resolved: [],
        unresolved: [],
        stockUpdates: 0,
        movementCount: 0,
        mode: 'resolve_only',
      );
    }
    final response = await _base.post(
      '/wp-json/mgws/v1/inventory/rfid/scan',
      data: {'tags': tagIds},
    );
    return MgwsRfidScanResult.fromResponse(
      response.data,
      statusCode: response.statusCode,
    );
  }

  Future<MgwsRfidScanResult> updateStockFromTags({
    required List<String> tagIds,
  }) {
    return resolveRfidScan(tagIds: tagIds);
  }

  @override
  Future<MgwsMoveResult> moveStock({
    required int productId,
    required int fromSiteId,
    required int fromWarehouseId,
    required int toSiteId,
    required int toWarehouseId,
    required int quantity,
    required String reason,
    String? note,
    String? movementKey,
  }) async {
    if (!await _availability.ensureConnected()) {
      return const MgwsMoveResult(
        success: false,
        message: 'Backend MGWS non disponibile',
        errors: ['Backend MGWS non disponibile'],
      );
    }
    // `from_site_id` e `to_site_id` viaggiano per compatibilita' con il
    // payload che il backend gia' accettava; il backend li ignora e ricava la
    // sede dal magazzino, perche' fidarsi della sede dichiarata dal client
    // lascerebbe aprire il perimetro consentito.
    //
    // Nessun campo stanza: la rotta e' la coppia di magazzini. Sul lato
    // partenza MGWS prende l'ubicazione che il prodotto ha gia' li', che e'
    // l'unica da cui si puo' togliere merce; dichiarare qui una stanza
    // significherebbe poter dichiarare un posto dove la merce non e'.
    final response = await _base.post(
      '$_inventoryPath/stock/move',
      data: _query({
        'product_id': productId,
        'from_site_id': fromSiteId,
        'from_warehouse_id': fromWarehouseId,
        'to_site_id': toSiteId,
        'to_warehouse_id': toWarehouseId,
        'quantity': quantity,
        'reason': reason,
        'note': _trimmed(note),
        'movement_key': movementKey,
      }),
    );
    return MgwsMoveResult.fromResponse(
      response.data,
      statusCode: response.statusCode,
    );
  }

  static String? _trimmed(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  Future<MgwsRestockResult<MgwsQuickLoad>> quickLoad(
    MgwsQuickLoadRequest request,
  ) => _object(
    () => _transport.post('$_inventoryPath/quick-load', data: request.toJson()),
    MgwsQuickLoad.fromMap,
  );

  @override
  Future<MgwsRestockResult<List<MgwsInventorySite>>> listSites() => _objects(
    () => _transport.get('$_inventoryPath/sites'),
    MgwsInventorySite.fromMap,
  );

  @override
  Future<MgwsRestockResult<List<MgwsInventoryWarehouse>>> listWarehouses({
    int? siteId,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/warehouses',
      queryParameters: _query({'site_id': siteId}),
    ),
    MgwsInventoryWarehouse.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsInventoryLocationTree>> getLocationTree({
    required int siteId,
  }) => _object(
    () => _transport.get(
      '$_inventoryPath/locations',
      queryParameters: _query({'site_id': siteId}),
    ),
    MgwsInventoryLocationTree.fromMap,
  );

  @override
  Future<MgwsRestockResult<List<MgwsSupplier>>> listSuppliers() => _objects(
    () => _transport.get('$_inventoryPath/suppliers'),
    MgwsSupplier.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsSupplier>> createSupplier(
    MgwsSupplierInput input,
  ) => _object(
    () => _transport.post('$_inventoryPath/suppliers', data: input.toJson()),
    MgwsSupplier.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsSupplier>> getSupplier(int supplierId) =>
      _object(
        () => _transport.get(supplierPath(supplierId)),
        MgwsSupplier.fromMap,
      );

  @override
  Future<MgwsRestockResult<MgwsSupplier>> updateSupplier(
    int supplierId,
    MgwsSupplierPatch patch,
  ) => _object(
    () => _transport.patch(supplierPath(supplierId), data: patch.toJson()),
    MgwsSupplier.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsDeleteResult>> deleteSupplier(int supplierId) =>
      _object(
        () => _transport.delete(supplierPath(supplierId)),
        MgwsDeleteResult.supplier,
      );

  @override
  Future<MgwsRestockResult<List<MgwsReorderRule>>> listReorderRules({
    int? siteId,
    int? warehouseId,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/reorder-rules',
      queryParameters: _query({'site_id': siteId, 'warehouse_id': warehouseId}),
    ),
    MgwsReorderRule.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReorderRule>> createReorderRule(
    MgwsReorderRuleInput input,
  ) => _object(
    () =>
        _transport.post('$_inventoryPath/reorder-rules', data: input.toJson()),
    MgwsReorderRule.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReorderRule>> updateReorderRule(
    int ruleId,
    MgwsReorderRulePatch patch,
  ) => _object(
    () => _transport.patch(reorderRulePath(ruleId), data: patch.toJson()),
    MgwsReorderRule.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsDeleteResult>> deleteReorderRule(int ruleId) =>
      _object(
        () => _transport.delete(reorderRulePath(ruleId)),
        MgwsDeleteResult.reorderRule,
      );

  @override
  Future<MgwsRestockResult<List<MgwsReorderSuggestion>>>
  listReorderSuggestions({int? siteId, int? warehouseId}) => _objects(
    () => _transport.get(
      '$_inventoryPath/reorder-suggestions',
      queryParameters: _query({'site_id': siteId, 'warehouse_id': warehouseId}),
    ),
    MgwsReorderSuggestion.fromMap,
  );

  @override
  Future<MgwsRestockResult<List<MgwsPurchaseOrder>>> listPurchaseOrders({
    int? siteId,
    int? supplierId,
    String? status,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/purchase-orders',
      queryParameters: _query({
        'site_id': siteId,
        'supplier_id': supplierId,
        'status': status,
      }),
    ),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrder>> createPurchaseOrder(
    MgwsPurchaseOrderInput input,
  ) => _object(
    () => _transport.post(
      '$_inventoryPath/purchase-orders',
      data: input.toJson(),
    ),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrder>> getPurchaseOrder(
    int purchaseOrderId,
  ) => _object(
    () => _transport.get(purchaseOrderPath(purchaseOrderId)),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrder>> updatePurchaseOrder(
    int purchaseOrderId,
    MgwsPurchaseOrderPatch patch,
  ) => _object(
    () => _transport.patch(
      purchaseOrderPath(purchaseOrderId),
      data: patch.toJson(),
    ),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrderLine>> savePurchaseOrderLine(
    int purchaseOrderId,
    MgwsPurchaseOrderLineInput input,
  ) => _object(
    () => _transport.post(
      '${purchaseOrderPath(purchaseOrderId)}/lines',
      data: input.toJson(),
    ),
    MgwsPurchaseOrderLine.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrder>> updatePurchaseOrderStatus(
    int purchaseOrderId,
    String status,
  ) => _object(
    () => _transport.post(
      '${purchaseOrderPath(purchaseOrderId)}/status',
      data: {'status': status},
    ),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsPurchaseOrder>> verifyPurchaseOrder(
    int purchaseOrderId,
  ) => _object(
    () => _transport.post('${purchaseOrderPath(purchaseOrderId)}/verify'),
    MgwsPurchaseOrder.fromMap,
  );

  @override
  Future<MgwsRestockResult<List<MgwsReceipt>>> listReceipts({
    int? siteId,
    int? purchaseOrderId,
    String? status,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/receipts',
      queryParameters: _query({
        'site_id': siteId,
        'purchase_order_id': purchaseOrderId,
        'status': status,
      }),
    ),
    MgwsReceipt.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReceipt>> createReceipt(
    MgwsReceiptInput input,
  ) => _object(
    () => _transport.post('$_inventoryPath/receipts', data: input.toJson()),
    MgwsReceipt.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReceipt>> getReceipt(int receiptId) => _object(
    () => _transport.get(receiptPath(receiptId)),
    MgwsReceipt.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReceipt>> updateReceipt(
    int receiptId,
    MgwsReceiptPatch patch,
  ) => _object(
    () => _transport.patch(receiptPath(receiptId), data: patch.toJson()),
    MgwsReceipt.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsReceipt>> convalidaReceipt(int receiptId) =>
      _object(
        () => _transport.post('${receiptPath(receiptId)}/convalida'),
        MgwsReceipt.fromMap,
      );

  @override
  Future<MgwsRestockResult<List<MgwsBackorder>>> listBackorders({
    int? siteId,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/backorders',
      queryParameters: _query({'site_id': siteId}),
    ),
    MgwsBackorder.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsMovementPage>> listMovements(
    MgwsMovementFilter filter,
  ) => _object(
    () => _transport.get(
      '$_inventoryPath/movements',
      queryParameters: filter.toQuery(),
    ),
    MgwsMovementPage.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsMovement>> getMovement(int movementId) =>
      _object(
        () => _transport.get(movementPath(movementId)),
        MgwsMovement.fromMap,
      );

  @override
  Future<MgwsRestockResult<List<MgwsCountSession>>> listCountSessions({
    int? siteId,
    int? warehouseId,
  }) => _objects(
    () => _transport.get(
      '$_inventoryPath/count-sessions',
      queryParameters: _query({'site_id': siteId, 'warehouse_id': warehouseId}),
    ),
    MgwsCountSession.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsCountSession>> createCountSession(
    MgwsCountSessionInput input,
  ) => _object(
    () =>
        _transport.post('$_inventoryPath/count-sessions', data: input.toJson()),
    MgwsCountSession.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsCountSession>> getCountSession(int sessionId) =>
      _object(
        () => _transport.get(countSessionPath(sessionId)),
        MgwsCountSession.fromMap,
      );

  @override
  Future<MgwsRestockResult<MgwsCountSession>> updateCountSession(
    int sessionId,
    MgwsCountSessionPatch patch,
  ) => _object(
    () => _transport.patch(countSessionPath(sessionId), data: patch.toJson()),
    MgwsCountSession.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsCountLine>> saveCountLine(
    int sessionId,
    MgwsCountLineInput input,
  ) => _object(
    () => _transport.post(
      '${countSessionPath(sessionId)}/lines',
      data: input.toJson(),
    ),
    MgwsCountLine.fromMap,
  );

  @override
  Future<MgwsRestockResult<MgwsCountSession>> approveCountSession(
    int sessionId,
  ) => _object(
    () => _transport.post('${countSessionPath(sessionId)}/approve'),
    MgwsCountSession.fromMap,
  );

  Future<MgwsRestockResult<T>> _object<T>(
    Future<MgwsInventoryResponse> Function() request,
    T? Function(Map<String, Object?> value) parser,
  ) async {
    if (!await _availability.ensureConnected())
      return _unavailableRestockResult();
    try {
      final response = await request();
      return MgwsRestockParser.object(
        response.data,
        response.statusCode,
        parser,
      );
    } catch (_) {
      return MgwsRestockResult.failure(
        const MgwsRestockError(
          code: 'mgws_transport_error',
          message: 'Servizio MGWS non raggiungibile',
        ),
      );
    }
  }

  Future<MgwsRestockResult<List<T>>> _objects<T>(
    Future<MgwsInventoryResponse> Function() request,
    T? Function(Map<String, Object?> value) parser,
  ) async {
    if (!await _availability.ensureConnected())
      return _unavailableRestockResult();
    try {
      final response = await request();
      return MgwsRestockParser.objects(
        response.data,
        response.statusCode,
        parser,
      );
    } catch (_) {
      return MgwsRestockResult.failure(
        const MgwsRestockError(
          code: 'mgws_transport_error',
          message: 'Servizio MGWS non raggiungibile',
        ),
      );
    }
  }

  Map<String, Object?> _query(Map<String, Object?> values) =>
      Map<String, Object?>.fromEntries(
        values.entries.where((entry) => entry.value != null),
      );

  MgwsRestockResult<T> _unavailableRestockResult<T>() {
    return MgwsRestockResult.failure(
      const MgwsRestockError(
        code: 'mgws_unavailable',
        message: 'Backend MGWS non disponibile',
      ),
    );
  }
}

class _QueryMgwsInventoryTransport implements MgwsInventoryTransport {
  _QueryMgwsInventoryTransport({QueryMgwsBase? base})
    : _base = base ?? QueryMgwsBase();

  final QueryMgwsBase _base;

  @override
  Future<MgwsInventoryResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final response = await _base.get(path, queryParameters: queryParameters);
    return MgwsInventoryResponse(
      data: response.data as Object?,
      statusCode: response.statusCode as int?,
    );
  }

  @override
  Future<MgwsInventoryResponse> post(
    String path, {
    Map<String, Object?>? data,
  }) async {
    final response = await _base.post(path, data: data);
    return MgwsInventoryResponse(
      data: response.data as Object?,
      statusCode: response.statusCode as int?,
    );
  }

  @override
  Future<MgwsInventoryResponse> patch(
    String path, {
    Map<String, Object?>? data,
  }) async {
    final response = await _base.patch(path, data: data);
    return MgwsInventoryResponse(
      data: response.data as Object?,
      statusCode: response.statusCode as int?,
    );
  }

  @override
  Future<MgwsInventoryResponse> delete(String path) async {
    final response = await _base.delete(path);
    return MgwsInventoryResponse(
      data: response.data as Object?,
      statusCode: response.statusCode as int?,
    );
  }
}
