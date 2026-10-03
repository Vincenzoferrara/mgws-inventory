// class_scontrino.dart

import '../prodotti/class_prodotti.dart';
import '../traduzioni/estensioni.dart';

enum TipoOperazioneCassa { vendita, reso, cambio }

enum TipoRigaCassa { vendita, reso }

enum StatoTurnoCassa { aperto, chiuso }

extension StatoTurnoCassaX on StatoTurnoCassa {
  String get value {
    switch (this) {
      case StatoTurnoCassa.aperto:
        return 'aperto';
      case StatoTurnoCassa.chiuso:
        return 'chiuso';
    }
  }
}

extension TipoOperazioneCassaX on TipoOperazioneCassa {
  String get value {
    switch (this) {
      case TipoOperazioneCassa.vendita:
        return 'vendita';
      case TipoOperazioneCassa.reso:
        return 'reso';
      case TipoOperazioneCassa.cambio:
        return 'cambio';
    }
  }

}

/// Etichetta tradotta del tipo di operazione di cassa.
///
/// Vive qui e non nell'estensione perche' la traduzione ha bisogno delle
/// localizzazioni, che un enum non puo' raggiungere.
String cassaTipoOperazioneLabel(
  AppLocalizations l10n,
  TipoOperazioneCassa tipo,
) => switch (tipo) {
  TipoOperazioneCassa.vendita => l10n.cassaTipoOperazioneVendita,
  TipoOperazioneCassa.reso => l10n.cassaTipoOperazioneReso,
  TipoOperazioneCassa.cambio => l10n.cassaTipoOperazioneCambio,
};

extension TipoRigaCassaX on TipoRigaCassa {
  String get value {
    switch (this) {
      case TipoRigaCassa.vendita:
        return 'vendita';
      case TipoRigaCassa.reso:
        return 'reso';
    }
  }

}

/// Etichetta tradotta del tipo di riga di cassa.
String cassaTipoRigaLabel(AppLocalizations l10n, TipoRigaCassa tipo) =>
    switch (tipo) {
      TipoRigaCassa.vendita => l10n.cassaTipoOperazioneVendita,
      TipoRigaCassa.reso => l10n.cassaTipoOperazioneReso,
    };

/// Rappresenta uno scontrino completo
///
/// Canale documentale: `pos` per la vendita fisica, mai mescolato con gli
/// ordini WooCommerce (canale `woo`). Lo storico POS vive in
/// `StoricoCassaStore` (SharedPreferences/JSON) in attesa degli endpoint
/// MGWS definitivi, che restano l'enforcement server-side.
class Scontrino {
  String id;
  DateTime data;
  List<RigaScontrino> righe;
  double subtotale;
  double iva;
  double sconto;
  double scontoPercentuale; // Sconto percentuale globale
  double totale;
  String? clienteId;
  String? clienteNome;
  String? clienteEmail;
  String? clienteTelefono;
  String metodoPagamento; // 'contanti', 'carta', 'bancomat'
  String? note;
  String
  stato; // 'aperto', 'pagato', 'annullato', 'sospeso', 'rimborsato', 'chiuso'
  TipoOperazioneCassa tipoOperazione;

  // Separazione canali: 'pos' per scontrini fisici, mai 'woo'.
  String canale;
  // Progressivo locale dello storico POS (assegnato alla chiusura).
  int? numeroProgressivo;
  // Progressivo emesso dal registratore telematico, quando collegato.
  // Resta null in modalita' simulazione, dove nessun dispositivo emette.
  // Receipt number issued by the fiscal register when one is attached. Stays
  // null in simulation mode, where no device issues anything.
  String? numeroProgressivoDispositivo;
  // Operatore legato all'anagrafica dipendenti (ref id + nome/cognome).
  int? operatoreId;
  String? operatoreNome;
  String? operatoreCognome;
  // Cassa fisica e sede, solo se configurate in Impostazioni > Cassa.
  String? cassaNome;
  String? sede;
  // Giornata operativa implicita: 'YYYY-MM-DD|cassa'.
  String? giornataId;
  // Turno cassa aperto esplicitamente prima delle vendite.
  String? turnoId;
  // Riferimenti al documento creato da MGWS/Woo al checkout.
  Object? wooOrderId;
  Object? mgwsOrderId;
  // Chiusura: data di archiviazione nello storico POS.
  DateTime? dataChiusura;
  List<String> rettifiche;

