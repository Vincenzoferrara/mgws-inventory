import '../l10n/extensions.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview_filters.dart';

/// Coupon del negozio, indipendente dalla piattaforma: la conversione dal
/// formato WooCommerce sta nelle query (`coupon_query.dart`,
/// `woo_query_coupon.dart`).
class CouponGlobal {
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

  CouponGlobal({
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

  /// Stato mostrato nella lista: `scaduto` per un coupon pubblicato ma
  /// oltre la scadenza, altrimenti lo stato del sito (`publish`, `draft`,
  /// `pending`, `trash`).
  String get statoLista => status == 'publish' && isExpired ? 'scaduto' : status;

  double get importo => double.tryParse(amount.replaceAll(',', '.')) ?? 0;

  /// Campi del coupon per la lista Coupon. Ricerca libera, codice esatto e
  /// ordinamento per codice o data li fa il server; gli altri filtri
  /// lavorano sull'elenco completo.
  static final List<DataGridField<CouponGlobal>> gridFields =
      <DataGridField<CouponGlobal>>[
        DataGridField<CouponGlobal>(
          name: 'codice',
          label: (l10n) => l10n.couponsFieldCode,
          aliases: const <String>['codice', 'code', 'coupon'],
          read: (c) => <Object?>[c.code],
          serverParam: 'code',
          serverOperators: const <DataGridFilterOperator>{
            DataGridFilterOperator.ugualeEsatto,
          },
          sortable: true,
          serverSortParam: 'title',
          width: 180,
          flexible: true,
        ),
        DataGridField<CouponGlobal>(
          name: 'tipo',
          label: (l10n) => l10n.couponsFieldType,
          aliases: const <String>['tipo', 'type', 'sconto'],
          type: DataGridFieldType.elenco,
          read: (c) => <Object?>[c.discountType],
          options: [
            for (final tipo in DiscountType.values)
              DataGridFieldOption(
                tipo.value,
                (l10n) => couponDiscountTypeLabel(l10n, tipo),
              ),
          ],
          width: 150,
        ),
        DataGridField<CouponGlobal>(
          name: 'importo',
          label: (l10n) => l10n.couponsFieldAmount,
          aliases: const <String>['importo', 'amount', 'valore'],
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.importo],
          format: (l10n, c) => c.discountDisplay,
          sortable: true,
          width: 110,
          numeric: true,
        ),
        DataGridField<CouponGlobal>(
          name: 'scadenza',
          label: (l10n) => l10n.couponsFieldExpiry,
          aliases: const <String>['scadenza', 'scade', 'expiry'],
          type: DataGridFieldType.data,
          read: (c) => <Object?>[c.dateExpires],
          format: (l10n, c) => c.expiryDisplay(l10n),
          sortable: true,
          searchable: false,
          width: 150,
        ),
        DataGridField<CouponGlobal>(
          name: 'utilizzi',
          label: (l10n) => l10n.couponsFieldUsage,
          aliases: const <String>['utilizzi', 'usi', 'usage'],
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.usageCount],
          format: (l10n, c) => c.usageLimit == null
              ? '${c.usageCount}'
              : '${c.usageCount}/${c.usageLimit}',
          sortable: true,
          searchable: false,
          width: 100,
          numeric: true,
        ),
        DataGridField<CouponGlobal>(
          name: 'stato',
          label: (l10n) => l10n.couponsFieldStatus,
          aliases: const <String>['stato', 'status'],
          type: DataGridFieldType.elenco,
          read: (c) => <Object?>[c.statoLista],
          options: [
            DataGridFieldOption('publish', (l10n) => l10n.couponsStatusAttivo),
            DataGridFieldOption('scaduto', (l10n) => l10n.couponsStatusScaduto),
            DataGridFieldOption('draft', (l10n) => l10n.couponsStatusBozza),
            DataGridFieldOption('trash', (l10n) => l10n.couponsStatusCestino),
          ],
          width: 120,
        ),
      ];

