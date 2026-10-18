// inventory_movement_groups.code.dart
//
// Il ledger MGWS letto per operazione, non per prodotto.
//
// MGWS restituisce una riga per prodotto: una rettifica su tre prodotti sono
// tre movimenti. L'operatore ragiona per operazione ("quel carico di ieri
// sera"), quindi qui i movimenti che condividono origine e documento vengono
// accorpati in un gruppo con una riga sola.
//
// Il file contiene anche l'annullamento per contromovimento. Il ledger e' in
// sola lettura: non esiste una rotta che cancelli un movimento, e non deve
// esserci perche' il ledger e' la prova. Quindi "annulla" non cancella niente:
// registra un movimento nuovo che riporta lo stock al valore che il prodotto
// aveva prima, accanto a quello che lo aveva cambiato. La storia resta
// intera e l'operatore vede entrambi i fatti.

import 'package:intl/intl.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import 'inventory.code.dart';
import 'inventory_module.code.dart';

/// Cosa ha prodotto il movimento.
///
/// MGWS non ha un vocabolario che l'app conosca: i valori arrivano come
/// stringhe libere. Per questo la classificazione guarda `sourceType` e `type`
/// e, quando non riconosce niente, tiene [altro] e mostra la parola grezza
/// invece di indovinare. Un tipo sconosciuto mostrato male e' un fastidio; un
/// tipo sconosciuto travestito da "Rettifica" e' un movimento che si riapre
/// nel pannello sbagliato.
enum InventoryMovementKind {
  carico,
  rettifica,
  sposta,
  conteggio,
  ricezione,
  altro,
}

const _kindLabels = {
  InventoryMovementKind.carico: 'Aggiungi',
  InventoryMovementKind.rettifica: 'Rettifica',
  InventoryMovementKind.sposta: 'Sposta',
  InventoryMovementKind.conteggio: 'Conteggio',
  InventoryMovementKind.ricezione: 'Ricezione',
  InventoryMovementKind.altro: 'Altro',
};

/// Numeri di movimento formattati per la lista e per il dettaglio.
///
/// Vivono qui e non nel file di dettaglio: il piano di annullamento scrive
/// numeri di movimento dentro il motivo che va a MGWS, e un file di logica non
/// puo' dipendere da uno di interfaccia.
String movementSigned(int value) => value > 0 ? '+$value' : value.toString();
String movementStock(int? value) => value?.toString() ?? '-';

/// Una operazione di magazzino, accorpata dai movimenti che l'hanno prodotta.
class InventoryMovementGroup {
  const InventoryMovementGroup({
    required this.key,
    required this.kind,
    required this.rawType,
    required this.sourceType,
    required this.sourceId,
    required this.movementId,
    required this.occurredAtGmt,
    required this.lastModifiedGmt,
    required this.operatorUserId,
    required this.reason,
    required this.note,
    required this.movements,
    required this.products,
  });

  /// Identita' del gruppo: l'id del movimento che lo raccoglie.
  final String key;
  final InventoryMovementKind kind;

  /// Parola esatta di MGWS. Resta visibile accanto all'etichetta quando
  /// l'app non riconosce il tipo, cosi' l'operatore vede anche il dato
  /// originale e non solo la sua interpretazione.
  final String rawType;
  final String sourceType;
  final int sourceId;

  /// L'operazione in MGWS. `0` quando le righe non hanno intestazione: restano
  /// uno per una, perche' non si sa se facciano parte della stessa operazione.
  final int movementId;

  /// Data del primo movimento del gruppo: quando l'operazione e' partita.
  final String occurredAtGmt;

  /// Ultimo tocco del gruppo.
  ///
  /// Non e' un campo di MGWS e non potrebbe esserlo: il ledger non si modifica,
  /// quindi l'ultima modifica e' per definizione il movimento piu' recente, e
  /// viene ricavata da qui.
  final String lastModifiedGmt;

  final int operatorUserId;
  final String reason;
  final String note;
  final List<MgwsMovement> movements;

  /// I prodotti dell'operazione, uno per codice.
  ///
  /// Non coincide con [movements] quando l'operazione e' uno spostamento: quello
  /// scrive due righe per prodotto, una di uscita e una di entrata, e per
  /// l'operatore il prodotto e' uno che e' andato da un magazzino a un altro.
  final List<InventoryMovementProduct> products;

  int get productCount => products.length;

  /// Pezzi totali, con segno: se l'operazione correggeva magari, il segno
  /// diceva da che parte andava.
  ///
  /// Per uno spostamento vale zero, ed e' il numero giusto: lo spostamento non
  /// cambia il totale, cambia dove stanno i pezzi. Per sapere quanti pezzi si
  /// sono spostati c'e' [movedQuantity].
  int get quantityDelta =>
      products.fold<int>(0, (sum, item) => sum + item.quantityDelta);

  /// Pezzi presi in carico da un movimento di magazzino, qualunque segno abbia
  /// il delta. Per uno spostamento e' la merce che ha cambiato magazzino.
  int get movedQuantity =>
      products.fold<int>(0, (sum, item) => sum + item.quantity);

  String get kindLabel => _kindLabels[kind]!;

  /// Motivo e dettagli sono due campi distinti su MGWS e non vanno mescolati:
  /// il motivo spiega perche', il dettaglio aggiunge contesto. Qui vengono
  /// accostati per la lista, dove serve una riga sola.
  String get reasonAndDetails => [
    if (reason.trim().isNotEmpty) reason.trim(),
    if (note.trim().isNotEmpty) note.trim(),
  ].join(' - ');

