import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory_restock_feedback.code.dart';

class InventoryMovementFilterForm {
  const InventoryMovementFilterForm({
    this.productIdText = '',
    this.variationIdText = '',
    this.dateFromText = '',
    this.dateToText = '',
    this.sourceTypeText = '',
    this.operatorUserIdText = '',
    this.reasonCodeText = '',
    this.stockEffectText = '',
    this.pageText = '1',

    /// Il massimo che MGWS accetta.
    ///
    /// E' il default perche' le righe del ledger sono una per prodotto, e il
    /// raggruppamento per operazione funziona solo se i prodotti della stessa
    /// operazione arrivano insieme: con 50 righe una rettifica da 60 prodotti
    /// verrebbe spezzata in due gruppi, e l'operatore vedrebbe due operazioni
    /// dove ce n'e' una. Non e' una soluzione — il backend non filtra per
    /// documento — ma e' il minimo difendibile senza una rotta nuova.
    this.perPageText = '100',
  });

  final String productIdText;
  final String variationIdText;
  final String dateFromText;
  final String dateToText;
  final String sourceTypeText;
  final String operatorUserIdText;
  final String reasonCodeText;
  final String stockEffectText;
  final String pageText;
  final String perPageText;

  InventoryFormParse<MgwsMovementFilter> parse() {
    final productId = _optionalPositiveInt(productIdText);
    if (productIdText.trim().isNotEmpty && productId == null) {
      return InventoryFormInvalid(invalidFieldText('product_id'));
    }
    final variationId = _optionalNonNegativeInt(variationIdText);
    if (variationIdText.trim().isNotEmpty && variationId == null) {
      return InventoryFormInvalid(invalidFieldText('variation_id'));
    }
    final dateFrom = _parseDate(
      dateFromText,
      (l10n) => l10n.inventoryInvalidStartDate,
    );
    if (dateFrom is InventoryFormInvalid<String?>) {
      return InventoryFormInvalid(dateFrom.message);
    }
    final dateTo = _parseDate(
      dateToText,
      (l10n) => l10n.inventoryInvalidEndDate,
    );
    if (dateTo is InventoryFormInvalid<String?>) {
      return InventoryFormInvalid(dateTo.message);
    }
    final page = InventoryInputParser.parsePositiveInt(pageText);
    if (page == null)
      return InventoryFormInvalid((l10n) => l10n.inventoryInvalidPage);
    final perPage = InventoryInputParser.parsePositiveInt(perPageText);
    if (perPage == null || perPage > 100) {
      return InventoryFormInvalid((l10n) => l10n.inventoryInvalidRowsPerPage);
    }
    final from = (dateFrom as InventoryFormValid<String?>).value;
    final to = (dateTo as InventoryFormValid<String?>).value;
    if (from != null &&
        to != null &&
        DateTime.parse(from).isAfter(DateTime.parse(to))) {
      return InventoryFormInvalid((l10n) => l10n.inventoryInvalidDateRange);
    }
    final operatorUserId = _optionalPositiveInt(operatorUserIdText);
    if (operatorUserIdText.trim().isNotEmpty && operatorUserId == null) {
      return InventoryFormInvalid((l10n) => l10n.inventoryInvalidOperator);
    }
    return InventoryFormValid(
      MgwsMovementFilter(
        productId: productId,
        variationId: variationId,
        dateFrom: from,
        dateTo: to,
        sourceType: _optional(sourceTypeText),
        operatorUserId: operatorUserId,
        reasonCode: _optional(reasonCodeText),
        stockEffect: _optional(stockEffectText),
        page: page,
        perPage: perPage,
      ),
    );
  }
}

class InventoryMovementController with InventoryFeedbackController {
  InventoryMovementController({MgwsRestockGateway? gateway})
    : gateway = gateway ?? QueryMgwsInventory();

  final MgwsRestockGateway gateway;
  MgwsMovementFilter? lastFilter;
  MgwsMovementPage? movementPage;
  bool isLoading = false;

  List<MgwsMovement> get movements => movementPage?.items ?? const [];

  Future<InventoryActionFeedback> load(InventoryMovementFilterForm form) async {
    final parsed = form.parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        isLoading = true;
        try {
          final result = await gateway.listMovements(value);
          if (result.success) {
            lastFilter = value;
            movementPage = result.data;
          }
          return remember(
            InventoryActionFeedback(
              success: result.success,
              message: literalText(result.message),
              details: literalTexts(result.details),
            ),
          );
        } finally {
          isLoading = false;
        }
    }
  }
}

InventoryFormParse<String?> _parseDate(String value, LocalizedText message) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const InventoryFormValid(null);
  final parsed = DateTime.tryParse(trimmed);
  return parsed == null
      ? InventoryFormInvalid(message)
      : InventoryFormValid(parsed.toUtc().toIso8601String());
}

int? _optionalPositiveInt(String value) {
  return value.trim().isEmpty
      ? null
      : InventoryInputParser.parsePositiveInt(value);
}

int? _optionalNonNegativeInt(String value) {
  return value.trim().isEmpty
      ? null
      : InventoryInputParser.parseNonNegativeInt(value);
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