  // Coupon applicato
  String? couponCode;
  double couponSconto;

  // Per calcolo resto
  double importoRicevuto;

  // Aliquota IVA (default 22%)
  double aliquotaIva;

  Scontrino({
    required this.id,
    required this.data,
    List<RigaScontrino>? righe,
    this.subtotale = 0.0,
    this.iva = 0.0,
    this.sconto = 0.0,
    this.scontoPercentuale = 0.0,
    this.totale = 0.0,
    this.clienteId,
    this.clienteNome,
    this.clienteEmail,
    this.clienteTelefono,
    this.metodoPagamento = 'contanti',
    this.note,
    this.stato = 'aperto',
    this.tipoOperazione = TipoOperazioneCassa.vendita,
    this.couponCode,
    this.couponSconto = 0.0,
    this.importoRicevuto = 0.0,
    this.aliquotaIva = 22.0,
    this.canale = 'pos',
    this.numeroProgressivo,
    this.numeroProgressivoDispositivo,
    this.operatoreId,
    this.operatoreNome,
    this.operatoreCognome,
    this.cassaNome,
    this.sede,
    this.giornataId,
    this.turnoId,
    this.wooOrderId,
    this.mgwsOrderId,
    this.dataChiusura,
    List<String>? rettifiche,
  }) : righe = righe ?? [],
       rettifiche = rettifiche ?? [];

  /// Calcola il totale dello scontrino
  void calcolaTotale() {
    // Subtotale netto = vendite - resi, con sconti di riga già applicati.
    subtotale = righe.fold(0.0, (sum, riga) => sum + riga.subtotaleSigned);

    // Calcola sconto totale (percentuale + fisso + coupon)
    double scontoTotale = sconto + couponSconto;
    if (scontoPercentuale > 0 && subtotale > 0) {
      scontoTotale += subtotale * (scontoPercentuale / 100);
    }

    // Subtotale dopo sconti
    double subtotaleScontato = subtotale - scontoTotale;
    if (subtotaleScontato < 0) subtotaleScontato = 0;

    // Calcola IVA (l'IVA è già inclusa nel prezzo, scorporiamo per mostrare)
    // Formula: IVA = Prezzo - (Prezzo / (1 + aliquota/100))
    iva = subtotaleScontato - (subtotaleScontato / (1 + aliquotaIva / 100));

    // Totale finale
    totale = subtotaleScontato;
  }

  /// Applica uno sconto percentuale globale
  void applicaScontoPercentualeGlobale(double percentuale) {
    scontoPercentuale = percentuale.clamp(0, 100);
    calcolaTotale();
  }

  /// Calcola il resto da dare al cliente
  double get resto => importoRicevuto > totale ? importoRicevuto - totale : 0;

  /// Verifica se l'importo ricevuto è sufficiente
  bool get importoSufficiente => importoRicevuto >= totale;

  /// Totale sconti applicati (righe + globale + coupon)
  double get totaleSconto {
    double scontoRighe = righe.fold(
      0.0,
      (sum, riga) => sum + riga.totaleSconto,
    );
    double scontoGlobale = sconto + couponSconto;
    if (scontoPercentuale > 0 && subtotale > 0) {
      scontoGlobale += subtotale * (scontoPercentuale / 100);
    }
    return scontoRighe + scontoGlobale;
  }

  double get totaleVendite {
    return righe
        .where((riga) => riga.tipoMovimento == TipoRigaCassa.vendita)
        .fold(0.0, (sum, riga) => sum + riga.subtotale);
  }

