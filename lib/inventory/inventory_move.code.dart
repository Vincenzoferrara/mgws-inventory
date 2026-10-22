// inventory_move.code.dart
//
// Logica dello spostamento tra sedi fisiche.
//
// Lo spostamento sposta pezzi da un magazzino a un altro lasciando invariato
// lo stock totale del prodotto. Per questo NON passa da reconcileStock, che
// azzererebbe il totale: chiama [InventoryController.moveStock] e usa la
// rotta dedicata /inventory/stock/move.
//
// Origine e destinazione sono scelte fra le ubicazioni che MGWS conosce gia'
// per quel prodotto ([InventoryStockLevel]): non si inventano sedi.

import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory.code.dart';

/// Una riga di spostamento: un prodotto, da dove parte, dove arriva e quanti
/// pezzi si muovono.
///
/// Ogni prodotto ha la sua rotta: due magazzini possono ricevere lo stesso
/// prodotto in due righe diverse senza che le rotte si tocchino.
class InventoryMoveLine {
  const InventoryMoveLine({
    required this.productId,
    required this.label,
    this.variationId = 0,
    this.snapshot,
    this.source,
    this.destinationSiteIdText = '',
    this.destinationWarehouseIdText = '',
    this.quantity = 0,
  });

  final int productId;
  final int variationId;
  final String label;

  /// Foto dello stock del prodotto: serve a sapere da dove si puo' partire e
  /// quanti pezzi ci sono davvero.
  final InventoryStockSnapshot? snapshot;

  /// Ubicazione di partenza, scelta fra quelle con pezzi disponibili.
  final InventoryStockLevel? source;

  final String destinationSiteIdText;
  final String destinationWarehouseIdText;
  final int quantity;

  /// Stessa identita' della riga del pannello, cosi' i due moduli parlano
  /// dello stesso prodotto senza una mappa di traduzione.
  String get key => '$productId:$variationId';

  int? get destinationSiteId =>
      InventoryInputParser.parseOptionalPositiveInt(destinationSiteIdText);

  int get destinationWarehouseId =>
      InventoryInputParser.parseOptionalNonNegativeInt(
        destinationWarehouseIdText,
      ) ??
      0;

  /// Le due ubicazioni sono la stessa, quindi spostare non avrebbe senso.
  bool get isSameLocation =>
      source != null &&
      destinationSiteId != null &&
      source!.siteId == destinationSiteId &&
      source!.warehouseId == destinationWarehouseId;

  /// Pezzi disponibili nel magazzino di partenza.
  int get availableInSource => source?.qty ?? 0;

  /// Pezzi che restano nel magazzino di partenza dopo lo spostamento.
  int get remainingInSource => availableInSource - quantity;

  bool get hasStock => snapshot != null;

  /// Solo le ubicazioni che hanno davvero pezzi: si puo' partire da una
  /// scaffale vuota solo se non c'e' nient'altro.
  List<InventoryStockLevel> get availableLevels =>
      snapshot?.levels.where((level) => level.qty > 0).toList() ??
      const <InventoryStockLevel>[];

  /// Il pulsante di invio si abilita solo con una riga completa e coerente.
  bool get canSubmit {
    if (productId <= 0) return false;
    if (source == null) return false;
    if (destinationSiteId == null) return false;
    if (isSameLocation) return false;
    if (quantity <= 0) return false;
    if (quantity > availableInSource) return false;
    return true;
  }

  /// Motivo passato a MGWS per la riga: origine, destinazione e pezzi devono
  /// restare leggibili nel ledger anche senza aprire l'app.
  String reasonTextFor(String reason) {
    final from = source;
    final destination = destinationSiteId;
    if (from == null || destination == null) return reason.trim();
    final head =
        'Sposta $quantity pezzi: sede $destination '
        'magazzino $destinationWarehouseId -> sede ${from.siteId} '
        'magazzino ${from.warehouseId}.';
    final room = from.locationLabel.trim();
    final tail = room.isEmpty || room == 'Nessuna ubicazione'
        ? reason.trim()
        : '${reason.trim()} [$room]';
    return '$head $tail';
  }

