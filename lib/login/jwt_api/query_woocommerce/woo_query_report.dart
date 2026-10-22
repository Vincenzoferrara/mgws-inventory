import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../dashboard/class_report.dart';
import 'woo_report_parser_helper.dart';

/// Query class per report e statistiche WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
class WooQueryReport {
  // Singleton pattern
  static final WooQueryReport _instance = WooQueryReport._internal();
  factory WooQueryReport() => _instance;
  WooQueryReport._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  /// Ottiene report vendite per periodo
  Future<ReportVendite> getSalesReport({
    DateTime? dataInizio,
    DateTime? dataFine,
  }) async {
    try {
      final woo = _woo;

      // Formatta le date per WooCommerce API (YYYY-MM-DD)
      String? dateMin;
      String? dateMax;

      if (dataInizio != null) {
        dateMin =
            '${dataInizio.year}-${dataInizio.month.toString().padLeft(2, '0')}-${dataInizio.day.toString().padLeft(2, '0')}';
      }

      if (dataFine != null) {
        dateMax =
            '${dataFine.year}-${dataFine.month.toString().padLeft(2, '0')}-${dataFine.day.toString().padLeft(2, '0')}';
      }

      // Prova prima a usare il metodo del package
      List<WooSalesReport>? reports;
      try {
        reports = await woo.getSalesReport(dateMin: dateMin, dateMax: dateMax);
      } catch (typeError) {
        // Se c'è un errore di tipo (String/int), usa chiamata raw con parsing manuale
        // Questo è un fallback per il bug nel modello WooSalesReportTotals
        final queryParameters = <String, dynamic>{'context': 'view'};
        if (dateMin != null) queryParameters['date_min'] = dateMin;
        if (dateMax != null) queryParameters['date_max'] = dateMax;

        final response = await woo.dio.get(
          '/reports/sales',
          queryParameters: queryParameters,
        );
        final responseData = response.data;
        final List<dynamic> reportsJson = responseData is List
            ? responseData
            : [responseData];

        // Parsing manuale con le funzioni safe
        return _parseReportsManually(reportsJson, dataInizio);
      }

      // Se il metodo del package ha funzionato, usa i dati normalmente
      double totaleVendite = 0.0;
      int totaleOrdini = 0;
      final venditeGiornaliere = <VenditaGiornaliera>[];

      for (final report in reports) {
        // Accumula totali con parsing sicuro
        totaleVendite += double.tryParse(report.totalSales ?? '0') ?? 0.0;
        totaleOrdini += report.totalOrders ?? 0;

        // Aggiungi vendite giornaliere se disponibili
        if (report.totals != null) {
          for (final dayTotal in report.totals!) {
            if (dayTotal.date != null) {
              venditeGiornaliere.add(
                VenditaGiornaliera(
                  data: dayTotal.date!,
                  totale: double.tryParse(dayTotal.sales ?? '0') ?? 0.0,
                  ordini: dayTotal.orders ?? 0,
                ),
              );
            }
          }
        }
      }

      return ReportVendite(
        periodo:
            dataInizio ?? DateTime.now().subtract(const Duration(days: 30)),
        totaleVendite: totaleVendite,
        numeroOrdini: totaleOrdini,
        ticketMedio: totaleOrdini > 0 ? totaleVendite / totaleOrdini : 0.0,
        venditePerCategoria: {},
        prodottiPiuVenduti: {},
        venditeGiornaliere: venditeGiornaliere,
      );
    } catch (e) {
      throw Exception('Sales report load failed: $e');
    }
  }

