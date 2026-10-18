/// Query WooCommerce - ORDINI
///
/// Gestisce tutte le operazioni sugli ordini usando woocommerce_flutter_api
/// L'autenticazione è gestita centralmente da WooConnect
/// CONVERTE tra OrdiniGlobal (app) e WooOrder (WooCommerce)

import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../ordini/class_ordini.dart';
import '../../../log_viewer/app_logger.dart';

/// Service per gestire gli ordini WooCommerce
class WooQueryOrdini {
  static const bool _debugOrderStatusConversion = false;

  // Singleton
  static final WooQueryOrdini _instance = WooQueryOrdini._internal();
  factory WooQueryOrdini() => _instance;
  WooQueryOrdini._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Getter per ottenere l'istanza WooCommerce centralizzata
  WooCommerce get _woo => _wooConnect.woo;

  // =======================================================
  // == METODI DI CONVERSIONE                             ==
  // =======================================================

  /// Converte OrdineStatus → WooOrderStatus
  WooOrderStatus _toWooStatus(OrdineStatus? status) {
    switch (status) {
      case OrdineStatus.pending:
        return WooOrderStatus.pending;
      case OrdineStatus.processing:
        return WooOrderStatus.processing;
      case OrdineStatus.onHold:
        return WooOrderStatus.onHold;
      case OrdineStatus.completed:
        return WooOrderStatus.completed;
      case OrdineStatus.cancelled:
        return WooOrderStatus.cancelled;
      case OrdineStatus.refunded:
        return WooOrderStatus.refunded;
      case OrdineStatus.failed:
        return WooOrderStatus.failed;
      case OrdineStatus.trash:
        return WooOrderStatus.trash;
      case OrdineStatus.any:
        return WooOrderStatus.any;
      case null:
        return WooOrderStatus.any;
    }
  }

  /// Converte WooOrderStatus → OrdineStatus
  /// Gestisce sia enum WooOrderStatus che String (bug del package)
  OrdineStatus _fromWooStatus(dynamic status) {
    if (status == null) return OrdineStatus.pending;

    // Se è una String (bug del package), convertila prima in WooOrderStatus
    WooOrderStatus wooStatus;
    if (status is String) {
      wooStatus = _parseOrderStatus(status);
    } else if (status is WooOrderStatus) {
      wooStatus = status;
    } else {
      log.w('Tipo status sconosciuto: ${status.runtimeType}, uso pending');
      return OrdineStatus.pending;
    }

    // Ora converte WooOrderStatus → OrdineStatus
    switch (wooStatus) {
      case WooOrderStatus.pending:
        return OrdineStatus.pending;
      case WooOrderStatus.processing:
        return OrdineStatus.processing;
      case WooOrderStatus.onHold:
        return OrdineStatus.onHold;
      case WooOrderStatus.completed:
        return OrdineStatus.completed;
      case WooOrderStatus.cancelled:
        return OrdineStatus.cancelled;
      case WooOrderStatus.refunded:
        return OrdineStatus.refunded;
      case WooOrderStatus.failed:
        return OrdineStatus.failed;
      case WooOrderStatus.unknown:
        return OrdineStatus.pending;
      case WooOrderStatus.trash:
        return OrdineStatus.trash;
      case WooOrderStatus.any:
        return OrdineStatus.any;
    }
  }