  /// Modulo da riaprire, quando il gruppo ne ha uno.
  ///
  /// Rettifica e spostamento. La rettifica si rifa da un valore assoluto, che e'
  /// l'unica cosa che il ledger conserva. Lo spostamento si rifa dalla rotta, e
  /// la rotta adesso c'e': MGWS scrive in ogni sua riga da quale magazzino a
  /// quale e' andata la merce. Un tipo che l'app non riconosce non ha modulo:
  /// non si indovina.
  InventoryModule? get resumeModule => switch (kind) {
    InventoryMovementKind.rettifica => InventoryModule.fix,
    InventoryMovementKind.sposta => InventoryModule.move,
    _ => null,
  };

  /// `true` se il gruppo si puo' riaprire in un pannello.
  ///
  /// Passa per [InventoryModuleX.canResumeFromLedger] e non per il tipo da
  /// solo: cosi' la regola "quali moduli si riaprono" resta in un posto solo
  /// invece di essere duplicata qui dentro.
  ///
  /// Sullo spostamento c'e' un secondo controllo, e non e' una difesa ma una
  /// condizione reale: si puo' rifare solo se le righe hanno la rotta. Le righe
  /// scritte prima che la rotta fosse registrata non ce l'hanno, e riaprirle
  /// aprirebbe un pannello vuoto senza dire perche'.
  bool get canResume {
    final module = resumeModule;
    if (module == null || !module.canResumeFromLedger) return false;
    if (kind == InventoryMovementKind.sposta) {
      return products.any((item) => item.hasRoute);
    }
    return true;
  }

  /// Perche' il gruppo non si puo' riaprire, quando non si puo'.
  String get resumeBlockMessage => switch (kind) {
    InventoryMovementKind.sposta =>
      'Uno spostamento si rifa dalla rotta dei pezzi, e questa operazione non '
          'la espone: le sue righe non hanno i magazzini di partenza e arrivo, '
          'quindi non si puo\' sapere da dove rimetterli.',
    InventoryMovementKind.carico =>
      'Il carico e\' l\'unica rotta del gruppo e sa solo aumentare lo stock: '
          'un carico corretto in meno e\' una diminuzione, che da li\' non si '
          'puo\' scrivere.',
    InventoryMovementKind.conteggio =>
      'Un conteggio fisico e\' registrato da MGWS e non da un pannello: '
          'riaprirlo qui produrrebbe una correzione, non un conteggio.',
    InventoryMovementKind.ricezione =>
      'Una ricezione viene da un ordine fornitore: si corregge dall\'ordine, '
          'non dal pannello carico.',
    InventoryMovementKind.altro =>
      'MGWS ha registrato il movimento come '
          '"${rawType.isEmpty ? 'senza tipo' : rawType}", e l\'app non sa di '
          'che modulo si tratta.',
    InventoryMovementKind.rettifica => '',
  };

  /// Lo spostamento non cambia il totale: cambia dove stanno i pezzi.
  bool get isMove => kind == InventoryMovementKind.sposta;

  /// `true` se l'operazione si puo' annullare.
  ///
  /// Vale per tutto, e la ragione non e' il tipo: ogni movimento che cambia il
  /// totale porta con se' lo stock di prima e riportarlo indietro e' esattamente
  /// cio' che si vuol dire con "annulla".
  ///
  /// Lo spostamento richiede qualcosa in piu', non perche' sia vietato ma
  /// perche' non cambia il totale: riportare i pezzi indietro non e' un
  /// contromovimento, e' un *altro* spostamento, fatto con la rotta capovolta.
  /// Serve quindi che la rotta sia leggibile dalle righe del gruppo. Se manca,
  /// annullare significherebbe tirare a indovino su dove mettere la merce, e la
  /// schermata dice perche' il pulsante e' spento invece di accenderlo a vuoto.
  ///
  /// Il numero e' almeno uno e non tutti: l'annullamento e' per prodotto, quindi
  /// un'operazione in cui due codici su cinque hanno perso la rotta resta
  /// annullabile per gli altri tre, e il dialogo mostra i due che restano
  /// indietro.
  bool get canRevert =>
      isMove ? products.any((item) => item.hasRoute) : products.isNotEmpty;

  /// Perche' l'annullamento non si puo' fare, quando non si puo' fare tutto.
  ///
  /// Vuota quando l'operazione e' annullabile per intero. Altrimenti spiega in
  /// una riga il motivo, perche' l'elenco dei prodotti bloccati arriva dopo,
  /// nella schermata di conferma.
  String get revertBlockMessage {
    if (canRevert) return '';
    if (!isMove) return 'Il movimento non ha prodotti da riportare indietro';
    return 'Nessun prodotto di questo spostamento ha la rotta registrata: '
        'senza sapere da quale magazzino erano partiti i pezzi non si puo\' '
        'decidere dove rimetterli';
  }

  /// Elenco sintetico dei prodotti, per il dettaglio.
  List<String> get productLines => [
    for (final item in products)
      '#${item.productId}'
          '${item.variationId > 0 ? '/${item.variationId}' : ''} '
          '${isMove ? '${item.quantity} pezzi' : movementSigned(item.quantityDelta)}'
          '${isMove && item.routeText.isNotEmpty ? ' · ${item.routeText}' : ''}',
  ];
}

/// Un prodotto dentro un'operazione.
///
/// Nasce dall'accorpamento delle righe che lo riguardano: di norma una sola,
/// due quando il prodotto e' stato spostato e quindi ha sia un'uscita sia
/// un'entrata.
class InventoryMovementProduct {
  const InventoryMovementProduct({
    required this.productId,
    required this.variationId,
    required this.quantityDelta,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    required this.warehouseFrom,
    required this.warehouseTo,
    required this.siteFrom,
    required this.siteTo,
    required this.roomTo,
    required this.movements,
  });

