import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';

/// Query class per la gestione delle tasse WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
class WooQueryTasse {
  // Singleton pattern
  static final WooQueryTasse _instance = WooQueryTasse._internal();
  factory WooQueryTasse() => _instance;
  WooQueryTasse._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  // =======================================================
  // == GESTIONE CLASSI TASSE                            ==
  // =======================================================

  /// Recupera tutte le classi di tasse configurate
  Future<List<WooTaxClass>> getTaxClasses() async {
    return await _woo.getTaxClasses();
  }

  /// Crea una nuova classe di tasse
  Future<WooTaxClass> createTaxClass({required String name}) async {
    return await _woo.createTaxClass(WooTaxClass(name: name));
  }

  /// Elimina una classe di tasse
  Future<void> deleteTaxClass(String slug) async {
    await _woo.deleteTaxClass(slug);
  }

  // =======================================================
  // == GESTIONE ALIQUOTE TASSE                          ==
  // =======================================================

  /// Recupera le aliquote fiscali con filtri opzionali.
  ///
  /// WooCommerce non filtra `country`/`state` lato endpoint REST delle
  /// aliquote. Quando questi filtri sono presenti, l'app recupera tutte le
  /// aliquote paginando e applica il filtro localmente, poi restituisce la
  /// pagina richiesta.
  Future<List<WooTaxRate>> getTaxRates({
    int page = 1,
    int perPage = 10,
    String? taxClass,
    String? country,
    String? state,
    WooOrderBy orderBy = WooOrderBy.date,
    WooSort order = WooSort.desc,
  }) async {
    if ((country ?? '').trim().isNotEmpty || (state ?? '').trim().isNotEmpty) {
      final filtered = (await getAllTaxRates()).where((rate) {
        return _matchesLocation(rate, country: country, state: state);
      }).toList();
      final start = (page - 1).clamp(0, filtered.length) * perPage;
      final end = (start + perPage).clamp(start, filtered.length);
      return filtered.sublist(start, end);
    }
    final result = await _woo.getTaxRates(
      page: page,
      perPage: perPage,
      taxClass: taxClass,
      orderBy: orderBy,
      order: order,
    );
    return result.items;
  }

  /// Recupera un'aliquota fiscale tramite ID
  Future<WooTaxRate> getTaxRateById(int taxRateId) async {
    return await _woo.getTaxRate(taxRateId);
  }

  /// Crea una nuova aliquota fiscale
  Future<WooTaxRate> createTaxRate({
    required String country,
    String state = '',
    required String rate,
    required String name,
    int priority = 1,
    bool compound = false,
    bool shipping = true,
    int order = 0,
    String taxClass = 'standard',
    List<String>? postcodes,
    List<String>? cities,
  }) async {
    final taxRate = WooTaxRate(
      country: country,
      state: state,
      rate: rate,
      name: name,
      priority: priority,
      compound: compound,
      shipping: shipping,
      order: order,
      taxClass: taxClass,
      postcodes: postcodes,
      cities: cities,
    );

    return await _woo.createTaxRate(taxRate);
  }

  /// Aggiorna un'aliquota fiscale esistente
  Future<WooTaxRate> updateTaxRate({
    required int taxRateId,
    String? country,
    String? state,
    String? rate,
    String? name,
    int? priority,
    bool? compound,
    bool? shipping,
    int? order,
    String? taxClass,
    List<String>? postcodes,
    List<String>? cities,
  }) async {
    // Prima ottieni l'aliquota esistente
    final existingRate = await _woo.getTaxRate(taxRateId);

    // Crea una nuova aliquota con i campi aggiornati
    final updatedRate = WooTaxRate(
      id: taxRateId,
      country: country ?? existingRate.country,
      state: state ?? existingRate.state,
      rate: rate ?? existingRate.rate,
      name: name ?? existingRate.name,
      priority: priority ?? existingRate.priority,
      compound: compound ?? existingRate.compound,
      shipping: shipping ?? existingRate.shipping,
      order: order ?? existingRate.order,
      taxClass: taxClass ?? existingRate.taxClass,
      postcodes: postcodes ?? existingRate.postcodes,
      cities: cities ?? existingRate.cities,
    );

    return await _woo.updateTaxRate(taxRateId, updatedRate);
  }

  /// Elimina un'aliquota fiscale
  Future<void> deleteTaxRate(int taxRateId) async {
    await _woo.deleteTaxRate(taxRateId);
  }

