import 'package:flutter/material.dart';

// ============================================================================
// HELPER FUNCTIONS PER GESTIONE NULL
// ============================================================================

/// Converte un int? in int, usando 0 come valore di default
int intNotNull(int? value) => value ?? 0;

/// Converte una String? in String, usando '' come valore di default
String stringNotNull(String? value) => value ?? '';

/// Converte una String? in String, usando un fallback se il valore è vuoto.
String stringNotNullOr(String? value, String fallback) {
  final normalized = stringNotNull(value);
  return normalized.isEmpty ? fallback : normalized;
}

/// Converte un double? in double, usando 0.0 come valore di default
double doubleNotNull(double? value) => value ?? 0.0;

// ============================================================================

class ProdottoGlobal {
  final int? id;
  final String? nome;

  /// Codice prodotto interno usato come SKU WooCommerce.
  final String? codiceProdotto;

  /// Barcode operativo usato internamente in negozio.
  /// Su WooCommerce corrisponde al campo core `global_unique_id`.
  final String? barcodeInterno;

  /// Barcode originale del produttore, se disponibile.
  /// Su WooCommerce viene salvato come custom field `barcode_manufacturer`.
  final String? barcodeProduttore;
  final double? prezzoNormale;
  final double? prezzoScontato;
  final double? costoAcquisto;
  final String? descrizioneBreve;
  final String? descrizioneCompleta;
  final String? immagineUrl;
  final List<String>? immaginiAggiuntive;
  final List<VarianteProductGlobal>? varianti;
  final List<int>? variations; // ID delle varianti da WooCommerce API
  final List<AttributoVariante>?
  attributi; // Attributi del prodotto (per prodotti variable)

  /// Tipo prodotto WooCommerce: 'simple' | 'variable' | 'grouped' | 'external'.
  /// È il segnale canonico per i prodotti variabile: a differenza di
  /// [variations], il campo `type` è sempre presente nelle risposte REST.
  final String? tipoProdotto;

  final List<CategoriaProdotto>? categoria; //todo sostitisci con una lista.
  final List<TagProdotto>? tag;
  //final String categoria;
  //final List<String> tag;

  final bool inStock;
  final int? quantitaTotale;
  final String? peso;
  final DimensioniProdotto? dimensioni;
  final String? marca;
  final String? permalink; // URL pubblico del prodotto su WooCommerce
  final DateTime? dataCreazione;
  final DateTime? dataModifica;
  final String status; // draft, publish, private
  final Map<String, dynamic>? metadatiCustom;

  // Campi per la posizione fisica nell'inventario
  final String? stanza;
  final String? scaffale;
  final String? mensola;

  ProdottoGlobal({
    this.id,
    this.nome,
    this.codiceProdotto,
    this.barcodeInterno,
    this.barcodeProduttore,
    this.prezzoNormale,
    this.prezzoScontato,
    this.costoAcquisto,
    this.descrizioneBreve,
    this.descrizioneCompleta,
    this.immagineUrl,
    this.immaginiAggiuntive,
    this.varianti,
    this.variations,
    this.attributi,
    this.tipoProdotto,
    this.categoria,
    this.tag,
    bool? inStock,
    this.quantitaTotale,
    this.peso,
    this.dimensioni,
    this.marca,
    this.permalink,
    this.dataCreazione,
    this.dataModifica,
    String? status,
    this.metadatiCustom,
    this.stanza,
    this.scaffale,
    this.mensola,
  }) : inStock = inStock ?? false,
       status = status ?? 'draft';