  final int productId;
  final int variationId;

  /// Effetto sul totale, con segno. Vale zero per uno spostamento, che sposta
  /// senza creare ne' togliere.
  final int quantityDelta;

  /// Pezzi toccati dal movimento, senza segno. Per uno spostamento sono i pezzi
  /// che hanno cambiato magazzino.
  final int quantity;

  final int? stockBefore;
  final int? stockAfter;

  /// Magazzini di partenza e arrivo. Valgono solo per uno spostamento; zero
  /// negli altri casi, dove la merce e' rimasta dove era.
  final int warehouseFrom;
  final int warehouseTo;

  /// Sede di partenza e di arrivo, ricavata dalle due righe.
  ///
  /// Serve per riaprire lo spostamento: il magazzino da solo non basta, lo
  /// stesso numero di magazzino puo' esistere in due sedi diverse e senza la
  /// sede la rotta da ricostruire sarebbe quella sbagliata. Vale zero se MGWS
  /// non ha registrato la rotta, e in quel caso il gruppo non e' riapribile.
  ///
  /// Su un movimento che non sposta la merce le due sedi coincidono: la merce e'
  /// rimasta dov'era, e la sua sede serve all'annullamento di una rettifica, che
  /// riscrive il totale di una sede. Se le righe non concordano su una sola sede,
  /// o MGWS non ne ha registrata nessuna, resta zero e l'annullamento si ferma
  /// dicendo perche'.
  final int siteFrom;
  final int siteTo;

  /// Stanza di arrivo, quando il movimento l'ha registrata. Serve a rifare lo
  /// spostamento com'era stato, non in un'altra stanza dello stesso magazzino.
  final String roomTo;

  /// Le righe di libro da cui questo prodotto e' stato ricostruito. Sono piu'
  /// di una solo per lo spostamento.
  final List<MgwsMovement> movements;

  String get quantityText => movementStock(quantity);

  /// "3 -> 5", la rotta di uno spostamento. Vuota quando non e' uno
  /// spostamento o quando MGWS non ha scritto la rotta.
  String get routeText => warehouseFrom > 0 && warehouseTo > 0
      ? '$warehouseFrom -> $warehouseTo'
      : '';

  /// `true` se questo prodotto puo' essere riportato indietro.
  ///
  /// Serve la rotta intera, non solo i magazzini: senza la sede si saprebbe
  /// *quale* magazzino ha perso i pezzi ma non *dove si trova*, e la merce
  /// finirebbe nel magazzino giusto dell'altra sede. Serve anche un numero di
  /// pezzi da riportare, altrimenti la rotta al contrario non sposta niente.
  bool get hasRoute =>
      siteFrom > 0 &&
      siteTo > 0 &&
      warehouseFrom > 0 &&
      warehouseTo > 0 &&
      quantity > 0;
}

/// Accorpa in un prodotto le righe che lo riguardano.
///
/// Solo lo spostamento ne produce due per lo stesso codice, e per unione
/// accidentale la chiave e' il codice stesso: due righe dello stesso prodotto
/// nella stessa operazione non possono essere che la sua uscita e il suo
/// arrivo, perche' ogni altra operazione scrive una riga sola per codice.
List<InventoryMovementProduct> _mergeProducts(List<MgwsMovement> movements) {
  final byProduct = <String, List<MgwsMovement>>{};
  for (final item in movements) {
    byProduct
        .putIfAbsent('${item.productId}:${item.variationId}', () => [])
        .add(item);
  }
  return [for (final rows in byProduct.values) _toProduct(rows)];
}

/// Costruisce il prodotto dalle sue righe.
///
/// La sede e la stanza si leggono dalle righe, non dai campi `warehouse_from` e
/// `warehouse_to`: quelle due righe portano ciascuna la propria ubicazione,
/// quella di uscita e quella di arrivo, e sapere *quele* e' quale e' l'unico
/// modo per non sbagliare la sede quando i due magazzini hanno lo stesso numero.
InventoryMovementProduct _toProduct(List<MgwsMovement> rows) {
  final warehouseFrom = rows.first.warehouseFrom;
  final warehouseTo = rows.first.warehouseTo;
  final from = rows.where((item) => item.location.warehouseId == warehouseFrom);
  final to = rows.where((item) => item.location.warehouseId == warehouseTo);
  // Una rotta sono gli stessi pezzi visti dai due lati, quindi si contano una
  // volta sola. Sommare i valori assoluti delle due righe li conterebbe due: uno
  // spostamento di cinque pezzi mostrerebbe "10 pezzi spostati", che e' un
  // numero che non e' mai esistito. La rotta si riconosce dal fatto che *tutte*
  // le righe la portano: e' l'unico dato che il backend scrive solo quando sa
  // che la merce cambia magazzino, quindi non si confonde con due movimenti
  // distinti dello stesso codetto finiti nella stessa operazione, che vanno
  // sommati per davvero.
  final isRoute =
      warehouseFrom > 0 &&
      warehouseTo > 0 &&
      rows.every((item) => item.warehouseFrom == warehouseFrom);
  // Una riga che non e' uno spostamento resta dove e', e la sua sede e' quella
  // scritta sulla riga. Serve all'annullamento di una rettifica, che riscrive un
  // totale di sede: senza questo numero l'annullamento non saprebbe quale sede
  // riportare indietro, e su un negozio con piu' sedi finirebbe per sceglierne
  // una a caso. Vale solo se le righe concordano: se dicono sedi diverse non c'e'
  // un unico posto da cui guardare, e resta zero.
  final homeSites = <int>{};
  for (final item in rows) {
    final siteId = item.location.siteId;
    if (siteId > 0) homeSites.add(siteId);
  }
  final homeSite = homeSites.length == 1 ? homeSites.first : 0;
  return InventoryMovementProduct(
    productId: rows.first.productId,
    variationId: rows.first.variationId,
    quantityDelta: rows.fold<int>(0, (sum, item) => sum + item.quantityDelta),
    quantity: isRoute
        ? rows.first.quantityDelta.abs()
        : rows.fold<int>(0, (sum, item) => sum + item.quantityDelta.abs()),
    stockBefore: rows.first.stockBefore,
    stockAfter: rows.first.stockAfter,
    warehouseFrom: warehouseFrom,
    warehouseTo: warehouseTo,
    // Sullo spostamento la sede si legge dal lato da cui la merce e' partita o
    // arrivata; su tutto il resto e' la sede in cui la merce sta, che e' la stessa
    // per lato perche' la merce non si e' mossa. `hasRoute` continua a richiedere
    // i due magazzini, quindi una riga che non e' uno spostamento non puo' passare
    // per uno spostamento solo per avere la sede.
    siteFrom: isRoute
        ? (from.isEmpty ? 0 : from.first.location.siteId)
        : homeSite,
    siteTo: isRoute ? (to.isEmpty ? 0 : to.first.location.siteId) : homeSite,
    roomTo: to.isEmpty ? '' : to.first.location.room,
    movements: List<MgwsMovement>.unmodifiable(rows),
  );
}

