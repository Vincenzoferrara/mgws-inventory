import '../reuse_class/datagridview/datagridview.code.dart';
import 'class_products.dart';
import 'product_cache.dart';

/// Campi di [ProdottoGlobal] per la lista Prodotti: filtri, ricerca,
/// ordinamento e colonne.
///
/// I nomi sono quelli dei vecchi `CampoFiltroProdotto`. Le colonne che prima
/// avevano un nome diverso (`sku`, `quantita`, `stato`, `marca`) sono alias
/// del campo: le colonne salvate nelle preferenze si leggono ancora e alla
/// prossima scelta vengono riscritte col nome nuovo.
final List<DataGridField<ProdottoGlobal>> prodottoGridFields =
    <DataGridField<ProdottoGlobal>>[
      DataGridField<ProdottoGlobal>(
        name: 'preview',
        label: (l10n) => l10n.prodottiColonnaAnteprima,
        read: (p) => <Object?>[p.immagineUrl],
        filterable: false,
        searchable: false,
        width: 112,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'id',
        label: (l10n) => l10n.prodottiFiltroCampo_id,
        aliases: const <String>['id', 'identificativo id'],
        type: DataGridFieldType.numero,
        read: (p) => <Object?>[p.id],
        sortable: true,
        width: 90,
        numeric: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'nome',
        label: (l10n) => l10n.prodottiFiltroCampo_nome,
        columnLabel: (l10n) => l10n.prodottiColonnaNome,
        aliases: const <String>['nome', 'prodotto', 'product', 'titolo'],
        read: (p) => <Object?>{
          p.nome,
          for (final variante in _varianti(p)) variante.nomeVisualizzabile,
          for (final variante in _varianti(p))
            for (final attr in variante.attributi) attr.opzione.trim(),
        },
        sortable: true,
        width: 240,
        // Il nome e' l'unica colonna che guadagna dalla larghezza extra: e'
        // il testo lungo che merita le decine di pixel rimaste libere.
        flexible: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'codiceArticolo',
        label: (l10n) => l10n.prodottiFiltroCampo_codiceArticolo,
        columnLabel: (l10n) => l10n.prodottiColonnaSkuV,
        aliases: const <String>[
          'sku',
          'codice',
          'codice prodotto',
          'articolo',
        ],
        read: (p) => <Object?>{
          p.codiceProdotto,
          for (final variante in _varianti(p)) variante.codiceProdotto,
        },
        sortable: true,
        width: 150,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'barcode',
        label: (l10n) => l10n.prodottiFiltroCampo_barcode,
        columnLabel: (l10n) => l10n.prodottiColonnaBarcodeV,
        aliases: const <String>[
          'barcode',
          'barcode interno',
          'barcode esterno',
          'barcode produttore',
          'ean',
          'upc',
          'gtin',
          'global_unique_id',
          'global unique id',
        ],
        read: (p) => <Object?>{
          p.barcodeInterno,
          p.barcodeProduttore,
          ..._externalBarcodeMetadataValues(p.metadatiCustom),
          for (final variante in _varianti(p)) ...[
            variante.barcodeInterno,
            variante.barcodeFornitore,
            ..._externalBarcodeMetadataValues(variante.metadatiCustom),
          ],
        },
        width: 150,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'categoria',
        label: (l10n) => l10n.prodottiFiltroCampo_categoria,
        aliases: const <String>['categoria', 'categorie', 'cat'],
        read: (p) => p.categoria?.map((c) => c.nome) ?? const <String>[],
        width: 180,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'tag',
        label: (l10n) => l10n.prodottiFiltroCampo_tag,
        aliases: const <String>['tag', 'etichette'],
        read: (p) => p.tag?.map((t) => t.nome) ?? const <String>[],
        width: 160,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'marchio',
        label: (l10n) => l10n.prodottiFiltroCampo_marchio,
        columnLabel: (l10n) => l10n.prodottiColonnaMarca,
        aliases: const <String>['marchio', 'marca', 'brand'],
        read: (p) => <Object?>[p.marca],
        sortable: true,
        width: 140,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'prezzo',
        label: (l10n) => l10n.prodottiFiltroCampo_prezzo,
        columnLabel: (l10n) => l10n.prodottiColonnaPrezzo,
        aliases: const <String>['prezzo', 'price', 'costo'],
        type: DataGridFieldType.numero,
        read: (p) => <Object?>[p.prezzoEffettivo],
        sortable: true,
        width: 120,
        numeric: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'sconto',
        label: (l10n) => l10n.prodottiColonnaSconto,
        type: DataGridFieldType.numero,
        read: (p) => <Object?>[p.prezzoScontato],
        format: (l10n, p) =>
            ProdottiCache.getPricingInfo(p).scontoLabel(l10n),
        filterable: false,
        searchable: false,
        width: 120,
        numeric: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'disponibilita',
        label: (l10n) => l10n.prodottiFiltroCampo_disponibilita,
        columnLabel: (l10n) => l10n.prodottiColonnaDisponibilitaV,
        aliases: const <String>['disponibilita', 'instock'],
        type: DataGridFieldType.booleano,
        read: (p) => <Object?>[p.isDisponibile],
        searchable: false,
        width: 140,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'giacenza',
        label: (l10n) => l10n.prodottiFiltroCampo_giacenza,
        columnLabel: (l10n) => l10n.prodottiColonnaQuantitaV,
        aliases: const <String>['giacenza', 'stock', 'quantita'],
        type: DataGridFieldType.numero,
        read: (p) => <Object?>[p.quantitaTotaleVarianti],
        sortable: true,
        width: 100,
        numeric: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'varianti',
        label: (l10n) => l10n.prodottiColonnaVarianti,
        type: DataGridFieldType.numero,
        read: (p) => <Object?>[p.varianti?.length ?? 0],
        filterable: false,
        searchable: false,
        width: 100,
        numeric: true,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'status',
        label: (l10n) => l10n.prodottiFiltroCampo_status,
        columnLabel: (l10n) => l10n.prodottiColonnaStatoV,
        aliases: const <String>['stato', 'status'],
        read: (p) => <Object?>[p.status],
        width: 120,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'descrizioneBreve',
        label: (l10n) => l10n.prodottiFiltroCampo_descrizioneBreve,
        aliases: const <String>['descrizione breve', 'breve', 'excerpt'],
        read: (p) => <Object?>[p.descrizioneBreve],
        column: false,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'descrizioneCompleta',
        label: (l10n) => l10n.prodottiFiltroCampo_descrizioneCompleta,
        aliases: const <String>[
          'descrizione',
          'descrizione completa',
          'contenuto',
        ],
        read: (p) => <Object?>[p.descrizioneCompleta],
        column: false,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'stanza',
        label: (l10n) => l10n.prodottiFiltroCampo_stanza,
        aliases: const <String>['stanza', 'room'],
        read: (p) => <Object?>[p.stanza],
        width: 120,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'scaffale',
        label: (l10n) => l10n.prodottiFiltroCampo_scaffale,
        aliases: const <String>['scaffale', 'rack'],
        read: (p) => <Object?>[p.scaffale],
        width: 120,
      ),
      DataGridField<ProdottoGlobal>(
        name: 'mensola',
        label: (l10n) => l10n.prodottiFiltroCampo_mensola,
        aliases: const <String>['mensola', 'shelf'],
        read: (p) => <Object?>[p.mensola],
        width: 120,
      ),
    ];

/// Colonne mostrate senza preferenze salvate.
const List<String> defaultProductGridColumns = <String>[
  'preview',
  'nome',
  'codiceArticolo',
  'barcode',
  'categoria',
  'prezzo',
  'sconto',
  'disponibilita',
  'giacenza',
  'varianti',
  'status',
];

const List<String> defaultMobileProductGridColumns = <String>[
  'preview',
  'nome',
  'codiceArticolo',
];

List<VarianteProductGlobal> _varianti(ProdottoGlobal p) =>
    p.varianti ?? const <VarianteProductGlobal>[];

/// Copre i dati precedenti al campo ufficiale `barcode_manufacturer` senza
/// confondere mai barcode e SKU.
List<String> _externalBarcodeMetadataValues(Map<String, dynamic>? metadata) {
  const keys = <String>[
    'barcode_manufacturer',
    'barcode_produttore',
    'supplier_sku',
    'barcode',
  ];
  return <String>{
    for (final key in keys)
      if ((metadata?[key]?.toString().trim() ?? '').isNotEmpty)
        metadata![key].toString().trim(),
  }.toList();
}