  ProdottoGlobal copyWith({
    int? id,
    String? nome,
    String? codiceProdotto,
    String? barcodeInterno,
    String? barcodeProduttore,
    double? prezzoNormale,
    double? prezzoScontato,
    double? costoAcquisto,
    String? descrizioneBreve,
    String? descrizioneCompleta,
    String? immagineUrl,
    List<String>? immaginiAggiuntive,
    List<VarianteProductGlobal>? varianti,
    List<int>? variations,
    List<AttributoVariante>? attributi,
    String? tipoProdotto,
    List<CategoriaProdotto>? categoria,
    List<TagProdotto>? tag,
    bool? inStock,
    int? quantitaTotale,
    String? peso,
    DimensioniProdotto? dimensioni,
    String? marca,
    String? permalink,
    DateTime? dataCreazione,
    DateTime? dataModifica,
    String? status,
    Map<String, dynamic>? metadatiCustom,
    String? stanza,
    String? scaffale,
    String? mensola,
  }) {
    return ProdottoGlobal(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      codiceProdotto: codiceProdotto ?? this.codiceProdotto,
      barcodeInterno: barcodeInterno ?? this.barcodeInterno,
      barcodeProduttore: barcodeProduttore ?? this.barcodeProduttore,
      prezzoNormale: prezzoNormale ?? this.prezzoNormale,
      prezzoScontato: prezzoScontato ?? this.prezzoScontato,
      costoAcquisto: costoAcquisto ?? this.costoAcquisto,
      descrizioneBreve: descrizioneBreve ?? this.descrizioneBreve,
      descrizioneCompleta: descrizioneCompleta ?? this.descrizioneCompleta,
      immagineUrl: immagineUrl ?? this.immagineUrl,
      immaginiAggiuntive: immaginiAggiuntive ?? this.immaginiAggiuntive,
      varianti: varianti ?? this.varianti,
      variations: variations ?? this.variations,
      attributi: attributi ?? this.attributi,
      tipoProdotto: tipoProdotto ?? this.tipoProdotto,
      categoria: categoria ?? this.categoria,
      tag: tag ?? this.tag,
      inStock: inStock ?? this.inStock,
      quantitaTotale: quantitaTotale ?? this.quantitaTotale,
      peso: peso ?? this.peso,
      dimensioni: dimensioni ?? this.dimensioni,
      marca: marca ?? this.marca,
      permalink: permalink ?? this.permalink,
      dataCreazione: dataCreazione ?? this.dataCreazione,
      dataModifica: dataModifica ?? this.dataModifica,
      status: status ?? this.status,
      metadatiCustom: metadatiCustom ?? this.metadatiCustom,
      stanza: stanza ?? this.stanza,
      scaffale: scaffale ?? this.scaffale,
      mensola: mensola ?? this.mensola,
    );
  }

  /// Calcola il prezzo effettivo (scontato se disponibile, altrimenti normale)
  double get prezzoEffettivo => prezzoScontato ?? prezzoNormale ?? 0;
  double? get percentualeSconto {
    if (prezzoScontato == null || (prezzoNormale ?? 0) == 0) return null;
    return (((prezzoNormale ?? 0) - prezzoScontato!) / (prezzoNormale ?? 1)) *
        100;
  }

  /// Verifica se il prodotto ha varianti
  bool get hasVarianti => varianti != null && (varianti?.isNotEmpty ?? false);

  /// Verifica se il prodotto è di tipo variabile (WooCommerce `type: variable`).
  ///
  /// Usa il campo `type` come fonte canonica e `variations` come fallback:
  /// alcune configurazioni server possono omettere la lista delle ID varianti
  /// nelle risposte di lista, mentre `type: "variable"` è sempre presente.
  bool get isVariabile =>
      tipoProdotto == 'variable' || (variations?.isNotEmpty ?? false);

  /// Ottiene tutte le immagini del prodotto (principale + aggiuntive)
  List<String> get tutteLeImmagini => [
    if (immagineUrl != null) immagineUrl!,
    ...(immaginiAggiuntive ?? []),
  ];
  int get quantitaTotaleVarianti {
    if (varianti?.isEmpty ?? true) return quantitaTotale ?? 0;
    return varianti?.fold<int>(0, (sum, variante) => sum + variante.quantita) ??
        0;
  }

  /// Verifica se il prodotto è disponibile (ha stock)
  bool get isDisponibile {
    if (!hasVarianti) return inStock && (quantitaTotale ?? 0) > 0;
    return varianti?.any((v) => v.quantita > 0) ?? false;
  }

