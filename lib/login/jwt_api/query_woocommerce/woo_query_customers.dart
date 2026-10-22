import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';

/// Query class per la gestione dei clienti WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
class WooQueryClienti {
  // Singleton pattern
  static final WooQueryClienti _instance = WooQueryClienti._internal();
  factory WooQueryClienti() => _instance;
  WooQueryClienti._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Getter per ottenere l'istanza WooCommerce centralizzata
  WooCommerce get _woo => _wooConnect.woo;

  /// Ottiene lista clienti con paginazione e filtri
  Future<WooPage<WooCustomer>> getCustomers({
    int page = 1,
    int perPage = 20,
    String? search,
    String? email,
    WooCustomerRole? role,
    WooOrderBy orderBy = WooOrderBy.registeredDate,
    WooSort order = WooSort.desc,
  }) async {
    return await _woo.getCustomers(
      page: page,
      perPage: perPage,
      search: search,
      email: email,
      role: role ?? WooCustomerRole.customer,
      orderBy: orderBy,
      order: order,
    );
  }

  /// Ottiene un cliente specifico per ID
  Future<WooCustomer> getCustomerById(int customerId) async {
    return await _woo.getCustomer(customerId);
  }

  /// Cerca clienti per email
  Future<List<WooCustomer>> searchCustomersByEmail(String email) async {
    final result = await _woo.getCustomers(email: email, perPage: 100);
    return result.items;
  }

  /// Cerca clienti per nome o cognome
  Future<List<WooCustomer>> searchCustomersByName(String searchTerm) async {
    final result = await _woo.getCustomers(search: searchTerm, perPage: 100);
    return result.items;
  }

  /// Crea un nuovo cliente
  Future<WooCustomer> createCustomer({
    required String email,
    String? firstName,
    String? lastName,
    String? username,
    String? password,
    WooBilling? billing,
    WooShipping? shipping,
    List<WooMetaData>? metaData,
  }) async {
    final customer = WooCustomer(
      email: email,
      firstName: firstName,
      lastName: lastName,
      username: username,
      password: password,
      billing: billing,
      shipping: shipping,
      metaData: metaData,
    );

    return await _woo.createCustomer(customer);
  }

  /// Aggiorna un cliente esistente
  Future<WooCustomer> updateCustomer({
    required int customerId,
    String? email,
    String? firstName,
    String? lastName,
    WooBilling? billing,
    WooShipping? shipping,
    List<WooMetaData>? metaData,
  }) async {
    // Prima ottieni il cliente esistente
    final existingCustomer = await _woo.getCustomer(customerId);

    // Crea un nuovo cliente con i campi aggiornati
    final updatedCustomer = WooCustomer(
      id: customerId,
      email: email ?? existingCustomer.email,
      firstName: firstName ?? existingCustomer.firstName,
      lastName: lastName ?? existingCustomer.lastName,
      billing: billing ?? existingCustomer.billing,
      shipping: shipping ?? existingCustomer.shipping,
      metaData: metaData ?? existingCustomer.metaData,
      username: existingCustomer.username,
      role: existingCustomer.role,
    );

    return await _woo.updateCustomer(customerId, updatedCustomer);
  }

  /// Aggiorna l'indirizzo di fatturazione di un cliente
  Future<WooCustomer> updateBillingAddress({
    required int customerId,
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? email,
    String? phone,
  }) async {
    // Ottieni il cliente esistente
    final existingCustomer = await getCustomerById(customerId);
    final existingBilling = existingCustomer.billing;

    final billing = WooBilling(
      firstName: firstName ?? existingBilling?.firstName,
      lastName: lastName ?? existingBilling?.lastName,
      company: company ?? existingBilling?.company,
      address1: address1 ?? existingBilling?.address1,
      address2: address2 ?? existingBilling?.address2,
      city: city ?? existingBilling?.city,
      state: state ?? existingBilling?.state,
      postcode: postcode ?? existingBilling?.postcode,
      country: country ?? existingBilling?.country,
      email: email ?? existingBilling?.email,
      phone: phone ?? existingBilling?.phone,
    );

    return await updateCustomer(customerId: customerId, billing: billing);
  }

  /// Aggiorna l'indirizzo di spedizione di un cliente
  Future<WooCustomer> updateShippingAddress({
    required int customerId,
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
  }) async {
    // Ottieni il cliente esistente
    final existingCustomer = await getCustomerById(customerId);
    final existingShipping = existingCustomer.shipping;

    final shipping = WooShipping(
      firstName: firstName ?? existingShipping?.firstName,
      lastName: lastName ?? existingShipping?.lastName,
      company: company ?? existingShipping?.company,
      address1: address1 ?? existingShipping?.address1,
      address2: address2 ?? existingShipping?.address2,
      city: city ?? existingShipping?.city,
      state: state ?? existingShipping?.state,
      postcode: postcode ?? existingShipping?.postcode,
      country: country ?? existingShipping?.country,
    );

    return await updateCustomer(customerId: customerId, shipping: shipping);
  }