  /// Verifica se il coupon è scaduto
  bool get isExpired {
    if (dateExpires == null) return false;
    return DateTime.now().isAfter(dateExpires!);
  }

  /// Verifica se il coupon è attivo
  bool get isActive {
    return status == 'publish' && !isExpired;
  }

  /// Verifica se il coupon ha raggiunto il limite di utilizzi
  bool get hasReachedUsageLimit {
    if (usageLimit == null) return false;
    return usageCount >= usageLimit!;
  }

  /// Calcola la percentuale di utilizzo
  double get usagePercentage {
    if (usageLimit == null || usageLimit == 0) return 0.0;
    return (usageCount / usageLimit!) * 100;
  }

  /// Ottiene il display formattato dello sconto
  String get discountDisplay {
    switch (discountType) {
      case 'percent':
        return '$amount%';
      case 'fixed_cart':
      case 'fixed_product':
        return '€$amount';
      default:
        return amount;
    }
  }

  /// Ottiene il display formattato della data di scadenza
  String expiryDisplay(AppLocalizations l10n) {
    if (dateExpires == null) return l10n.couponsNessunaScadenza;
    if (isExpired) return l10n.couponsScadutoIl(_formatDate(dateExpires!));
    return _formatDate(dateExpires!);
  }

  /// Ottiene il display formattato del tipo di sconto
  String discountTypeDisplay(AppLocalizations l10n) =>
      couponDiscountTypeLabel(l10n, DiscountType.fromValue(discountType));

  /// Ottiene il display formattato dello status
  String statusDisplay(AppLocalizations l10n) {
    switch (status) {
      case 'publish':
        return isExpired ? l10n.couponsStatusScaduto : l10n.couponsStatusAttivo;
      case 'draft':
        return l10n.couponsStatusBozza;
      case 'trash':
        return l10n.couponsStatusCestino;
      default:
        return status;
    }
  }

  /// Ottiene un sommario del coupon
  String summary(AppLocalizations l10n) {
    final parts = <String>[
      discountDisplay,
      if (freeShipping) l10n.couponsSpedizioneGratis,
      if (minimumAmount != null) l10n.couponsMinImporto(minimumAmount!),
      if (usageLimit != null) l10n.couponsMaxUtilizzi('$usageLimit'),
    ];
    return parts.join(' • ');
  }

  /// Verifica se il coupon è riservato a utenti specifici
  bool get hasEmailRestrictions => emailRestrictions.isNotEmpty;

  /// Verifica se il coupon è applicabile a prodotti specifici
  bool get hasProductRestrictions =>
      productIds.isNotEmpty || excludedProductIds.isNotEmpty;

  /// Verifica se il coupon è applicabile a categorie specifiche
  bool get hasCategoryRestrictions =>
      productCategories.isNotEmpty || excludedProductCategories.isNotEmpty;

  /// Verifica se il coupon ha restrizioni
  bool get hasRestrictions =>
      hasEmailRestrictions ||
      hasProductRestrictions ||
      hasCategoryRestrictions ||
      minimumAmount != null ||
      maximumAmount != null;