  /// Converte il prodotto in Map per il report builder
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome ?? '',
      'sku': codiceProdotto ?? '',
      'global_unique_id': barcodeInterno ?? '',
      'barcode_manufacturer': barcodeProduttore ?? '',
      'prezzoNormale': prezzoNormale ?? 0,
      'prezzoScontato': prezzoScontato,
      'prezzoEffettivo': prezzoEffettivo,
      'percentualeSconto': percentualeSconto,
      'descrizioneBreve': descrizioneBreve ?? '',
      'descrizioneCompleta': descrizioneCompleta ?? '',
      'immagineUrl': immagineUrl ?? '',
      'categoria': categoria?.map((c) => c.nome).join(', ') ?? '',
      'tag': tag?.map((t) => t.nome).join(', ') ?? '',
      'marca': marca ?? '',
      'permalink': permalink ?? '',
      'quantitaTotale': quantitaTotale ?? 0,
      'inStock': inStock,
      'peso': peso ?? '',
      'stanza': stanza ?? '',
      'scaffale': scaffale ?? '',
      'mensola': mensola ?? '',
      'status': status,
      'dataCreazione': dataCreazione?.toIso8601String() ?? '',
      'dataModifica': dataModifica?.toIso8601String() ?? '',
    };
  }
}

class ColorUtils {
  /// Converte una stringa esadecimale in un oggetto Color.
  /// Supporta formati come #RRGGBB, #AARRGGBB, RRGGBB, AARRGGBB.
  static Color colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.white; // Colore di fallback in caso di errore
    }
  }

  /// Converte un oggetto Color in una stringa esadecimale nel formato #RRGGBB.
  static String colorToHex(Color color, {bool leadingHashSign = true}) {
    String toHexChannel(double channel) {
      return (channel * 255).round().toRadixString(16).padLeft(2, '0');
    }

    return '${leadingHashSign ? '#' : ''}'
        '${toHexChannel(color.r)}'
        '${toHexChannel(color.g)}'
        '${toHexChannel(color.b)}';
  }
}

/// Rappresenta le dimensioni di un prodotto
class DimensioniProdotto {
  final double lunghezza;
  final double larghezza;
  final double altezza;
  final String unita; // cm, mm, in, etc.

  DimensioniProdotto({
    double? lunghezza,
    double? larghezza,
    double? altezza,
    String? unita,
  }) : lunghezza = doubleNotNull(lunghezza),
       larghezza = doubleNotNull(larghezza),
       altezza = doubleNotNull(altezza),
       unita = stringNotNullOr(unita, 'cm');

  /// Calcola il volume
  double get volume => lunghezza * larghezza * altezza;

  @override
  String toString() => '${lunghezza}x${larghezza}x$altezza $unita';
}

/// Rappresenta un singolo attributo di una variante.
/// Esempio: { nome: "Colore", opzione: "Rosso", valore: "#FF0000", tipo: "color" }
class AttributoVariante {
  final int? id; // ID dell'attributo nel sistema backend
  final String nome; // Es. "Colore", "Taglia"
  final String opzione; // Es. "Rosso", "M"
  final String? valore; // Es. "#FF0000" (per i colori), opzionale
  final String? slug; // slug per l'attributo nel backend
  final TipoAttributo tipo; // Tipo di attributo
  final bool visibile; // Se l'attributo è visibile nel frontend
  final bool usatoPerVariazioni; // Se è usato per creare variazioni

  AttributoVariante({
    this.id,
    String? nome,
    String? opzione,
    this.valore,
    this.slug,
    this.tipo = TipoAttributo.select,
    this.visibile = true,
    this.usatoPerVariazioni = true,
  }) : nome = stringNotNull(nome),
       opzione = stringNotNull(opzione);

  /// Crea una copia dell'attributo con i campi specificati modificati
  AttributoVariante copyWith({
    int? id,
    String? nome,
    String? opzione,
    String? valore,
    String? slug,
    TipoAttributo? tipo,
    bool? visibile,
    bool? usatoPerVariazioni,
  }) {
    return AttributoVariante(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      opzione: opzione ?? this.opzione,
      valore: valore ?? this.valore,
      slug: slug ?? this.slug,
      tipo: tipo ?? this.tipo,
      visibile: visibile ?? this.visibile,
      usatoPerVariazioni: usatoPerVariazioni ?? this.usatoPerVariazioni,
    );
  }

  /// Verifica se l'attributo ha un valore specifico (per colori, immagini, etc.)
  bool get hasValore => valore != null && valore!.isNotEmpty;

