// inventory_add_products.code.dart
//
// Logica del flusso unificato "Aggiungi prodotto".
//
// Il pannello offre due modalita':
//  - [InventoryAddMode.simple]: i pezzi vengono caricati in magazzino e basta.
//  - [InventoryAddMode.order]: le stesse righe di carico vengono registrate
//    anche come bozza di ordine fornitore, con le spunta di convalida.
//
// Il punto fermo del modulo e che il movimento di magazzino e identico in
// entrambe le modalita'. Aggiungere un fornitore non cambia la realta del
// magazzino, cambia solo la tracciatura amministrativa: per questo l'ordine
// viene scritto attorno al carico, non al posto del carico.

import '../login/mgws/query/query_mgws_inventory.dart';
import '../l10n/extensions.dart';
import 'inventory_purchase_orders.code.dart';
import 'inventory_quick_load.code.dart';
import 'inventory_receipts.code.dart';
import 'inventory_restock_feedback.code.dart';

/// Come viene registrata un'aggiunta di prodotti.
enum InventoryAddMode { simple, order }

/// Nome della modalita' di aggiunta, mostrato nel dropdown.
String inventoryAddModeLabel(AppLocalizations l10n, InventoryAddMode mode) =>
    switch (mode) {
      InventoryAddMode.simple => l10n.inventoryModalitaSemplice,
      InventoryAddMode.order => l10n.inventoryModalitaOrdine,
    };

/// Riga di chiarimento sotto il dropdown della modalita'.
String inventoryAddModeDescription(
  AppLocalizations l10n,
  InventoryAddMode mode,
) => switch (mode) {
  InventoryAddMode.simple => l10n.inventoryModalitaSempliceDescrizione,
  InventoryAddMode.order => l10n.inventoryModalitaOrdineDescrizione,
};

/// Stato completo del pannello "Aggiungi prodotto" al momento del salvataggio.
class InventoryAddProductsPlan {
  const InventoryAddProductsPlan({
    required this.mode,
    required this.lines,
    required this.siteIdText,
    required this.documentNumberText,
    this.supplier,
    this.validated = false,
    this.note = '',
    this.warehouseId,
    this.room,
  });

  final InventoryAddMode mode;
  final MgwsSupplier? supplier;
  final bool validated;
  final String siteIdText;
  final String documentNumberText;
  final List<InventoryQuickLoadLineDraft> lines;
  final String note;
  final int? warehouseId;
  final String? room;

  bool get isOrder => mode == InventoryAddMode.order;

  int get lineCount => lines.length;

  /// Pezzi che l'operatore ha inserito a mano o scansionato.
  int get enteredQuantity =>
      lines.fold<int>(0, (sum, line) => sum + line.quantity);

  /// Pezzi coperti dalla convalida. Senza spunta l'ordine resta bozza e i
  /// pezzi non sono confermati, quindi il conteggio convalidato e zero.
  int get validatedQuantity => validated ? enteredQuantity : 0;

  /// Quanta merce inserita non e ancora coperta dalla convalida.
  int get difference => enteredQuantity - validatedQuantity;

  String get supplierLabel {
    final value = supplier;
    if (value == null) return '';
    return value.name;
  }

  InventoryFormParse<InventoryAddProductsCommand> parse() {
    final siteId = InventoryInputParser.parsePositiveInt(siteIdText);
    if (siteId == null)
      return InventoryFormInvalid((l10n) => l10n.inventorySiteRequired);
    if (isOrder) {
      if (supplier == null) {
        return InventoryFormInvalid((l10n) => l10n.inventorySelectSupplier);
      }
      if (documentNumberText.trim().isEmpty) {
        return InventoryFormInvalid(
          (l10n) => l10n.inventoryDocumentNumberRequired,
        );
      }
    }
    // Il piano di carico resta il cuore del flusso: in modalita' ordine
    // valida anche le righe che andranno a finire sull'ordine.
    final quickLoad = InventoryQuickLoadSubmissionPlan(
      lines: lines,
      siteId: siteId,
      note: note,
      warehouseId: warehouseId,
      room: room,
    );
    switch (quickLoad.parse()) {
      case InventoryFormInvalid(:final message):
        return InventoryFormInvalid(message);
      case InventoryFormValid():
        return InventoryFormValid(
          InventoryAddProductsCommand(
            quickLoadPlan: quickLoad,
            supplierId: isOrder ? supplier!.id : null,
            siteIdText: siteId.toString(),
            documentNumber: documentNumberText.trim(),
            validated: validated,
          ),
        );
    }
  }
}

/// Piano validato, pronto per essere eseguito dal controller.
class InventoryAddProductsCommand {
  const InventoryAddProductsCommand({
    required this.quickLoadPlan,
    required this.siteIdText,
    required this.documentNumber,
    required this.validated,
    this.supplierId,
  });

  final InventoryQuickLoadSubmissionPlan quickLoadPlan;

