// Free report questions answered by the MGWS report engine.
//
// A question is a measure (what to count), an optional dimension (what to
// split by) and filters (which products, customers, registers...). The
// dashboard period applies to every question. MGWS aggregates POS receipts
// and online orders server-side and returns totals plus one row per group.

import 'package:dio/dio.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import 'dashboard.code.dart';

/// Where a measure comes from. Measures of different sources cannot be mixed.
enum ReportSource { sales, closings }

/// How a report value is formatted.
enum ReportValueFormat { currency, count, percent, decimal, days }

/// Business area of a measure, used to group the editor list.
enum ReportArea { sales, products, customers, cash }

/// A measure the report engine can compute.
class ReportMeasure {
  const ReportMeasure(this.key, this.source, this.format, this.area);

  final String key;
  final ReportSource source;
  final ReportValueFormat format;
  final ReportArea area;
}

/// Measures offered in the editor. Keys match the MGWS catalog.
const reportMeasures = <ReportMeasure>[
  ReportMeasure(
    'revenue',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'net_revenue',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'tax',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'documents',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.sales,
  ),
  ReportMeasure(
    'average_ticket',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'units_per_document',
    ReportSource.sales,
    ReportValueFormat.decimal,
    ReportArea.sales,
  ),
  ReportMeasure(
    'discount',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'discount_rate',
    ReportSource.sales,
    ReportValueFormat.percent,
    ReportArea.sales,
  ),
  ReportMeasure(
    'returns_value',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.sales,
  ),
  ReportMeasure(
    'returns_rate',
    ReportSource.sales,
    ReportValueFormat.percent,
    ReportArea.sales,
  ),
  ReportMeasure(
    'quantity',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.products,
  ),
  ReportMeasure(
    'quantity_sold',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.products,
  ),
  ReportMeasure(
    'quantity_returned',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.products,
  ),
  ReportMeasure(
    'average_unit_price',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.products,
  ),
  ReportMeasure(
    'distinct_products',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.products,
  ),
  ReportMeasure(
    'customers',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.customers,
  ),
  ReportMeasure(
    'new_customers',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.customers,
  ),
  ReportMeasure(
    'returning_customers',
    ReportSource.sales,
    ReportValueFormat.count,
    ReportArea.customers,
  ),
  ReportMeasure(
    'revenue_per_customer',
    ReportSource.sales,
    ReportValueFormat.currency,
    ReportArea.customers,
  ),
  ReportMeasure(
    'documents_per_customer',
    ReportSource.sales,
    ReportValueFormat.decimal,
    ReportArea.customers,
  ),
  ReportMeasure(
    'days_since_last_purchase',
    ReportSource.sales,
    ReportValueFormat.days,
    ReportArea.customers,
  ),
  ReportMeasure(
    'collected_total',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'cash_collected',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'card_collected',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'other_collected',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'refunds_paid',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'manual_in',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'manual_out',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'cash_expected',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'cash_counted',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'cash_difference',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'card_difference',
    ReportSource.closings,
    ReportValueFormat.currency,
    ReportArea.cash,
  ),
  ReportMeasure(
    'closings',
    ReportSource.closings,
    ReportValueFormat.count,
    ReportArea.cash,
  ),
];

ReportMeasure reportMeasureByKey(String key) => reportMeasures.firstWhere(
  (measure) => measure.key == key,
  orElse: () => reportMeasures.first,
);

/// What a report can be split by.
enum ReportDimension {
  hour(true, {ReportSource.sales, ReportSource.closings}),
  weekday(true, {ReportSource.sales, ReportSource.closings}),
  day(true, {ReportSource.sales, ReportSource.closings}),
  week(true, {ReportSource.sales, ReportSource.closings}),
  month(true, {ReportSource.sales, ReportSource.closings}),
  quarter(true, {ReportSource.sales, ReportSource.closings}),
  year(true, {ReportSource.sales, ReportSource.closings}),
  product(false, {ReportSource.sales}),
  variation(false, {ReportSource.sales}),
  category(false, {ReportSource.sales}),
  brand(false, {ReportSource.sales}),
  customer(false, {ReportSource.sales}),
  channel(false, {ReportSource.sales}),
  register(false, {ReportSource.sales, ReportSource.closings}),
  operator(false, {ReportSource.sales, ReportSource.closings}),
  paymentMethod(false, {ReportSource.sales});

  const ReportDimension(this.isTime, this.sources);

  final bool isTime;
  final Set<ReportSource> sources;

  /// Key used by MGWS.
  String get key => this == paymentMethod ? 'payment_method' : name;

  static ReportDimension? fromKey(String? key) {
    for (final dimension in values) {
      if (dimension.key == key) return dimension;
    }
    return null;
  }
}

