// inventory_adjustment.code.dart
//
// Logica della rettifica di magazzino.
//
// La rettifica serve a mettere la quantita reale del magazzino allineata a
// quella che MGWS ha registrato. L'operatore puo muoversi in due direzioni:
//  - [InventoryRettificaDirection.increase]: mancano pezzi (incremento)
//  - [InventoryRettificaDirection.decrease]: pezzi in eccesso o spariti
//
// Il dato autorevole resta MGWS: qui si prepara il comando e si delega a
// [InventoryController.reconcileStock], che conosce gia' disponibilita' del
// backend e rotta di riconciliazione.

import '../login/mgws/query/query_mgws_inventory.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';

enum InventoryRettificaDirection {
  increase('Aumenta', 'Manca merce: porto lo stock al valore reale piu alto.'),
  decrease(
    'Diminuisci',
    'Merce in eccesso: porto lo stock al valore reale piu basso.',
  );

  const InventoryRettificaDirection(this.label, this.description);

  final String label;
  final String description;
}

/// Una riga di stock letta da MGWS, con il dettaglio delle ubicazioni.
class InventoryStockLevel {
  const InventoryStockLevel({
    required this.siteId,
    required this.warehouseId,
    required this.qty,
    required this.locationLabel,
  });

  final int siteId;
  final int warehouseId;
  final int qty;
  final String locationLabel;

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}'.trim()) ?? 0;

  static String _text(Object? value) => '${value ?? ''}'.trim();

  static InventoryStockLevel fromRecord(Map<String, dynamic> record) {
    final room = _text(record['room']);
    final rack = _text(record['rack']);
    final shelf = _text(record['shelf']);
    final parts = [
      if (room.isNotEmpty) 'Stanza $room',
      if (rack.isNotEmpty) 'Scaffale $rack',
      if (shelf.isNotEmpty) 'Ripiano $shelf',
    ];
    return InventoryStockLevel(
      siteId: _int(record['site_id']),
      warehouseId: _int(record['warehouse_id']),
      qty: _int(record['qty']),
      locationLabel: parts.isEmpty ? 'Nessuna ubicazione' : parts.join(' · '),
    );
  }
}

/// Foto dello stock di un prodotto, come la restituisce MGWS.
class InventoryStockSnapshot {
  const InventoryStockSnapshot({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.levels,
    this.variationId = 0,
  });

  final int productId;
  final int variationId;
  final String productName;
  final int currentStock;
  final List<InventoryStockLevel> levels;

  /// Pezzi di questo prodotto nella sede indicata.
  ///
  /// [currentStock] e' il totale del prodotto, cioe' la somma di tutte le sedi. Su
  /// una rettifica, che scrive il totale di una sola sede, quel numero non
  /// descrive niente di quello che sta per succedere: se l'operatore dichiarasse
  /// il totale che vede, il backend lo confronterebbe con il totale della sua sede
  /// e troverebbe una differenza, e quella differenza si tradurrebbe in pezzi
  /// spostati o spariti per sbaglio. Il numero da mostrare e da dichiarare e' quello
  /// di qui, che e' l'unico dentro cui la rettifica puo' muovere lo stock.
  int stockAtSite(int siteId) {
    if (siteId <= 0) return 0;
    return levels
        .where((level) => level.siteId == siteId)
        .fold<int>(0, (sum, level) => sum + level.qty);
  }

  /// Sedi in cui questo prodotto ha pezzi, in ordine di magazzino come arriva.
  ///
  /// Serve a proporre una sede all'operatore invece di chiedergli un numero. Le
  /// sedi elencate sono solo quelle dove c'e' merce: proporre una sede vuota come
  /// prima scelta sarebbe proporre di spostare un numero che non c'entra con la
  /// merce che l'operatore sta guardando.
  List<int> get sitesWithStock {
    final sites = <int>[];
    for (final level in levels) {
      if (level.siteId > 0 && !sites.contains(level.siteId)) {
        sites.add(level.siteId);
      }
    }
    return List<int>.unmodifiable(sites);
  }

  String get label =>
      productName.trim().isEmpty ? 'Prodotto #$productId' : productName.trim();

  static int _int(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}'.trim()) ?? 0;