  /// Parse manuale dei report quando il modello del package fallisce
  ReportVendite _parseReportsManually(
    List<dynamic> reportsJson,
    DateTime? dataInizio,
  ) {
    double totaleVendite = 0.0;
    int totaleOrdini = 0;
    final venditeGiornaliere = <VenditaGiornaliera>[];

    for (final reportData in reportsJson) {
      if (reportData is! Map<String, dynamic>) continue;

      // Accumula totali con parsing sicuro
      totaleVendite += parseDoubleSafe(reportData['total_sales']) ?? 0.0;
      totaleOrdini += parseIntSafe(reportData['total_orders']) ?? 0;

      // Aggiungi vendite giornaliere se disponibili
      final totalsData = reportData['totals'];
      if (totalsData is Map<String, dynamic>) {
        totalsData.forEach((dateKey, dayData) {
          if (dayData is Map<String, dynamic>) {
            final date = DateTime.tryParse(dateKey);
            if (date != null) {
              venditeGiornaliere.add(
                VenditaGiornaliera(
                  data: date,
                  totale: parseDoubleSafe(dayData['sales']) ?? 0.0,
                  ordini: parseIntSafe(dayData['orders']) ?? 0,
                ),
              );
            }
          }
        });
      }
    }

    return ReportVendite(
      periodo: dataInizio ?? DateTime.now().subtract(const Duration(days: 30)),
      totaleVendite: totaleVendite,
      numeroOrdini: totaleOrdini,
      ticketMedio: totaleOrdini > 0 ? totaleVendite / totaleOrdini : 0.0,
      venditePerCategoria: {},
      prodottiPiuVenduti: {},
      venditeGiornaliere: venditeGiornaliere,
    );
  }

  /// Ottiene statistiche prodotti
  ///
  /// `/reports/products/totals` raggruppa per *tipo* di prodotto (simple,
  /// variable...), non per stato o disponibilità: i conteggi vengono quindi
  /// letti dall'header `X-WP-Total` di richieste `/products` con `per_page=1`.
  Future<Statistiche> getProductStats() async {
    try {
      final counts = await Future.wait([
        _countProducts({'status': 'publish'}),
        _countProducts({'status': 'draft'}),
        _countProducts({'status': 'publish', 'stock_status': 'instock'}),
        _countProducts({'status': 'publish', 'stock_status': 'outofstock'}),
        _countProducts({'status': 'publish', 'type': 'variable'}),
      ]);

      return Statistiche(
        totaleProdotti: counts[0],
        prodottiPubblicati: counts[0],
        prodottiBozza: counts[1],
        prodottiConVarianti: counts[4],
        prodottiInStock: counts[2],
        prodottiOutOfStock: counts[3],
        valoreInventarioTotale: 0.0,
        prodottiPerCategoria: {},
        prodottiPerTag: {},
      );
    } catch (e) {
      throw Exception('Product statistics load failed: $e');
    }
  }

  Future<int> _countProducts(Map<String, dynamic> filters) =>
      _countResource('/products', filters);

  /// Numero di record che soddisfano i filtri, senza scaricarli.
  Future<int> _countResource(String path, Map<String, dynamic> filters) async {
    final response = await _woo.dio.get(
      path,
      queryParameters: {...filters, 'per_page': 1, '_fields': 'id'},
    );
    return int.tryParse(response.headers.value('x-wp-total') ?? '') ?? 0;
  }

  /// Stati ordine conteggiati nel periodo.
  static const orderStatuses = [
    'completed',
    'processing',
    'on-hold',
    'pending',
    'cancelled',
    'refunded',
    'failed',
  ];

  /// Ordini creati nel periodo, per stato.
  ///
  /// `/reports/orders/totals` restituisce invece i totali di sempre, che non
  /// sono confrontabili con le vendite del periodo.
  Future<Map<String, int>> getOrdersByStatusInPeriod({
    required DateTime dataInizio,
    required DateTime dataFine,
  }) async {
    final after = _isoDay(dataInizio, endOfDay: false);
    final before = _isoDay(dataFine, endOfDay: true);
    final counts = await Future.wait([
      for (final status in orderStatuses)
        _countResource('/orders', {
          'status': status,
          'after': after,
          'before': before,
        }),
    ]);
    return {
      for (var i = 0; i < orderStatuses.length; i++)
        if (counts[i] > 0) orderStatuses[i]: counts[i],
    };
  }

  static String _isoDay(DateTime d, {required bool endOfDay}) {
    final day =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return endOfDay ? '${day}T23:59:59' : '${day}T00:00:00';
  }