/// Motivo con cui l'annullamento finisce sul ledger.
///
/// L'annullamento e' un movimento come gli altri e deve dire da solo perche'
/// esiste e a cosa si riferisce: chi legge il ledger tra un mese deve capire
/// che quel pezzo non e' sparito, e' stato rimesso a posto.
///
/// Lo spostamento e' l'unico caso in cui la frase non basta. Un contromovimento
/// torna indietro nel tempo: riporta lo stock a come era e basta. Uno
/// spostamento capovolto invece crea pezzi nuovi in un magazzino che non li
/// aveva, e MGWS non sa che e' un annullamento se non glielo dicono. Per questo
/// il motivo nomina la rotta originale: chi legge vede che quel magazzino si
/// e' svuotato perche' un movimento #N era andato nel senso opposto.
String inventoryRevertReason(
  InventoryMovementGroup group,
  InventoryMovementProduct product,
) {
  final origin = product.movements.first;
  if (group.isMove) {
    return 'Annullamento movimento #${origin.id}: riporto ${product.quantity} '
        'pezzi da S${product.siteTo} W${product.warehouseTo} a '
        'S${product.siteFrom} W${product.warehouseFrom} '
        '(spostamento al contrario)';
  }
  return 'Annullamento movimento #${origin.id}: riporto stock da '
      '${movementStock(product.stockAfter)} a '
      '${movementStock(product.stockBefore)} '
      '(${group.kindLabel.toLowerCase()})';
}

/// Perche' un movimento non si puo' annullare.
enum InventoryRevertBlock {
  /// MGWS non ha registrato lo stock di prima: senza il valore da ripristinare
  /// non c'e' niente da fare.
  senzaStockPrecedente,

  /// Un movimento successivo ha gia' mosso lo stesso prodotto. Riportarlo al
  /// valore di prima di questo movimento azzererebbe anche quello, quindi ci si
  /// ferma e si dice quale prodotto.
  stockCambiato,

  /// Le righe dello spostamento non portano la rotta, o la portano incompleta.
  /// Senza sapere da dove erano partiti i pezzi non si puo' decidere dove
  /// rimetterli, e tirare a indovino sposta merce dove non deve andare.
  rottaMancante,

  /// Il magazzino di arrivo non ha piu' i pezzi da riportare indietro: qualcuno
  /// li ha gia' spostati o venduti. Riportarli significherebbe toglierli dal
  /// magazzino di partenza e trovarsi con un totale negativo.
  pezziAssenti,

  /// Non si e' potuto leggere lo stock di adesso, quindi non si sa se
  /// l'annullamento sarebbe lecito. Non si scrive niente: e' una domanda senza
  /// risposta, non un no.
  letturaFallita,

  /// Le righe non dicono in che sede il prodotto era, quindi non si sa quale
  /// totale riportare indietro. Un contromovimento scrive il totale di una sede:
  /// scriverlo senza sapere quale significherebbe correggere un posto a caso.
  sedeMancante,

  /// Il totale che il movimento ha registrato e' di tutto il negozio, non della
  /// sede: vale per un carico o una ricezione, che contano il totale del prodotto
  /// su tutte le sedi. Se il prodotto ha pezzi anche in un'altra sede quel numero
  /// non e' il totale di nessuna di esse, e riversarlo in una sola azzererebbe pezzi
  /// che stanno li'. Si rimane fermi invece di produrre uno stock che nessuno ha
  /// contato.
  totaleDiNegozio,
}

/// Un prodotto da annullare, con l'esito della verifica fatta prima di toccare
/// lo stock.
class InventoryMovementRevertLine {
  const InventoryMovementRevertLine({
    required this.product,
    required this.reverseMove,
    this.currentStock,
    this.availableAtDestination,
    this.readError,
    this.block,
  });

  final InventoryMovementProduct product;

