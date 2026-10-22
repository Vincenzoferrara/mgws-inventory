import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory_restock_feedback.code.dart';

class InventoryReorderController with InventoryFeedbackController {
  InventoryReorderController({MgwsRestockGateway? gateway})
    : gateway = gateway ?? QueryMgwsInventory();

  final MgwsRestockGateway gateway;
  List<MgwsReorderSuggestion> suggestions = const [];
  MgwsReorderSuggestion? lastSuggestion;
  MgwsPurchaseOrder? lastPurchaseOrder;
  MgwsPurchaseOrderLine? lastPurchaseOrderLine;

  Future<InventoryActionFeedback> loadSuggestions({
    String siteIdText = '',
    String warehouseIdText = '',
  }) async {
    final siteId = _optionalPositive(siteIdText, 'site_id');
    if (siteId case InventoryFormInvalid(:final message)) {
      return invalid(message);
    }
    final warehouseId = _optionalPositive(warehouseIdText, 'warehouse_id');
    if (warehouseId case InventoryFormInvalid(:final message)) {
      return invalid(message);
    }
    final result = await gateway.listReorderSuggestions(
      siteId: (siteId as InventoryFormValid<int?>).value,
      warehouseId: (warehouseId as InventoryFormValid<int?>).value,
    );
    if (result.success && result.data != null) suggestions = result.data!;
    return _feedback(result);
  }

  /// [notes] e la nota salvata sull'ordine, nella lingua dell'operatore.
  Future<InventoryActionFeedback> createDraftFromSuggestion(
    MgwsReorderSuggestion suggestion, {
    required String notes,
  }) async {
    lastSuggestion = suggestion;
    if (suggestion.supplierId <= 0) {
      return invalid((l10n) => l10n.inventorySuggestionMissingSupplier);
    }
    final orderResult = await gateway.createPurchaseOrder(
      MgwsPurchaseOrderInput(
        siteId: suggestion.siteId,
        supplierId: suggestion.supplierId,
        documentNumber: 'RIORD-${suggestion.ruleId}-${suggestion.productId}',
        warehouseId: suggestion.warehouseId,
        notes: notes,
      ),
    );
    lastPurchaseOrder = orderResult.data;
    if (!orderResult.success || orderResult.data == null) {
      return _feedback(orderResult);
    }
    final lineResult = await gateway.savePurchaseOrderLine(
      orderResult.data!.id,
      MgwsPurchaseOrderLineInput(
        productId: suggestion.productId,
        variationId: suggestion.variationId,
        orderedQuantity: suggestion.suggestedQuantity,
        unitCost: '0',
      ),
    );
    lastPurchaseOrderLine = lineResult.data;
    return _feedback(lineResult);
  }

  InventoryActionFeedback _feedback<T>(MgwsRestockResult<T> result) {
    return remember(
      InventoryActionFeedback(
        success: result.success,
        message: literalText(result.message),
        details: literalTexts(result.details),
      ),
    );
  }
}

InventoryFormParse<int?> _optionalPositive(String value, String label) {
  if (value.trim().isEmpty) return const InventoryFormValid(null);
  final parsed = InventoryInputParser.parsePositiveInt(value);
  if (parsed == null) return InventoryFormInvalid(invalidFieldText(label));
  return InventoryFormValid(parsed);
}