  /// Elimina un cliente
  Future<bool> deleteCustomer({required int customerId, int? reassign}) async {
    final result = await _woo.deleteCustomer(customerId, reassign: reassign);
    return result.deleted;
  }

  /// Ottiene clienti per ruolo
  Future<WooPage<WooCustomer>> getCustomersByRole(
    WooCustomerRole role, {
    int page = 1,
    int perPage = 20,
  }) async {
    return await _woo.getCustomers(role: role, page: page, perPage: perPage);
  }

  /// Ottiene tutti i clienti (uso con cautela!)
  Future<List<WooCustomer>> getAllCustomers() async {
    final List<WooCustomer> allCustomers = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      final page = await _woo.getCustomers(page: currentPage, perPage: 100);

      if (page.items.isEmpty) {
        hasMore = false;
      } else {
        allCustomers.addAll(page.items);
        currentPage++;
      }
    }

    return allCustomers;
  }

  /// Batch update clienti
  /// Usa l'istanza Dio del plugin che ha già l'autenticazione JWT
  Future<Map<String, dynamic>> batchUpdateCustomers({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    final batchData = {
      if (create != null && create.isNotEmpty) 'create': create,
      if (update != null && update.isNotEmpty) 'update': update,
      if (delete != null && delete.isNotEmpty) 'delete': delete,
    };

    final response = await _woo.dio.post('/customers/batch', data: batchData);

    return response.data as Map<String, dynamic>;
  }

  /// Ottiene statistiche clienti
  /// Usa l'istanza Dio del plugin per accedere agli headers
  Future<Map<String, dynamic>> getCustomerStats() async {
    final response = await _woo.dio.get(
      '/customers',
      queryParameters: {'per_page': 1, 'page': 1},
    );

    final totalCustomers =
        int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;

    return {'total_customers': totalCustomers};
  }

  /// Verifica se un email esiste già
  Future<bool> emailExists(String email) async {
    try {
      final customers = await searchCustomersByEmail(email);
      return customers.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Ottiene gli ordini di un cliente
  Future<List<WooOrder>> getCustomerOrders(
    int customerId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final result = await _woo.getOrders(
      customer: customerId,
      page: page,
      perPage: perPage,
    );
    return result.items;
  }

  /// Ottiene il totale speso da un cliente
  Future<double> getCustomerTotalSpent(int customerId) async {
    final orders = await getCustomerOrders(customerId, perPage: 100);
    double total = 0.0;

    for (var order in orders) {
      if (order.status == WooOrderStatus.completed ||
          order.status == WooOrderStatus.processing) {
        total += double.tryParse(order.total?.toString() ?? '0') ?? 0.0;
      }
    }

    return total;
  }

  /// Ottiene download disponibili per un cliente
  Future<List<WooCustomerDownload>> getCustomerDownloads(int customerId) async {
    final result = await _woo.getCustomerDownloads(customerId);
    return result.items;
  }

  // =======================================================
  // == METODI HELPER AGGIUNTIVI                         ==
  // =======================================================

  /// Recupera i clienti per paese
  Future<List<WooCustomer>> getByCountry(
    String country, {
    int limit = 50,
  }) async {
    final page = await _woo.getCustomers(perPage: limit);
    final allCustomers = page.items;

    return allCustomers
        .where(
          (customer) =>
              customer.billing?.country == country ||
              customer.shipping?.country == country,
        )
        .toList();
  }

  /// Cerca clienti per email parziale
  Future<List<WooCustomer>> searchByEmail(
    String emailFragment, {
    int limit = 20,
  }) async {
    final result = await _woo.getCustomers(
      search: emailFragment,
      perPage: limit,
    );
    return result.items;
  }

  /// Recupera i clienti più attivi (con più ordini)
  /// Nota: questo metodo conta manualmente gli ordini per ogni cliente
  Future<List<WooCustomer>> getTopCustomers({
    int limit = 20,
    int minOrders = 1,
  }) async {
    final page = await _woo.getCustomers(perPage: 100);
    final customers = page.items;

    // Crea una lista di clienti con il conteggio degli ordini
    final customersWithOrderCount = <Map<String, dynamic>>[];

    for (var customer in customers) {
      if (customer.id != null) {
        final orders = await getCustomerOrders(customer.id!, perPage: 1000);
        final orderCount = orders.length;

        if (orderCount >= minOrders) {
          customersWithOrderCount.add({
            'customer': customer,
            'orderCount': orderCount,
          });
        }
      }
    }

    // Ordina per numero di ordini
    customersWithOrderCount.sort(
      (a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int),
    );

    // Restituisce solo i clienti
    return customersWithOrderCount
        .take(limit)
        .map((item) => item['customer'] as WooCustomer)
        .toList();
  }

  /// Verifica disponibilità servizio
  Future<bool> isServiceAvailable() async {
    try {
      await _woo.getCustomers(perPage: 1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