  @override
  String toString() => '$nome: $opzione${hasValore ? ' ($valore)' : ''}';
}

/// Enum per i tipi di attributo supportati
enum TipoAttributo {
  select, // Dropdown classico
  color, // Campione di colore
  image, // Campione con immagine
  label, // Etichetta testuale
  button, // Bottone (es. per taglie)
  radio, // Radio button
  text, // Campo di testo libero
}

/// Extension per convertire TipoAttributo in stringa e viceversa
extension TipoAttributoExtension on TipoAttributo {
  String get value {
    switch (this) {
      case TipoAttributo.select:
        return 'select';
      case TipoAttributo.color:
        return 'color';
      case TipoAttributo.image:
        return 'image';
      case TipoAttributo.label:
        return 'label';
      case TipoAttributo.button:
        return 'button';
      case TipoAttributo.radio:
        return 'radio';
      case TipoAttributo.text:
        return 'text';
    }
  }

  static TipoAttributo fromString(String value) {
    switch (value.toLowerCase()) {
      case 'color':
        return TipoAttributo.color;
      case 'image':
        return TipoAttributo.image;
      case 'label':
        return TipoAttributo.label;
      case 'button':
        return TipoAttributo.button;
      case 'radio':
        return TipoAttributo.radio;
      case 'text':
        return TipoAttributo.text;
      default:
        return TipoAttributo.select;
    }
  }
}

/// Rappresenta una singola variante di un ProdottoWoo.
class VarianteProductGlobal {
  final int id;
  final String nome;
  final List<AttributoVariante> attributi;

  /// Codice prodotto interno usato come SKU WooCommerce.
  final String codiceProdotto;

  /// Barcode operativo usato internamente in negozio.
  /// Su WooCommerce corrisponde al campo core `global_unique_id`.
  final String barcodeInterno;

  /// Barcode originale del produttore, se disponibile.
  /// Su WooCommerce viene salvato come custom field `barcode_manufacturer`.
  final String barcodeFornitore;
  final double prezzo;
  final double? prezzoScontato;
  final double? costoAcquisto;
  final int quantita;
  final String? immagineUrl;
  final List<String> immaginiAggiuntive;
  final String? peso;
  final DimensioniProdotto? dimensioni;
  final bool attiva;
  final Map<String, dynamic>? metadatiCustom;

  // Campi per la posizione fisica nell'inventario
  final String? stanza;
  final String? scaffale;
  final String? mensola;

  VarianteProductGlobal({
    int? id,
    String? nome,
    List<AttributoVariante>? attributi,
    String? codiceProdotto,
    String? barcodeInterno,
    String? barcodeFornitore,
    double? prezzo,
    this.prezzoScontato,
    this.costoAcquisto,
    int? quantita,
    this.immagineUrl,
    List<String>? immaginiAggiuntive,
    this.peso,
    this.dimensioni,
    bool? attiva,
    this.metadatiCustom,
    this.stanza,
    this.scaffale,
    this.mensola,
  }) : id = intNotNull(id),
       nome = stringNotNull(nome),
       attributi = attributi ?? [],
       codiceProdotto = stringNotNull(codiceProdotto),
       barcodeInterno = stringNotNull(barcodeInterno),
       barcodeFornitore = stringNotNull(barcodeFornitore),
       prezzo = doubleNotNull(prezzo),
       quantita = intNotNull(quantita),
       attiva = attiva ?? true,
       immaginiAggiuntive = immaginiAggiuntive ?? [];

