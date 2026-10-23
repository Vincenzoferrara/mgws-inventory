import '../../../loyalty_cards/loyalty_stats.dart';
import 'query_mgws_base.dart';

class QueryMgwsLoyalty {
  QueryMgwsLoyalty();

  final QueryMgwsBase _base = QueryMgwsBase();

  static String cardLookupPath(String cardNumber) {
    return '/wp-json/mgws/v1/loyalty/lookup/card/${Uri.encodeComponent(cardNumber)}';
  }

  static String emailLookupPath(String email) {
    return '/wp-json/mgws/v1/loyalty/lookup/email/${Uri.encodeComponent(email)}';
  }

  static int customerPointsFromResponse(Object? response) {
    final data = customerFromResponse(response);
    return int.tryParse(data?['points']?.toString() ?? '0') ?? 0;
  }

  static Map<String, dynamic>? customerFromResponse(Object? response) {
    if (response is! Map<String, dynamic>) return null;
    return response;
  }

  Future<int> getCustomerPoints(int customerId) async {
    final response = await _base.get(
      '/wp-json/mgws/v1/loyalty/customers/$customerId',
    );
    return customerPointsFromResponse(response.data);
  }

  Future<bool> addPointsToCustomer({
    required int customerId,
    required int points,
    String? reference,
    String? note,
  }) async {
    final response = await _base.post(
      '/wp-json/mgws/v1/loyalty/customers/$customerId/points/add',
      data: {'points': points, 'reference': reference, 'note': note},
    );
    return (response.statusCode ?? 500) >= 200 &&
        (response.statusCode ?? 500) < 300;
  }

  Future<bool> deductPointsFromCustomer({
    required int customerId,
    required int points,
    String? reference,
    String? note,
  }) async {
    final response = await _base.post(
      '/wp-json/mgws/v1/loyalty/customers/$customerId/points/deduct',
      data: {'points': points, 'reference': reference, 'note': note},
    );
    return (response.statusCode ?? 500) >= 200 &&
        (response.statusCode ?? 500) < 300;
  }

  Future<Map<String, dynamic>?> getCustomerLoyaltyCard(int customerId) async {
    final response = await _base.get(
      '/wp-json/mgws/v1/loyalty/customers/$customerId',
    );
    return customerFromResponse(response.data);
  }

  /// Restituisce tutte le carte fedeltà in un'unica chiamata.
  ///
  /// Usata per caricare le carte in parallelo con i clienti, senza
  /// fare una richiesta per ciascun cliente.
  Future<List<Map<String, dynamic>>> listAllCards() async {
    final response = await _base.get('/wp-json/mgws/v1/loyalty/cards');
    final raw = response.data;
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>?> findCustomerByCardNumber(
    String cardNumber,
  ) async {
    final response = await _base.get(cardLookupPath(cardNumber));
    return customerFromResponse(response.data);
  }

  Future<Map<String, dynamic>?> findCustomerByEmail(String email) async {
    final response = await _base.get(emailLookupPath(email));
    return customerFromResponse(response.data);
  }

  Future<bool> createOrUpdateLoyaltyCard({
    required int customerId,
    required String cardNumber,
    String tier = 'bronze',
  }) async {
    final response = await _base.put(
      '/wp-json/mgws/v1/loyalty/customers/$customerId/card',
      data: {'card_number': cardNumber, 'tier': tier},
    );
    return (response.statusCode ?? 500) >= 200 &&
        (response.statusCode ?? 500) < 300;
  }

  Future<bool> removeLoyaltyCard(int customerId) async {
    final response = await _base.delete(
      '/wp-json/mgws/v1/loyalty/customers/$customerId/card',
    );
    return (response.statusCode ?? 500) >= 200 &&
        (response.statusCode ?? 500) < 300;
  }

  Future<List<Map<String, dynamic>>> getPointsHistory(
    int customerId, {
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _base.get(
      '/wp-json/mgws/v1/loyalty/customers/$customerId/history',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final raw = response.data;
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<LoyaltyStats> getLoyaltyStats() async {
    final response = await _base.get('/wp-json/mgws/v1/loyalty/stats');
    return loyaltyStatsFromResponse(response.data);
  }

  /// Legge /loyalty/stats. `total_points_issued` e `tier_distribution` sono
  /// arrivati dopo: con un plugin più vecchio restano null.
  static LoyaltyStats loyaltyStatsFromResponse(Object? response) {
    if (response is! Map) return LoyaltyStats.empty;
    int? asInt(Object? value) =>
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

    final tiers = response['tier_distribution'];
    return LoyaltyStats(
      customers: asInt(response['customers']) ?? 0,
      cards: asInt(response['cards']) ?? 0,
      pointsBalance: asInt(response['points']) ?? 0,
      pointsIssued: asInt(response['total_points_issued']),
      tierCounts: tiers is Map
          ? {
              for (final entry in tiers.entries)
                entry.key.toString(): asInt(entry.value) ?? 0,
            }
          : null,
    );
  }
}