  /// Converte WooOrder → OrdiniGlobal
  OrdiniGlobal _fromWooOrder(WooOrder wooOrder) {
    // DEBUG: Log del tipo e valore di status
    if (_debugOrderStatusConversion) {
      log.d(
        'DEBUG ordine ${wooOrder.id} status type=${wooOrder.status.runtimeType} value=${wooOrder.status}',
      );
    }

    return OrdiniGlobal(
      id: wooOrder.id,
      number: wooOrder.number,
      status: _fromWooStatus(wooOrder.status),
      currency: wooOrder.currency,
      dateCreated: wooOrder.dateCreated,
      dateModified: wooOrder.dateModified,
      datePaid: wooOrder.datePaid,
      dateCompleted: wooOrder.dateCompleted,
      total: wooOrder.total,
      subtotal:
          wooOrder.total != null &&
              wooOrder.shippingTotal != null &&
              wooOrder.totalTax != null
          ? wooOrder.total! - wooOrder.shippingTotal! - wooOrder.totalTax!
          : null,
      totalTax: wooOrder.totalTax,
      shippingTotal: wooOrder.shippingTotal,
      shippingTax: wooOrder.shippingTax,
      discountTotal: wooOrder.discountTotal,
      discountTax: wooOrder.discountTax,
      paymentMethod: wooOrder.paymentMethod,
      paymentMethodTitle: wooOrder.paymentMethodTitle,
      billing: wooOrder.billing != null
          ? IndirizzoBilling(
              firstName: wooOrder.billing!.firstName,
              lastName: wooOrder.billing!.lastName,
              company: wooOrder.billing!.company,
              address1: wooOrder.billing!.address1,
              address2: wooOrder.billing!.address2,
              city: wooOrder.billing!.city,
              state: wooOrder.billing!.state,
              postcode: wooOrder.billing!.postcode,
              country: wooOrder.billing!.country,
              email: wooOrder.billing!.email,
              phone: wooOrder.billing!.phone,
            )
          : null,
      shipping: wooOrder.shipping != null
          ? IndirizzoShipping(
              firstName: wooOrder.shipping!.firstName,
              lastName: wooOrder.shipping!.lastName,
              company: wooOrder.shipping!.company,
              address1: wooOrder.shipping!.address1,
              address2: wooOrder.shipping!.address2,
              city: wooOrder.shipping!.city,
              state: wooOrder.shipping!.state,
              postcode: wooOrder.shipping!.postcode,
              country: wooOrder.shipping!.country,
            )
          : null,
      lineItems: wooOrder.lineItems
          ?.map(
            (item) => ProdottoOrdine(
              id: item.id,
              name: item.name,
              productId: item.productId,
              variationId: item.variationId,
              quantity: item.quantity,
              subtotal: item.subtotal,
              total: item.total,
              barcodeInterno: item.sku,
              price: item.price,
            ),
          )
          .toList(),
      customerNote: wooOrder.customerNote,
    );
  }

  /// Converte OrdiniGlobal → WooOrder
  WooOrder _toWooOrder(OrdiniGlobal ordine) {
    return WooOrder(
      id: ordine.id ?? 0,
      status: ordine.status != null ? _toWooStatus(ordine.status!) : null,
      paymentMethod: ordine.paymentMethod,
      paymentMethodTitle: ordine.paymentMethodTitle,
      billing: ordine.billing != null
          ? WooBilling(
              firstName: ordine.billing!.firstName,
              lastName: ordine.billing!.lastName,
              company: ordine.billing!.company,
              address1: ordine.billing!.address1,
              address2: ordine.billing!.address2,
              city: ordine.billing!.city,
              state: ordine.billing!.state,
              postcode: ordine.billing!.postcode,
              country: ordine.billing!.country,
              email: ordine.billing!.email,
              phone: ordine.billing!.phone,
            )
          : null,
      shipping: ordine.shipping != null
          ? WooShipping(
              firstName: ordine.shipping!.firstName,
              lastName: ordine.shipping!.lastName,
              company: ordine.shipping!.company,
              address1: ordine.shipping!.address1,
              address2: ordine.shipping!.address2,
              city: ordine.shipping!.city,
              state: ordine.shipping!.state,
              postcode: ordine.shipping!.postcode,
              country: ordine.shipping!.country,
            )
          : null,
      lineItems: ordine.lineItems
          ?.map(
            (item) => WooLineItem(
              id: item.id,
              name: item.name,
              productId: item.productId,
              variationId: item.variationId,
              quantity: item.quantity,
              subtotal: item.subtotal,
              total: item.total,
              sku: item.barcodeInterno,
              price: item.price,
            ),
          )
          .toList(),
      customerNote: ordine.customerNote,
    );
  }

  // =======================================================
  // == METODI ORDINI                                     ==
  // =======================================================