  double get totaleResi {
    return righe
        .where((riga) => riga.tipoMovimento == TipoRigaCassa.reso)
        .fold(0.0, (sum, riga) => sum + riga.subtotale);
  }

  double get saldoOperazione => totale;

  bool get hasVendite =>
      righe.any((riga) => riga.tipoMovimento == TipoRigaCassa.vendita);

  bool get hasResi =>
      righe.any((riga) => riga.tipoMovimento == TipoRigaCassa.reso);

  TipoOperazioneCassa get tipoOperazioneEffettiva {
    if (hasVendite && hasResi) return TipoOperazioneCassa.cambio;
    if (hasResi) return TipoOperazioneCassa.reso;
    return TipoOperazioneCassa.vendita;
  }

  /// Imponibile (totale senza IVA)
  double get imponibile => totale - iva;

  /// Aggiunge una riga allo scontrino
  void aggiungiRiga(RigaScontrino riga) {
    righe.add(riga);
    calcolaTotale();
  }

  /// Rimuove una riga dallo scontrino
  void rimuoviRiga(int index) {
    if (index >= 0 && index < righe.length) {
      righe.removeAt(index);
      calcolaTotale();
    }
  }

  /// Svuota lo scontrino
  void reset() {
    righe.clear();
    subtotale = 0.0;
    iva = 0.0;
    sconto = 0.0;
    scontoPercentuale = 0.0;
    totale = 0.0;
    clienteId = null;
    clienteNome = null;
    clienteEmail = null;
    clienteTelefono = null;
    note = null;
    stato = 'aperto';
    couponCode = null;
    couponSconto = 0.0;
    importoRicevuto = 0.0;
    rettifiche.clear();
  }

  /// Verifica se lo scontrino è vuoto
  bool get isVuoto => righe.isEmpty;

  /// Numero totale di articoli
  int get numeroArticoli => righe.fold(0, (sum, riga) => sum + riga.quantita);

  /// Scontrini POS e ordini Woo non condividono mai il ciclo documentale.
  bool get isPos => canale == 'pos';

  String get operatoreLabel {
    final nome = [operatoreNome ?? '', operatoreCognome ?? ''].join(' ').trim();
    if (nome.isEmpty) return 'Operatore non assegnato';
    if (operatoreId != null) return '$nome (id $operatoreId)';
    return nome;
  }

  /// Giornata operativa: data + cassa. Il turno esplicito usa questa giornata
  /// come contenitore, ma lo scontrino conserva anche `turnoId`.
  static String calcolaGiornataId(DateTime data, String? cassaNome) {
    final giorno =
        '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
    final cassa = (cassaNome ?? '').trim().isEmpty
        ? 'cassa'
        : cassaNome!.trim();
    return '$giorno|$cassa';
  }

  void aggiungiRettifica(String nota) {
    final trimmed = nota.trim();
    if (trimmed.isEmpty) return;
    rettifiche.add('${DateTime.now().toIso8601String()} — $trimmed');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': data.toIso8601String(),
    'righe': righe.map((r) => r.toJson()).toList(),
    'subtotale': subtotale,
    'iva': iva,
    'sconto': sconto,
    'scontoPercentuale': scontoPercentuale,
    'totale': totale,
    'clienteId': clienteId,
    'clienteNome': clienteNome,
    'clienteEmail': clienteEmail,
    'clienteTelefono': clienteTelefono,
    'metodoPagamento': metodoPagamento,
    'note': note,
    'stato': stato,
    'tipoOperazione': tipoOperazione.value,
    'couponCode': couponCode,
    'couponSconto': couponSconto,
    'importoRicevuto': importoRicevuto,
    'aliquotaIva': aliquotaIva,
    'canale': canale,
    'numeroProgressivo': numeroProgressivo,
    'numeroProgressivoDispositivo': numeroProgressivoDispositivo,
    'operatoreId': operatoreId,
    'operatoreNome': operatoreNome,
    'operatoreCognome': operatoreCognome,
    'cassaNome': cassaNome,
    'sede': sede,
    'giornataId': giornataId,
    'turnoId': turnoId,
    'wooOrderId': wooOrderId?.toString(),
    'mgwsOrderId': mgwsOrderId?.toString(),
    'dataChiusura': dataChiusura?.toIso8601String(),
    'rettifiche': rettifiche,
  };