/// Kind of a report filter.
enum ReportFilterKind {
  product(ReportSource.sales, 'product_ids'),
  customer(ReportSource.sales, 'customer_keys'),
  category(ReportSource.sales, 'category_ids'),
  brand(ReportSource.sales, 'brand_ids'),
  channel(ReportSource.sales, 'channels'),
  register(null, 'registers'),
  operator(null, 'operator_ids'),
  paymentMethod(ReportSource.sales, 'payment_methods');

  const ReportFilterKind(this.onlySource, this.requestKey);

  /// Source the filter is limited to; null when every source accepts it.
  final ReportSource? onlySource;
  final String requestKey;

  bool appliesTo(ReportSource source) =>
      onlySource == null || onlySource == source;

  /// True when MGWS expects numeric ids.
  bool get numeric => switch (this) {
    product || category || brand || operator => true,
    _ => false,
  };
}

/// One filter value, with the name shown in the editor.
class ReportFilterValue {
  const ReportFilterValue({
    required this.kind,
    required this.id,
    required this.label,
  });

  final ReportFilterKind kind;
  final String id;
  final String label;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'label': label,
  };

  static ReportFilterValue? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = ReportFilterKind.values
        .where((value) => value.name == raw['kind']?.toString())
        .firstOrNull;
    final id = raw['id']?.toString() ?? '';
    if (kind == null || id.isEmpty) return null;
    return ReportFilterValue(
      kind: kind,
      id: id,
      label: raw['label']?.toString() ?? id,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReportFilterValue && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// A report question saved in a dashboard widget.
class DashboardReportQuery {
  const DashboardReportQuery({
    this.measure = 'revenue',
    this.dimension,
    this.filters = const [],
  });

  final String measure;
  final ReportDimension? dimension;
  final List<ReportFilterValue> filters;

  ReportMeasure get measureInfo => reportMeasureByKey(measure);

  ReportSource get source => measureInfo.source;

  DashboardReportQuery copyWith({
    String? measure,
    ReportDimension? dimension,
    bool clearDimension = false,
    List<ReportFilterValue>? filters,
  }) {
    final nextMeasure = measure ?? this.measure;
    final nextSource = reportMeasureByKey(nextMeasure).source;
    var nextDimension = clearDimension ? null : (dimension ?? this.dimension);
    if (nextDimension != null && !nextDimension.sources.contains(nextSource)) {
      nextDimension = null;
    }
    return DashboardReportQuery(
      measure: nextMeasure,
      dimension: nextDimension,
      filters: (filters ?? this.filters)
          .where((filter) => filter.kind.appliesTo(nextSource))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'measure': measure,
    'dimension': dimension?.key ?? '',
    'filters': filters.map((filter) => filter.toJson()).toList(),
  };

  factory DashboardReportQuery.fromJson(Object? raw) {
    if (raw is! Map) return const DashboardReportQuery();
    final filters = raw['filters'];
    final filterItems = filters is List
        ? filters
        : (filters is Map ? filters.values.toList() : const []);
    final measure = raw['measure']?.toString() ?? 'revenue';
    return DashboardReportQuery(
      measure: reportMeasures.any((item) => item.key == measure)
          ? measure
          : 'revenue',
      dimension: ReportDimension.fromKey(raw['dimension']?.toString()),
      filters: [
        for (final item in filterItems)
          if (ReportFilterValue.fromJson(item) case final filter?) filter,
      ],
    );
  }

  /// Request body for MGWS.
  Map<String, dynamic> toRequest({
    required PeriodoReport period,
    required bool compare,
    required String sort,
    required int limit,
  }) {
    String day(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final grouped = <String, List<Object>>{};
    for (final filter in filters) {
      final value = filter.kind.numeric
          ? (int.tryParse(filter.id) ?? 0)
          : filter.id;
      grouped.putIfAbsent(filter.kind.requestKey, () => []).add(value);
    }
    return {
      'measures': [measure],
      if (dimension != null) 'dimension': dimension!.key,
      'date_from': day(period.dataInizio),
      'date_to': day(period.dataFine),
      'filters': grouped,
      'compare': compare ? 'previous_period' : 'none',
      if (sort.isNotEmpty) 'sort': sort,
      if (dimension != null && !dimension!.isTime) 'limit': limit,
    };
  }
}

/// One group of a report answer.
class ReportRow {
  const ReportRow({required this.key, required this.label, this.value});

  final String key;
  final String label;
  final double? value;
}

/// The answer of MGWS to a report question.
class DashboardReportResult {
  const DashboardReportResult({
    required this.measure,
    required this.dimension,
    required this.dateFrom,
    required this.dateTo,
    this.total,
    this.compareTotal,
    this.rows = const [],
  });

  factory DashboardReportResult.fromJson(
    Map<String, dynamic> raw,
    DashboardReportQuery query,
  ) {
    double? valueOf(Object? values) {
      if (values is! Map) return null;
      final value = values[query.measure];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    List<ReportRow> rowsOf(Object? rows) => [
      if (rows is List)
        for (final row in rows)
          if (row is Map)
            ReportRow(
              key: row['key']?.toString() ?? '',
              label: row['label']?.toString() ?? '',
              value: valueOf(row['values']),
            ),
    ];

    final totals = raw['totals'];
    final compare = raw['compare'];
    return DashboardReportResult(
      measure: query.measure,
      dimension: query.dimension,
      dateFrom: DateTime.tryParse(raw['date_from']?.toString() ?? ''),
      dateTo: DateTime.tryParse(raw['date_to']?.toString() ?? ''),
      total: valueOf(totals is Map ? totals['values'] : null),
      compareTotal: compare is Map
          ? valueOf(
              compare['totals'] is Map
                  ? (compare['totals'] as Map)['values']
                  : null,
            )
          : null,
      rows: rowsOf(raw['rows']),
    );
  }

  final String measure;
  final ReportDimension? dimension;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? total;
  final double? compareTotal;
  final List<ReportRow> rows;
}

/// Why a report could not be answered.
enum ReportFailure { unavailable, forbidden, failed }

class DashboardReportException implements Exception {
  const DashboardReportException(this.failure, [this.detail]);

  final ReportFailure failure;
  final Object? detail;

  @override
  String toString() => 'DashboardReportException($failure, $detail)';
}

/// Values the editor offers for registers, operators and payment methods.
class ReportCatalogValues {
  const ReportCatalogValues({
    this.registers = const [],
    this.paymentMethods = const [],
    this.operators = const [],
    this.onlineAvailable = false,
  });

  final List<String> registers;
  final List<String> paymentMethods;

  /// Operator id and name.
  final List<(String, String)> operators;
  final bool onlineAvailable;
}

/// Talks to MGWS and caches answers for the dashboard.
class DashboardReportService {
  DashboardReportService._();

  static final instance = DashboardReportService._();

  ReportCatalogValues? _catalog;

  Future<DashboardReportResult> run(
    DashboardReportQuery query,
    Map<String, dynamic> request,
  ) async {
    if (!await PlatformManager.ensureCanUseMgws()) {
      throw const DashboardReportException(ReportFailure.unavailable);
    }
    try {
      final raw = await PlatformManager.reports.query(request);
      return DashboardReportResult.fromJson(raw, query);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw DashboardReportException(ReportFailure.forbidden, error);
      }
      if (status == 404) {
        // An MGWS version without the report engine.
        throw DashboardReportException(ReportFailure.unavailable, error);
      }
      log.w('MGWS report failed: $error');
      throw DashboardReportException(ReportFailure.failed, error);
    }
  }

  Future<ReportCatalogValues> catalogValues() async {
    final cached = _catalog;
    if (cached != null) return cached;
    try {
      if (!await PlatformManager.ensureCanUseMgws()) {
        return const ReportCatalogValues();
      }
      final raw = await PlatformManager.reports.catalog();
      final values = raw['values'];
      List<String> strings(Object? list) => [
        if (list is List)
          for (final item in list) item.toString(),
      ];
      final operators = values is Map ? values['operators'] : null;
      final result = ReportCatalogValues(
        registers: strings(values is Map ? values['registers'] : null),
        paymentMethods: strings(
          values is Map ? values['payment_methods'] : null,
        ),
        operators: [
          if (operators is List)
            for (final item in operators)
              if (item is Map)
                (item['id']?.toString() ?? '', item['name']?.toString() ?? ''),
        ],
        onlineAvailable: raw['online_available'] == true,
      );
      _catalog = result;
      return result;
    } catch (error) {
      log.w('MGWS report catalog not available: $error');
      return const ReportCatalogValues();
    }
  }

  /// Searches products, customers, categories or brands for a filter.
  Future<List<ReportFilterValue>> search(
    ReportFilterKind kind,
    String term,
  ) async {
    final text = term.trim();
    switch (kind) {
      case ReportFilterKind.product:
        if (text.isEmpty) return const [];
        final List<dynamic> products = await PlatformManager.prodotti
            .searchProducts(text, limit: 20);
        return [
          for (final product in products)
            if (product.id != null)
              ReportFilterValue(
                kind: kind,
                id: '${product.id}',
                label: product.nome?.toString() ?? '#${product.id}',
              ),
        ];
      case ReportFilterKind.customer:
        if (text.isEmpty) return const [];
        final List<dynamic> customers = await PlatformManager.clienti
            .searchCustomersByName(text);
        return [
          for (final customer in customers)
            if (customer.id != null)
              ReportFilterValue(
                kind: kind,
                id: 'u${customer.id}',
                label: _customerName(
                  customer.firstName,
                  customer.lastName,
                  customer.email,
                  customer.id,
                ),
              ),
        ];
      case ReportFilterKind.category:
        final List<dynamic> categories = text.isEmpty
            ? await PlatformManager.categorie.getAllCategories()
            : await PlatformManager.categorie.searchCategories(text);
        return [
          for (final category in categories)
            ReportFilterValue(
              kind: kind,
              id: '${category.id}',
              label: category.nome.toString(),
            ),
        ];
      case ReportFilterKind.brand:
        final List<dynamic> brands = text.isEmpty
            ? await PlatformManager.marchi.getBrands()
            : await PlatformManager.marchi.searchBrands(text);
        return [
          for (final brand in brands)
            ReportFilterValue(
              kind: kind,
              id: '${brand.id}',
              label: brand.nome.toString(),
            ),
        ];
      case ReportFilterKind.channel:
        return const [];
      case ReportFilterKind.register:
        final catalog = await catalogValues();
        return [
          for (final register in catalog.registers)
            if (_matches(register, text))
              ReportFilterValue(kind: kind, id: register, label: register),
        ];
      case ReportFilterKind.operator:
        final catalog = await catalogValues();
        return [
          for (final (id, name) in catalog.operators)
            if (_matches(name, text))
              ReportFilterValue(kind: kind, id: id, label: name),
        ];
      case ReportFilterKind.paymentMethod:
        final catalog = await catalogValues();
        return [
          for (final method in catalog.paymentMethods)
            if (_matches(method, text))
              ReportFilterValue(kind: kind, id: method, label: method),
        ];
    }
  }

  static bool _matches(String value, String term) =>
      term.isEmpty || value.toLowerCase().contains(term.toLowerCase());

  static String _customerName(
    Object? first,
    Object? last,
    Object? email,
    Object? id,
  ) {
    final name = '${first ?? ''} ${last ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    final mail = email?.toString() ?? '';
    return mail.isNotEmpty ? mail : '#$id';
  }
}

/// Ready-made questions offered in the editor and in the standard dashboard.
enum ReportPreset {
  productSales,
  bestCustomers,
  averageTicketPerCustomer,
  averagePricePerCustomer,
  revenuePerCustomer,
  newCustomers,
  dormantCustomers,
  salesByHour,
  salesByWeekday,
  salesByOperator,
  salesByPaymentMethod,
  salesByChannel,
  cashDifferences;

  DashboardReportQuery get query => switch (this) {
    productSales => const DashboardReportQuery(measure: 'quantity_sold'),
    bestCustomers => const DashboardReportQuery(
      dimension: ReportDimension.customer,
    ),
    averageTicketPerCustomer => const DashboardReportQuery(
      measure: 'average_ticket',
      dimension: ReportDimension.customer,
    ),
    averagePricePerCustomer => const DashboardReportQuery(
      measure: 'average_unit_price',
      dimension: ReportDimension.customer,
    ),
    revenuePerCustomer => const DashboardReportQuery(
      measure: 'revenue_per_customer',
    ),
    newCustomers => const DashboardReportQuery(measure: 'new_customers'),
    dormantCustomers => const DashboardReportQuery(
      measure: 'days_since_last_purchase',
      dimension: ReportDimension.customer,
    ),
    salesByHour => const DashboardReportQuery(dimension: ReportDimension.hour),
    salesByWeekday => const DashboardReportQuery(
      dimension: ReportDimension.weekday,
    ),
    salesByOperator => const DashboardReportQuery(
      dimension: ReportDimension.operator,
    ),
    salesByPaymentMethod => const DashboardReportQuery(
      dimension: ReportDimension.paymentMethod,
    ),
    salesByChannel => const DashboardReportQuery(
      dimension: ReportDimension.channel,
    ),
    cashDifferences => const DashboardReportQuery(
      measure: 'cash_difference',
      dimension: ReportDimension.day,
    ),
  };

  /// Filter the question needs before it makes sense.
  ReportFilterKind? get requiredFilter =>
      this == productSales ? ReportFilterKind.product : null;
}

/// Answers a report question; injectable so the page can be tested offline.
typedef DashboardReportRunner =
    Future<DashboardReportResult> Function(
      DashboardReportQuery query,
      Map<String, dynamic> request,
    );

/// Looks up filter values (products, customers...); injectable for tests.
typedef DashboardReportSearch =
    Future<List<ReportFilterValue>> Function(
      ReportFilterKind kind,
      String term,
    );