  static InventoryStockSnapshot? fromRecord(Map<String, dynamic>? record) {
    if (record == null || record.isEmpty) return null;
    final rawLevels = record['locations'];
    final levels = <InventoryStockLevel>[];
    if (rawLevels is List) {
      for (final item in rawLevels) {
        if (item is Map) {
          levels.add(
            InventoryStockLevel.fromRecord(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return InventoryStockSnapshot(
      productId: _int(record['product_id']),
      variationId: _int(record['variation_id']),
      productName: '${record['product_name'] ?? ''}'.trim(),
      currentStock: _int(record['current_stock']),
      levels: List<InventoryStockLevel>.unmodifiable(levels),
    );
  }
}

/// Una riga di rettifica: un prodotto e la correzione che vuole subire.
///
/// La correzione si puo' esprimere in due modi, come prima: un delta con verso
/// (incremento o diminuzione) oppure il valore assoluto contato sullo scaffale.
class InventoryRettificaLine {
  const InventoryRettificaLine({
    required this.productId,
    required this.label,
    this.variationId = 0,
    this.direction = InventoryRettificaDirection.increase,
    this.snapshot,
    this.delta = 0,
    this.correctStock,
    this.siteId = 0,
  });

  final int productId;
  final int variationId;

  /// Sede su cui opera la correzione.
  ///
  /// Una rettifica scrive il totale di una sede, quindi il numero da cui parte e
  /// quello a cui arriva sono entrambi di quella sede. Senza questo campo la riga
  /// confronterebbe il totale del prodotto con il totale che il backend applice'
  /// a una sola sede, e la differenza risulterebbe non nulla anche quando
  /// l'operatore non ha sbagliato niente.
  final int siteId;

  /// Nome del prodotto: serve nei messaggi, perche' MGWS risponde con gli id.
  final String label;
  final InventoryRettificaDirection direction;
  final InventoryStockSnapshot? snapshot;

  /// Quanti pezzi correggere. Il segno lo decide [direction], cosi'
  /// l'operatore sceglie prima il verso e poi quanto.
  final int delta;

  /// Se valorizzato vince sul delta: e' il conteggio reale.
  final int? correctStock;

  /// Chiave usata dal pannello per tenere insieme riga e stato: stessa
  /// identita' di [InventoryQuickLoadLineDraft.key], cosi' i due moduli
  /// parlano dello stesso prodotto senza una mappa di traduzione.
  String get key => '$productId:$variationId';

  int get previousStock {
    final snapshot = this.snapshot;
    if (snapshot == null) return 0;
    // Zero vuol dire "ancora nessuna sede scelta" e il totale e' quello del
    // prodotto: e' il valore con cui la riga si presenta appena letta, prima che
    // l'operatore scelga la sede. Il piano non lascia filare zero al submit, per
    //che' sul wire la sede e' sempre dichiarata.
    return siteId > 0 ? snapshot.stockAtSite(siteId) : snapshot.currentStock;
  }

  /// Delta con segno, come verra' applicato allo stock.
  int get signedDelta =>
      direction == InventoryRettificaDirection.increase ? delta : -delta;

  int get targetStock {
    final absolute = correctStock;
    if (absolute != null) return absolute;
    final next = previousStock + signedDelta;
    return next < 0 ? 0 : next;
  }

  int get effectiveDelta => targetStock - previousStock;

  bool get hasDelta => effectiveDelta != 0;

  bool get isIncrease => effectiveDelta > 0;

  String directionName([AppLocalizations? l10n]) => l10n == null
      ? (isIncrease ? 'incremento' : 'diminuzione')
      : (isIncrease
            ? l10n.inventoryRettificaDirectionIncrease
            : l10n.inventoryRettificaDirectionDecrease);

  InventoryRettificaLine copyWith({
    InventoryRettificaDirection? direction,
    InventoryStockSnapshot? snapshot,
    int? delta,
    int? correctStock,
    bool clearCorrectStock = false,
    int? siteId,
  }) {
    return InventoryRettificaLine(
      productId: productId,
      variationId: variationId,
      label: label,
      direction: direction ?? this.direction,
      snapshot: snapshot ?? this.snapshot,
      delta: delta ?? this.delta,
      correctStock: clearCorrectStock
          ? null
          : (correctStock ?? this.correctStock),
      siteId: siteId ?? this.siteId,
    );
  }
}

/// Un prodotto che era nel movimento riaperto e che l'operatore non ha
/// confermato.
///
/// Toglierlo dalla lista non puo' valere come "non me ne occupo": il movimento
/// che si sta modificando ha gia' cambiato il suo stock, quindi senza un
/// ripristino il prodotto resterebbe con la quantita' di quel movimento. Per
/// questo finisce nel piano come ripristino esplicito.
///
/// Il ripristino parte solo se il prodotto e' ancora dove lo aveva lasciato
/// quel movimento. Se nel frattempo qualcun altro lo ha toccato, riportarlo al
/// valore di prima azzererebbe anche quell'altra operazione: meglio fermarsi e
/// dirlo.
class InventoryRettificaRestoreLine {
  const InventoryRettificaRestoreLine({
    required this.productId,
    required this.variationId,
    required this.label,
    required this.stockBefore,
    required this.stockAfter,
    this.movementId,
    this.snapshot,
  });

  final int productId;
  final int variationId;
  final String label;

  /// Movimento originale: serve a costruire un motivo che dica da dove si
  /// torna, altrimenti nel ledger il ripristino sembrerebbe una rettifica
  /// qualunque.
  final int? movementId;

  /// Stock che il prodotto aveva prima del movimento riaperto. `null` se MGWS
  /// non lo ha registrato: senza il valore di partenza non c'e' niente da
  /// ripristinare.
  final int? stockBefore;

  /// Stock che il movimento gli aveva lasciato: se il prodotto e' ancora qui,
  /// il ripristino e' lecito.
  final int? stockAfter;

  /// Stock letto adesso dal pannello, quando c'e'.
  final InventoryStockSnapshot? snapshot;

  String get key => '$productId:$variationId';

  /// Perche' il ripristino non parte, quando non parte. `null` se parte.
  String? blockReason([AppLocalizations? l10n]) {
    if (stockBefore == null) {
      return l10n?.inventoryRettificaBlockMissingBefore ??
          "MGWS non ha registrato lo stock precedente, non c'e' nulla da ripristinare";
    }
    if (stockAfter == null) {
      return l10n?.inventoryRettificaBlockMissingAfter ??
          'MGWS non ha registrato lo stock lasciato dal movimento';
    }
    final current = snapshot;
    if (current == null) {
      return l10n?.inventoryRettificaBlockMissingCurrent ??
          'non ho ancora lo stock attuale del prodotto, caricalo e riprova';
    }
    if (current.currentStock != stockAfter) {
      return l10n == null
          ? "lo stock e' ora ${current.currentStock}, non $stockAfter: un movimento successivo ha gia' toccato questo prodotto"
          : l10n.inventoryRettificaBlockStockChanged(
              '${current.currentStock}',
              '$stockAfter',
            );
    }
    return null;
  }

  bool get canRestore {
    final current = snapshot;
    return stockBefore != null &&
        stockAfter != null &&
        current != null &&
        current.currentStock == stockAfter;
  }
}

/// Cosa vuole ottenere l'operatore, su uno o piu' prodotti.
///
/// Un piano per riga: ogni prodotto ha la sua correzione, e il motivo e' uno
/// solo perche' l'operatore sta facendo una sola operazione di magazzino.
class InventoryRettificaPlan {
  const InventoryRettificaPlan({
    required this.lines,
    this.details = '',
    this.restores = const [],
    this.siteIdText = '',
    this.documentNumberText = '',
  });

  final List<InventoryRettificaLine> lines;

  /// Sede su cui si corregge, come testo del campo che l'operatore vede.
  ///
  /// Va dichiarata sempre, anche per un amministratore che puo' lavorare su tutte
  /// le sedi: e' lui che sceglie quale, e una scelta che il backend fa al posto suo
  /// non e' una scelta. Chi ha una sede di riferimento la trova gia' compilata e
  /// non modificabile, e il valore arriva comunque da qui.
  final String siteIdText;

  /// Sede letta dal campo, o zero se non contiene un intero positivo.
  int get siteId =>
      InventoryInputParser.parseOptionalPositiveInt(siteIdText) ?? 0;

  /// Prodotti del movimento riaperto che l'operatore ha tolto: tornano al
  /// valore di prima invece di restare con quello del movimento.
  final List<InventoryRettificaRestoreLine> restores;

  /// Dettagli scritti una volta sola a pagina, sopra il pannello.
  ///
  /// Testo operativo scritto una volta sola a pagina, sopra il pannello. Sostituisce
  /// il vecchio campo motivo locale della rettifica.
  final String details;
  final String documentNumberText;

  int get lineCount => lines.length;

  /// Correzioni nulle: righe che non muoverebbero niente. Devono stare a zero
  /// perche' inviare una riconciliazione a se stessa e' rumore sul ledger.
  int get unchangedCount => lines.where((line) => !line.hasDelta).length;

  /// Il pulsante di invio si abilita solo con un piano completo: almeno un
  /// prodotto da correggere o da rimettere a posto, una sede e una
  /// correzione su ognuno. Con piu' righe basta che una manchi per tenere il
  /// pulsante spento, altrimenti l'operatore scoprirebbe solo al submit che meta'
  /// del piano e' andata a terra.
  ///
  /// La sede e' nella stessa lista perche' senza di lei il backend rifiuta la
  /// richiesta: meglio un pulsante spento con una spiegazione qui, che un
  /// invio che torna indietro con un errore che l'operatore non puo' collegare a
  /// nulla che abbia scritto.
  bool get canSubmit =>
      (lines.isNotEmpty || restores.isNotEmpty) &&
      siteId > 0 &&
      lines.every((line) => line.hasDelta) &&
      restores.every((line) => line.canRestore);

  /// Motivo passato a MGWS per una riga: la correzione resta leggibile nel
  /// ledger anche senza aprire l'app, e i dettagli dell'operatore viaggiano
  /// con lei perche' il backend ha un solo campo libero.
  String reasonTextFor(InventoryRettificaLine line, [AppLocalizations? l10n]) {
    final sign = line.isIncrease ? '+' : '';
    final base = l10n == null
        ? 'Rettifica ${line.directionName()}: ${line.previousStock} -> '
              '${line.targetStock} (delta $sign${line.effectiveDelta}). '
              '${details.trim()}'
        : l10n.inventoryRettificaReasonAdjustment(
            line.directionName(l10n),
            '${line.previousStock}',
            '${line.targetStock}',
            '$sign${line.effectiveDelta}',
            details.trim(),
          );
    final document = documentNumberText.trim();
    return document.isEmpty ? base : '$base [$document]';
  }

  /// Motivo del ripristino: dice da quale movimento si torna indietro,
  /// altrimenti nel ledger sembrerebbe una correzione senza origine.
  String restoreReasonTextFor(
    InventoryRettificaRestoreLine line, [
    AppLocalizations? l10n,
  ]) {
    final origin = line.movementId;
    final movement = origin == null
        ? ''
        : (l10n?.inventoryRettificaReasonMovementSuffix('$origin') ??
              ' (movimento #$origin)');
    return l10n == null
        ? 'Prodotto tolto dalla modifica: riporto stock da '
              '${line.stockAfter} a ${line.stockBefore}'
              '$movement. ${details.trim()}'
        : l10n.inventoryRettificaReasonRestore(
            '${line.stockAfter}',
            '${line.stockBefore}',
            movement,
            details.trim(),
          );
  }

  /// `movementKey` identifica l'operazione a cui appartengono le righe.
  ///
  /// Va passata identica su tutte, correzioni e ripristini insieme: sono lo
  /// stesso gesto fatto dall'operatore in un momento solo, e dividerli renderebbe
  /// lo storico una lista di pezzi invece di una lista di operazioni.
  InventoryFormParse<List<InventoryRettificaCommand>> parse({
    String? movementKey,
    AppLocalizations? l10n,
  }) {
    if (lines.isEmpty && restores.isEmpty) {
      return InventoryFormInvalid(
        l10n?.inventoryRettificaInvalidNoProducts ??
            'Seleziona almeno un prodotto',
      );
    }
    if (siteId <= 0) {
      return InventoryFormInvalid(
        l10n?.inventoryRettificaInvalidSiteRequired ??
            'Sede richiesta: la rettifica corregge il totale di una sede, e la sede va detta',
      );
    }
    final commands = <InventoryRettificaCommand>[];
    for (final line in lines) {
      if (line.productId <= 0) {
        return InventoryFormInvalid(
          l10n?.inventoryRettificaInvalidProductId ?? 'product_id non valido',
        );
      }
      if (!line.hasDelta) {
        return InventoryFormInvalid(
          l10n?.inventoryRettificaInvalidNoDelta(line.label) ??
              'Correzione nulla per ${line.label}: nessun delta',
        );
      }
      if (line.snapshot == null && line.correctStock == null) {
        return InventoryFormInvalid(
          l10n?.inventoryRettificaInvalidLoadStock(line.label) ??
              'Carica lo stock di ${line.label}',
        );
      }
      commands.add(
        InventoryRettificaCommand(
          productId: line.productId,
          correctStock: line.targetStock,
          reason: reasonTextFor(line, l10n),
          siteId: siteId,
          movementKey: movementKey,
        ),
      );
    }
    for (final line in restores) {
      final blocked = line.blockReason(l10n);
      if (blocked != null) {
        return InventoryFormInvalid(
          l10n?.inventoryRettificaInvalidBlocked(line.label, blocked) ??
              '${line.label}: $blocked',
        );
      }
      commands.add(
        InventoryRettificaCommand(
          productId: line.productId,
          correctStock: line.stockBefore!,
          reason: restoreReasonTextFor(line, l10n),
          siteId: siteId,
          movementKey: movementKey,
        ),
      );
    }
    return InventoryFormValid(
      List<InventoryRettificaCommand>.unmodifiable(commands),
    );
  }
}

class InventoryRettificaCommand {
  const InventoryRettificaCommand({
    required this.productId,
    required this.correctStock,
    required this.reason,
    required this.siteId,
    this.movementKey,
  });

  final int productId;
  final int correctStock;
  final String reason;

  /// Sede su cui il backend deve scrivere il totale. Va su ogni riga anche se e'
  /// sempre la stessa: e' la dichiarazione dell'ambito, e una riga senza
  /// significherebbe un totale di cui non si sa quale sia.
  final int siteId;

  /// Chiave dell'operazione. Condivisa da tutte le righe dello stesso invio.
  final String? movementKey;
}

class InventoryRettificaController with InventoryFeedbackController {
  InventoryRettificaController({InventoryController? inventory})
    : inventory = inventory ?? InventoryController();

  final InventoryController inventory;

  /// Foto dello stock appena letta. In un piano multi-prodotto vale per
  /// l'ultimo prodotto caricato: ogni riga del pannello porta con se' la
  /// propria, quindi qui resta solo per l'uso leggero e per i test.
  InventoryStockSnapshot? lastSnapshot;

  /// Esiti delle riconciliazioni, uno per prodotto nell'ordine di invio.
  List<MgwsReconcileResult> lastResults = const [];

  MgwsReconcileResult? lastResult;
  bool isLoading = false;
  bool isSubmitting = false;

  /// Carica lo stock MGWS del prodotto indicato.
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

  /// Applica la rettifica. E l'unica azione di questo modulo che tocca lo
  /// stock, ed e sempre autorizzata da un motivo.
  ///
  /// Le righe vanno in sequenza e non si fermano al primo errore: fermarsi
  /// lascerebbe meta' dei prodotti corretti e l'operatore senza un elenco di
  /// cosa e' passato e cosa no. Ogni riga e' un prodetto indipendente, quindi
  /// un fallimento non invalida le altre.
  Future<InventoryActionFeedback> submit(
    AppLocalizations l10n,
    InventoryRettificaPlan plan,
  ) async {
    if (isSubmitting) return invalid('Rettifica gia in corso');
    // Una chiave per invio: la rettifica di cinque prodotti e' un movimento, non
    // cinque. Le righe che falliscono portano la stessa chiave di quelle che
    // passano, cosi' lo storico mostra quello che e' successo e non quello che si
    // sperava.
    final parsed = plan.parse(
      l10n: l10n,
      movementKey: newInventoryMovementKey(),
    );
    switch (parsed) {
      case InventoryFormInvalid(:final message):
        return invalid(message);
      case InventoryFormValid(value: final commands):
        isSubmitting = true;
        final results = <MgwsReconcileResult>[];
        final steps = <String>[];
        final details = <String>[];
        var failed = 0;
        try {
          for (final command in commands) {
            final feedback = await inventory.reconcileStock(
              productIdText: '${command.productId}',
              correctStockText: '${command.correctStock}',
              siteIdText: '${command.siteId}',
              reasonText: command.reason,
              movementKey: command.movementKey,
            );
            final result = inventory.lastReconcileResult;
            if (result != null) results.add(result);
            if (feedback.success) {
              steps.add(
                'Prodotto ${command.productId}: stock '
                '${result?.previousStock ?? '?'} -> ${command.correctStock}',
              );
            } else {
              failed++;
              details.add('Prodotto ${command.productId}: ${feedback.message}');
            }
          }
          lastResults = List<MgwsReconcileResult>.unmodifiable(results);
          lastResult = results.isEmpty ? null : results.last;
          lastSnapshot = null;
          return remember(
            InventoryActionFeedback(
              success: failed == 0,
              message: failed == 0
                  ? 'Rettifica applicata a ${commands.length} prodotti'
                  : 'Rettifica parziale: ${commands.length - failed} su '
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
