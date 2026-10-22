// product_picker.dart
//
// Selettore prodotti condiviso fra cassa e inventario.
//
// La cassa lo usa per "aggiungi prodotto esistente" (lo aggiunge allo
// scontrino), l'inventario per la stessa operazione sulle righe di
// magazzino. Stessa schermata, stessa espansione prodotto+varianti: due
// copie avrebbero finito per divergere, e i due moduli finirebbero per
// chiedere cose diverse all'operatore.

import 'package:flutter/material.dart';

import '../class_products.dart';
import 'product_list.gui.dart';

/// Apre il selettore prodotti e restituisce i prodotti scelti.
///
/// Restituisce null se l'operatore preme "Annulla" o chiude col gesture:
/// per il chiamante null e "nessuna scelta" sono la stessa cosa.
Future<List<ProdottoGlobal>?> openProdottoPicker(BuildContext context) {
  return Navigator.of(context).push<List<ProdottoGlobal>>(
    MaterialPageRoute(
      builder: (_) => const ProdottiGestisciPage(modalitaCassa: true),
    ),
  );
}

/// Una unita' vendibile: un prodotto semplice, oppure una variante precisa.
///
/// Il picker restituisce i prodotti con dentro le sole varianti scelte, quindi
/// non serve a chi riceve il risultato sapere se sta guardando un prodotto
/// semplice o uno variabile: legge [variant] e basta.
class SelectedProductUnit {
  const SelectedProductUnit({required this.product, this.variant});

  final ProdottoGlobal product;
  final VarianteProductGlobal? variant;

  int get productId => product.id ?? 0;

  /// Zero per i prodotti semplici: e' il valore che MGWS usa per dire
  /// "prodotto senza varianti".
  int get variationId => variant?.id ?? 0;

  bool get isVariant => variant != null;

  bool get isValid => productId > 0;

  /// Etichetta leggibile: nome variante se c'e', altrimenti nome prodotto.
  String get label {
    final nome = variant?.nome.trim().isNotEmpty == true
        ? variant!.nome.trim()
        : (product.nome ?? '').trim();
    return nome.isEmpty ? '#$productId' : nome;
  }

  /// Barcode interno: quello della variante se esiste, altrimenti quello del
  /// prodotto. E' il codice che l'operatore scansiona, quindi quello che
  /// identifica la riga.
  String get barcodeInterno {
    final value = variant?.barcodeInterno.trim().isNotEmpty == true
        ? variant!.barcodeInterno
        : (product.barcodeInterno ?? '');
    return value.trim();
  }

  String? get imageUrl {
    final value = variant?.immagineUrl?.trim().isNotEmpty == true
        ? variant!.immagineUrl
        : product.immagineUrl;
    final url = value?.trim();
    return url == null || url.isEmpty ? null : url;
  }
}

/// Espande la selezione del picker in una riga per ogni unita' vendibile.
///
/// Il picker consegna un prodotto semplice con `varianti` vuota e un prodotto
/// variabile con dentro solo le varianti scelte. Qui quel guscio viene
/// staccato, cosi' ogni chiamante riceve una lista piatta e non deve
/// ricontrollare il caso "semplice o variabile".
List<SelectedProductUnit> expandSelectedProducts(
  List<ProdottoGlobal> prodotti,
) {
  final units = <SelectedProductUnit>[];
  for (final product in prodotti) {
    if ((product.id ?? 0) <= 0) continue;
    final varianti = (product.varianti ?? const <VarianteProductGlobal>[])
        .where((variante) => variante.id > 0)
        .toList();
    if (varianti.isEmpty) {
      units.add(SelectedProductUnit(product: product));
      continue;
    }
    for (final variante in varianti) {
      units.add(SelectedProductUnit(product: product, variant: variante));
    }
  }
  return units;
}