  /// Ottiene lista ordini con paginazione e filtri
  Future<List<OrdiniGlobal>> getOrders({
    int page = 1,
    int perPage = 20,
    OrdineStatus? status,
    int? customer,
  }) async {
    try {
      // WORKAROUND: Bypassiamo il metodo getOrders del package perché ha un bug
      // nel parsing del campo status (assegna String invece di convertire in enum)

      // Costruisce i parametri query
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'orderby': 'date',
        'order': 'desc',
      };

      // Aggiungi filtro status se specificato
      if (status != null) {
        final wooStatus = _toWooStatus(status);
        String statusParam = wooStatus.toString().split('.').last;
        // Converte onHold → on-hold
        if (statusParam == 'onHold') statusParam = 'on-hold';
        queryParams['status'] = statusParam;
      }

      if (customer != null) {
        queryParams['customer'] = customer;
      }

      // Chiamata raw per bypassare il bug del package
      log.d('getOrders query params: $queryParams');
      final response = await _woo.dio.get(
        '/orders',
        queryParameters: queryParams,
      );

      // Parse manuale del JSON (bypassa WooOrder.fromJson che ha il bug)
      final List<dynamic> ordersJson = response.data is List
          ? response.data
          : [];
      log.i('Ricevuti ${ordersJson.length} ordini dal server');

      final orders = <OrdiniGlobal>[];
      for (final json in ordersJson) {
        final order = _fromJsonToOrdiniGlobal(json as Map<String, dynamic>);
        orders.add(await _withBarcodeInterniFromProducts(order));
      }
      return orders;
    } catch (e) {
      log.e('Errore getOrders: $e');
      rethrow;
    }
  }

  /// Converte JSON → OrdiniGlobal direttamente (bypassa il bug del package)
  OrdiniGlobal _fromJsonToOrdiniGlobal(Map<String, dynamic> json) {
    return OrdiniGlobal(
      id: json['id'],
      number: json['number'],
      status: json['status'] != null ? _fromWooStatus(json['status']) : null,
      currency: json['currency'],
      dateCreated: json['date_created'] != null
          ? DateTime.tryParse(json['date_created'])
          : null,
      dateModified: json['date_modified'] != null
          ? DateTime.tryParse(json['date_modified'])
          : null,
      datePaid: json['date_paid'] != null
          ? DateTime.tryParse(json['date_paid'])
          : null,
      dateCompleted: json['date_completed'] != null
          ? DateTime.tryParse(json['date_completed'])
          : null,
      total: json['total'] != null
          ? double.tryParse(json['total'].toString())
          : null,
      subtotal: _calculateSubtotal(json),
      totalTax: json['total_tax'] != null
          ? double.tryParse(json['total_tax'].toString())
          : null,
      shippingTotal: json['shipping_total'] != null
          ? double.tryParse(json['shipping_total'].toString())
          : null,
      shippingTax: json['shipping_tax'] != null
          ? double.tryParse(json['shipping_tax'].toString())
          : null,
      discountTotal: json['discount_total'] != null
          ? double.tryParse(json['discount_total'].toString())
          : null,
      discountTax: json['discount_tax'] != null
          ? double.tryParse(json['discount_tax'].toString())
          : null,
      paymentMethod: json['payment_method'],
      paymentMethodTitle: json['payment_method_title'],
      billing: json['billing'] != null ? _parseBilling(json['billing']) : null,
      shipping: json['shipping'] != null
          ? _parseShipping(json['shipping'])
          : null,
      lineItems: json['line_items'] != null
          ? _parseLineItems(json['line_items'])
          : null,
      customerNote: json['customer_note'],
    );
  }

  /// Calcola subtotal dall'ordine
  double? _calculateSubtotal(Map<String, dynamic> json) {
    final total = json['total'] != null
        ? double.tryParse(json['total'].toString())
        : null;
    final shippingTotal = json['shipping_total'] != null
        ? double.tryParse(json['shipping_total'].toString())
        : null;
    final totalTax = json['total_tax'] != null
        ? double.tryParse(json['total_tax'].toString())
        : null;

    if (total != null && shippingTotal != null && totalTax != null) {
      return total - shippingTotal - totalTax;
    }
    return null;
  }

  /// Parse billing address dal JSON
  IndirizzoBilling _parseBilling(Map<String, dynamic> json) {
    return IndirizzoBilling(
      firstName: json['first_name'],
      lastName: json['last_name'],
      company: json['company'],
      address1: json['address_1'],
      address2: json['address_2'],
      city: json['city'],
      state: json['state'],
      postcode: json['postcode'],
      country: json['country'],
      email: json['email'],
      phone: json['phone'],
    );
  }

  /// Parse shipping address dal JSON
  IndirizzoShipping _parseShipping(Map<String, dynamic> json) {
    return IndirizzoShipping(
      firstName: json['first_name'],
      lastName: json['last_name'],
      company: json['company'],
      address1: json['address_1'],
      address2: json['address_2'],
      city: json['city'],
      state: json['state'],
      postcode: json['postcode'],
      country: json['country'],
    );
  }

  /// Parse line items dal JSON
  List<ProdottoOrdine> _parseLineItems(List<dynamic> items) {
    return items.map((item) {
      final json = item as Map<String, dynamic>;
      return ProdottoOrdine(
        id: json['id'],
        name: json['name'],
        productId: json['product_id'],
        variationId: json['variation_id'],
        quantity: json['quantity'],
        subtotal: json['subtotal'] != null
            ? double.tryParse(json['subtotal'].toString())
            : null,
        total: json['total'] != null
            ? double.tryParse(json['total'].toString())
            : null,
        // WooCommerce espone qui lo SKU della riga. Dopo la nuova mappatura lo
        // SKU è il codice prodotto; il barcode operativo viene recuperato da
        // `global_unique_id` con _withBarcodeInterniFromProducts().
        barcodeInterno: json['global_unique_id'],
        price: json['price'] != null
            ? double.tryParse(json['price'].toString())
            : null,
      );
    }).toList();
  }

  Future<OrdiniGlobal> _withBarcodeInterniFromProducts(
    OrdiniGlobal order,
  ) async {
    final items = order.lineItems;
    if (items == null || items.isEmpty) return order;

    final enriched = <ProdottoOrdine>[];
    for (final item in items) {
      final barcode = await _fetchLineItemGlobalUniqueId(item);
      enriched.add(
        ProdottoOrdine(
          id: item.id,
          name: item.name,
          productId: item.productId,
          variationId: item.variationId,
          quantity: item.quantity,
          subtotal: item.subtotal,
          total: item.total,
          barcodeInterno: barcode ?? item.barcodeInterno,
          price: item.price,
        ),
      );
    }

    return order.copyWith(lineItems: enriched);
  }

  Future<String?> _fetchLineItemGlobalUniqueId(ProdottoOrdine item) async {
    final productId = item.productId;
    if (productId == null || productId <= 0) return null;

    try {
      Map<String, dynamic> data;
      final variationId = item.variationId;
      if (variationId != null && variationId > 0) {
        final response = await _woo.dio.get(
          '/products/$productId/variations/$variationId',
        );
        data = Map<String, dynamic>.from(response.data as Map);
      } else {
        final response = await _woo.dio.get('/products/$productId');
        data = Map<String, dynamic>.from(response.data as Map);
      }

      final value = data['global_unique_id']?.toString().trim();
      return value?.isNotEmpty == true ? value : null;
    } catch (e) {
      log.w(
        'Barcode ordine non recuperato per productId=$productId variationId=${item.variationId}: $e',
      );
      return null;
    }
  }

  /// Ottiene un singolo ordine per ID
  Future<OrdiniGlobal> getOrderById(int orderId) async {
    try {
      final response = await _woo.dio.get('/orders/$orderId');
      final order = _fromJsonToOrdiniGlobal(
        response.data as Map<String, dynamic>,
      );
      return await _withBarcodeInterniFromProducts(order);
    } catch (e) {
      log.e('❌ Errore getOrderById: $e');
      rethrow;
    }
  }

  /// Ottiene ordini per stato
  Future<List<OrdiniGlobal>> getOrdersByStatus(
    OrdineStatus status, {
    int limit = 50,
  }) async {
    return await getOrders(perPage: limit, status: status);
  }

  /// Ottiene ordini di un cliente specifico
  Future<List<OrdiniGlobal>> getOrdersByCustomer(
    int customerId, {
    int limit = 50,
  }) async {
    return await getOrders(perPage: limit, customer: customerId);
  }

  /// Crea un nuovo ordine
  Future<OrdiniGlobal> createOrder(OrdiniGlobal order) async {
    try {
      final wooOrder = _toWooOrder(order);
      final createdOrder = await _woo.createOrder(wooOrder);
      return _fromWooOrder(createdOrder);
    } catch (e) {
      log.e('❌ Errore createOrder: $e');
      rethrow;
    }
  }

  /// Aggiorna un ordine esistente
  Future<OrdiniGlobal> updateOrder(OrdiniGlobal order) async {
    try {
      final wooOrder = _toWooOrder(order);
      final updatedOrder = await _woo.updateOrder(wooOrder.id!, wooOrder);
      return _fromWooOrder(updatedOrder);
    } catch (e) {
      log.e('❌ Errore updateOrder: $e');
      rethrow;
    }
  }

  /// Aggiorna lo stato di un ordine
  Future<OrdiniGlobal> updateOrderStatus(
    int orderId,
    OrdineStatus status,
  ) async {
    try {
      final order = await getOrderById(orderId);
      final updatedOrder = order.copyWith(status: status);
      return await updateOrder(updatedOrder);
    } catch (e) {
      log.e('❌ Errore updateOrderStatus: $e');
      rethrow;
    }
  }

  /// Elimina un ordine
  Future<bool> deleteOrder(int orderId, {bool force = false}) async {
    try {
      final result = await _woo.deleteOrder(orderId, force: force);
      return result.deleted;
    } catch (e) {
      log.e('❌ Errore deleteOrder: $e');
      rethrow;
    }
  }

  /// Ottiene note di un ordine
  Future<List<WooOrderNote>> getOrderNotes(int orderId) async {
    try {
      final result = await _woo.getOrderNotes(orderId);
      return result.items;
    } catch (e) {
      log.e('❌ Errore getOrderNotes: $e');
      rethrow;
    }
  }

  /// Aggiungi nota a un ordine
  Future<WooOrderNote> addOrderNote(
    int orderId, {
    required String note,
    bool customerNote = false,
  }) async {
    try {
      final orderNote = WooOrderNote(note: note, customerNote: customerNote);
      return await _woo.createOrderNote(orderId, orderNote);
    } catch (e) {
      log.e('❌ Errore addOrderNote: $e');
      rethrow;
    }
  }

  /// Ottiene statistiche sugli ordini
  Future<Map<String, dynamic>> getOrderStats() async {
    try {
      // Stati ordine comuni
      const stati = [
        'pending',
        'processing',
        'on-hold',
        'completed',
        'cancelled',
        'refunded',
        'failed',
      ];

      final futures = stati.map((stato) => _getOrderCountByStatus(stato));
      final conteggi = await Future.wait(futures);

      final result = <String, dynamic>{};
      for (var i = 0; i < stati.length; i++) {
        result[stati[i]] = conteggi[i];
      }

      return result;
    } catch (e) {
      log.e('❌ Errore getOrderStats: $e');
      return {};
    }
  }

  /// Helper: ottiene il conteggio ordini per stato
  Future<int> _getOrderCountByStatus(String status) async {
    try {
      return await countOrdersByStatus(status);
    } catch (e) {
      return 0;
    }
  }

  /// Numero di ordini nello stato WooCommerce [status] (es. `processing`,
  /// `on-hold`). Chiede una sola riga e legge il totale da `x-wp-total`, quindi
  /// e leggero da ripetere. A differenza di [getOrderStats] gli errori
  /// arrivano al chiamante: la campanella notifiche non deve scambiare un
  /// errore di rete per "nessun ordine".
  Future<int> countOrdersByStatus(String status) async {
    final response = await _woo.dio.get(
      '/orders',
      queryParameters: {'per_page': 1, 'status': status},
    );
    return int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;
  }

  /// Operazioni batch sugli ordini
  Future<Map<String, dynamic>> batchUpdateOrders({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    try {
      final batchData = <String, dynamic>{};
      if (create != null && create.isNotEmpty) batchData['create'] = create;
      if (update != null && update.isNotEmpty) batchData['update'] = update;
      if (delete != null && delete.isNotEmpty) batchData['delete'] = delete;

      if (batchData.isEmpty) {
        throw Exception('Nessuna operazione batch specificata');
      }

      final response = await _woo.dio.post('/orders/batch', data: batchData);

      return response.data as Map<String, dynamic>;
    } catch (e) {
      log.e('❌ Errore batchUpdateOrders: $e');
      rethrow;
    }
  }

  /// Verifica disponibilità del servizio
  Future<bool> isServiceAvailable() async {
    try {
      await getOrders(perPage: 1);
      return true;
    } catch (e) {
      return false;
    }
  }
}

WooOrderStatus _parseOrderStatus(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return WooOrderStatus.pending;
    case 'processing':
      return WooOrderStatus.processing;
    case 'on-hold':
      return WooOrderStatus.onHold;
    case 'completed':
      return WooOrderStatus.completed;
    case 'cancelled':
      return WooOrderStatus.cancelled;
    case 'refunded':
      return WooOrderStatus.refunded;
    case 'failed':
      return WooOrderStatus.failed;
    default:
      return WooOrderStatus.unknown;
  }
}