  /// `true` se l'annullamento di questa riga e' uno spostamento al contrario.
  ///
  /// Lo decide il gruppo, non il numero di righe del prodotto. Dedurlo dalle
  /// righe sarebbe fragile: un carico vecchio, scritto quando l'origine non
  /// veniva registrata, puo' avere due righe per lo stesso codice, e un
  /// annullamento di quel tipo preso per spostamento manderebbe pezzi verso
  /// magazzini che non esistono invece di riportare il totale a prima.
  final bool reverseMove;

  /// Stock letto adesso da MGWS, non quello del movimento: e' quello che
  /// decide se l'annullamento e' lecito. Vale per i movimenti che cambiano il
  /// totale.
  final int? currentStock;

  /// Pezzi che il magazzino di arrivo dello spostamento ha adesso. Vale per lo
  /// spostamento: senza questi non c'e' niente da riportare indietro.
  final int? availableAtDestination;

  /// Cosa ha risposto MGWS quando si e' andati a leggere lo stock, se la lettura
  /// e' fallita. Va detto all'operatore: "non si puo' controllare" e "qualcun
  /// altro ha mosso il prodotto" sono fatti diversi e dicono cosa fare.
  final String? readError;

  final InventoryRevertBlock? block;

  /// Valore a cui riportare il totale. Solo per i movimenti che lo cambiano:
  /// per lo spostamento il totale e' gia' quello giusto e non si tocca.
  int get restoreTo => product.stockBefore ?? 0;
  bool get canRevert => block == null;
  int get movementId => product.movements.first.id;
  int get productId => product.productId;
  int get quantity => product.quantity;
  bool get isReverseMove => reverseMove;

  /// Sede in cui si scrive il totale riportato indietro.
  ///
  /// Vale solo per il contromovimento: lo spostamento al contrario dichiara gia'
  /// le due sedi della rotta. Su un movimento che non sposta la merce e' la sede
  /// in cui la merce stava, ed e' l'unica informazione che rende il totale
  /// riportato un numero di un posto invece che un numero senza indirizzo.
  int get siteId => product.siteFrom;

  /// Rotta da usare per l'annullamento: quella al contrario per lo spostamento,
  /// vuota per tutto il resto, che non si muove.
  String get routeText => isReverseMove
      ? 'S${product.siteTo} W${product.warehouseTo} -> '
            'S${product.siteFrom} W${product.warehouseFrom}'
      : '';

  String get productLabel =>
      'Prodotto #$productId'
      '${product.variationId > 0 ? ' variante ${product.variationId}' : ''}';

  String get blockMessage => switch (block) {
    InventoryRevertBlock.senzaStockPrecedente =>
      'MGWS non ha registrato lo stock precedente, non c\'e\' nulla da '
          'ripristinare',
    InventoryRevertBlock.stockCambiato =>
      'lo stock e\' ora ${currentStock ?? '?'} in sede $siteId, non '
          '${movementStock(product.stockAfter)}: un movimento successivo ha '
          'gia\' toccato questo prodotto',
    InventoryRevertBlock.sedeMancante =>
      'le righe del movimento non dicono in che sede era il prodotto, quindi non '
          'si sa quale totale riportare indietro',
    InventoryRevertBlock.totaleDiNegozio =>
      'il totale registrato e\' di tutto il negozio e il prodotto ha pezzi anche '
          'in un\'altra sede: riportarlo in una sola azzererebbe pezzi che stanno '
          'li\'',
    InventoryRevertBlock.rottaMancante =>
      'le righe dello spostamento non dicono da quale magazzino erano partiti '
          'i pezzi, quindi non si puo\' sapere dove rimetterli',
    InventoryRevertBlock.pezziAssenti =>
      'nel magazzino di arrivo ci sono ${availableAtDestination ?? 0} pezzi e '
          'ne servivano ${product.quantity}: qualcuno li ha gia\' spostati o '
          'venduti',
    InventoryRevertBlock.letturaFallita =>
      'non si e\' riusciti a leggere lo stock attuale: ${readError ?? 'MGWS non ha risposto'}',
    null => '',
  };
}

/// Cosa succede se l'operatore annulla l'operazione.
///
/// Il piano non parte da sola: ogni riga e' gia' stata verificata contro lo
/// stock attuale, quindi il dialogo di conferma puo' dire onestamente cosa
/// verra' fatto e cosa no prima di scrivere qualcosa.
class InventoryMovementRevertPlan {
  const InventoryMovementRevertPlan({required this.group, required this.lines});

  final InventoryMovementGroup group;
  final List<InventoryMovementRevertLine> lines;

  List<InventoryMovementRevertLine> get revertable =>
      lines.where((line) => line.canRevert).toList();

  List<InventoryMovementRevertLine> get blocked =>
      lines.where((line) => !line.canRevert).toList();

  bool get canRevert => revertable.isNotEmpty;

  /// Le righe bloccate non annullano l'operazione: sono prodotti che il
  /// movimento ha toccato ma che non si possono riportare indietro. L'operatore
  /// vede l'elenco e decide, invece di trovarsi un pulsante spento senza
  /// spiegazione.
  bool get isPartial => canRevert && blocked.isNotEmpty;
}

/// Prepara ed esegue l'annullamento.
///
/// Non riusa [InventoryRettificaController] perche' il piano e' diverso: la
/// rettifica corregge verso un valore scelto dall'operatore, l'annullamento
/// corregge verso il valore che MGWS aveva registrato prima del movimento, e
/// soprattutto rifiuta di partire se quello non e' piu' lo stock corrente.
///
/// Lo spostamento segue un'altra strada, ed e' l'unica cosa che rende questa
/// classe diversa da un semplice wrapper: annullare un trasferimento significa
/// rifarlo al contrario, e un movimento al contrario non e' un contromovimento ma
/// un movimento come gli altri, solo nel senso opposto. Non puo' passare da
/// `reconcileStock`, che azzererebbe il totale del prodotto togliendogli pezzi
/// che sono invece spostati: qui si richiama la stessa rotta che usa il modulo
/// Sposta, con i due magazzini scambiati.
class InventoryMovementRevertController with InventoryFeedbackController {
  InventoryMovementRevertController({InventoryController? inventory})
    : inventory = inventory ?? InventoryController();