  /// Ottiene un elenco delle restrizioni
  List<String> restrictionsList(AppLocalizations l10n) {
    final restrictions = <String>[];

    if (minimumAmount != null) {
      restrictions.add(l10n.couponsRestrizioneImportoMinimo(minimumAmount!));
    }
    if (maximumAmount != null) {
      restrictions.add(l10n.couponsRestrizioneImportoMassimo(maximumAmount!));
    }
    if (usageLimit != null) {
      restrictions.add(
        l10n.couponsRestrizioneLimiteUtilizzi('$usageLimit', '$usageCount'),
      );
    }
    if (usageLimitPerUser != null) {
      restrictions.add(
        l10n.couponsRestrizioneLimitePerUtente('$usageLimitPerUser'),
      );
    }
    if (emailRestrictions.isNotEmpty) {
      restrictions.add(
        l10n.couponsEmailEtichetta(emailRestrictions.join(", ")),
      );
    }
    if (productIds.isNotEmpty) {
      restrictions.add(
        l10n.couponsRestrizioneProdottiSpecifici('${productIds.length}'),
      );
    }
    if (excludedProductIds.isNotEmpty) {
      restrictions.add(
        l10n.couponsRestrizioneProdottiEsclusi('${excludedProductIds.length}'),
      );
    }
    if (productCategories.isNotEmpty) {
      restrictions.add(
        l10n.couponsRestrizioneCategorieSpecifiche(
          '${productCategories.length}',
        ),
      );
    }
    if (excludedProductCategories.isNotEmpty) {
      restrictions.add(
        l10n.couponsRestrizioneCategorieEscluse(
          '${excludedProductCategories.length}',
        ),
      );
    }
    if (excludeSaleItems) {
      restrictions.add(l10n.couponsRestrizioneEsclusiSaldo);
    }
    if (individualUse) {
      restrictions.add(l10n.couponsRestrizioneUsoIndividuale);
    }
    if (freeShipping) {
      restrictions.add(l10n.couponsRestrizioneSpedizioneGratuita);
    }

    return restrictions;
  }

  /// Formatta una data
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Crea una copia del coupon con modifiche
  CouponGlobal copyWith({
    String? code,
    String? amount,
    String? status,
    String? discountType,
    String? description,
    DateTime? dateExpires,
    int? usageCount,
    bool? individualUse,
    List<int>? productIds,
    List<int>? excludedProductIds,
    int? usageLimit,
    int? usageLimitPerUser,
    int? limitUsageToXItems,
    bool? freeShipping,
    List<int>? productCategories,
    List<int>? excludedProductCategories,
    bool? excludeSaleItems,
    String? minimumAmount,
    String? maximumAmount,
    List<String>? emailRestrictions,
  }) {
    return CouponGlobal(
      id: id,
      code: code ?? this.code,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      discountType: discountType ?? this.discountType,
      description: description ?? this.description,
      dateExpires: dateExpires ?? this.dateExpires,
      dateCreated: dateCreated,
      dateModified: DateTime.now(),
      usageCount: usageCount ?? this.usageCount,
      individualUse: individualUse ?? this.individualUse,
      productIds: productIds ?? this.productIds,
      excludedProductIds: excludedProductIds ?? this.excludedProductIds,
      usageLimit: usageLimit ?? this.usageLimit,
      usageLimitPerUser: usageLimitPerUser ?? this.usageLimitPerUser,
      limitUsageToXItems: limitUsageToXItems ?? this.limitUsageToXItems,
      freeShipping: freeShipping ?? this.freeShipping,
      productCategories: productCategories ?? this.productCategories,
      excludedProductCategories:
          excludedProductCategories ?? this.excludedProductCategories,
      excludeSaleItems: excludeSaleItems ?? this.excludeSaleItems,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumAmount: maximumAmount ?? this.maximumAmount,
      emailRestrictions: emailRestrictions ?? this.emailRestrictions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CouponGlobal &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CouponGlobal(id: $id, code: $code, discount: $discountDisplay, status: $status)';
}

/// Modello di visualizzazione per le statistiche dei coupon
class CouponStatsDisplay {
  final int totalCoupons;
  final int activeCoupons;
  final int totalUsage;
  final String totalDiscount;
  final String period;

  CouponStatsDisplay({
    required this.totalCoupons,
    required this.activeCoupons,
    required this.totalUsage,
    required this.totalDiscount,
    required this.period,
  });

  /// Calcola la percentuale di coupon attivi
  double get activePercentage {
    if (totalCoupons == 0) return 0.0;
    return (activeCoupons / totalCoupons) * 100;
  }

  /// Calcola la media di utilizzi per coupon
  double get averageUsagePerCoupon {
    if (activeCoupons == 0) return 0.0;
    return totalUsage / activeCoupons;
  }

  /// Ottiene il display formattato dello sconto totale
  String get totalDiscountFormatted => '€$totalDiscount';

  /// Ottiene il display formattato del periodo
  String periodDisplay(AppLocalizations l10n) {
    switch (period) {
      case 'month':
        return l10n.couponsPeriodoMese;
      case 'year':
        return l10n.couponsPeriodoAnno;
      case 'all':
        return l10n.couponsPeriodoTutto;
      default:
        return period;
    }
  }

  @override
  String toString() =>
      'CouponStatsDisplay(total: $totalCoupons, active: $activeCoupons, usage: $totalUsage, discount: $totalDiscountFormatted)';
}

/// Enum per i tipi di sconto
///
/// I valori sono gli identificatori che WooCommerce si aspetta nel payload e non
/// si toccano mai: la label mostrata all'utente sta in
/// [couponDiscountTypeLabel], che riceve le traduzioni del contesto.
enum DiscountType {
  percent('percent', '%'),
  fixedCart('fixed_cart', '€'),
  fixedProduct('fixed_product', '€');

  final String value;
  final String symbol;

  const DiscountType(this.value, this.symbol);

  static DiscountType fromValue(String value) {
    return DiscountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => DiscountType.percent,
    );
  }
}

/// Nome del tipo di sconto, mostrato nei badge e nei dropdown.
///
/// Non piu' un campo costante dentro l'enum: le stringhe sono localizzate, quindi
/// servono le traduzioni del contesto per restituirle.
String couponDiscountTypeLabel(AppLocalizations l10n, DiscountType type) =>
    switch (type) {
      DiscountType.percent => l10n.couponsTipoPercentuale,
      DiscountType.fixedCart => l10n.couponsTipoFissoCarrello,
      DiscountType.fixedProduct => l10n.couponsTipoFissoProdotto,
    };

/// Enum per gli status dei coupon
///
/// Come [DiscountType], `value` e' l'identificatore del protocollo e la label
/// vive in [couponStatusLabel].
enum CouponStatus {
  publish('publish'),
  draft('draft'),
  trash('trash');

