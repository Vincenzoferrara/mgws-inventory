import '../../../l10n/known_messages.dart';
import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';
import '../woo_connect.dart';
import '../../../coupons/class_coupon.dart';
import '../../../log_viewer/app_logger.dart';
import '../../../reuse_class/logic/global_pagination_controller.dart';

/// Query class per la gestione dei coupon/codici sconto WooCommerce
/// Utilizza WooConnect per l'autenticazione centralizzata
class WooQueryCoupon {
  // Singleton pattern
  static final WooQueryCoupon _instance = WooQueryCoupon._internal();
  factory WooQueryCoupon() => _instance;
  WooQueryCoupon._internal();

  final WooConnect _wooConnect = WooConnect();

  /// Ottiene l'istanza WooCommerce autenticata da WooConnect
  WooCommerce get _woo => _wooConnect.woo;

  /// Ottiene lista coupon con paginazione e filtri
  Future<WooPage<WooCoupon>> getCoupons({
    int page = 1,
    int perPage = 20,
    String? search,
    String? code,
  }) async {
    final woo = _woo;

    return await woo.getCoupons(
      page: page,
      perPage: perPage,
      search: search,
      code: code,
    );
  }

  /// Pagina di coupon come [CouponGlobal], con il totale letto da
  /// `X-WP-Total`.
  ///
  /// Legge il JSON invece del modello del pacchetto, che non espone lo stato
  /// del coupon (pubblicato, bozza, cestino). [orderBy] e' un valore di
  /// `orderby` di WooCommerce (`date`, `title`, `id`).
  Future<PaginatedResult<CouponGlobal>> getCouponPaginati({
    int page = 1,
    int perPage = 20,
    String? search,
    String? code,
    String orderBy = 'date',
    bool ascending = false,
  }) async {
    final response = await _woo.dio.get(
      '/coupons',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        'orderby': orderBy,
        'order': ascending ? 'asc' : 'desc',
        if (search != null && search.isNotEmpty) 'search': search,
        if (code != null && code.isNotEmpty) 'code': code,
      },
    );
    final rows = response.data is List
        ? (response.data as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    return PaginatedResult<CouponGlobal>(
      items: rows.map(couponGlobalFromJson).toList(),
      page: page,
      perPage: perPage,
      totalItems: int.tryParse(response.headers.value('x-wp-total') ?? ''),
      totalPages: int.tryParse(
        response.headers.value('x-wp-totalpages') ?? '',
      ),
    );
  }

