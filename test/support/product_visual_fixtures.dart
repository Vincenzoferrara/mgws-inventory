import 'package:mgws_inventory/prodotti/class_prodotti.dart';

/// Local-only catalog for layout and interaction checks. No backend is needed.
List<ProdottoGlobal> productVisualFixtures() => [
  ProdottoGlobal(
    id: 901,
    nome: 'Camicia Oxford in cotone',
    barcodeInterno: 'CAM-OXF-001',
    prezzoNormale: 59,
    inStock: true,
    status: 'publish',
    quantitaTotale: 7,
    descrizioneBreve:
        'Cotone morbido, colletto button-down e vestibilità regolare.',
    categoria: [CategoriaProdotto(id: 1, nome: 'Camicie')],
    tag: [TagProdotto(id: 1, nome: 'Cotone')],
    metadatiCustom: {'barcode': '8000000000901'},
    varianti: [
      VarianteProductGlobal(
        id: 9011,
        nome: 'Blu / M',
        barcodeInterno: 'CAM-OXF-BLU-M',
        prezzo: 59,
        quantita: 7,
        attributi: [
          AttributoVariante(nome: 'Colore', opzione: 'Blu'),
          AttributoVariante(nome: 'Taglia', opzione: 'M'),
        ],
      ),
      VarianteProductGlobal(
        id: 9012,
        nome: 'Bianco / L',
        barcodeInterno: 'CAM-OXF-BIA-L',
        prezzo: 59,
        quantita: 0,
        attributi: [
          AttributoVariante(nome: 'Colore', opzione: 'Bianco'),
          AttributoVariante(nome: 'Taglia', opzione: 'L'),
        ],
      ),
    ],
  ),
  ProdottoGlobal(
    id: 902,
    nome: 'Pantalone sartoriale',
    barcodeInterno: 'PAN-SAR-002',
    prezzoNormale: 89,
    inStock: false,
    status: 'draft',
    quantitaTotale: 0,
  ),
  for (var i = 3; i <= 24; i++)
    ProdottoGlobal(
      id: 900 + i,
      nome: 'Maglia girocollo ${i.toString().padLeft(2, '0')}',
      barcodeInterno: 'MAG-${i.toString().padLeft(3, '0')}',
      prezzoNormale: 39,
      inStock: true,
      status: 'publish',
      quantitaTotale: i,
    ),
];