  final InventoryController inventory;

  InventoryMovementRevertPlan? lastPlan;
  bool isPreparing = false;
  bool isReverting = false;

  /// Verifica riga per riga se l'annullamento e' lecito, leggendo lo stock
  /// attuale di ogni prodotto.
  Future<InventoryActionFeedback> prepare(InventoryMovementGroup group) async {
    if (isPreparing || isReverting) {
      return invalid('Operazione gia in corso');
    }
    isPreparing = true;
    try {
      final lines = <InventoryMovementRevertLine>[];
      // Si lavora sui prodotti, non sulle righe: uno spostamento ha due righe
      // per codice e restituirne due blocchi per lo stesso prodotto fa sembrare
      // che l'operazione riguardasse due pezzi diversi.
      for (final product in group.products) {
        if (group.isMove) {
          lines.add(await _checkReverseMove(product));
          continue;
        }
        lines.add(await _checkCounterMovement(group, product));
      }
      final plan = InventoryMovementRevertPlan(group: group, lines: lines);
      lastPlan = plan;
      return remember(
        InventoryActionFeedback(
          success: plan.canRevert,
          message: plan.canRevert
              ? '${plan.revertable.length} prodotti riportabili indietro'
              : 'Nessun prodotto riportabile: controlla i dettagli',
          details: [
            for (final line in plan.blocked)
              '${line.productLabel}: ${line.blockMessage}',
          ],
        ),
      );
    } finally {
      isPreparing = false;
    }
  }