  /// Null in modalita' semplice: senza fornitore non viene toccato alcun ordine.
  final int? supplierId;
  final String siteIdText;
  final String documentNumber;
  final bool validated;
}

class InventoryAddProductsController with InventoryFeedbackController {
  InventoryAddProductsController({
    InventoryQuickLoadController? quickLoadController,
    InventoryPurchaseOrderController? purchaseOrderController,
    InventoryReceiptController? receiptController,
  }) : quickLoadController =
           quickLoadController ?? InventoryQuickLoadController(),
       purchaseOrderController =
           purchaseOrderController ?? InventoryPurchaseOrderController(),
       receiptController = receiptController ?? InventoryReceiptController();

  final InventoryQuickLoadController quickLoadController;
  final InventoryPurchaseOrderController purchaseOrderController;
  final InventoryReceiptController receiptController;

  MgwsPurchaseOrder? lastOrder;
  MgwsReceipt? lastReceipt;
  List<String> lastSteps = const [];
  bool isSubmitting = false;

  List<InventoryQuickLoadLineResult> get lastLineResults =>
      quickLoadController.lastQuickLoadResults;

  /// Righe che MGWS ha rifiutato: restano nel pannello per il giro dopo.
  List<InventoryQuickLoadLineDraft> get retryableLines =>
      quickLoadController.retryableLines;