  final String value;

  const CouponStatus(this.value);

  static CouponStatus fromValue(String value) {
    return CouponStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CouponStatus.draft,
    );
  }
}

/// Nome dello stato del coupon, mostrato nei dropdown e nei badge.
String couponStatusLabel(AppLocalizations l10n, CouponStatus status) =>
    switch (status) {
      CouponStatus.publish => l10n.couponsStatusPubblicato,
      CouponStatus.draft => l10n.couponsStatusBozza,
      CouponStatus.trash => l10n.couponsStatusCestino,
    };

/// Helper per formattare i valori dei coupon
class CouponFormatter {
  /// Formatta un importo in euro
  static String formatAmount(String amount) {
    final value = double.tryParse(amount) ?? 0.0;
    return '€${value.toStringAsFixed(2)}';
  }

  /// Formatta una percentuale
  static String formatPercentage(String amount) {
    return '$amount%';
  }

  /// Formatta lo sconto in base al tipo
  static String formatDiscount(String amount, String discountType) {
    switch (discountType) {
      case 'percent':
        return formatPercentage(amount);
      case 'fixed_cart':
      case 'fixed_product':
        return formatAmount(amount);
      default:
        return amount;
    }
  }

  /// Formatta una data
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Formatta una data con ora
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Calcola i giorni rimanenti fino alla scadenza
  static int daysUntilExpiry(DateTime expiryDate) {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  /// Ottiene un messaggio per i giorni rimanenti
  static String expiryMessage(AppLocalizations l10n, DateTime? expiryDate) {
    if (expiryDate == null) return l10n.couponsNessunaScadenza;

    final days = daysUntilExpiry(expiryDate);

    if (days < 0) return l10n.couponsScadutoGiorniFa('${-days}');
    if (days == 0) return l10n.couponsScadeOggi;
    if (days == 1) return l10n.couponsScadeDomani;
    if (days < 7) return l10n.couponsScadeTraGiorni('$days');
    if (days < 30)
      return l10n.couponsScadeTraSettimane('${(days / 7).floor()}');
    return l10n.couponsScadeTraMesi('${(days / 30).floor()}');
  }
}

/// Helper per validare i dati dei coupon
///
/// Ogni validatore riceve `AppLocalizations` perche' i suoi messaggi sono
/// mostrati sotto ai campi del form.
class CouponValidator {
  /// Valida il codice coupon
  static String? validateCode(AppLocalizations l10n, String? code) {
    if (code == null || code.isEmpty) {
      return l10n.couponsErroreCodiceObbligatorio;
    }
    if (code.length < 3) {
      return l10n.couponsErroreCodiceTroppoCorto;
    }
    if (code.length > 50) {
      return l10n.couponsErroreCodiceTroppoLungo;
    }
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(code)) {
      return l10n.couponsErroreCodiceCaratteri;
    }
    return null;
  }