  /// Ottiene top prodotti più venduti
  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit = 10,
    DateTime? dataInizio,
    DateTime? dataFine,
  }) async {
    try {
      final woo = _woo;

      // Formatta le date
      String? dateMin;
      String? dateMax;

      if (dataInizio != null) {
        dateMin =
            '${dataInizio.year}-${dataInizio.month.toString().padLeft(2, '0')}-${dataInizio.day.toString().padLeft(2, '0')}';
      }

      if (dataFine != null) {
        dateMax =
            '${dataFine.year}-${dataFine.month.toString().padLeft(2, '0')}-${dataFine.day.toString().padLeft(2, '0')}';
      }

      // Usa l'API nativa del package
      final List<WooTopSellersReport> reports = await woo.getTopSellersReport(
        dateMin: dateMin,
        dateMax: dateMax,
      );

      // Converti in formato Map (per compatibilità con codice esistente)
      // Nota: WooTopSellersReport non ha il campo 'total', usiamo quantity
      return reports.take(limit).map((report) {
        return {
          'product_id': report.productId,
          'title': report.title,
          'quantity': report.quantity,
          'total': '0', // Non disponibile nel modello WooTopSellersReport
        };
      }).toList();
    } catch (e) {
      throw Exception('Top products load failed: $e');
    }
  }

  /// Ottiene ordini per stato
  Future<Map<String, int>> getOrdersByStatus() async {
    try {
      final woo = _woo;

      // Usa l'API nativa del package
      final List<WooOrderTotalReport> reports = await woo
          .getOrdersTotalReport();

      final Map<String, int> statusCounts = {};

      for (final report in reports) {
        final slug = report.slug ?? '';
        final total = int.tryParse(report.total ?? '0') ?? 0;
        if (slug.isNotEmpty) {
          statusCounts[slug] = total;
        }
      }

      return statusCounts;
    } catch (e) {
      throw Exception('Orders by status load failed: $e');
    }
  }

  /// Ottiene statistiche clienti
  Future<Map<String, dynamic>> getCustomerStats() async {
    try {
      final woo = _woo;

      // Usa l'API nativa del package
      final List<WooCustomerTotalReport> reports = await woo
          .getCustomersTotalReport();

      // Aggrega i dati dalla lista di report
      int totaleClienti = 0;
      int payingCustomers = 0;
      int newCustomers = 0;
      int nonPayingCustomers = 0;

      for (final report in reports) {
        final slug = report.slug ?? '';
        final total = int.tryParse(report.total ?? '0') ?? 0;

        switch (slug) {
          case 'customers':
          case 'all':
            totaleClienti = total;
            break;
          case 'paying':
            payingCustomers = total;
            break;
          case 'non_paying':
            nonPayingCustomers = total;
            break;
          case 'new':
            newCustomers = total;
            break;
        }
      }

      // L'endpoint non espone un totale: e' la somma di paganti e non paganti.
      if (totaleClienti == 0) {
        totaleClienti = payingCustomers + nonPayingCustomers;
      }

      return {
        'customers_count': totaleClienti,
        'paying_customers': payingCustomers,
        'new_customers': newCustomers,
        'avg_orders_per_customer': '0', // Non disponibile in questo endpoint
        'avg_lifetime_value': '0', // Non disponibile in questo endpoint
      };
    } catch (e) {
      throw Exception('Customer statistics load failed: $e');
    }
  }

  /// Ottiene review statistiche
  Future<Map<String, int>> getReviewStats() async {
    try {
      final woo = _woo;

      // Usa l'API nativa del package
      final List<WooProductReviewTotalReport> reports = await woo
          .getProductReviewsTotalReport();

      final Map<String, int> ratingCounts = {};

      for (final report in reports) {
        final rating = report.slug ?? '';
        final total = int.tryParse(report.total ?? '0') ?? 0;
        if (rating.isNotEmpty) {
          ratingCounts[rating] = total;
        }
      }

      return ratingCounts;
    } catch (e) {
      throw Exception('Review statistics load failed: $e');
    }
  }

  /// Ottiene coupon usage statistics
  Future<List<Map<String, dynamic>>> getCouponUsageReport({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final woo = _woo;

      // Usa l'API nativa del package
      final List<WooCouponTotalReport> reports = await woo
          .getCouponsTotalReport();

      // Converti in formato Map (per compatibilità)
      return reports.take(perPage).map((report) {
        return {
          'slug': report.slug,
          'name': report.name,
          'total': report.total,
        };
      }).toList();
    } catch (e) {
      throw Exception('Coupon report load failed: $e');
    }
  }

  /// Ottiene dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary({
    DateTime? dataInizio,
    DateTime? dataFine,
  }) async {
    try {
      // Carica tutti i dati in parallelo
      final results = await Future.wait([
        getSalesReport(dataInizio: dataInizio, dataFine: dataFine),
        getProductStats(),
        getOrdersByStatus(),
        getCustomerStats(),
        getOrdersByStatusInPeriod(
          dataInizio: dataInizio ?? DateTime.now(),
          dataFine: dataFine ?? DateTime.now(),
        ),
      ]);

      final salesReport = results[0] as ReportVendite;
      final productStats = results[1] as Statistiche;
      final ordersAllTime = results[2] as Map<String, int>;
      final customerStats = results[3] as Map<String, dynamic>;
      final ordersInPeriod = results[4] as Map<String, int>;

      return {
        'sales': {
          'total': salesReport.totaleVendite,
          'orders': salesReport.numeroOrdini,
          'average_order': salesReport.ticketMedio,
        },
        'products': {
          'total': productStats.totaleProdotti,
          'in_stock': productStats.prodottiInStock,
          'out_of_stock': productStats.prodottiOutOfStock,
        },
        'orders_by_status': ordersInPeriod,
        'orders_all_time': ordersAllTime,
        'customers': customerStats,
        'period': {
          'start': dataInizio?.toIso8601String(),
          'end': dataFine?.toIso8601String(),
        },
      };
    } catch (e) {
      throw Exception('Dashboard summary load failed: $e');
    }
  }

  /// Ottiene trend vendite (giornaliero/settimanale/mensile)
  ///
  /// WORKAROUND per bug nel package woocommerce_flutter_api:
  /// Il modello WooSalesReportTotals ha campi definiti come int? ma l'API
  /// WooCommerce restituisce stringhe ("0" invece di 0), causando errore:
  /// "type 'String' is not a subtype of type 'int?'"
  ///
  /// Questo metodo usa chiamata raw invece del modello per evitare il problema.
  /// TODO: Aprire issue su https://github.com/loaidev64/woocommerce_flutter_api
  Future<List<Map<String, dynamic>>> getSalesTrend({
    DateTime? dataInizio,
    DateTime? dataFine,
    String period = 'day', // day, week, month
  }) async {
    try {
      final woo = _woo;

      // Formatta le date
      String? dateMin;
      String? dateMax;

      if (dataInizio != null) {
        dateMin =
            '${dataInizio.year}-${dataInizio.month.toString().padLeft(2, '0')}-${dataInizio.day.toString().padLeft(2, '0')}';
      }

      if (dataFine != null) {
        dateMax =
            '${dataFine.year}-${dataFine.month.toString().padLeft(2, '0')}-${dataFine.day.toString().padLeft(2, '0')}';
      }

      // Usa chiamata raw per evitare problemi di parsing del modello WooSalesReport
      final queryParameters = <String, dynamic>{'context': 'view'};
      if (dateMin != null) queryParameters['date_min'] = dateMin;
      if (dateMax != null) queryParameters['date_max'] = dateMax;

      final response = await woo.dio.get(
        '/reports/sales',
        queryParameters: queryParameters,
      );
      final responseData = response.data;
      final List<dynamic> reportsJson = responseData is List
          ? responseData
          : [responseData];

      // Converti in formato Map con parsing manuale sicuro
      final List<Map<String, dynamic>> trends = [];

      for (final reportData in reportsJson) {
        if (reportData is! Map<String, dynamic>) continue;

        // Aggiungi vendite giornaliere se disponibili
        final totalsData = reportData['totals'];
        if (totalsData is Map<String, dynamic>) {
          totalsData.forEach((dateKey, dayData) {
            if (dayData is Map<String, dynamic>) {
              trends.add({
                'date': dateKey,
                'monthly': RegExp(r'^\d{4}-\d{2}$').hasMatch(dateKey),
                'total_sales': parseDoubleSafe(dayData['sales']) ?? 0.0,
                'total_orders': parseIntSafe(dayData['orders']) ?? 0,
                'total_items': parseIntSafe(dayData['items']) ?? 0,
              });
            }
          });
        }
      }

      return trends;
    } catch (e) {
      throw Exception('Sales trend load failed: $e');
    }
  }

  /// Verifica disponibilità servizio
  Future<bool> isServiceAvailable() async {
    try {
      final woo = _woo;
      await woo.getSalesReport();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ottiene conteggio prodotti per categoria
  Future<Map<String, int>> getProductsByCategory() async {
    try {
      final woo = _woo;
      final Map<String, int> result = {};

      // Recupera tutte le categorie via API raw
      final response = await woo.dio.get(
        '/products/categories',
        queryParameters: {'per_page': 100},
      );

      final List<dynamic> categories = response.data;

      for (final category in categories) {
        if (category is Map<String, dynamic>) {
          final name = category['name']?.toString() ?? 'Sconosciuto';
          final count = parseIntSafe(category['count']) ?? 0;
          if (count > 0) {
            result[name] = count;
          }
        }
      }

      return result;
    } catch (e) {
      throw Exception('Products by category load failed: $e');
    }
  }

  /// Ottiene prodotti con stock basso (sotto una soglia)
  Future<List<Map<String, dynamic>>> getLowStockProducts({
    int threshold = 5,
    int perPage = 100,
  }) async {
    try {
      final woo = _woo;

      // Recupera prodotti con stock_status instock e filtra quelli con quantità bassa
      final response = await woo.dio.get(
        '/products',
        queryParameters: {
          'per_page': perPage,
          'stock_status': 'instock',
          'status': 'publish',
        },
      );

      final List<dynamic> productsData = response.data;
      final lowStockProducts = <Map<String, dynamic>>[];

      for (final product in productsData) {
        if (product is Map<String, dynamic>) {
          final stockQuantity = product['stock_quantity'];
          final manageStock = product['manage_stock'] ?? false;

          if (manageStock == true && stockQuantity != null) {
            final qty = stockQuantity is int
                ? stockQuantity
                : int.tryParse(stockQuantity.toString()) ?? 0;
            if (qty > 0 && qty <= threshold) {
              lowStockProducts.add({
                'id': product['id'],
                'name': product['name'],
                'sku': product['sku'],
                'stock_quantity': qty,
                'price': product['price'],
                'image': product['images']?.isNotEmpty == true
                    ? product['images'][0]['src']
                    : null,
              });
            }
          }
        }
      }

      // Ordina per quantità crescente
      lowStockProducts.sort(
        (a, b) =>
            (a['stock_quantity'] as int).compareTo(b['stock_quantity'] as int),
      );

      return lowStockProducts;
    } catch (e) {
      throw Exception('Low stock products load failed: $e');
    }
  }

  /// Calcola il valore totale dell'inventario
  Future<double> getInventoryValue() async {
    try {
      final woo = _woo;
      double totalValue = 0.0;
      int page = 1;
      const perPage = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await woo.dio.get(
          '/products',
          queryParameters: {
            'per_page': perPage,
            'page': page,
            'status': 'publish',
          },
        );

        final List<dynamic> productsData = response.data;

        if (productsData.isEmpty) {
          hasMore = false;
          break;
        }

        for (final product in productsData) {
          if (product is Map<String, dynamic>) {
            final manageStock = product['manage_stock'] ?? false;
            final stockQuantity = product['stock_quantity'];
            final priceStr = product['price']?.toString() ?? '0';

            if (manageStock == true && stockQuantity != null) {
              final qty = stockQuantity is int
                  ? stockQuantity
                  : int.tryParse(stockQuantity.toString()) ?? 0;
              final price = double.tryParse(priceStr) ?? 0.0;
              totalValue += qty * price;
            }
          }
        }

        // Controlla se ci sono altre pagine
        final totalProducts =
            int.tryParse(response.headers.value('x-wp-total') ?? '0') ?? 0;
        if (page * perPage >= totalProducts) {
          hasMore = false;
        } else {
          page++;
        }
      }

      return totalValue;
    } catch (e) {
      throw Exception('Inventory value calculation failed: $e');
    }
  }

  /// Ottiene statistiche stock avanzate (esauriti, bassi, valore)
  Future<Map<String, dynamic>> getStockStatistics({
    int lowStockThreshold = 5,
  }) async {
    try {
      // Carica dati in parallelo
      final results = await Future.wait([
        getProductStats(),
        getLowStockProducts(threshold: lowStockThreshold),
        getInventoryValue(),
      ]);

      final productStats = results[0] as Statistiche;
      final lowStockProducts = results[1] as List<Map<String, dynamic>>;
      final inventoryValue = results[2] as double;

      return {
        'total_products': productStats.totaleProdotti,
        'in_stock': productStats.prodottiInStock,
        'out_of_stock': productStats.prodottiOutOfStock,
        'low_stock_count': lowStockProducts.length,
        'low_stock_products': lowStockProducts,
        'inventory_value': inventoryValue,
        'low_stock_threshold': lowStockThreshold,
      };
    } catch (e) {
      throw Exception('Stock statistics load failed: $e');
    }
  }

  // =======================================================
  // == ANALYTICS CLIENTI                                 ==
  // =======================================================

  /// Recupera le statistiche generali della clientela
  /// Nota: questo metodo è computazionalmente intensivo perché deve recuperare
  /// gli ordini per ogni cliente. Usare con cautela.
  Future<CustomerStatistics> getCustomerStatistics() async {
    final page = await _woo.getCustomers(perPage: 100);
    final customers = page.items;

    if (customers.isEmpty) {
      return CustomerStatistics(
        totalCustomers: 0,
        activeCustomers: 0,
        newCustomersThisMonth: 0,
        averageOrdersPerCustomer: 0.0,
        totalCustomerValue: '0.00',
        averageCustomerValue: '0.00',
        topCountries: [],
      );
    }

    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    // Calcola metriche recuperando gli ordini per ogni cliente
    int totalOrders = 0;
    double totalSpent = 0.0;
    int activeCustomers = 0;

    for (final customer in customers) {
      if (customer.id != null) {
        try {
          final page = await _woo.getOrders(
            customer: customer.id!,
            perPage: 100,
          );
          final orders = page.items;
          final orderCount = orders.length;

          if (orderCount > 0) {
            activeCustomers++;
            totalOrders += orderCount;

            // Calcola totale speso
            for (var order in orders) {
              if (order.status == WooOrderStatus.completed ||
                  order.status == WooOrderStatus.processing) {
                totalSpent +=
                    double.tryParse(order.total?.toString() ?? '0') ?? 0.0;
              }
            }
          }
        } catch (e) {
          // Ignora errori per singoli clienti
        }
      }
    }

    final newCustomers = customers
        .where((c) => c.dateCreated != null && c.dateCreated!.isAfter(monthAgo))
        .length;

    final averageOrders = customers.isNotEmpty
        ? totalOrders / customers.length
        : 0.0;
    final averageSpent = customers.isNotEmpty
        ? totalSpent / customers.length
        : 0.0;

    // Top paesi
    final countryCounts = <String, int>{};
    for (final customer in customers) {
      final country = customer.billing?.country ?? '';
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
    }

    final topCountries = countryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomerStatistics(
      totalCustomers: customers.length,
      activeCustomers: activeCustomers,
      newCustomersThisMonth: newCustomers,
      averageOrdersPerCustomer: averageOrders,
      totalCustomerValue: totalSpent.toStringAsFixed(2),
      averageCustomerValue: averageSpent.toStringAsFixed(2),
      topCountries: topCountries
          .take(5)
          .map((e) => CountryStatistic(country: e.key, customerCount: e.value))
          .toList(),
    );
  }

  /// Segmenta i clienti in base al valore degli acquisti
  /// Nota: questo metodo è computazionalmente intensivo perché deve recuperare
  /// gli ordini per ogni cliente. Usare con cautela.
  Future<CustomerSegmentation> getCustomerSegmentation({
    double highValueThreshold = 1000.0,
    double mediumValueThreshold = 100.0,
  }) async {
    final page = await _woo.getCustomers(perPage: 100);
    final customers = page.items;

    List<WooCustomer> highValue = [];
    List<WooCustomer> mediumValue = [];
    List<WooCustomer> lowValue = [];
    List<WooCustomer> inactive = [];

    for (final customer in customers) {
      if (customer.id == null) continue;

      // Recupera gli ordini del cliente
      double totalSpent = 0.0;
      int ordersCount = 0;

      try {
        final page = await _woo.getOrders(customer: customer.id!, perPage: 100);
        final orders = page.items;
        ordersCount = orders.length;

        // Calcola totale speso
        for (var order in orders) {
          if (order.status == WooOrderStatus.completed ||
              order.status == WooOrderStatus.processing) {
            totalSpent +=
                double.tryParse(order.total?.toString() ?? '0') ?? 0.0;
          }
        }
      } catch (e) {
        // Ignora errori per singoli clienti
      }

      if (ordersCount == 0) {
        inactive.add(customer);
      } else if (totalSpent >= highValueThreshold) {
        highValue.add(customer);
      } else if (totalSpent >= mediumValueThreshold) {
        mediumValue.add(customer);
      } else {
        lowValue.add(customer);
      }
    }

    return CustomerSegmentation(
      highValueCustomers: highValue,
      mediumValueCustomers: mediumValue,
      lowValueCustomers: lowValue,
      inactiveCustomers: inactive,
      highValueThreshold: highValueThreshold,
      mediumValueThreshold: mediumValueThreshold,
    );
  }

  /// Recupera i clienti a rischio abbandono
  /// Nota: questo metodo è computazionalmente intensivo perché deve recuperare
  /// gli ordini per ogni cliente. Usare con cautela.
  Future<List<WooCustomer>> getChurnRiskCustomers({
    int daysSinceLastOrder = 90,
    int minPreviousOrders = 2,
  }) async {
    final page = await _woo.getCustomers(perPage: 100);
    final customers = page.items;
    final cutoffDate = DateTime.now().subtract(
      Duration(days: daysSinceLastOrder),
    );

    List<WooCustomer> churnRiskCustomers = [];

    for (final customer in customers) {
      if (customer.id == null) continue;

      try {
        final page = await _woo.getOrders(customer: customer.id!, perPage: 100);
        final orders = page.items;

        if (orders.length >= minPreviousOrders) {
          // Controlla la data dell'ultimo ordine
          final dateModified = customer.dateModified;

          if (dateModified != null && dateModified.isBefore(cutoffDate)) {
            churnRiskCustomers.add(customer);
          }
        }
      } catch (e) {
        // Ignora errori per singoli clienti
      }
    }

    return churnRiskCustomers;
  }
}

