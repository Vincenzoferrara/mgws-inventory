import 'package:flutter/foundation.dart';
import '../class_coupon.dart';
import '../../login/jwt_api/query/coupon_query.dart';
import '../../log_viewer/app_logger.dart';

/// Controller per la gestione dei coupon.
/// Gestisce la logica di business e le chiamate API.
class CouponGestisciController extends ChangeNotifier {
  final CouponsService _couponService;

  List<CouponGlobal> _coupons = [];
  CouponStatsDisplay? _stats;
  bool _isLoading = false;
  String? _error;

  List<CouponGlobal> get coupons => _coupons;
  CouponStatsDisplay? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CouponGestisciController({CouponsService? couponService})
    : _couponService = couponService ?? CouponsService();

  /// Carica i coupon con filtri opzionali
  Future<void> loadCoupons({
    int page = 1,
    int perPage = 50,
    String? search,
    String? status,
    String? type,
    String? userEmail,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Carica i coupon
      final wooCoupons = await _couponService.couponManagementService.list(
        page: page,
        perPage: perPage,
        search: search,
        status: status,
        type: type,
      );

      // Filtra per email utente se specificato
      List<WooCoupon> filteredCoupons = wooCoupons;
      if (userEmail != null) {
        filteredCoupons = wooCoupons
            .where(
              (c) =>
                  c.emailRestrictions.isEmpty ||
                  c.emailRestrictions.contains(userEmail),
            )
            .toList();
      }

      // Converte in modelli di visualizzazione
      _coupons = filteredCoupons
          .map((c) => c.toCouponGlobal())
          .toList();

      // Carica le statistiche
      await loadStats();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Carica le statistiche dei coupon
  Future<void> loadStats() async {
    try {
      final wooStats = await _couponService.couponManagementService
          .getUsageStats();
      _stats = wooStats.toCouponStatsDisplay();
      notifyListeners();
    } catch (e) {
      log.d('Errore caricamento statistiche: $e');
    }
  }

  /// Crea un nuovo coupon
  Future<CouponGlobal> createCoupon({
    required String code,
    required String discountType,
    required String amount,
    String status = 'publish',
    String? description,
    DateTime? dateExpires,
    int? usageLimit,
    int? usageLimitPerUser,
    int? limitUsageToXItems,
    bool freeShipping = false,
    List<int>? productIds,
    List<int>? excludedProductIds,
    List<int>? productCategories,
    List<int>? excludedProductCategories,
    bool excludeSaleItems = false,
    String? minimumAmount,
    String? maximumAmount,
    List<String>? emailRestrictions,
  }) async {
    try {
      final createData = CreateCouponData(
        code: code,
        discountType: discountType,
        amount: amount,
        status: status,
        description: description,
        dateExpires: dateExpires,
        usageLimit: usageLimit,
        usageLimitPerUser: usageLimitPerUser,
        limitUsageToXItems: limitUsageToXItems,
        freeShipping: freeShipping,
        productIds: productIds,
        excludedProductIds: excludedProductIds,
        productCategories: productCategories,
        excludedProductCategories: excludedProductCategories,
        excludeSaleItems: excludeSaleItems,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        emailRestrictions: emailRestrictions,
      );

      final wooCoupon = await _couponService.couponManagementService.create(
        createData,
      );
      final couponDisplay = wooCoupon.toCouponGlobal();

      // Aggiorna la lista locale
      _coupons.insert(0, couponDisplay);
      notifyListeners();

      return couponDisplay;
    } catch (e) {
      rethrow;
    }
  }

  /// Aggiorna un coupon esistente
  Future<CouponGlobal> updateCoupon(
    int couponId, {
    String? code,
    String? discountType,
    String? amount,
    String? status,
    String? description,
    DateTime? dateExpires,
    int? usageLimit,
    int? usageLimitPerUser,
    int? limitUsageToXItems,
    bool? freeShipping,
    List<int>? productIds,
    List<int>? excludedProductIds,
    List<int>? productCategories,
    List<int>? excludedProductCategories,
    bool? excludeSaleItems,
    String? minimumAmount,
    String? maximumAmount,
    List<String>? emailRestrictions,
  }) async {
    try {
      final updateData = UpdateCouponData(
        code: code,
        discountType: discountType,
        amount: amount,
        status: status,
        description: description,
        dateExpires: dateExpires,
        usageLimit: usageLimit,
        usageLimitPerUser: usageLimitPerUser,
        limitUsageToXItems: limitUsageToXItems,
        freeShipping: freeShipping,
        productIds: productIds,
        excludedProductIds: excludedProductIds,
        productCategories: productCategories,
        excludedProductCategories: excludedProductCategories,
        excludeSaleItems: excludeSaleItems,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        emailRestrictions: emailRestrictions,
      );

      final wooCoupon = await _couponService.couponManagementService.update(
        couponId,
        updateData,
      );
      final couponDisplay = wooCoupon.toCouponGlobal();

      // Aggiorna la lista locale
      final index = _coupons.indexWhere((c) => c.id == couponId);
      if (index != -1) {
        _coupons[index] = couponDisplay;
        notifyListeners();
      }

      return couponDisplay;
    } catch (e) {
      rethrow;
    }
  }

  /// Elimina un coupon
  Future<void> deleteCoupon(int couponId, {bool force = false}) async {
    try {
      await _couponService.couponManagementService.delete(
        couponId,
        force: force,
      );

      // Rimuovi dalla lista locale
      _coupons.removeWhere((c) => c.id == couponId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Attiva/disattiva un coupon
  Future<void> toggleCouponStatus(CouponGlobal coupon) async {
    final newStatus = coupon.status == 'publish' ? 'draft' : 'publish';
    await updateCoupon(coupon.id, status: newStatus);
  }

  /// Duplica un coupon
  Future<CouponGlobal> duplicateCoupon(CouponGlobal coupon) async {
    return await createCoupon(
      code: '${coupon.code}_COPY',
      discountType: coupon.discountType,
      amount: coupon.amount,
      status: 'draft',
      description: coupon.description,
      dateExpires: coupon.dateExpires,
      usageLimit: coupon.usageLimit,
      usageLimitPerUser: coupon.usageLimitPerUser,
      freeShipping: coupon.freeShipping,
      excludeSaleItems: coupon.excludeSaleItems,
      minimumAmount: coupon.minimumAmount,
      maximumAmount: coupon.maximumAmount,
      emailRestrictions: coupon.emailRestrictions.isNotEmpty
          ? List.from(coupon.emailRestrictions)
          : null,
    );
  }

  /// Valida un coupon per un ordine
  Future<CouponValidationResult> validateCoupon({
    required String couponCode,
    required double orderTotal,
    List<int>? productIds,
    List<int>? categoryIds,
    String? customerEmail,
  }) async {
    try {
      final validation = await _couponService.couponManagementService
          .validateCoupon(
            couponCode: couponCode,
            orderTotal: orderTotal.toString(),
            productIds: productIds,
            categoryIds: categoryIds,
            customerEmail: customerEmail,
          );

      return CouponValidationResult(
        isValid: validation.isValid,
        errorMessage: validation.errorMessage,
        discountAmount: validation.discountAmount != null
            ? double.tryParse(validation.discountAmount!)
            : null,
        coupon: validation.coupon != null
            ? validation.coupon!.toCouponGlobal()
            : null,
      );
    } catch (e) {
      return CouponValidationResult(isValid: false, errorMessage: e.toString());
    }
  }

  /// Ottiene i coupon scaduti
  List<CouponGlobal> getExpiredCoupons() {
    return _coupons.where((c) => c.isExpired).toList();
  }

  /// Ottiene i coupon attivi
  List<CouponGlobal> getActiveCoupons() {
    return _coupons
        .where((c) => c.status == 'publish' && !c.isExpired)
        .toList();
  }

  /// Ottiene i coupon per un utente specifico
  List<CouponGlobal> getCouponsForUser(String email) {
    return _coupons
        .where(
          (c) =>
              c.emailRestrictions.isEmpty ||
              c.emailRestrictions.contains(email),
        )
        .toList();
  }

  /// Cerca coupon per codice
  List<CouponGlobal> searchByCode(String query) {
    if (query.isEmpty) return _coupons;
    return _coupons
        .where((c) => c.code.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Filtra coupon per tipo
  List<CouponGlobal> filterByType(String type) {
    return _coupons.where((c) => c.discountType == type).toList();
  }

  /// Filtra coupon per status
  List<CouponGlobal> filterByStatus(String status) {
    return _coupons.where((c) => c.status == status).toList();
  }

  /// Ottiene coupon con spedizione gratuita
  List<CouponGlobal> getFreeShippingCoupons() {
    return _coupons.where((c) => c.freeShipping).toList();
  }

  /// Ottiene coupon con limite di utilizzi
  List<CouponGlobal> getCouponsWithUsageLimit() {
    return _coupons.where((c) => c.usageLimit != null).toList();
  }

  /// Ottiene coupon quasi esauriti (>80% utilizzi)
  List<CouponGlobal> getAlmostExpiredByUsage() {
    return _coupons.where((c) {
      if (c.usageLimit == null || c.usageLimit == 0) return false;
      final usagePercent = (c.usageCount / c.usageLimit!) * 100;
      return usagePercent >= 80;
    }).toList();
  }

  /// Calcola lo sconto per un importo specifico
  double calculateDiscount(CouponGlobal coupon, double amount) {
    switch (coupon.discountType) {
      case 'percent':
        final percent = double.tryParse(coupon.amount) ?? 0.0;
        return (amount * percent) / 100;
      case 'fixed_cart':
      case 'fixed_product':
        return double.tryParse(coupon.amount) ?? 0.0;
      default:
        return 0.0;
    }
  }

  /// Ottiene il miglior coupon per un determinato importo
  CouponGlobal? getBestCouponForAmount(double amount, {String? userEmail}) {
    var availableCoupons = getActiveCoupons();

    // Filtra per utente se specificato
    if (userEmail != null) {
      availableCoupons = availableCoupons
          .where(
            (c) =>
                c.emailRestrictions.isEmpty ||
                c.emailRestrictions.contains(userEmail),
          )
          .toList();
    }

    // Filtra per importo minimo/massimo
    availableCoupons = availableCoupons.where((c) {
      if (c.minimumAmount != null) {
        final min = double.tryParse(c.minimumAmount!) ?? 0.0;
        if (amount < min) return false;
      }
      if (c.maximumAmount != null) {
        final max = double.tryParse(c.maximumAmount!) ?? double.infinity;
        if (amount > max) return false;
      }
      return true;
    }).toList();

    if (availableCoupons.isEmpty) return null;

    // Ordina per sconto decrescente
    availableCoupons.sort((a, b) {
      final discountA = calculateDiscount(a, amount);
      final discountB = calculateDiscount(b, amount);
      return discountB.compareTo(discountA);
    });

    return availableCoupons.first;
  }

  @override
  void dispose() {
    // Cleanup se necessario
    super.dispose();
  }
}

/// Risultato della validazione di un coupon
class CouponValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double? discountAmount;
  final CouponGlobal? coupon;

  CouponValidationResult({
    required this.isValid,
    this.errorMessage,
    this.discountAmount,
    this.coupon,
  });

  String get discountAmountFormatted {
    if (discountAmount == null) return '€0.00';
    return '€${discountAmount!.toStringAsFixed(2)}';
  }
}
