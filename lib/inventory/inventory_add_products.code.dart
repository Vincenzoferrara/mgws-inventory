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
    if (siteId == null) return const InventoryFormInvalid('Sede richiesta');
    if (isOrder) {
      if (supplier == null) {
        return const InventoryFormInvalid('Seleziona il fornitore');
      }
      if (documentNumberText.trim().isEmpty) {
        return const InventoryFormInvalid('numero documento richiesto');
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

  Future<InventoryActionFeedback> submit(InventoryAddProductsPlan plan) async {
    if (isSubmitting) return invalid('Aggiunta prodotti gia in corso');
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
            final draft = await _createOrder(command, plan);
            order = purchaseOrderController.lastPurchaseOrder;
            if (!draft.success) {
              // Nessun carico eseguito: l'ordine non e nato, quindi si
              // lascia lo stock intatto invece di registrare pezzi senza
              // documento.
              return _feedback(
                false,
                'Aggiunta interrotta: nessun carico eseguito',
                [draft.message, ...draft.details],
                steps: steps,
              );
            }
            steps.add('Bozza ordine ${command.documentNumber} creata');

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
                details.add('Riga ordine "${line.label}": ${saved.message}');
              } else {
                orderLines.add(savedLine);
              }
            }
            steps.add(
              'Righe ordine registrate: ${orderLines.length}'
              '/${command.quickLoadPlan.lines.length}',
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
              steps.add('Ordine ${order.id} messo in attesa verifica');
            } else {
              orderOk = false;
              details.add('Stato pending ordine: ${pending.message}');
            }
            final received = await _creaRicezioneInVerifica(
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
                details.add('Ricezione in verifica: ${received.message}');
              case _ValidationOutcome.done:
                steps.add(received.message);
            }
            load = InventoryActionFeedback(
              success: orderOk,
              message: 'Stock in attesa approvazione manager',
              details: const [],
            );
          } else {
            // Passo reale per carico semplice o ordine non verificato.
            load = await quickLoadController.submitPlan(command.quickLoadPlan);
            if (load.success) {
              steps.add(
                'Carico eseguito: ${command.quickLoadPlan.lines.length} righe, '
                '${command.quickLoadPlan.totalQuantity} pezzi',
              );
            }
          }

          if (order != null) lastOrder = order;
          final success = load.success && orderOk;
          return _feedback(success, _summary(plan, success, load.message), [
            ...details,
            ...load.details,
          ], steps: steps);
        } finally {
          isSubmitting = false;
        }
    }
  }

  /// Registra la ricezione della merce sull'ordine e la lascia in verifica.
  /// Non muove stock: il carico reale avviene solo con approvazione manager.
  Future<_ValidationResult> _creaRicezioneInVerifica(
    InventoryAddProductsCommand command,
    MgwsPurchaseOrder order,
    List<MgwsPurchaseOrderLine> orderLines,
  ) async {
    if (orderLines.length != command.quickLoadPlan.lines.length) {
      return const _ValidationResult(
        _ValidationOutcome.skipped,
        'Convalida saltata: ordine incompleto',
      );
    }
    final form = InventoryReceiptForm(
      siteIdText: command.siteIdText,
      purchaseOrderIdText: order.id.toString(),
      documentNumberText: inventoryReceiptNumber(command.documentNumber),
      // Chiave stabile: un invio ripetuto dopo un errore di rete non crea una
      // seconda ricezione per lo stesso ordine.
      idempotencyKeyText: 'add-products-${order.id}',
      notesText: 'Ricezione generata da aggiunta prodotti, in attesa verifica.',
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
        'Ricezione ${receipt?.id ?? ''} '
        '${inventoryReceiptNumber(command.documentNumber)} in attesa verifica',
      );
    }
    // La ricezione puo essere stata creata senza pero essere convalidata:
    // in quel caso resta su MGWS e serve conoscerne l'id.
    lastReceipt = receipt;
    return _ValidationResult(_ValidationOutcome.failed, result.message);
  }

  Future<InventoryActionFeedback> _createOrder(
    InventoryAddProductsCommand command,
    InventoryAddProductsPlan plan,
  ) {
    return purchaseOrderController.createDraft(
      InventoryPurchaseOrderForm(
        siteIdText: command.siteIdText,
        supplierIdText: command.supplierId!.toString(),
        documentNumberText: command.documentNumber,
        warehouseIdText: (plan.warehouseId ?? 0).toString(),
        notesText: _orderNotes(plan),
      ),
    );
  }

  String _orderNotes(InventoryAddProductsPlan plan) {
    final base =
        'Aggiunta prodotti: ${plan.enteredQuantity} pezzi '
        'su ${plan.lineCount} righe.';
    return plan.validated
        ? '$base Ordine convalidato.'
        : '$base Ordine in bozza, da convalidare.';
  }

  String _summary(InventoryAddProductsPlan plan, bool success, String load) {
    if (!plan.isOrder) return load;
    final supplier = plan.supplierLabel;
    if (!success) {
      return plan.validated
          ? '$load; ordine $supplier da controllare'
          : '$load; ordine $supplier salvato in bozza';
    }
    return plan.validated
        ? '$load; ordine $supplier convalidato'
        : '$load; ordine $supplier salvato in bozza';
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
        message: message,
        details: details,
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