  // =======================================================
  // == FILTRI E RICERCHE                                ==
  // =======================================================

  /// Recupera le aliquote fiscali per una zona specifica
  Future<List<WooTaxRate>> getTaxRatesByLocation({
    required String country,
    String? state,
    String? city,
    String? postcode,
  }) async {
    final allRates = await getAllTaxRates();

    // Filtra le aliquote applicabili alla zona specifica
    return allRates.where((rate) {
      if (!_matchesLocation(rate, country: country, state: state)) return false;

      // Verifica città (se specificata)
      if (city != null && rate.cities != null && rate.cities!.isNotEmpty) {
        if (!rate.cities!.contains(city)) return false;
      }

      // Verifica codice postale (se specificato)
      if (postcode != null &&
          rate.postcodes != null &&
          rate.postcodes!.isNotEmpty) {
        bool matchesPostcode = rate.postcodes!.any((pc) {
          // Supporta wildcards semplici
          if (pc.contains('*')) {
            final pattern = pc.replaceAll('*', '');
            return postcode.startsWith(pattern);
          }
          return pc == postcode;
        });
        if (!matchesPostcode) return false;
      }

      return true;
    }).toList();
  }

  bool _matchesLocation(WooTaxRate rate, {String? country, String? state}) {
    final requestedCountry = (country ?? '').trim().toUpperCase();
    final requestedState = (state ?? '').trim().toUpperCase();
    final rateCountry = (rate.country ?? '').trim().toUpperCase();
    final rateState = (rate.state ?? '').trim().toUpperCase();

    if (requestedCountry.isNotEmpty &&
        rateCountry.isNotEmpty &&
        rateCountry != requestedCountry) {
      return false;
    }
    if (requestedState.isNotEmpty &&
        rateState.isNotEmpty &&
        rateState != requestedState) {
      return false;
    }
    return true;
  }

  /// Ottiene tutte le aliquote (uso con cautela!)
  Future<List<WooTaxRate>> getAllTaxRates() async {
    final List<WooTaxRate> allRates = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      final resultPage = await _woo.getTaxRates(
        page: currentPage,
        perPage: 100,
      );

      if (resultPage.items.isEmpty) {
        hasMore = false;
      } else {
        allRates.addAll(resultPage.items);
        currentPage++;
      }
    }