  factory Scontrino.fromJson(Map<String, dynamic> json) {
    TipoOperazioneCassa tipo = TipoOperazioneCassa.vendita;
    final rawTipo = json['tipoOperazione']?.toString();
    for (final v in TipoOperazioneCassa.values) {
      if (v.value == rawTipo) tipo = v;
    }
    final scontrino = Scontrino(
      id: json['id']?.toString() ?? '',
      data: DateTime.tryParse(json['data']?.toString() ?? '') ?? DateTime.now(),
      righe: ((json['righe'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RigaScontrino.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtotale: (json['subtotale'] as num?)?.toDouble() ?? 0,
      iva: (json['iva'] as num?)?.toDouble() ?? 0,
      sconto: (json['sconto'] as num?)?.toDouble() ?? 0,
      scontoPercentuale: (json['scontoPercentuale'] as num?)?.toDouble() ?? 0,
      totale: (json['totale'] as num?)?.toDouble() ?? 0,
      clienteId: json['clienteId']?.toString(),
      clienteNome: json['clienteNome']?.toString(),
      clienteEmail: json['clienteEmail']?.toString(),
      clienteTelefono: json['clienteTelefono']?.toString(),
      metodoPagamento: json['metodoPagamento']?.toString() ?? 'contanti',
      note: json['note']?.toString(),
      stato: json['stato']?.toString() ?? 'pagato',
      tipoOperazione: tipo,
      couponCode: json['couponCode']?.toString(),
      couponSconto: (json['couponSconto'] as num?)?.toDouble() ?? 0,
      importoRicevuto: (json['importoRicevuto'] as num?)?.toDouble() ?? 0,
      aliquotaIva: (json['aliquotaIva'] as num?)?.toDouble() ?? 22,
      canale: json['canale']?.toString() ?? 'pos',
      numeroProgressivo: (json['numeroProgressivo'] as num?)?.toInt(),
      numeroProgressivoDispositivo: json['numeroProgressivoDispositivo'] as String?,
      operatoreId: (json['operatoreId'] as num?)?.toInt(),
      operatoreNome: json['operatoreNome']?.toString(),
      operatoreCognome: json['operatoreCognome']?.toString(),
      cassaNome: json['cassaNome']?.toString(),
      sede: json['sede']?.toString(),
      giornataId: json['giornataId']?.toString(),
      turnoId: json['turnoId']?.toString(),
      wooOrderId: json['wooOrderId']?.toString(),
      mgwsOrderId: json['mgwsOrderId']?.toString(),
      dataChiusura: json['dataChiusura'] != null
          ? DateTime.tryParse(json['dataChiusura'].toString())
          : null,
      rettifiche: ((json['rettifiche'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
    return scontrino;
  }
}

/// Turno operativo di cassa aperto prima delle vendite e chiuso con una
/// chiusura cassa. Persistito localmente nello storico cassa; MGWS riceve il
/// riferimento nel payload POS per enforcement server-side futuro.
class TurnoCassa {
  final String id;
  final String giornataId;
  final String cassaNome;
  final String? sede;
  final int? operatoreId;
  final String? operatoreNome;
  final String? operatoreCognome;
  final DateTime dataApertura;
  final DateTime? dataChiusura;
  final double fondoIniziale;
  final StatoTurnoCassa stato;

  const TurnoCassa({
    required this.id,
    required this.giornataId,
    required this.cassaNome,
    this.sede,
    this.operatoreId,
    this.operatoreNome,
    this.operatoreCognome,
    required this.dataApertura,
    this.dataChiusura,
    this.fondoIniziale = 0,
    this.stato = StatoTurnoCassa.aperto,
  });

  bool get isAperto => stato == StatoTurnoCassa.aperto;

  String get operatoreLabel {
    final nome = [operatoreNome ?? '', operatoreCognome ?? ''].join(' ').trim();
    if (nome.isEmpty) return 'Operatore non assegnato';
    if (operatoreId != null) return '$nome (id $operatoreId)';
    return nome;
  }

  TurnoCassa chiudi(DateTime dataChiusura) => TurnoCassa(
    id: id,
    giornataId: giornataId,
    cassaNome: cassaNome,
    sede: sede,
    operatoreId: operatoreId,
    operatoreNome: operatoreNome,
    operatoreCognome: operatoreCognome,
    dataApertura: dataApertura,
    dataChiusura: dataChiusura,
    fondoIniziale: fondoIniziale,
    stato: StatoTurnoCassa.chiuso,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'giornataId': giornataId,
    'cassaNome': cassaNome,
    'sede': sede,
    'operatoreId': operatoreId,
    'operatoreNome': operatoreNome,
    'operatoreCognome': operatoreCognome,
    'dataApertura': dataApertura.toIso8601String(),
    'dataChiusura': dataChiusura?.toIso8601String(),
    'fondoIniziale': fondoIniziale,
    'stato': stato.value,
  };

  factory TurnoCassa.fromJson(Map<String, dynamic> json) {
    final rawStato = json['stato']?.toString();
    final stato = rawStato == StatoTurnoCassa.chiuso.value
        ? StatoTurnoCassa.chiuso
        : StatoTurnoCassa.aperto;
    return TurnoCassa(
      id: json['id']?.toString() ?? '',
      giornataId: json['giornataId']?.toString() ?? '',
      cassaNome: json['cassaNome']?.toString() ?? 'cassa',
      sede: json['sede']?.toString(),
      operatoreId: (json['operatoreId'] as num?)?.toInt(),
      operatoreNome: json['operatoreNome']?.toString(),
      operatoreCognome: json['operatoreCognome']?.toString(),
      dataApertura:
          DateTime.tryParse(json['dataApertura']?.toString() ?? '') ??
          DateTime.now(),
      dataChiusura: json['dataChiusura'] != null
          ? DateTime.tryParse(json['dataChiusura'].toString())
          : null,
      fondoIniziale: (json['fondoIniziale'] as num?)?.toDouble() ?? 0,
      stato: stato,
    );
  }
}

/// Rappresenta una singola riga dello scontrino
///
/// Le righe di reso vincolato ereditano prezzo/sconti dalla riga vendita
/// originaria e conservano `riferimentoScontrinoId` + `riferimentoChiaveRiga`.
class RigaScontrino {
  final ProdottoGlobal prodotto;
  final VarianteProductGlobal? variante;
  int quantita;
  double subtotale;
  double scontoRiga; // Sconto applicato alla singola riga (valore assoluto)
  double scontoPercentuale; // Sconto percentuale sulla riga
  String? note; // Note sulla riga
  TipoRigaCassa tipoMovimento;
  // Vincolo reso -> vendita originale.
  String? riferimentoScontrinoId;
  String? riferimentoChiaveRiga;
  String? motivoReso;
  String?
  esitoMerce; // 'reintegro', 'difettoso', 'buono', 'sostituzione', 'rimborso'

  // Prezzo unitario come lo registra il documento. Serve perche' il prezzo
  // di listino puo' cambiare dopo la vendita, mentre il documento conserva
  // quello realmente pagato.
  // Unit price as recorded on the document, needed because the list price may
  // change after the sale.
  double? recordedPrice;

  RigaScontrino({
    required this.prodotto,
    this.variante,
    required this.quantita,
    required this.subtotale,
    this.scontoRiga = 0.0,
    this.scontoPercentuale = 0.0,
    this.note,
    this.tipoMovimento = TipoRigaCassa.vendita,
    this.riferimentoScontrinoId,
    this.riferimentoChiaveRiga,
    this.motivoReso,
    this.esitoMerce,
    this.recordedPrice,
  });

  /// Ottiene il prezzo unitario effettivo (variante o prodotto)
  ///
  /// Se il documento ha registrato un prezzo, quello vince: la riga letta dal
  /// server deve mostrare cio' che il cliente ha pagato, non il listino di
  /// oggi.
  /// Effective unit price: the recorded price wins over the current list price.
  double get prezzoUnitario {
    final registrato = recordedPrice;
    if (registrato != null && registrato > 0) return registrato;
    if (variante != null) {
      return variante!.prezzoEffettivo;
    }
    return prodotto.prezzoEffettivo;
  }

  /// Ottiene il nome visualizzabile
  String get nomeCompleto {
    final prefix = tipoMovimento == TipoRigaCassa.reso ? '[RESO] ' : '';
    if (variante != null) {
      return '$prefix${prodotto.nome ?? ''} - ${variante!.nomeVisualizzabile}';
    }
    return '$prefix${prodotto.nome ?? ''}';
  }

  /// Ottiene l'immagine URL
  String? get immagineUrl {
    if (variante != null && variante!.immagineUrl != null) {
      return variante!.immagineUrl;
    }
    return prodotto.immagineUrl;
  }

  /// Ottiene il barcode interno
  String get barcodeInterno {
    if (variante != null) {
      return variante!.barcodeInterno;
    }
    return prodotto.barcodeInterno ?? '';
  }

  /// Calcola il subtotale della riga (con sconti applicati)
  void calcolaSubtotale() {
    double totaleRiga = quantita * prezzoUnitario;

    // Applica sconto percentuale
    if (scontoPercentuale > 0) {
      totaleRiga -= totaleRiga * (scontoPercentuale / 100);
    }

    // Applica sconto fisso
    totaleRiga -= scontoRiga;

    subtotale = totaleRiga > 0 ? totaleRiga : 0;
  }

  /// Applica uno sconto percentuale alla riga
  void applicaScontoPercentuale(double percentuale) {
    scontoPercentuale = percentuale.clamp(0, 100);
    calcolaSubtotale();
  }

  /// Applica uno sconto fisso alla riga
  void applicaScontoFisso(double sconto) {
    scontoRiga = sconto > 0 ? sconto : 0;
    calcolaSubtotale();
  }

  /// Rimuove tutti gli sconti dalla riga
  void rimuoviSconti() {
    scontoRiga = 0;
    scontoPercentuale = 0;
    calcolaSubtotale();
  }

  /// Totale sconti applicati alla riga
  double get totaleSconto {
    double totaleOriginale = quantita * prezzoUnitario;
    double scontoPerc = scontoPercentuale > 0
        ? totaleOriginale * (scontoPercentuale / 100)
        : 0;
    return scontoPerc + scontoRiga;
  }

  bool get isReso => tipoMovimento == TipoRigaCassa.reso;

  double get subtotaleSigned => isReso ? -subtotale : subtotale;

  /// Chiave stabile della riga vendita: identifica cosa e stato venduto e a
  /// quali condizioni, senza usare il prezzo di listino corrente.
  String get chiaveRiga {
    final prodottoId =
        prodotto.id?.toString() ?? prodotto.barcodeInterno ?? '?';
    final varianteId = variante?.id.toString() ?? '-';
    return '$prodottoId|$varianteId|'
        '${prezzoUnitario.toStringAsFixed(2)}|'
        '${scontoRiga.toStringAsFixed(2)}|'
        '${scontoPercentuale.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
    'productId': prodotto.id,
    'productName': prodotto.nome,
    'productCode': prodotto.codiceProdotto,
    'productBarcode': prodotto.barcodeInterno,
    'productSku': prodotto.barcodeInterno,
    'variationId': variante?.id,
    'variationCode': variante?.codiceProdotto,
    'variationBarcode': variante?.barcodeInterno,
    'variationSku': variante?.barcodeInterno,
    'variationName': variante?.nomeVisualizzabile,
    'unitPrice': prezzoUnitario,
    'quantita': quantita,
    'subtotale': subtotale,
    'scontoRiga': scontoRiga,
    'scontoPercentuale': scontoPercentuale,
    'note': note,
    'tipoMovimento': tipoMovimento.value,
    'riferimentoScontrinoId': riferimentoScontrinoId,
    'riferimentoChiaveRiga': riferimentoChiaveRiga,
    'motivoReso': motivoReso,
    'esitoMerce': esitoMerce,
  };

  factory RigaScontrino.fromJson(Map<String, dynamic> json) {
    TipoRigaCassa tipo = TipoRigaCassa.vendita;
    final raw = json['tipoMovimento']?.toString();
    for (final v in TipoRigaCassa.values) {
      if (v.value == raw) tipo = v;
    }
    final prodotto = ProdottoGlobal(
      id: (json['productId'] as num?)?.toInt(),
      nome: json['productName']?.toString(),
      codiceProdotto: json['productCode']?.toString(),
      barcodeInterno:
          json['productBarcode']?.toString() ?? json['productSku']?.toString(),
      prezzoNormale: (json['unitPrice'] as num?)?.toDouble(),
    );
    VarianteProductGlobal? variante;
    if (json['variationId'] != null) {
      variante = VarianteProductGlobal(
        id: (json['variationId'] as num?)?.toInt(),
        nome: json['variationName']?.toString(),
        codiceProdotto: json['variationCode']?.toString(),
        barcodeInterno:
            json['variationBarcode']?.toString() ??
            json['variationSku']?.toString() ??
            '',
        prezzo: (json['unitPrice'] as num?)?.toDouble(),
      );
    }
    final riga = RigaScontrino(
      prodotto: prodotto,
      variante: variante,
      quantita: (json['quantita'] as num?)?.toInt() ?? 0,
      subtotale: (json['subtotale'] as num?)?.toDouble() ?? 0,
      scontoRiga: (json['scontoRiga'] as num?)?.toDouble() ?? 0,
      scontoPercentuale: (json['scontoPercentuale'] as num?)?.toDouble() ?? 0,
      note: json['note']?.toString(),
      tipoMovimento: tipo,
      riferimentoScontrinoId: json['riferimentoScontrinoId']?.toString(),
      riferimentoChiaveRiga: json['riferimentoChiaveRiga']?.toString(),
      motivoReso: json['motivoReso']?.toString(),
      esitoMerce: json['esitoMerce']?.toString(),
    );
    // Se lo storico non conserva il prezzo unitario, lo ricostruisce dal
    // subtotale per mantenere il vincolo reso = prezzo realmente pagato.
    final storedUnit = (json['unitPrice'] as num?)?.toDouble();
    if (storedUnit != null &&
        riga.quantita > 0 &&
        (riga.prezzoUnitario == 0 || storedUnit != riga.prezzoUnitario)) {
      final lordo = storedUnit * riga.quantita;
      final daSconti = lordo - riga.subtotale;
      if (daSconti > 0.009 && riga.scontoRiga == 0) {
        riga.scontoRiga = double.parse(daSconti.toStringAsFixed(2));
        riga.calcolaSubtotale();
      }
    }
    return riga;
  }

  /// Aggiorna la quantità e ricalcola
  void aggiornaQuantita(int nuovaQuantita) {
    quantita = nuovaQuantita;
    calcolaSubtotale();
  }

  /// Incrementa la quantità di 1
  void incrementaQuantita() {
    quantita++;
    calcolaSubtotale();
  }

  /// Decrementa la quantità di 1 (minimo 1)
  void decrementaQuantita() {
    if (quantita > 1) {
      quantita--;
      calcolaSubtotale();
    }
  }
}
