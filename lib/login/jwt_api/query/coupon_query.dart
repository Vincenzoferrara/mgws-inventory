/*
 * coupons_query.dart
 *
 * Servizio per la gestione dei Coupon WooCommerce.
 * Usa WooQueryCoupon con la libreria woocommerce_flutter_api
 */

import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart'
    as woo_lib;
import '../query_woocommerce/woo_query_coupon.dart';

// =======================================================
// ==              SERVIZIO GESTIONE COUPON             ==
// =======================================================

/// Servizio per la gestione completa dei coupon WooCommerce.
/// Wrapper che usa WooQueryCoupon con la libreria woocommerce_flutter_api
class CouponManagementService {
  final WooQueryCoupon _wooQuery = WooQueryCoupon();

  /// Crea un nuovo coupon
  Future<WooCoupon> create(CreateCouponData data) async {
    final wooCoupon = await _wooQuery.createCoupon(
      code: data.code,
      discountType: data.discountType,
      amount: data.amount,
      individualUse: data.individualUse,
      excludeSaleItems: data.excludeSaleItems,
      minimumAmount: data.minimumAmount,
      maximumAmount: data.maximumAmount,
      productIds: data.productIds,
      excludedProductIds: data.excludedProductIds,
      usageLimit: data.usageLimit,
      usageLimitPerUser: data.usageLimitPerUser,
      limitUsageToXItems: data.limitUsageToXItems,
      dateExpires: data.dateExpires,
    );
    return _convertFromLibrary(wooCoupon);
  }

  /// Recupera un coupon tramite ID
  Future<WooCoupon> getById(int couponId) async {
    final wooCoupon = await _wooQuery.getCouponById(couponId);
    return _convertFromLibrary(wooCoupon);
  }

  /// Recupera un coupon tramite codice
  Future<WooCoupon> getByCode(String code) async {
    final wooCoupon = await _wooQuery.getCouponByCode(code);
    return _convertFromLibrary(wooCoupon);
  }

  /// Recupera una lista di coupon con filtri opzionali
  Future<List<WooCoupon>> list({
    int page = 1,
    int perPage = 10,
    String? search,
    String? status,
    String? type,
  }) async {
    final wooCoupons = await _wooQuery.getCoupons(
      page: page,
      perPage: perPage,
      search: search,
    );
    return wooCoupons.items.map(_convertFromLibrary).toList();
  }

  /// Aggiorna un coupon esistente
  Future<WooCoupon> update(int couponId, UpdateCouponData data) async {
    final wooCoupon = await _wooQuery.updateCoupon(
      couponId: couponId,
      code: data.code,
      discountType: data.discountType,
      amount: data.amount,
      individualUse: data.individualUse,
      excludeSaleItems: data.excludeSaleItems,
      minimumAmount: data.minimumAmount,
      maximumAmount: data.maximumAmount,
      productIds: data.productIds,
      excludedProductIds: data.excludedProductIds,
      usageLimit: data.usageLimit,
      usageLimitPerUser: data.usageLimitPerUser,
      dateExpires: data.dateExpires,
    );
    return _convertFromLibrary(wooCoupon);
  }

  /// Elimina un coupon
  Future<void> delete(int couponId, {bool force = false}) async {
    await _wooQuery.deleteCoupon(couponId: couponId, force: force);
  }

  /// Verifica la validità di un coupon
  Future<CouponValidation> validateCoupon({
    required String couponCode,
    required String orderTotal,
    List<int>? productIds,
    List<int>? categoryIds,
    String? customerEmail,
  }) async {
    try {
      final result = await _wooQuery.validateCoupon(
        couponCode,
        productIds: productIds,
        cartTotal: double.tryParse(orderTotal),
      );

      return CouponValidation(
        isValid: result['valid'] as bool,
        errorMessage: result['valid'] == false ? 'Coupon non valido' : null,
        coupon: result['coupon'] != null
            ? _convertFromLibrary(result['coupon'] as woo_lib.WooCoupon)
            : null,
        discountAmount: result['amount']?.toString(),
      );
    } catch (e) {
      return CouponValidation(isValid: false, errorMessage: e.toString());
    }
  }

  /// Recupera le statistiche di utilizzo dei coupon
  Future<CouponStats> getUsageStats({
    String period = 'month',
    String? startDate,
    String? endDate,
  }) async {
    final stats = await _wooQuery.getAllCouponsStats();

    return CouponStats(
      totalCoupons: stats['total_coupons'] ?? 0,
      activeCoupons: stats['active_coupons'] ?? 0,
      totalUsage: 0,
      totalDiscount: '0.00',
      period: period,
    );
  }

  /// Converte WooCoupon della libreria nel nostro modello
  WooCoupon _convertFromLibrary(woo_lib.WooCoupon libCoupon) {
    return WooCoupon(
      id: libCoupon.id ?? 0,
      code: libCoupon.code ?? '',
      amount: libCoupon.amount?.toString() ?? '0',
      status: 'publish', // La libreria non espone status, assumiamo publish
      discountType: libCoupon.discountType?.toString() ?? 'fixed_cart',
      description: libCoupon.description ?? '',
      dateExpires: libCoupon.dateExpires,
      dateCreated: libCoupon.dateCreated ?? DateTime.now(),
      dateModified: libCoupon.dateModified ?? DateTime.now(),
      usageCount: libCoupon.usageCount ?? 0,
      individualUse: libCoupon.individualUse ?? false,
      productIds: libCoupon.productIds ?? [],
      excludedProductIds: libCoupon.excludedProductIds ?? [],
      usageLimit: libCoupon.usageLimit,
      usageLimitPerUser: libCoupon.usageLimitPerUser,
      limitUsageToXItems: libCoupon.limitUsageToXItems,
      freeShipping: libCoupon.freeShipping ?? false,
      productCategories: libCoupon.productCategories!.map((e) => e).toList(),
      excludedProductCategories: libCoupon.excludedProductCategories ?? [],
      excludeSaleItems: libCoupon.excludeSaleItems ?? false,
      minimumAmount: libCoupon.minimumAmount?.toString(),
      maximumAmount: libCoupon.maximumAmount?.toString(),
      emailRestrictions: libCoupon.emailRestrictions ?? [],
    );
  }
}