    return allRates;
  }

  // =======================================================
  // == CALCOLO TASSE (LOCALE)                           ==
  // =======================================================

  /// Calcola le tasse per un prodotto in una zona specifica
  Future<TaxCalculation> calculateProductTax({
    required String productPrice,
    String taxClass = 'standard',
    required String country,
    String? state,
    String? city,
    String? postcode,
    bool priceIncludesTax = false,
  }) async {
    final price = double.tryParse(productPrice) ?? 0.0;
    if (price <= 0) {
      return TaxCalculation(
        priceExcludingTax: productPrice,
        taxAmount: '0.00',
        priceIncludingTax: productPrice,
        taxBreakdown: [],
      );
    }

    // Recupera le aliquote applicabili
    final applicableRates = await getTaxRatesByLocation(
      country: country,
      state: state,
      city: city,
      postcode: postcode,
    );

    // Filtra per classe di tasse
    final rates = applicableRates
        .where(
          (rate) =>
              rate.taxClass == taxClass ||
              (taxClass == 'standard' && (rate.taxClass?.isEmpty ?? true)),
        )
        .toList();

    if (rates.isEmpty) {
      return TaxCalculation(
        priceExcludingTax: productPrice,
        taxAmount: '0.00',
        priceIncludingTax: productPrice,
        taxBreakdown: [],
      );
    }

    // Calcola le tasse
    double totalTaxRate = 0.0;
    List<TaxBreakdownItem> breakdown = [];

    for (final rate in rates) {
      final rateValue = double.tryParse(rate.rate ?? '0') ?? 0.0;
      totalTaxRate += rateValue;

      breakdown.add(
        TaxBreakdownItem(
          rateId: rate.id ?? 0,
          name: rate.name ?? '',
          rate: rate.rate ?? '0',
          taxAmount: _calculateTaxForRate(
            price,
            rateValue,
            priceIncludesTax,
          ).toStringAsFixed(2),
        ),
      );
    }

    double priceExTax, taxAmount, priceIncTax;

    if (priceIncludesTax) {
      // Il prezzo include già le tasse
      priceIncTax = price;
      priceExTax = price / (1 + (totalTaxRate / 100));
      taxAmount = priceIncTax - priceExTax;
    } else {
      // Il prezzo è senza tasse
      priceExTax = price;
      taxAmount = price * (totalTaxRate / 100);
      priceIncTax = priceExTax + taxAmount;
    }

    return TaxCalculation(
      priceExcludingTax: priceExTax.toStringAsFixed(2),
      taxAmount: taxAmount.toStringAsFixed(2),
      priceIncludingTax: priceIncTax.toStringAsFixed(2),
      taxBreakdown: breakdown,
    );
  }

  /// Calcola l'importo della tassa per una singola aliquota
  double _calculateTaxForRate(
    double price,
    double rate,
    bool priceIncludesTax,
  ) {
    if (priceIncludesTax) {
      return (price * rate) / (100 + rate);
    } else {
      return price * (rate / 100);
    }
  }

  /// Calcola le tasse per un intero carrello
  Future<CartTaxCalculation> calculateCartTax({
    required List<CartTaxItem> items,
    required String country,
    String? state,
    String? city,
    String? postcode,
    bool priceIncludesTax = false,
  }) async {
    List<TaxCalculation> itemCalculations = [];
    double totalTaxAmount = 0.0;
    double totalPriceExTax = 0.0;
    double totalPriceIncTax = 0.0;

    for (final item in items) {
      final calculation = await calculateProductTax(
        productPrice: item.price,
        taxClass: item.taxClass,
        country: country,
        state: state,
        city: city,
        postcode: postcode,
        priceIncludesTax: priceIncludesTax,
      );

      // Moltiplica per la quantità
      final quantity = item.quantity;
      final itemTaxAmount =
          (double.tryParse(calculation.taxAmount) ?? 0.0) * quantity;
      final itemPriceExTax =
          (double.tryParse(calculation.priceExcludingTax) ?? 0.0) * quantity;
      final itemPriceIncTax =
          (double.tryParse(calculation.priceIncludingTax) ?? 0.0) * quantity;

      totalTaxAmount += itemTaxAmount;
      totalPriceExTax += itemPriceExTax;
      totalPriceIncTax += itemPriceIncTax;

      itemCalculations.add(
        TaxCalculation(
          priceExcludingTax: itemPriceExTax.toStringAsFixed(2),
          taxAmount: itemTaxAmount.toStringAsFixed(2),
          priceIncludingTax: itemPriceIncTax.toStringAsFixed(2),
          taxBreakdown: calculation.taxBreakdown,
        ),
      );
    }

    return CartTaxCalculation(
      itemCalculations: itemCalculations,
      totalPriceExcludingTax: totalPriceExTax.toStringAsFixed(2),
      totalTaxAmount: totalTaxAmount.toStringAsFixed(2),
      totalPriceIncludingTax: totalPriceIncTax.toStringAsFixed(2),
    );
  }

  /// Verifica disponibilità servizio
  Future<bool> isServiceAvailable() async {
    try {
      await _woo.getTaxClasses();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// =======================================================
// == MODELLI DI DATI                                   ==
// =======================================================

/// Modello per il calcolo delle tasse su un prodotto
class TaxCalculation {
  final String priceExcludingTax;
  final String taxAmount;
  final String priceIncludingTax;
  final List<TaxBreakdownItem> taxBreakdown;

  TaxCalculation({
    required this.priceExcludingTax,
    required this.taxAmount,
    required this.priceIncludingTax,
    required this.taxBreakdown,
  });
}

/// Dettaglio di una singola aliquota nel calcolo delle tasse
class TaxBreakdownItem {
  final int rateId;
  final String name;
  final String rate;
  final String taxAmount;

  TaxBreakdownItem({
    required this.rateId,
    required this.name,
    required this.rate,
    required this.taxAmount,
  });
}

/// Modello per un articolo nel calcolo delle tasse del carrello
class CartTaxItem {
  final String price;
  final String taxClass;
  final int quantity;

  CartTaxItem({
    required this.price,
    this.taxClass = 'standard',
    this.quantity = 1,
  });
}

/// Modello per il calcolo delle tasse dell'intero carrello
class CartTaxCalculation {
  final List<TaxCalculation> itemCalculations;
  final String totalPriceExcludingTax;
  final String totalTaxAmount;
  final String totalPriceIncludingTax;

  CartTaxCalculation({
    required this.itemCalculations,
    required this.totalPriceExcludingTax,
    required this.totalTaxAmount,
    required this.totalPriceIncludingTax,
  });
}
