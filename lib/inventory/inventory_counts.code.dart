import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory_restock_feedback.code.dart';

class InventoryCountSessionForm {
  const InventoryCountSessionForm({
    required this.siteIdText,
    required this.warehouseIdText,
    required this.documentNumberText,
    this.notesText = '',
  });

  final String siteIdText;
  final String warehouseIdText;
  final String documentNumberText;
  final String notesText;

  InventoryFormParse<MgwsCountSessionInput> parse() {
    final siteId = InventoryInputParser.parsePositiveInt(siteIdText);
    if (siteId == null)
      return InventoryFormInvalid(invalidFieldText('site_id'));
    final warehouseId = InventoryInputParser.parsePositiveInt(warehouseIdText);
    if (warehouseId == null) {
      return InventoryFormInvalid(invalidFieldText('warehouse_id'));
    }
    final documentNumber = documentNumberText.trim();
    if (documentNumber.isEmpty) {
      return InventoryFormInvalid(
        (l10n) => l10n.inventoryDocumentNumberRequired,
      );
    }
    return InventoryFormValid(
      MgwsCountSessionInput(
        siteId: siteId,
        warehouseId: warehouseId,
        documentNumber: documentNumber,
        notes: notesText.trim(),
      ),
    );
  }
}

class InventoryCountLineForm {
  const InventoryCountLineForm({
    required this.sessionIdText,
    required this.physicalQuantityText,
    this.productIdText = '',
    this.variationIdText = '',
    this.barcodeText = '',
    this.tagText = '',
    this.warehouseIdText = '',
    this.roomText = '',
    this.rackText = '',
    this.shelfText = '',
    this.reasonCodeText = '',
  });

  final String sessionIdText;
  final String physicalQuantityText;
  final String productIdText;
  final String variationIdText;
  final String barcodeText;
  final String tagText;
  final String warehouseIdText;
  final String roomText;
  final String rackText;
  final String shelfText;
  final String reasonCodeText;

  InventoryFormParse<InventoryCountLineCommand> parse() {
    final sessionId = InventoryInputParser.parsePositiveInt(sessionIdText);
    if (sessionId == null) {
      return InventoryFormInvalid(invalidFieldText('count_session_id'));
    }
    final physicalQuantity = InventoryInputParser.parseNonNegativeInt(
      physicalQuantityText,
    );
    if (physicalQuantity == null) {
      return InventoryFormInvalid(
        (l10n) => l10n.inventoryInvalidPhysicalQuantity,
      );
    }
    final productId = _optionalPositiveInt(productIdText);
    if (productIdText.trim().isNotEmpty && productId == null) {
      return InventoryFormInvalid(invalidFieldText('product_id'));
    }
    final barcode = _optional(barcodeText);
    final tag = _optional(tagText);
    if (productId == null && barcode == null && tag == null) {
      return InventoryFormInvalid(
        (l10n) => l10n.inventoryProductBarcodeOrTagRequired,
      );
    }
    final variationId = _optionalNonNegativeInt(variationIdText);
    if (variationIdText.trim().isNotEmpty && variationId == null) {
      return InventoryFormInvalid(invalidFieldText('variation_id'));
    }
    final warehouseId = _optionalPositiveInt(warehouseIdText);
    if (warehouseIdText.trim().isNotEmpty && warehouseId == null) {
      return InventoryFormInvalid(invalidFieldText('warehouse_id'));
    }
    return InventoryFormValid(
      InventoryCountLineCommand(
        sessionId: sessionId,
        input: MgwsCountLineInput(
          physicalQuantity: physicalQuantity,
          productId: productId,
          variationId: variationId,
          barcode: barcode,
          tag: tag,
          warehouseId: warehouseId,
          room: roomText.trim(),
          rack: rackText.trim(),
          shelf: shelfText.trim(),
          reasonCode: reasonCodeText.trim(),
        ),
      ),
    );
  }
}

class InventoryCountLineCommand {
  const InventoryCountLineCommand({
    required this.sessionId,
    required this.input,
  });

  final int sessionId;
  final MgwsCountLineInput input;
}

class InventoryCountSessionController with InventoryFeedbackController {
  InventoryCountSessionController({MgwsRestockGateway? gateway})
    : gateway = gateway ?? QueryMgwsInventory();

  final MgwsRestockGateway gateway;
  List<MgwsCountSession> sessions = const [];
  MgwsCountSession? activeSession;
  MgwsCountLine? lastCountLine;
  bool isApproving = false;

  Future<InventoryActionFeedback> loadSessions({
    String siteIdText = '',
    String warehouseIdText = '',
  }) async {
    final siteId = _optionalPositiveInt(siteIdText);
    if (siteIdText.trim().isNotEmpty && siteId == null) {
      return invalid(invalidFieldText('site_id'));
    }
    final warehouseId = _optionalPositiveInt(warehouseIdText);
    if (warehouseIdText.trim().isNotEmpty && warehouseId == null) {
      return invalid(invalidFieldText('warehouse_id'));
    }
    final result = await gateway.listCountSessions(
      siteId: siteId,
      warehouseId: warehouseId,
    );
    if (result.success) sessions = result.data ?? const [];
    return _feedback(result);
  }

  Future<InventoryActionFeedback> create(InventoryCountSessionForm form) async {
    final parsed = form.parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        final result = await gateway.createCountSession(value);
        if (result.success) activeSession = result.data;
        return _feedback(result);
    }
  }

  Future<InventoryActionFeedback> load(String sessionIdText) async {
    final parsed = InventoryIdentifierForm(
      sessionIdText,
      label: 'count_session_id',
    ).parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        final result = await gateway.getCountSession(value);
        if (result.success) activeSession = result.data;
        return _feedback(result);
    }
  }

  Future<InventoryActionFeedback> saveLine(InventoryCountLineForm form) async {
    final parsed = form.parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        if (_isPosted(value.sessionId)) {
          return invalid((l10n) => l10n.inventoryCountSessionAlreadyPosted);
        }
        final result = await gateway.saveCountLine(
          value.sessionId,
          value.input,
        );
        lastCountLine = result.data;
        return _feedback(result);
    }
  }

  Future<InventoryActionFeedback> approve(String sessionIdText) async {
    final parsed = InventoryIdentifierForm(
      sessionIdText,
      label: 'count_session_id',
    ).parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        if (_isPosted(value))
          return invalid((l10n) => l10n.inventoryCountSessionAlreadyPosted);
        if (isApproving)
          return invalid((l10n) => l10n.inventoryCountApprovalInProgress);
        isApproving = true;
        try {
          final result = await gateway.approveCountSession(value);
          if (result.success) activeSession = result.data;
          return _feedback(result);
        } finally {
          isApproving = false;
        }
    }
  }

  bool _isPosted(int sessionId) {
    return activeSession?.id == sessionId &&
        activeSession!.status.toLowerCase() == 'posted';
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
