import '../../../loyalty_cards/loyalty_stats.dart';
import '../../mgws/query/query_mgws_loyalty.dart';
import '../../mgws/connection/mgws_connection.dart';

class LoyaltyGateway {
  LoyaltyGateway({MgwsConnection? mgwsConnection})
    : _availability = mgwsConnection ?? MgwsConnection.instance;

  final QueryMgwsLoyalty _mgws = QueryMgwsLoyalty();
  final MgwsConnection _availability;

  Future<int> getCustomerPoints(int customerId) async {
    if (!await _availability.ensureConnected()) return 0;
    return _mgws.getCustomerPoints(customerId);
  }

  Future<bool> addPointsToCustomer({
    required int customerId,
    required int points,
    String? reference,
    String? note,
  }) async {
    if (!await _availability.ensureConnected()) return false;
    return _mgws.addPointsToCustomer(
      customerId: customerId,
      points: points,
      reference: reference,
      note: note,
    );
  }

  Future<bool> deductPointsFromCustomer({
    required int customerId,
    required int points,
    String? reference,
    String? note,
  }) async {
    if (!await _availability.ensureConnected()) return false;
    return _mgws.deductPointsFromCustomer(
      customerId: customerId,
      points: points,
      reference: reference,
      note: note,
    );
  }

  Future<Map<String, dynamic>?> getCustomerLoyaltyCard(int customerId) async {
    if (!await _availability.ensureConnected()) return null;
    return _mgws.getCustomerLoyaltyCard(customerId);
  }

  Future<Map<String, dynamic>?> findCustomerByCardNumber(
    String cardNumber,
  ) async {
    if (!await _availability.ensureConnected()) return null;
    return _mgws.findCustomerByCardNumber(cardNumber);
  }

  Future<Map<String, dynamic>?> findCustomerByEmail(String email) async {
    if (!await _availability.ensureConnected()) return null;
    return _mgws.findCustomerByEmail(email);
  }

  Future<bool> createOrUpdateLoyaltyCard({
    required int customerId,
    required String cardNumber,
    String tier = 'bronze',
  }) async {
    if (!await _availability.ensureConnected()) return false;
    return _mgws.createOrUpdateLoyaltyCard(
      customerId: customerId,
      cardNumber: cardNumber,
      tier: tier,
    );
  }

  Future<bool> removeLoyaltyCard(int customerId) async {
    if (!await _availability.ensureConnected()) return false;
    return _mgws.removeLoyaltyCard(customerId);
  }

  Future<List<Map<String, dynamic>>> getPointsHistory(
    int customerId, {
    int page = 1,
    int perPage = 20,
  }) async {
    if (!await _availability.ensureConnected())
      return const <Map<String, dynamic>>[];
    return _mgws.getPointsHistory(customerId, page: page, perPage: perPage);
  }

  Future<LoyaltyStats> getLoyaltyStats() async {
    if (!await _availability.ensureConnected()) return LoyaltyStats.empty;
    return _mgws.getLoyaltyStats();
  }

  Future<bool> isLoyaltyAvailable() async => _availability.ensureConnected();

  /// Restituisce tutte le carte fedeltà in un'unica chiamata,
  /// senza verifica di disponibilità (il caricamento dei clienti
  /// non deve essere bloccato da MGWS).
  Future<List<Map<String, dynamic>>> listAllCards() async {
    return _mgws.listAllCards();
  }
}