  /// Valida l'importo dello sconto
  ///
  /// `discountType` resta l'identificatore grezzo del protocollo: e' solo
  /// confrontato con `percent`, non mostrato.
  static String? validateAmount(
    AppLocalizations l10n,
    String? amount,
    String discountType,
  ) {
    if (amount == null || amount.isEmpty) {
      return l10n.couponsErroreImportoObbligatorio;
    }

    final value = double.tryParse(amount);
    if (value == null) {
      return l10n.couponsErroreImportoNonValido;
    }

    if (value <= 0) {
      return l10n.couponsErroreImportoNonPositivo;
    }

    if (discountType == 'percent' && value > 100) {
      return l10n.couponsErrorePercentualeTroppoAlta;
    }

    return null;
  }

  /// Valida l'importo minimo
  static String? validateMinimumAmount(
    AppLocalizations l10n,
    String? minimum,
    String? maximum,
  ) {
    if (minimum == null || minimum.isEmpty) return null;

    final minValue = double.tryParse(minimum);
    if (minValue == null) {
      return l10n.couponsErroreMinimoNonValido;
    }

    if (minValue < 0) {
      return l10n.couponsErroreMinimoNegativo;
    }

    if (maximum != null && maximum.isNotEmpty) {
      final maxValue = double.tryParse(maximum);
      if (maxValue != null && minValue > maxValue) {
        return l10n.couponsErroreMinimoMaggioreMassimo;
      }
    }

    return null;
  }

  /// Valida l'importo massimo
  static String? validateMaximumAmount(
    AppLocalizations l10n,
    String? maximum,
    String? minimum,
  ) {
    if (maximum == null || maximum.isEmpty) return null;

    final maxValue = double.tryParse(maximum);
    if (maxValue == null) {
      return l10n.couponsErroreMassimoNonValido;
    }

    if (maxValue < 0) {
      return l10n.couponsErroreMassimoNegativo;
    }

    if (minimum != null && minimum.isNotEmpty) {
      final minValue = double.tryParse(minimum);
      if (minValue != null && maxValue < minValue) {
        return l10n.couponsErroreMassimoMinoreMinimo;
      }
    }

    return null;
  }

  /// Valida il limite di utilizzi
  static String? validateUsageLimit(AppLocalizations l10n, String? limit) {
    if (limit == null || limit.isEmpty) return null;

    final value = int.tryParse(limit);
    if (value == null) {
      return l10n.couponsErroreLimiteNonValido;
    }

    if (value < 1) {
      return l10n.couponsErroreLimiteTroppoBasso;
    }

    return null;
  }

  /// Valida la data di scadenza
  static String? validateExpiryDate(AppLocalizations l10n, DateTime? date) {
    if (date == null) return null;

    if (date.isBefore(DateTime.now())) {
      return l10n.couponsErroreScadenzaPassata;
    }

    return null;
  }

  /// Valida un indirizzo email
  static String? validateEmail(AppLocalizations l10n, String? email) {
    if (email == null || email.isEmpty) return null;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return l10n.couponsErroreEmailNonValida;
    }

    return null;
  }
}