  /// Contromovimento: il totale torna al valore che MGWS aveva registrato prima.
  ///
  /// Il confronto e' fra numeri della stessa ambito, e questa e' la parte che
  /// rende l'annullamento affidabile. Il contromovimento scrive il totale di *una
  /// sede*, quindi il numero da confrontare e' il totale di quella sede e non il
  /// totale del prodotto: su un negozio con due sedi i due numeri divergono, e
  /// confrontarli darebbe sempre "qualcuno ha mosso il prodotto" anche quando non
  /// e' successo niente.
  ///
  /// Non tutti i movimenti registrano numeri della stessa ambito. La rettifica
  /// registra il totale della sede che corregge. Un carico e una ricezione
  /// registrano il totale del prodotto su tutte le sedi: sono numeri giusti per
  /// quello che fanno, ma non sono il totale di nessuna sede in particolare. Se
  /// il prodotto sta tutto in una sede, i due numeri coincidono e si puo'
  /// riportare indietro senza problemi; se ha pezzi anche altrove, il numero non
  /// indica nessun posto e si dice che non si puo', invece di riversarlo da
  /// qualche parte.
  Future<InventoryMovementRevertLine> _checkCounterMovement(
    InventoryMovementGroup group,
    InventoryMovementProduct product,
  ) async {
    if (product.stockBefore == null) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: false,
        block: InventoryRevertBlock.senzaStockPrecedente,
      );
    }
    if (product.siteFrom <= 0) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: false,
        block: InventoryRevertBlock.sedeMancante,
      );
    }
    final feedback = await inventory.loadStock(
      productIdText: '${product.productId}',
    );
    if (!feedback.success) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: false,
        readError: feedback.message,
        block: InventoryRevertBlock.letturaFallita,
      );
    }
    final snapshot = InventoryStockSnapshot.fromRecord(
      inventory.stockRows.isEmpty ? null : inventory.stockRows.first,
    );
    final siteStock = snapshot?.stockAtSite(product.siteFrom);
    if (siteStock == null) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: false,
        readError: 'MGWS non ha restituito lo stock della sede',
        block: InventoryRevertBlock.letturaFallita,
      );
    }
    // La rettifica e' l'unico modulo che registra il totale della sede: gli
    // altri contano il prodotto. La differenza si vede dai numeri, non dal
    // modulo, e si controlla qui perche' e' l'unico posto in cui si hanno
    // entrambi i numeri.
    if (group.kind != InventoryMovementKind.rettifica &&
        siteStock != snapshot!.currentStock) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: false,
        currentStock: siteStock,
        block: InventoryRevertBlock.totaleDiNegozio,
      );
    }
    return InventoryMovementRevertLine(
      product: product,
      reverseMove: false,
      currentStock: siteStock,
      // Lo stock deve essere ancora quello che il movimento ha lasciato:
      // altrimenti c'e' stata un'altra operazione e riportare indietro
      // azzererebbe anche quella.
      block: siteStock == product.stockAfter
          ? null
          : InventoryRevertBlock.stockCambiato,
    );
  }

  /// Spostamento al contrario: la rotta e' gia' nel gruppo, quindi qui si
  /// controlla solo che i pezzi da riportare siano ancora nel magazzino di
  /// arrivo. Se non ci sono, tirarli indietro produrrebbe un totale negativo.
  Future<InventoryMovementRevertLine> _checkReverseMove(
    InventoryMovementProduct product,
  ) async {
    if (!product.hasRoute) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: true,
        block: InventoryRevertBlock.rottaMancante,
      );
    }
    final feedback = await inventory.loadStock(
      productIdText: '${product.productId}',
    );
    if (!feedback.success) {
      return InventoryMovementRevertLine(
        product: product,
        reverseMove: true,
        readError: feedback.message,
        block: InventoryRevertBlock.letturaFallita,
      );
    }
    final levels = InventoryStockSnapshot.fromRecord(
      inventory.stockRows.isEmpty ? null : inventory.stockRows.first,
    )?.levels;
    // Le ubicazioni sono per magazzino: piu' righe con lo stesso magazzino
    // sono la stessa pila divisa per stanza o scaffale, e contare solo la
    // prima riga direbbe che il magazzino e' vuoto mentre ha pezzi.
    final available = (levels ?? const <InventoryStockLevel>[])
        .where(
          (level) =>
              level.warehouseId == product.warehouseTo &&
              level.siteId == product.siteTo,
        )
        .fold<int>(0, (sum, level) => sum + level.qty);
    return InventoryMovementRevertLine(
      product: product,
      reverseMove: true,
      availableAtDestination: available,
      block: available >= product.quantity
          ? null
          : InventoryRevertBlock.pezziAssenti,
    );
  }

  /// Esegue i contromovimenti sui prodotti verificati.
  ///
  /// Non si ferma al primo errore come nel resto del modulo: ogni prodotto e'
  /// indipendente, e fermarsi a meta' lascerebbe l'operazione annullata a
  /// meta' con l'operatore senza un elenco di cosa e' passato e cosa no.
  Future<InventoryActionFeedback> execute(
    InventoryMovementRevertPlan plan,
  ) async {
    if (isReverting) return invalid('Annullamento gia in corso');
    if (!plan.canRevert) return invalid('Niente da annullare');
    isReverting = true;
    // Una sola chiave per l'annullamento intero: se ogni prodotto ne avesse una
    // sua, lo storico mostrerebbe cinque annullamenti dove l'operatore ne ha
    // premuto uno, e nessuno saprebbe piu' quale operazione sta riportando
    // indietro.
    final movementKey = newInventoryMovementKey();
    try {
      var done = 0;
      var failed = 0;
      final details = <String>[];
      for (final line in plan.revertable) {
        final feedback = line.isReverseMove
            ? await _reverseMove(plan.group, line, movementKey)
            : await _counterMovement(plan.group, line, movementKey);
        if (feedback.success) {
          done++;
          details.add(
            line.isReverseMove
                ? '· ${line.productLabel}: ${line.quantity} pezzi riportati a '
                      'S${line.product.siteFrom} W${line.product.warehouseFrom}'
                : '· ${line.productLabel}: tornato a ${line.restoreTo}',
          );
        } else {
          failed++;
          details.add('${line.productLabel}: ${feedback.message}');
        }
      }
      for (final line in plan.blocked) {
        details.add('Saltato ${line.productLabel}: ${line.blockMessage}');
      }
      return remember(
        InventoryActionFeedback(
          success: failed == 0,
          message: failed == 0
              ? 'Annullati $done prodotti: lo stock e\' tornato a prima'
              : 'Annullamento parziale: $done su '
                    '${plan.revertable.length} prodotti riportati indietro',
          details: details,
        ),
      );
    } finally {
      isReverting = false;
    }
  }

  /// Riporta il totale a com'era prima del movimento.
  ///
  /// La sede dichiarata e' quella in cui la merce stava: e' il perimetro entro
  /// cui il totale verra' riscritto, e senza di lei il numero tornerebbe a
  /// significare il totale del prodotto su tutte le sedi, che e' un'altra
  /// operazione.
  Future<InventoryActionFeedback> _counterMovement(
    InventoryMovementGroup group,
    InventoryMovementRevertLine line,
    String movementKey,
  ) {
    return inventory.reconcileStock(
      productIdText: '${line.productId}',
      correctStockText: '${line.restoreTo}',
      siteIdText: '${line.siteId}',
      reasonText: inventoryRevertReason(group, line.product),
      movementKey: movementKey,
    );
  }

  /// Riflette lo spostamento con la rotta capovolta.
  ///
  /// La stanza di partenza si lascia vuota: quella di partenza dell'originale non
  /// e' nota al ledger, e sceglierne una a caso metterebbe i pezzi dove il
  /// magazzino non li aveva. Il magazzino basta e avanza, e se l'operatore
  /// vuole la stanza esatta la indica nel pannello Sposta con un secondo
  /// spostamento.
  Future<InventoryActionFeedback> _reverseMove(
    InventoryMovementGroup group,
    InventoryMovementRevertLine line,
    String movementKey,
  ) {
    final product = line.product;
    return inventory.moveStock(
      productIdText: '${line.productId}',
      fromSiteIdText: '${product.siteTo}',
      fromWarehouseIdText: '${product.warehouseTo}',
      toSiteIdText: '${product.siteFrom}',
      toWarehouseIdText: '${product.warehouseFrom}',
      quantityText: '${product.quantity}',
      reasonText: inventoryRevertReason(group, product),
      movementKey: movementKey,
    );
  }
}

/// Accorpa i movimenti in operazioni.
///
/// L'ordine segue quello di arrivo di MGWS, che e' dal piu' recente: e' l'ordine
/// in cui l'operatore ha lavorato e in cui gli eventi si sono susseguiti.
List<InventoryMovementGroup> groupMovements(List<MgwsMovement> movements) {
  final byKey = <String, List<MgwsMovement>>{};
  for (final item in movements) {
    byKey.putIfAbsent(_groupKey(item), () => <MgwsMovement>[]).add(item);
  }
  return [for (final entry in byKey.entries) _toGroup(entry.key, entry.value)];
}

