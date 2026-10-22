import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory_movement_key.code.dart';
import 'inventory_restock_feedback.code.dart';

/// Unico motivo registrato per un carico di magazzino.
///
/// Il carico e' un'operazione sola, quindi non ha senso offrire un elenco di
/// motivi da scegliere: un dropdown con una voce sembra una scelta e non lo e',
/// e il rischio non e' che l'operatore sbagli la voce, e' che non capisca
/// cosa sta scrivendo. Chi voleva registrare qualcos'altro (un reso, una
/// rettifica) usa il modulo dedicato, che chiede il proprio motivo.
///
/// E il valore salvato su MGWS, quindi non si traduce: la GUI mostra
/// `inventoryStockInReason`.
const kInventoryCaricoReason = 'Carico merce';

class InventoryQuickLoadLineDraft {
  const InventoryQuickLoadLineDraft({
    required this.productId,
    required this.variationId,
    required this.label,
    required this.quantity,
    required this.idempotencyKey,
    this.barcodeInterno,
    this.barcode,
    this.imageUrl,
    this.rack,
    this.shelf,
  });

  final int productId;
  final int variationId;
  final String label;
  final String? barcodeInterno;
  final String? barcode;
  final String? imageUrl;
  final String? rack;
  final String? shelf;
  final int quantity;
  final String idempotencyKey;

  String get key => '$productId:$variationId';
  bool get isVariant => variationId > 0;