  /// Converte il JSON di un coupon WooCommerce nel modello dell'app.
  CouponGlobal couponGlobalFromJson(Map<String, dynamic> json) {
    List<int> ids(String key) =>
        (json[key] as List? ?? const []).whereType<num>().map((n) => n.toInt()).toList();
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.tryParse(json[key].toString());
    int? intOrNull(String key) => (json[key] as num?)?.toInt();
    String? amountOrNull(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    return CouponGlobal(
      id: intOrNull('id') ?? 0,
      code: json['code']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'publish',
      discountType: json['discount_type']?.toString() ?? 'fixed_cart',
      description: json['description']?.toString() ?? '',
      dateExpires: date('date_expires'),
      dateCreated: date('date_created') ?? DateTime.now(),
      dateModified: date('date_modified') ?? DateTime.now(),
      usageCount: intOrNull('usage_count') ?? 0,
      individualUse: json['individual_use'] == true,
      productIds: ids('product_ids'),
      excludedProductIds: ids('excluded_product_ids'),
      usageLimit: intOrNull('usage_limit'),
      usageLimitPerUser: intOrNull('usage_limit_per_user'),
      limitUsageToXItems: intOrNull('limit_usage_to_x_items'),
      freeShipping: json['free_shipping'] == true,
      productCategories: ids('product_categories'),
      excludedProductCategories: ids('excluded_product_categories'),
      excludeSaleItems: json['exclude_sale_items'] == true,
      minimumAmount: amountOrNull('minimum_amount'),
      maximumAmount: amountOrNull('maximum_amount'),
      emailRestrictions: (json['email_restrictions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Ottiene un coupon specifico per ID
  Future<WooCoupon> getCouponById(int couponId) async {
    final woo = _woo;
    return await woo.getCoupon(couponId);
  }

  /// Ottiene coupon per codice
  Future<WooCoupon> getCouponByCode(String code) async {
    final woo = _woo;
    final coupons = await woo.getCoupons(code: code, perPage: 1);

    if (coupons.items.isEmpty) {
      throw Exception(AppMessages.couponNotFound);
    }

    return coupons.items.first;
  }

  /// Crea un nuovo coupon
  Future<WooCoupon> createCoupon({
    required String code,
    String? discountType,
    String? amount,
    bool? individualUse,
    bool? excludeSaleItems,
    String? minimumAmount,
    String? maximumAmount,
    List<int>? productIds,
    List<int>? excludedProductIds,
    int? usageLimit,
    int? usageLimitPerUser,
    int? limitUsageToXItems,
    DateTime? dateExpires,
    List<WooMetaData>? metaData,
  }) async {
    final woo = _woo;

    final coupon = WooCoupon(
      code: code,
      discountType: _discountTypeFrom(discountType),
      amount: double.tryParse(amount ?? ""),
      individualUse: individualUse,
      excludeSaleItems: excludeSaleItems,
      minimumAmount: double.tryParse(minimumAmount ?? ""),
      maximumAmount: double.tryParse(maximumAmount ?? ""),
      productIds: productIds,
      excludedProductIds: excludedProductIds,
      usageLimit: usageLimit,
      usageLimitPerUser: usageLimitPerUser,
      limitUsageToXItems: limitUsageToXItems,
      dateExpires: dateExpires,
      metaData: metaData,
    );

    return await woo.createCoupon(coupon);
  }

  /// Tipo di sconto della libreria dal nome WooCommerce (percent, fixed_cart,
  /// fixed_product); un nome sconosciuto diventa percent.
  static WooCouponDiscountType? _discountTypeFrom(String? discountType) {
    if (discountType == null) return null;
    return WooCouponDiscountType.values.firstWhere(
      (t) => t.value == discountType,
      orElse: () => WooCouponDiscountType.percent,
    );
  }

  /// Aggiorna un coupon esistente
  Future<WooCoupon> updateCoupon({
    required int couponId,
    String? code,
    String? discountType,
    String? amount,
    bool? individualUse,
    bool? excludeSaleItems,
    String? minimumAmount,
    String? maximumAmount,
    List<int>? productIds,
    List<int>? excludedProductIds,
    int? usageLimit,
    int? usageLimitPerUser,
    DateTime? dateExpires,
    List<WooMetaData>? metaData,
  }) async {
    final woo = _woo;

    // Prima ottieni il coupon esistente
    final existingCoupon = await woo.getCoupon(couponId);

    // Crea un nuovo coupon con i campi aggiornati
    final updatedCoupon = WooCoupon(
      id: couponId,
      code: code ?? existingCoupon.code,
      discountType:
          _discountTypeFrom(discountType) ?? existingCoupon.discountType,
      amount: amount as double? ?? existingCoupon.amount,
      individualUse: individualUse ?? existingCoupon.individualUse,
      excludeSaleItems: excludeSaleItems ?? existingCoupon.excludeSaleItems,
      minimumAmount: minimumAmount as double? ?? existingCoupon.minimumAmount,
      maximumAmount: maximumAmount as double? ?? existingCoupon.maximumAmount,
      productIds: productIds ?? existingCoupon.productIds,
      excludedProductIds:
          excludedProductIds ?? existingCoupon.excludedProductIds,
      usageLimit: usageLimit ?? existingCoupon.usageLimit,
      usageLimitPerUser: usageLimitPerUser ?? existingCoupon.usageLimitPerUser,
      dateExpires: dateExpires ?? existingCoupon.dateExpires,
      metaData: metaData ?? existingCoupon.metaData,
    );

    return await woo.updateCoupon(updatedCoupon.id!, updatedCoupon);
  }

  /// Elimina un coupon
  Future<bool> deleteCoupon({required int couponId, bool force = false}) async {
    final woo = _woo;
    final r = await woo.deleteCoupon(couponId, force: force);
    return r.deleted;
  }

  /// Ottiene tutti i coupon (uso con cautela!)
  Future<List<WooCoupon>> getAllCoupons() async {
    final woo = _woo;
    final List<WooCoupon> allCoupons = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      final couponsPage = await woo.getCoupons(page: currentPage, perPage: 100);

      if (couponsPage.items.isEmpty) {
        hasMore = false;
      } else {
        allCoupons.addAll(couponsPage.items);
        currentPage++;
      }
    }

    return allCoupons;
  }

  /// Batch update coupon (usa Dio diretto)
  Future<Map<String, dynamic>> batchUpdateCoupons({
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<int>? delete,
  }) async {
    final batchData = {
      if (create != null && create.isNotEmpty) 'create': create,
      if (update != null && update.isNotEmpty) 'update': update,
      if (delete != null && delete.isNotEmpty) 'delete': delete,
    };

    final response = await _woo.dio.post('/coupons/batch', data: batchData);

    return response.data as Map<String, dynamic>;
  }

  /// Verifica validità coupon
  Future<Map<String, dynamic>> validateCoupon(
    String code, {
    List<int>? productIds,
    double? cartTotal,
  }) async {
    try {
      final coupon = await getCouponByCode(code);

      // Controlla se il coupon è valido
      final now = DateTime.now();
      final dateExpires = coupon.dateExpires;

      final isExpired = dateExpires != null && dateExpires.isBefore(now);
      final usageLimit = coupon.usageLimit;
      final usageCount = coupon.usageCount ?? 0;
      final isLimitReached = usageLimit != null && usageCount >= usageLimit;

      final minimumAmount = coupon.minimumAmount != null
          ? coupon.minimumAmount
          : null;
      final meetsMinimum =
          minimumAmount == null ||
          (cartTotal != null && cartTotal >= minimumAmount);

      return {
        'valid': !isExpired && !isLimitReached && meetsMinimum,
        'coupon': coupon,
        'expired': isExpired,
        'limit_reached': isLimitReached,
        'meets_minimum': meetsMinimum,
        'discount_type': coupon.discountType,
        'amount': coupon.amount,
      };
    } catch (e) {
      throw Exception('Coupon validation failed: $e');
    }
  }

  /// Ottiene statistiche utilizzo coupon
  Future<Map<String, dynamic>> getCouponStats(int couponId) async {
    final coupon = await getCouponById(couponId);

    return {
      'coupon_id': couponId,
      'code': coupon.code,
      'usage_count': coupon.usageCount ?? 0,
      'usage_limit': coupon.usageLimit,
      'usage_limit_per_user': coupon.usageLimitPerUser,
      'discount_type': coupon.discountType,
      'amount': coupon.amount,
      'date_expires': coupon.dateExpires,
      'minimum_amount': coupon.minimumAmount,
      'maximum_amount': coupon.maximumAmount,
    };
  }

  /// Verifica se codice coupon esiste già
  Future<bool> couponCodeExists(String code) async {
    try {
      await getCouponByCode(code);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ottiene coupon attivi (non scaduti)
  Future<List<WooCoupon>> getActiveCoupons({
    int page = 1,
    int perPage = 100,
  }) async {
    final allCouponsPage = await getCoupons(page: page, perPage: perPage);
    final allCoupons = allCouponsPage.items;
    final now = DateTime.now();

    return allCoupons.where((coupon) {
      if (coupon.dateExpires == null) return true;
      return coupon.dateExpires!.isAfter(now);
    }).toList();
  }

  /// Ottiene coupon scaduti
  Future<List<WooCoupon>> getExpiredCoupons() async {
    final allCoupons = await getAllCoupons();
    final now = DateTime.now();

    return allCoupons.where((coupon) {
      if (coupon.dateExpires == null) return false;
      return coupon.dateExpires!.isBefore(now);
    }).toList();
  }

  /// Ottiene coupon con limite di utilizzo raggiunto
  Future<List<WooCoupon>> getFullyUsedCoupons() async {
    final allCoupons = await getAllCoupons();

    return allCoupons.where((coupon) {
      if (coupon.usageLimit == null) return false;
      return (coupon.usageCount ?? 0) >= coupon.usageLimit!;
    }).toList();
  }

  /// Cerca coupon per codice parziale
  Future<WooPage<WooCoupon>> searchCoupons(String searchTerm) async {
    final woo = _woo;
    return await woo.getCoupons(search: searchTerm, perPage: 50);
  }

  /// Statistiche dei coupon su tutto il negozio, non sulla pagina visibile.
  ///
  /// Il totale viene da `X-WP-Total`. Attivi, scaduti e utilizzi richiedono
  /// la data di scadenza e il contatore di ogni coupon, che il server non
  /// sa contare: si scorrono tutte le pagine (100 coupon per richiesta). Lo
  /// sconto totale viene dalle statistiche del negozio (`wc-analytics`).
  Future<Map<String, dynamic>> getAllCouponsStats() async {
    var total = 0;
    var active = 0;
    var expired = 0;
    var usage = 0;
    final now = DateTime.now();
    for (var page = 1; page <= 100; page++) {
      final result = await getCouponPaginati(page: page, perPage: 100);
      total = result.totalItems ?? total;
      for (final coupon in result.items) {
        usage += coupon.usageCount;
        final scaduto =
            coupon.dateExpires != null && coupon.dateExpires!.isBefore(now);
        if (scaduto) {
          expired++;
        } else if (coupon.status == 'publish') {
          active++;
        }
      }
      if (page >= (result.totalPages ?? 1)) break;
    }

    var discount = 0.0;
    try {
      final siteUrl = _woo.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await _woo.dio.get(
        '$siteUrl/wp-json/wc-analytics/reports/coupons/stats',
        queryParameters: {
          'interval': 'year',
          'after': '2000-01-01T00:00:00',
          'before': now.add(const Duration(days: 1)).toIso8601String(),
        },
      );
      final totals = (response.data as Map?)?['totals'] as Map?;
      discount = (totals?['amount'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      log.w('Sconto totale coupon non disponibile: $e');
    }

    return {
      'total_coupons': total,
      'active_coupons': active,
      'expired_coupons': expired,
      'total_usage': usage,
      'total_discount': discount,
    };
  }
}