/// L'id del movimento e' l'unica cosa che mette insieme i prodotti della
/// stessa operazione.
///
/// Non basta `sourceId`: sui tre moduli dell'app quel campo valeva 0 per tutte le
/// righe, perche' nessuno scriveva l'origine. E non basta neanche il timestamp:
/// un carico di trenta codici entra in un colpo solo e le righe condividono il
/// secondo.
///
/// Quando l'id manca la riga resta da solo. Meglio una riga in piu' che due
/// operazioni diverse fuse: e il caso delle righe scritte dai flussi interni del
/// plugin, che non nascono da un'azione di un operatore e quindi non hanno
/// nessuna intestazione.
String _groupKey(MgwsMovement movement) {
  if (movement.movementId > 0) {
    return 'movimento#${movement.movementId}';
  }
  if (movement.sourceId > 0 && movement.sourceType.trim().isNotEmpty) {
    return '${movement.sourceType}#${movement.sourceId}';
  }
  return 'riga#${movement.id}';
}

InventoryMovementGroup _toGroup(String key, List<MgwsMovement> movements) {
  final head = movements.first;
  final kind = _classify(head);
  final stamps = [for (final item in movements) item.occurredAtGmt]..sort();
  return InventoryMovementGroup(
    key: key,
    kind: kind,
    rawType: [
      head.stockEffect,
      head.sourceType,
      head.type,
    ].where((value) => value.trim().isNotEmpty).join(' / '),
    sourceType: head.sourceType,
    sourceId: head.sourceId,
    movementId: head.movementId,
    occurredAtGmt: stamps.first,
    lastModifiedGmt: stamps.last,
    operatorUserId: head.operatorUserId,
    reason: head.reasonCode,
    note: head.note,
    movements: List<MgwsMovement>.unmodifiable(movements),
    products: _mergeProducts(movements),
  );
}

/// Riconosce il modulo dalla parola che MGWS usa.
///
/// Si guarda `stockEffect`, `sourceType` e poi `type`: il primo descrive che
/// cosa ha fatto l'operazione sullo stock, il secondo da dove arriva, il terzo
/// che forma ha. Bastano i tre per coprire i moduli dell'app senza una lista di
/// valori da mantenere.
///
/// L'ordine dei riscontri e' quello che evita di confondere una ricezione che
/// contiene "move" nel nome, o un "load" dentro un "quick load": vince il primo
/// segnale che arriva, e i piu' specifici sono testati per primi.
InventoryMovementKind _classify(MgwsMovement movement) {
  for (final candidate in [
    movement.stockEffect.toLowerCase(),
    movement.sourceType.toLowerCase(),
    movement.type.toLowerCase(),
  ]) {
    if (candidate.isEmpty) continue;
    if (candidate.contains('reconcile') || candidate.contains('rettific')) {
      return InventoryMovementKind.rettifica;
    }
    if (candidate.contains('quick') || candidate.contains('caric')) {
      return InventoryMovementKind.carico;
    }
    if (candidate.contains('move') ||
        candidate.contains('spost') ||
        candidate.contains('transfer')) {
      return InventoryMovementKind.sposta;
    }
    if (candidate.contains('count') || candidate.contains('conte')) {
      return InventoryMovementKind.conteggio;
    }
    if (candidate.contains('receipt') || candidate.contains('ricez')) {
      return InventoryMovementKind.ricezione;
    }
  }
  return InventoryMovementKind.altro;
}

/// Prepara la riapertura di un'operazione nel pannello che l'ha prodotta.
///
/// Il seme porta solo cio' che il ledger registra davvero. Quello che non c'
/// viene lasciato fuori, non inventato: un pannello riaperto con meta' dei
/// valori e' peggio di un pannello vuoto, perche' l'operatore non sa piu' se
/// quello che vede e' il movimento o quello che sta per mandare.
class InventoryPanelSeed {
  const InventoryPanelSeed({
    required this.module,
    required this.movements,
    required this.products,
    required this.reason,
    required this.details,
  });

  final InventoryModule module;

  /// Righe di libro, una per riga che MGWS ha scritto. E' quello che serve
  /// quando ogni prodotto corrisponde a una riga sola, cioe' la rettifica.
  final List<MgwsMovement> movements;

  /// Prodotti dell'operazione, uno per codice.
  ///
  /// Lo spostamento scrive due righe per lo stesso prodotto e restituirle cosi'
  /// farebbe comparire due volte lo stesso articolo in un pannello che ne
  /// accetta uno solo per riga, con due magazzini da scegliere. Qui il prodotto
  /// e' gia' uno solo e porta con se' la rotta da -> a.
  final List<InventoryMovementProduct> products;

  final String reason;
  final String details;

  /// Impronta del seme: i pannelli la confrontano per capire se devono
  /// ricaricarsi. Due aperture dello stesso movimento producono la stessa
  /// impronta, che e' quello che serve: riaprire due volte lo stesso movimento
  /// da due punti diversi non deve duplicare i prodotti in lista.
  int get stamp => Object.hashAll([
    module,
    reason,
    details,
    for (final item in products) '${item.productId}:${item.variationId}',
  ]);
}

final DateFormat _formatoDataMovimento = DateFormat('dd/MM/yyyy HH:mm');

/// MGWS scrive le date in GMT come "2026-09-27 15:47:09": per l'operatore
/// diventano ora locale nel formato usato nel resto dell'app. Un valore che
/// non si legge resta com'e', invece di sparire.
String formatMovementDate(String gmt) {
  final parsed = DateTime.tryParse('${gmt.trim().replaceFirst(' ', 'T')}Z');
  return parsed == null ? gmt : _formatoDataMovimento.format(parsed.toLocal());
}