  InventoryQuickLoadLineDraft copyWith({
    int? quantity,
    String? idempotencyKey,
    String? rack,
    String? shelf,
  }) {
    return InventoryQuickLoadLineDraft(
      productId: productId,
      variationId: variationId,
      label: label,
      barcodeInterno: barcodeInterno,
      barcode: barcode,
      imageUrl: imageUrl,
      rack: rack ?? this.rack,
      shelf: shelf ?? this.shelf,
      quantity: quantity ?? this.quantity,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

class InventoryQuickLoadSubmissionPlan {
  const InventoryQuickLoadSubmissionPlan({
    required this.lines,
    required this.siteId,
    this.note,
    this.warehouseId,
    this.room,
  });

  final List<InventoryQuickLoadLineDraft> lines;
  final int siteId;
  final String? note;
  final int? warehouseId;
  final String? room;

  int get totalQuantity =>
      lines.fold<int>(0, (sum, line) => sum + line.quantity);

  /// `movementKey` identifica l'operazione a cui appartengono le righe.
  ///
  /// Va passata identica su tutte: e' l'unica cosa che tiene insieme un carico
  /// di trenta codici, che sul backend sono trenta richieste separate. Senza,
  /// lo storico mostrerebbe trenta carichi da un pezzo.
  InventoryFormParse<List<MgwsQuickLoadRequest>> parse({String? movementKey}) {
    if (lines.isEmpty) {
      return InventoryFormInvalid(
        (l10n) => l10n.inventorySelectProductOrVariant,
      );
    }
    if (siteId <= 0) {
      return InventoryFormInvalid((l10n) => l10n.inventorySiteRequired);
    }
    if (warehouseId != null && warehouseId! <= 0) {
      return InventoryFormInvalid(invalidFieldText('warehouse_id'));
    }
    for (final line in lines) {
      if (line.productId <= 0) {
        return InventoryFormInvalid(invalidFieldText('product_id'));
      }
      if (line.variationId < 0) {
        return InventoryFormInvalid(invalidFieldText('variation_id'));
      }
      if (line.quantity <= 0) {
        return InventoryFormInvalid(
          (l10n) => l10n.inventoryInvalidQuantityFor(line.label),
        );
      }
    }
    return InventoryFormValid(
      lines
          .map(
            (line) => MgwsQuickLoadRequest(
              productId: line.productId,
              variationId: line.variationId,
              quantityDelta: line.quantity,
              reason: kInventoryCaricoReason,
              siteId: siteId,
              note: _optional(note ?? ''),
              barcode: _optional(line.barcode ?? ''),
              warehouseId: warehouseId,
              room: _optional(room ?? ''),
              rack: _optional(line.rack ?? ''),
              shelf: _optional(line.shelf ?? ''),
              idempotencyKey: line.idempotencyKey,
              movementKey: movementKey,
            ),
          )
          .toList(growable: false),
    );
  }
}

class InventoryQuickLoadLineResult {
  const InventoryQuickLoadLineResult({
    required this.line,
    required this.success,
    required this.message,
    this.details = const <String>[],
    this.data,
  });

  final InventoryQuickLoadLineDraft line;
  final bool success;
  final LocalizedText message;
  final List<String> details;
  final MgwsQuickLoad? data;
}

class InventoryQuickLoadForm {
  const InventoryQuickLoadForm({
    required this.productIdText,
    required this.quantityText,
    required this.siteIdText,
    this.variationIdText = '',
    this.noteText = '',
    this.barcodeText = '',
    this.warehouseIdText = '',
    this.roomText = '',
    this.rackText = '',
    this.shelfText = '',
    this.idempotencyKeyText = '',
  });

  final String productIdText;
  final String quantityText;
  final String siteIdText;
  final String variationIdText;
  final String noteText;
  final String barcodeText;
  final String warehouseIdText;
  final String roomText;
  final String rackText;
  final String shelfText;
  final String idempotencyKeyText;

  InventoryFormParse<MgwsQuickLoadRequest> parse() {
    final productId = InventoryInputParser.parseProductId(productIdText);
    if (productId == null)
      return InventoryFormInvalid(invalidFieldText('product_id'));
    final quantity = InventoryInputParser.parsePositiveInt(quantityText);
    if (quantity == null)
      return InventoryFormInvalid((l10n) => l10n.inventoryInvalidQuantity);
    final siteId = InventoryInputParser.parsePositiveInt(siteIdText);
    if (siteId == null)
      return InventoryFormInvalid((l10n) => l10n.inventorySiteRequired);
    final variationId = InventoryInputParser.parseOptionalNonNegativeInt(
      variationIdText,
    );
    if (variationId == null) {
      return InventoryFormInvalid(invalidFieldText('variation_id'));
    }
    final warehouseId = warehouseIdText.trim().isEmpty
        ? null
        : InventoryInputParser.parsePositiveInt(warehouseIdText);
    if (warehouseIdText.trim().isNotEmpty && warehouseId == null) {
      return InventoryFormInvalid(invalidFieldText('warehouse_id'));
    }
    return InventoryFormValid(
      MgwsQuickLoadRequest(
        productId: productId,
        quantityDelta: quantity,
        reason: kInventoryCaricoReason,
        siteId: siteId,
        variationId: variationId,
        note: _optional(noteText),
        barcode: _optional(barcodeText),
        warehouseId: warehouseId,
        room: _optional(roomText),
        rack: _optional(rackText),
        shelf: _optional(shelfText),
        idempotencyKey: _optional(idempotencyKeyText),
      ),
    );
  }
}

class InventoryQuickLoadController with InventoryFeedbackController {
  InventoryQuickLoadController({MgwsRestockGateway? gateway})
    : gateway = gateway ?? QueryMgwsInventory();

  final MgwsRestockGateway gateway;
  MgwsQuickLoad? lastQuickLoad;
  List<InventoryQuickLoadLineResult> lastQuickLoadResults = const [];
  bool isSubmitting = false;

  List<InventoryQuickLoadLineDraft> get retryableLines => lastQuickLoadResults
      .where((result) => !result.success)
      .map((result) => result.line)
      .toList(growable: false);

  Future<InventoryActionFeedback> submit(InventoryQuickLoadForm form) async {
    final parsed = form.parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        if (isSubmitting)
          return invalid((l10n) => l10n.inventoryQuickLoadInProgress);
        isSubmitting = true;
        try {
          final result = await gateway.quickLoad(value);
          lastQuickLoad = result.data;
          return remember(
            InventoryActionFeedback(
              success: result.success,
              message: literalText(result.message),
              details: literalTexts(result.details),
            ),
          );
        } finally {
          isSubmitting = false;
        }
    }
  }

  Future<InventoryActionFeedback> submitPlan(
    InventoryQuickLoadSubmissionPlan plan,
  ) async {
    // Una chiave per invio, non per riga: e' il carico intero a essere un solo
    // movimento. Righe che non partono portano con se' la stessa chiave di quelle
    // che partono, e cosi' lo storico mostra il carico come l'operatore l'ha
    // fatto, anche se a meta'.
    final parsed = plan.parse(movementKey: newInventoryMovementKey());
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(:final value):
        if (isSubmitting)
          return invalid((l10n) => l10n.inventoryQuickLoadInProgress);
        isSubmitting = true;
        final results = <InventoryQuickLoadLineResult>[];
        try {
          for (int index = 0; index < value.length; index++) {
            final request = value[index];
            final line = plan.lines[index];
            try {
              final result = await gateway.quickLoad(request);
              final success = result.success && result.data != null;
              if (success) lastQuickLoad = result.data;
              results.add(
                InventoryQuickLoadLineResult(
                  line: line,
                  success: success,
                  message: success || !result.success
                      ? literalText(result.message)
                      : (l10n) => l10n.inventoryMgwsNoData,
                  details: result.details,
                  data: result.data,
                ),
              );
            } catch (error) {
              results.add(
                InventoryQuickLoadLineResult(
                  line: line,
                  success: false,
                  message: literalText(error.toString()),
                ),
              );
            }
          }
          lastQuickLoadResults =
              List<InventoryQuickLoadLineResult>.unmodifiable(results);
          final succeeded = results.where((result) => result.success).length;
          final failed = results.length - succeeded;
          return remember(
            InventoryActionFeedback(
              success: failed == 0,
              message: failed == 0
                  ? (l10n) =>
                        l10n.inventoryQuickLoadDone(succeeded, results.length)
                  : (l10n) => l10n.inventoryQuickLoadPartial(
                      succeeded,
                      results.length,
                      failed,
                    ),
              details: [
                for (final result in results.where((item) => !item.success))
                  (l10n) => '${result.line.label}: ${result.message(l10n)}',
                for (final result in results.where((item) => !item.success))
                  for (final detail in result.details)
                    literalText('${result.line.label}: $detail'),
              ],
            ),
          );
        } finally {
          isSubmitting = false;
        }
    }
  }
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