  /// Crea una copia della variante con i campi specificati modificati
  VarianteProductGlobal copyWith({
    int? id,
    String? nome,
    List<AttributoVariante>? attributi,
    String? codiceProdotto,
    String? barcodeInterno,
    String? barcodeFornitore,
    double? prezzo,
    double? prezzoScontato,
    double? costoAcquisto,
    int? quantita,
    String? immagineUrl,
    List<String>? immaginiAggiuntive,
    String? peso,
    DimensioniProdotto? dimensioni,
    bool? attiva,
    Map<String, dynamic>? metadatiCustom,
    String? stanza,
    String? scaffale,
    String? mensola,
  }) {
    return VarianteProductGlobal(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      attributi: attributi ?? this.attributi,
      codiceProdotto: codiceProdotto ?? this.codiceProdotto,
      barcodeInterno: barcodeInterno ?? this.barcodeInterno,
      barcodeFornitore: barcodeFornitore ?? this.barcodeFornitore,
      prezzo: prezzo ?? this.prezzo,
      prezzoScontato: prezzoScontato ?? this.prezzoScontato,
      costoAcquisto: costoAcquisto ?? this.costoAcquisto,
      quantita: quantita ?? this.quantita,
      immagineUrl: immagineUrl ?? this.immagineUrl,
      immaginiAggiuntive: immaginiAggiuntive ?? this.immaginiAggiuntive,
      peso: peso ?? this.peso,
      dimensioni: dimensioni ?? this.dimensioni,
      attiva: attiva ?? this.attiva,
      metadatiCustom: metadatiCustom ?? this.metadatiCustom,
      stanza: stanza ?? this.stanza,
      scaffale: scaffale ?? this.scaffale,
      mensola: mensola ?? this.mensola,
    );
  }

  /// Calcola il prezzo effettivo (scontato se disponibile, altrimenti normale)
  double get prezzoEffettivo => prezzoScontato ?? prezzo;

  /// Nome visualizzabile basato sugli attributi
  String get nomeVisualizzabile {
    if (attributi.isEmpty) return nome.isEmpty ? 'Variante' : nome;
    return attributi.map((a) => a.opzione).join(' - ');
  }

  /// Trova l'attributo colore nella variante
  AttributoVariante? get attributoColore {
    try {
      return attributi.firstWhere(
        (a) => a.tipo == TipoAttributo.color && a.hasValore,
      );
    } catch (e) {
      return null;
    }
  }

  /// Verifica se la variante è disponibile
  bool get isDisponibile => attiva && quantita > 0;

  /// Ottiene tutte le immagini della variante
  List<String> get tutteLeImmagini {
    if (immagineUrl == null) return immaginiAggiuntive;
    return [immagineUrl!, ...immaginiAggiuntive];
  }

  /// Calcola la percentuale di sconto se presente
  double? get percentualeSconto {
    if (prezzoScontato == null || prezzo == 0) return null;
    return ((prezzo - prezzoScontato!) / prezzo) * 100;
  }

  @override
  String toString() =>
      '$nomeVisualizzabile (Barcode interno: $barcodeInterno, Prezzo: €${prezzoEffettivo.toStringAsFixed(2)})';
}

/// Classe per rappresentare una categoria di prodotti
class CategoriaProdotto {
  final int id;
  final String nome;
  final String slug;
  final String? descrizione;
  final String? immagine;
  final int? parentId;
  final int count; // Numero di prodotti nella categoria
  final bool visibile;

  CategoriaProdotto({
    int? id,
    String? nome,
    String? slug,
    this.descrizione,
    this.immagine,
    this.parentId,
    int? count,
    bool? visibile,
  }) : id = intNotNull(id),
       nome = stringNotNull(nome),
       slug = stringNotNull(slug),
       count = intNotNull(count),
       visibile = visibile ?? true;

  /// Verifica se è una categoria principale (senza parent)
  bool get isPrincipale => parentId == null;

  @override
  String toString() => nome;
}

/// Classe per rappresentare un tag di prodotto
class TagProdotto {
  final int id;
  final String nome;
  final String slug;
  final String? descrizione;
  final int count; // Numero di prodotti con questo tag

  TagProdotto({
    int? id,
    String? nome,
    String? slug,
    this.descrizione,
    int? count,
  }) : id = intNotNull(id),
       nome = stringNotNull(nome),
       slug = stringNotNull(slug),
       count = intNotNull(count);

  @override
  String toString() => nome;
}

class MarcaProdotto {
  final int id;
  final String nome;
  final String slug;
  final String? descrizione;
  final int count; // Numero di prodotti con questa marca

  MarcaProdotto({
    int? id,
    String? nome,
    String? slug,
    this.descrizione,
    int? count,
  }) : id = intNotNull(id),
       nome = stringNotNull(nome),
       slug = stringNotNull(slug),
       count = intNotNull(count);

  @override
  String toString() => nome;
}