  InventoryMoveLine copyWith({
    InventoryStockSnapshot? snapshot,
    InventoryStockLevel? source,
    String? destinationSiteIdText,
    String? destinationWarehouseIdText,
    int? quantity,
  }) {
    return InventoryMoveLine(
      productId: productId,
      variationId: variationId,
      label: label,
      snapshot: snapshot ?? this.snapshot,
      source: source ?? this.source,
      destinationSiteIdText:
          destinationSiteIdText ?? this.destinationSiteIdText,
      destinationWarehouseIdText:
          destinationWarehouseIdText ?? this.destinationWarehouseIdText,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Cosa vuole ottenere l'operatore: spostare pezzi su uno o piu' prodotti.
///
/// Il motivo e' uno solo perche' e' una sola operazione di magazzino; origine
/// e destinazione stanno nella riga, perche' cambiano da prodotto a prodotto.
class InventoryMovePlan {
  const InventoryMovePlan({required this.lines, this.details = ''});

  final List<InventoryMoveLine> lines;

  /// Dettagli scritti una volta sola a pagina, sopra il pannello.
  ///
  /// Testo operativo scritto una volta sola a pagina, sopra il pannello. Sostituisce
  /// il vecchio campo motivo locale dello spostamento.
  final String details;

  int get lineCount => lines.length;
  int get totalQuantity =>
      lines.fold<int>(0, (sum, line) => sum + line.quantity);

  /// Il pulsante di invio si abilita solo con un piano completo: almeno un
  /// prodotto e una rotta valida su ognuno. Il testo libero vive nel Dettaglio
  /// globale della pagina inventario.
  bool get canSubmit =>
      lines.isNotEmpty && lines.every((line) => line.canSubmit);

  /// `movementKey` identifica l'operazione a cui appartengono le righe.
  ///
  /// Va passata identica su tutte: uno spostamento di quattro prodotti e' un
  /// movimento solo, anche se il backend ne scrive otto righe, due per prodotto.
  InventoryFormParse<List<InventoryMoveCommand>> parse({String? movementKey}) {
    if (lines.isEmpty) {
      return const InventoryFormInvalid('Seleziona almeno un prodotto');
    }
    final commands = <InventoryMoveCommand>[];
    for (final line in lines) {
      if (line.productId <= 0) {
        return const InventoryFormInvalid('product_id non valido');
      }
      if (line.source == null) {
        return InventoryFormInvalid(
          'Scegli il magazzino di partenza per ${line.label}',
        );
      }
      if (line.destinationSiteId == null) {
        return InventoryFormInvalid(
          'Sede di destinazione non valida per ${line.label}',
        );
      }
      if (line.isSameLocation) {
        return InventoryFormInvalid(
          'Origine e destinazione sono la stessa per ${line.label}',
        );
      }
      if (line.quantity <= 0) {
        return InventoryFormInvalid(
          'Quantita da spostare non valida per ${line.label}',
        );
      }
      if (line.quantity > line.availableInSource) {
        return InventoryFormInvalid(
          'Per ${line.label} nel magazzino di partenza ci sono solo '
          '${line.availableInSource} pezzi',
        );
      }
      commands.add(
        InventoryMoveCommand(
          productId: line.productId,
          fromSiteId: line.source!.siteId,
          fromWarehouseId: line.source!.warehouseId,
          toSiteId: line.destinationSiteId!,
          toWarehouseId: line.destinationWarehouseId,
          quantity: line.quantity,
          reason: line.reasonTextFor(details),
          movementKey: movementKey,
        ),
      );
    }
    return InventoryFormValid(
      List<InventoryMoveCommand>.unmodifiable(commands),
    );
  }
}

class InventoryMoveCommand {
  const InventoryMoveCommand({
    required this.productId,
    required this.fromSiteId,
    required this.fromWarehouseId,
    required this.toSiteId,
    required this.toWarehouseId,
    required this.quantity,
    required this.reason,
    this.movementKey,
  });

  final int productId;
  final int fromSiteId;
  final int fromWarehouseId;
  final int toSiteId;
  final int toWarehouseId;
  final int quantity;
  final String reason;

  /// Chiave dell'operazione. Condivisa da tutte le righe dello stesso invio, cosi'
  /// che i due lati dello spostamento di un prodotto restino uniti.
  final String? movementKey;
}

class InventoryMoveController with InventoryFeedbackController {
  InventoryMoveController({InventoryController? inventory})
    : inventory = inventory ?? InventoryController();

  final InventoryController inventory;

  /// Foto dello stock appena letta. In un piano multi-prodotto vale per
  /// l'ultimo prodotto caricato: ogni riga del pannello porta con se' la
  /// propria, quindi qui resta solo per l'uso leggero e per i test.
  InventoryStockSnapshot? lastSnapshot;

  /// Esiti degli spostamenti, uno per prodotto nell'ordine di invio.
  List<MgwsMoveResult> lastResults = const [];

  MgwsMoveResult? lastResult;
  bool isLoading = false;
  bool isSubmitting = false;

  /// Carica lo stock MGWS del prodotto indicato: da li' l'operatore sceglie il
  /// magazzino di partenza fra le ubicazioni che hanno pezzi.
  Future<InventoryActionFeedback> loadStock(String productIdText) async {
    if (isLoading) return invalid('Caricamento stock gia in corso');
    final productId = InventoryInputParser.parseProductId(productIdText);
    if (productId == null) return invalid('product_id non valido');

    isLoading = true;
    try {
      final feedback = await inventory.loadStock(productIdText: '$productId');
      if (!feedback.success) return remember(feedback);
      final snapshot = InventoryStockSnapshot.fromRecord(
        inventory.stockRows.isEmpty ? null : inventory.stockRows.first,
      );
      if (snapshot == null) {
        return invalid(
          'MGWS non ha restituito stock per il prodotto $productId',
        );
      }
      lastSnapshot = snapshot;
      return remember(
        InventoryActionFeedback(
          success: true,
          message: 'Stock ${snapshot.label}: ${snapshot.currentStock} pezzi',
        ),
      );
    } finally {
      isLoading = false;
    }
  }

  void clear() {
    lastSnapshot = null;
    lastResult = null;
    lastResults = const [];
  }

  /// Esegue gli spostamenti, uno per riga.
  ///
  /// Le righe vanno in sequenza e non si fermano al primo errore: ogni
  /// prodotto e' indipendente, quindi un fallimento non invalida gli altri e
  /// l'operatore riceve l'elenco di cosa e' passato e cosa no.
  Future<InventoryActionFeedback> submit(InventoryMovePlan plan) async {
    if (isSubmitting) return invalid('Spostamento gia in corso');
    // Una chiave per invio: quattro prodotti spostati insieme sono un movimento
    // solo, anche se il backend ne scrive otto righe.
    final parsed = plan.parse(movementKey: newInventoryMovementKey());
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(value: final commands):
        isSubmitting = true;
        final results = <MgwsMoveResult>[];
        final steps = <String>[];
        final details = <String>[];
        var failed = 0;
        try {
          for (final command in commands) {
            final feedback = await inventory.moveStock(
              productIdText: '${command.productId}',
              fromSiteIdText: '${command.fromSiteId}',
              fromWarehouseIdText: '${command.fromWarehouseId}',
              toSiteIdText: '${command.toSiteId}',
              toWarehouseIdText: '${command.toWarehouseId}',
              quantityText: '${command.quantity}',
              reasonText: command.reason,
              // I dettagli hanno un campo proprio su questa rotta, quindi non
              // viaggiano agganciati al motivo come fanno le altre due: nello
              // storico "perche'" e "quale circostanza" restano due fatti.
              note: plan.details.trim(),
              movementKey: command.movementKey,
            );
            final result = inventory.lastMoveResult;
            if (result != null) results.add(result);
            if (feedback.success) {
              steps.add(
                'Prodotto ${command.productId}: ${command.quantity} pezzi da '
                'sede ${command.fromSiteId} a sede ${command.toSiteId}',
              );
            } else {
              failed++;
              details.add('Prodotto ${command.productId}: ${feedback.message}');
            }
          }
          lastResults = List<MgwsMoveResult>.unmodifiable(results);
          lastResult = results.isEmpty ? null : results.last;
          lastSnapshot = null;
          return remember(
            InventoryActionFeedback(
              success: failed == 0,
              message: failed == 0
                  ? 'Spostati ${plan.totalQuantity} pezzi su '
                        '${commands.length} prodotti'
                  : 'Spostamento parziale: ${commands.length - failed} su '
                        '${commands.length} prodotti',
              details: [for (final step in steps) '· $step', ...details],
            ),
          );
        } finally {
          isSubmitting = false;
        }
    }
  }
}