// =======================================================
// == MODELLI ANALYTICS CLIENTI                         ==
// =======================================================

/// Modello per le statistiche generali della clientela
class CustomerStatistics {
  final int totalCustomers;
  final int activeCustomers;
  final int newCustomersThisMonth;
  final double averageOrdersPerCustomer;
  final String totalCustomerValue;
  final String averageCustomerValue;
  final List<CountryStatistic> topCountries;

  CustomerStatistics({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.newCustomersThisMonth,
    required this.averageOrdersPerCustomer,
    required this.totalCustomerValue,
    required this.averageCustomerValue,
    required this.topCountries,
  });
}

/// Modello per le statistiche per paese
class CountryStatistic {
  final String country;
  final int customerCount;

  CountryStatistic({required this.country, required this.customerCount});
}

/// Modello per la segmentazione dei clienti
class CustomerSegmentation {
  final List<WooCustomer> highValueCustomers;
  final List<WooCustomer> mediumValueCustomers;
  final List<WooCustomer> lowValueCustomers;
  final List<WooCustomer> inactiveCustomers;
  final double highValueThreshold;
  final double mediumValueThreshold;

  CustomerSegmentation({
    required this.highValueCustomers,
    required this.mediumValueCustomers,
    required this.lowValueCustomers,
    required this.inactiveCustomers,
    required this.highValueThreshold,
    required this.mediumValueThreshold,
  });

  /// Restituisce il numero totale di clienti segmentati
  int get totalCustomers =>
      highValueCustomers.length +
      mediumValueCustomers.length +
      lowValueCustomers.length +
      inactiveCustomers.length;

  /// Restituisce la percentuale di clienti di alto valore
  double get highValuePercentage => totalCustomers > 0
      ? (highValueCustomers.length / totalCustomers) * 100
      : 0.0;

  /// Restituisce la percentuale di clienti inattivi
  double get inactivePercentage => totalCustomers > 0
      ? (inactiveCustomers.length / totalCustomers) * 100
      : 0.0;
}