/// Classe per la gestione dei filtri di ricerca prodotti
class FiltroProdotti {
  final String? search;
  final List<int>? categorieIds;
  final List<int>? tagIds;
  final double? prezzoMin;
  final double? prezzoMax;
  final bool? inStock;
  final String? status;
  final List<String>? barcodeInterni;
  final String? orderBy;
  final String? order;
  final int page;
  final int perPage;
  final Map<String, List<String>>? attributi; // Filtri per attributi specifici

  FiltroProdotti({
    this.search,
    this.categorieIds,
    this.tagIds,
    this.prezzoMin,
    this.prezzoMax,
    this.inStock,
    this.status,
    this.barcodeInterni,
    this.orderBy = 'date',
    this.order = 'desc',
    this.page = 1,
    this.perPage = 10,
    this.attributi,
  });

  /// Crea una copia del filtro con i parametri modificati
  FiltroProdotti copyWith({
    String? search,
    List<int>? categorieIds,
    List<int>? tagIds,
    double? prezzoMin,
    double? prezzoMax,
    bool? inStock,
    String? status,
    List<String>? barcodeInterni,
    String? orderBy,
    String? order,
    int? page,
    int? perPage,
    Map<String, List<String>>? attributi,
  }) {
    return FiltroProdotti(
      search: search ?? this.search,
      categorieIds: categorieIds ?? this.categorieIds,
      tagIds: tagIds ?? this.tagIds,
      prezzoMin: prezzoMin ?? this.prezzoMin,
      prezzoMax: prezzoMax ?? this.prezzoMax,
      inStock: inStock ?? this.inStock,
      status: status ?? this.status,
      barcodeInterni: barcodeInterni ?? this.barcodeInterni,
      orderBy: orderBy ?? this.orderBy,
      order: order ?? this.order,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      attributi: attributi ?? this.attributi,
    );
  }
}

/// Classe per il risultato di una ricerca paginata
class RisultatoProdotti {
  final List<ProdottoGlobal> prodotti;
  final int totaleProdotti;
  final int totalePagine;
  final int paginaCorrente;
  final int prodottiPerPagina;
  final bool hasPaginaPrecedente;
  final bool hasPaginaSuccessiva;

  RisultatoProdotti({
    required this.prodotti,
    required this.totaleProdotti,
    required this.totalePagine,
    required this.paginaCorrente,
    required this.prodottiPerPagina,
  }) : hasPaginaPrecedente = paginaCorrente > 1,
       hasPaginaSuccessiva = paginaCorrente < totalePagine;
}

/// Classe per le statistiche dei prodotti
class StatisticheProdotti {
  final int totaleProdotti;
  final int prodottiPubblicati;
  final int prodottiBozza;
  final int prodottiConVarianti;
  final int prodottiInStock;
  final int prodottiOutOfStock;
  final double valoreInventarioTotale;
  final Map<String, int> prodottiPerCategoria;
  final Map<String, int> prodottiPerTag;

  StatisticheProdotti({
    required this.totaleProdotti,
    required this.prodottiPubblicati,
    required this.prodottiBozza,
    required this.prodottiConVarianti,
    required this.prodottiInStock,
    required this.prodottiOutOfStock,
    required this.valoreInventarioTotale,
    required this.prodottiPerCategoria,
    required this.prodottiPerTag,
  });
}

/// Classe per rappresentare un'operazione batch
class OperazioneBatch<T> {
  final List<T> create;
  final List<T> update;
  final List<int> delete;

  OperazioneBatch({List<T>? create, List<T>? update, List<int>? delete})
    : create = create ?? [],
      update = update ?? [],
      delete = delete ?? [];

  bool get isEmpty => create.isEmpty && update.isEmpty && delete.isEmpty;
  bool get hasOperazioni => !isEmpty;
  int get totaleOperazioni => create.length + update.length + delete.length;
}

/// Risultato di un'operazione batch
class RisultatoBatch<T> {
  final List<T> created;
  final List<T> updated;
  final List<T> deleted;
  final List<String> errori;
  final bool success;

  RisultatoBatch({
    List<T>? created,
    List<T>? updated,
    List<T>? deleted,
    List<String>? errori,
  }) : created = created ?? [],
       updated = updated ?? [],
       deleted = deleted ?? [],
       errori = errori ?? [],
       success = (errori ?? []).isEmpty;