  /// [l10n] scrive le note salvate su MGWS e i passi mostrati all'operatore.
  Future<InventoryActionFeedback> submit(
    AppLocalizations l10n,
    InventoryAddProductsPlan plan,
  ) async {
    if (isSubmitting)
      return invalid((l10n) => l10n.inventoryAddProductsInProgress);
    final parsed = plan.parse();
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(value: final command):
        isSubmitting = true;
        final steps = <String>[];
        final details = <String>[];
        var orderOk = true;
        MgwsPurchaseOrder? order;
        final orderLines = <MgwsPurchaseOrderLine>[];
        try {
          if (command.supplierId != null) {
            final draft = await _createOrder(l10n, command, plan);
            order = purchaseOrderController.lastPurchaseOrder;
            if (!draft.success) {
              // Nessun carico eseguito: l'ordine non e nato, quindi si
              // lascia lo stock intatto invece di registrare pezzi senza
              // documento.
              return _feedback(false, l10n.inventoryAddInterrupted, [
                draft.message(l10n),
                for (final detail in draft.details) detail(l10n),
              ], steps: steps);
            }
            steps.add(l10n.inventoryAddDraftCreated(command.documentNumber));

            for (final line in command.quickLoadPlan.lines) {
              final saved = await purchaseOrderController.saveLine(
                InventoryPurchaseOrderLineForm(
                  purchaseOrderIdText: order!.id.toString(),
                  productIdText: line.productId.toString(),
                  orderedQuantityText: line.quantity.toString(),
                  // Costo unitario non gestito: i costi vivono su WooCommerce,
                  // l'ordine MGWS serve come tracciatura del ricevuto.
                  unitCostText: '0',
                  variationIdText: line.variationId.toString(),
                  barcodeText: line.barcode ?? '',
                ),
              );
              final savedLine = purchaseOrderController.lastPurchaseOrderLine;
              if (!saved.success || savedLine == null) {
                orderOk = false;
                details.add(
                  l10n.inventoryAddOrderLineFailed(
                    line.label,
                    saved.message(l10n),
                  ),
                );
              } else {
                orderLines.add(savedLine);
              }
            }
            steps.add(
              l10n.inventoryAddOrderLinesSaved(
                orderLines.length,
                command.quickLoadPlan.lines.length,
              ),
            );
          }

          InventoryActionFeedback load;
          if (order != null && command.validated) {
            final pending = await purchaseOrderController.updateStatus(
              InventoryPurchaseOrderStatusForm(
                purchaseOrderIdText: order.id.toString(),
                statusText: 'pending',
              ),
            );
            if (pending.success) {
              steps.add(l10n.inventoryAddOrderPending(order.id));
            } else {
              orderOk = false;
              details.add(
                l10n.inventoryAddOrderPendingFailed(pending.message(l10n)),
              );
            }
            final received = await _creaRicezioneInVerifica(
              l10n,
              command,
              order,
              orderLines,
            );
            switch (received._outcome) {
              case _ValidationOutcome.skipped:
                orderOk = false;
                details.add(received.message);
              case _ValidationOutcome.failed:
                orderOk = false;
                details.add(
                  l10n.inventoryAddReceiptVerificationFailed(received.message),
                );
              case _ValidationOutcome.done:
                steps.add(received.message);
            }
            load = InventoryActionFeedback(
              success: orderOk,
              message: (l10n) => l10n.inventoryAddAwaitingManager,
              details: const [],
            );
          } else {
            // Passo reale per carico semplice o ordine non verificato.
            load = await quickLoadController.submitPlan(command.quickLoadPlan);
            if (load.success) {
              steps.add(
                l10n.inventoryAddLoadDone(
                  command.quickLoadPlan.lines.length,
                  command.quickLoadPlan.totalQuantity,
                ),
              );
            }
          }

          if (order != null) lastOrder = order;
          final success = load.success && orderOk;
          return _feedback(
            success,
            _summary(l10n, plan, success, load.message(l10n)),
            [...details, for (final detail in load.details) detail(l10n)],
            steps: steps,
          );
        } finally {
          isSubmitting = false;
        }
    }
  }

  /// Registra la ricezione della merce sull'ordine e la lascia in verifica.
  /// Non muove stock: il carico reale avviene solo con approvazione manager.
  Future<_ValidationResult> _creaRicezioneInVerifica(
    AppLocalizations l10n,
    InventoryAddProductsCommand command,
    MgwsPurchaseOrder order,
    List<MgwsPurchaseOrderLine> orderLines,
  ) async {
    if (orderLines.length != command.quickLoadPlan.lines.length) {
      return _ValidationResult(
        _ValidationOutcome.skipped,
        l10n.inventoryAddValidationSkipped,
      );
    }
    final form = InventoryReceiptForm(
      siteIdText: command.siteIdText,
      purchaseOrderIdText: order.id.toString(),
      documentNumberText: inventoryReceiptNumber(command.documentNumber),
      // Chiave stabile: un invio ripetuto dopo un errore di rete non crea una
      // seconda ricezione per lo stesso ordine.
      idempotencyKeyText: 'add-products-${order.id}',
      notesText: l10n.inventoryAddReceiptNote,
      statusText: 'pending_verification',
      lines: [
        for (final line in orderLines)
          InventoryReceiptLineForm(
            purchaseOrderLineIdText: line.id.toString(),
            expectedQuantityText: line.orderedQuantity.toString(),
            receivedQuantityText: line.orderedQuantity.toString(),
            rejectedQuantityText: '0',
            backorderQuantityText: '0',
          ),
      ],
    );
    final result = await receiptController.create(form);
    final receipt = receiptController.lastReceipt;
    if (result.success) {
      lastReceipt = receipt;
      return _ValidationResult(
        _ValidationOutcome.done,
        l10n.inventoryAddReceiptPending(
          '${receipt?.id ?? ''}',
          inventoryReceiptNumber(command.documentNumber),
        ),
      );
    }
    // La ricezione puo essere stata creata senza pero essere convalidata:
    // in quel caso resta su MGWS e serve conoscerne l'id.
    lastReceipt = receipt;
    return _ValidationResult(_ValidationOutcome.failed, result.message(l10n));
  }

  Future<InventoryActionFeedback> _createOrder(
    AppLocalizations l10n,
    InventoryAddProductsCommand command,
    InventoryAddProductsPlan plan,
  ) {
    return purchaseOrderController.createDraft(
      InventoryPurchaseOrderForm(
        siteIdText: command.siteIdText,
        supplierIdText: command.supplierId!.toString(),
        documentNumberText: command.documentNumber,
        warehouseIdText: (plan.warehouseId ?? 0).toString(),
        notesText: _orderNotes(l10n, plan),
      ),
    );
  }

  String _orderNotes(AppLocalizations l10n, InventoryAddProductsPlan plan) {
    final base = l10n.inventoryAddOrderNote(
      plan.enteredQuantity,
      plan.lineCount,
    );
    return plan.validated
        ? '$base ${l10n.inventoryAddOrderNoteValidated}'
        : '$base ${l10n.inventoryAddOrderNoteDraft}';
  }

  String _summary(
    AppLocalizations l10n,
    InventoryAddProductsPlan plan,
    bool success,
    String load,
  ) {
    if (!plan.isOrder) return load;
    final supplier = plan.supplierLabel;
    if (!success) {
      return plan.validated
          ? l10n.inventoryAddSummaryToCheck(load, supplier)
          : l10n.inventoryAddSummaryDraft(load, supplier);
    }
    return plan.validated
        ? l10n.inventoryAddSummaryValidated(load, supplier)
        : l10n.inventoryAddSummaryDraft(load, supplier);
  }

  InventoryActionFeedback _feedback(
    bool success,
    String message,
    List<String> details, {
    required List<String> steps,
  }) {
    lastSteps = List<String>.unmodifiable(steps);
    return remember(
      InventoryActionFeedback(
        success: success,
        message: literalText(message),
        details: literalTexts(details),
      ),
    );
  }
}

/// Esito della convalida: distingue le tre cose che possono succedere.
enum _ValidationOutcome { done, failed, skipped }

class _ValidationResult {
  const _ValidationResult(this._outcome, this.message);

  final _ValidationOutcome _outcome;
  final String message;
}

/// Numero del documento di ricezione derivato da quello dell'ordine.
///
/// L'ordine e la ricezione sono due documenti distinti, ma l'operatore ne
/// digita uno solo: il suffisso -RC li tiene separati senza chiedere un
/// secondo input.
String inventoryReceiptNumber(String documentNumber) => '$documentNumber-RC';