// =======================================================
// ==                 MODELLI DI DATI                   ==
// =======================================================

/// Dati per creare un nuovo coupon
class CreateCouponData {
  final String code;
  final String discountType;
  final String amount;
  final String status;
  final String? description;
  final DateTime? dateExpires;
  final int? usageLimit;
  final int? usageLimitPerUser;
  final int? limitUsageToXItems;
  final bool freeShipping;
  final List<int>? productIds;
  final List<int>? excludedProductIds;
  final List<int>? productCategories;
  final List<int>? excludedProductCategories;
  final bool excludeSaleItems;
  final String? minimumAmount;
  final String? maximumAmount;
  final List<String>? emailRestrictions;
  final bool? individualUse;

  CreateCouponData({
    required this.code,
    required this.discountType,
    required this.amount,
    this.status = 'publish',
    this.description,
    this.dateExpires,
    this.usageLimit,
    this.usageLimitPerUser,
    this.limitUsageToXItems,
    this.freeShipping = false,
    this.productIds,
    this.excludedProductIds,
    this.productCategories,
    this.excludedProductCategories,
    this.excludeSaleItems = false,
    this.minimumAmount,
    this.maximumAmount,
    this.emailRestrictions,
    this.individualUse,
  });
}

/// Dati per aggiornare un coupon esistente
class UpdateCouponData {
  final String? code;
  final String? discountType;
  final String? amount;
  final String? status;
  final String? description;
  final DateTime? dateExpires;
  final int? usageLimit;
  final int? usageLimitPerUser;
  final int? limitUsageToXItems;
  final bool? freeShipping;
  final List<int>? productIds;
  final List<int>? excludedProductIds;
  final List<int>? productCategories;
  final List<int>? excludedProductCategories;
  final bool? excludeSaleItems;
  final String? minimumAmount;
  final String? maximumAmount;
  final List<String>? emailRestrictions;
  final bool? individualUse;

  UpdateCouponData({
    this.code,
    this.discountType,
    this.amount,
    this.status,
    this.description,
    this.dateExpires,
    this.usageLimit,
    this.usageLimitPerUser,
    this.limitUsageToXItems,
    this.freeShipping,
    this.productIds,
    this.excludedProductIds,
    this.productCategories,
    this.excludedProductCategories,
    this.excludeSaleItems,
    this.minimumAmount,
    this.maximumAmount,
    this.emailRestrictions,
    this.individualUse,
  });
}

/// Modello per un coupon WooCommerce (compatibile con l'interfaccia esistente)
class WooCoupon {
  final int id;
  final String code;
  final String amount;
  final String status;
  final String discountType;
  final String description;
  final DateTime? dateExpires;
  final DateTime dateCreated;
  final DateTime dateModified;
  final int usageCount;
  final bool individualUse;
  final List<int> productIds;
  final List<int> excludedProductIds;
  final int? usageLimit;
  final int? usageLimitPerUser;
  final int? limitUsageToXItems;
  final bool freeShipping;
  final List<int> productCategories;
  final List<int> excludedProductCategories;
  final bool excludeSaleItems;
  final String? minimumAmount;
  final String? maximumAmount;
  final List<String> emailRestrictions;

  WooCoupon({
    required this.id,
    required this.code,
    required this.amount,
    required this.status,
    required this.discountType,
    required this.description,
    this.dateExpires,
    required this.dateCreated,
    required this.dateModified,
    required this.usageCount,
    required this.individualUse,
    required this.productIds,
    required this.excludedProductIds,
    this.usageLimit,
    this.usageLimitPerUser,
    this.limitUsageToXItems,
    required this.freeShipping,
    required this.productCategories,
    required this.excludedProductCategories,
    required this.excludeSaleItems,
    this.minimumAmount,
    this.maximumAmount,
    required this.emailRestrictions,
  });
}

/// Modello per la validazione di un coupon
class CouponValidation {
  final bool isValid;
  final String? errorMessage;
  final WooCoupon? coupon;
  final String? discountAmount;

  CouponValidation({
    required this.isValid,
    this.errorMessage,
    this.coupon,
    this.discountAmount,
  });
}

/// Modello per le statistiche dei coupon
class CouponStats {
  final int totalCoupons;
  final int activeCoupons;
  final int totalUsage;
  final String totalDiscount;
  final String period;

  CouponStats({
    required this.totalCoupons,
    required this.activeCoupons,
    required this.totalUsage,
    required this.totalDiscount,
    required this.period,
  });
}

/// Servizio principale per aggregare tutti i servizi coupon
class CouponsService {
  late final CouponManagementService couponManagementService;

  CouponsService() {
    couponManagementService = CouponManagementService();
  }
}