  int get totaleSuccessi => created.length + updated.length + deleted.length;
  bool get hasErrori => errori.isNotEmpty;
}

/// Interfaccia per l'export/import dei prodotti
abstract class ProdottoExportImport {
  /// Esporta i prodotti in formato JSON
  Future<String> esportaJSON(List<ProdottoGlobal> prodotti);

  /// Importa prodotti da JSON
  Future<List<ProdottoGlobal>> importaJSON(String jsonData);
}

/// Classe per la validazione dei prodotti
class ValidatoreProdotti {
  static List<String> valida(ProdottoGlobal prodotto) {
    final errori = <String>[];

    // Validazioni base
    if ((prodotto.nome?.trim() ?? '').isEmpty) {
      errori.add('Il nome del prodotto è obbligatorio');
    }

    if ((prodotto.barcodeInterno?.trim() ?? '').isEmpty) {
      errori.add('Il barcode interno è obbligatorio');
    }

    if ((prodotto.prezzoNormale ?? 0) <= 0) {
      errori.add('Il prezzo normale deve essere maggiore di 0');
    }

    if (prodotto.prezzoScontato != null &&
        prodotto.prezzoScontato! >= (prodotto.prezzoNormale ?? 0)) {
      errori.add('Il prezzo scontato deve essere minore del prezzo normale');
    }

    if ((prodotto.descrizioneBreve?.trim() ?? '').isEmpty) {
      errori.add('La descrizione breve è obbligatoria');
    }

    if ((prodotto.categoria?.isEmpty ?? true)) {
      errori.add('La categoria è obbligatoria');
    }

    // Validazione URL immagine
    if ((prodotto.immagineUrl?.isNotEmpty ?? false) &&
        !_isValidUrl(prodotto.immagineUrl!)) {
      errori.add('URL dell\'immagine principale non valido');
    }

    // Validazione varianti
    if (prodotto.varianti?.isNotEmpty ?? false) {
      errori.addAll(_validaVarianti(prodotto.varianti!));
    }

    return errori;
  }

  static List<String> _validaVarianti(List<VarianteProductGlobal> varianti) {
    final errori = <String>[];
    final barcodeInterniUsati = <String>{};
    final codiciProdottoUsati = <String>{};

    for (int i = 0; i < varianti.length; i++) {
      final variante = varianti[i];
      final prefisso = 'Variante ${i + 1}: ';

      if (variante.barcodeInterno.trim().isEmpty) {
        errori.add('${prefisso}Barcode interno obbligatorio');
      } else if (barcodeInterniUsati.contains(variante.barcodeInterno)) {
        errori.add('${prefisso}Barcode interno duplicato');
      } else {
        barcodeInterniUsati.add(variante.barcodeInterno);
      }

      // Il codice prodotto (SKU) della variante è opzionale: se assente,
      // WooCommerce usa il riferimento del prodotto genitore.
      final codiceProdotto = variante.codiceProdotto.trim();
      if (codiceProdotto.isNotEmpty) {
        if (codiciProdottoUsati.contains(codiceProdotto)) {
          errori.add('${prefisso}Codice prodotto duplicato');
        } else {
          codiciProdottoUsati.add(codiceProdotto);
        }
      }

      if (variante.prezzo <= 0) {
        errori.add('${prefisso}Il prezzo deve essere maggiore di 0');
      }

      if (variante.quantita < 0) {
        errori.add('${prefisso}La quantità non può essere negativa');
      }

      if (variante.attributi.isEmpty) {
        errori.add('${prefisso}Almeno un attributo è richiesto');
      }

      // Validazione attributi
      for (final attributo in variante.attributi) {
        if (attributo.nome.trim().isEmpty) {
          errori.add('${prefisso}Nome attributo obbligatorio');
        }
        if (attributo.opzione.trim().isEmpty) {
          errori.add('${prefisso}Opzione attributo obbligatoria');
        }
      }

      // Validazione URL immagine variante
      if (variante.immagineUrl != null &&
          variante.immagineUrl!.isNotEmpty &&
          !_isValidUrl(variante.immagineUrl!)) {
        errori.add('${prefisso}URL dell\'immagine non valido');
      }
    }

    return errori;
  }

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
}
