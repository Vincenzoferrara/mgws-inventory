import 'package:woocommerce_flutter_api/woocommerce_flutter_api.dart';

import 'class_scontrino.dart';

/// Coupon WooCommerce applicato allo scontrino in cassa.
///
/// Conserva le regole del coupon, non solo l'importo: lo sconto si ricalcola
/// a ogni modifica del carrello, così aggiungere o togliere articoli non
/// lascia uno sconto calcolato su un carrello che non esiste più.
class CouponCassa {
  final String codice;
  final WooCouponDiscountType tipo;
  final double valore;
  final DateTime? scadenza;
  final int? limiteUtilizzi;
  final int utilizzi;
  final double? importoMinimo;
  final double? importoMassimo;
  final int? limiteArticoli;
  final bool escludiInSaldo;
  final Set<int> prodotti;
  final Set<int> prodottiEsclusi;
  final Set<int> categorie;
  final Set<int> categorieEscluse;
  final List<String> emailConsentite;

  const CouponCassa({
    required this.codice,
    required this.tipo,
    required this.valore,
    this.scadenza,
    this.limiteUtilizzi,
    this.utilizzi = 0,
    this.importoMinimo,
    this.importoMassimo,
    this.limiteArticoli,
    this.escludiInSaldo = false,
    this.prodotti = const {},
    this.prodottiEsclusi = const {},
    this.categorie = const {},
    this.categorieEscluse = const {},
    this.emailConsentite = const [],
  });

  factory CouponCassa.daWoo(WooCoupon coupon, String codice) {
    return CouponCassa(
      codice: codice,
      tipo: coupon.discountType ?? WooCouponDiscountType.unknown,
      valore: coupon.amount ?? 0,
      scadenza: coupon.dateExpiresGmt ?? coupon.dateExpires,
      limiteUtilizzi: coupon.usageLimit,
      utilizzi: coupon.usageCount ?? 0,
      // WooCommerce usa 0 per "nessun limite".
      importoMinimo: (coupon.minimumAmount ?? 0) > 0
          ? coupon.minimumAmount
          : null,
      importoMassimo: (coupon.maximumAmount ?? 0) > 0
          ? coupon.maximumAmount
          : null,
      limiteArticoli: (coupon.limitUsageToXItems ?? 0) > 0
          ? coupon.limitUsageToXItems
          : null,
      escludiInSaldo: coupon.excludeSaleItems ?? false,
      prodotti: {...?coupon.productIds},
      prodottiEsclusi: {...?coupon.excludedProductIds},
      categorie: {...?coupon.productCategories},
      categorieEscluse: {...?coupon.excludedProductCategories},
      emailConsentite: [
        for (final email in coupon.emailRestrictions ?? const <String>[])
          if (email.trim().isNotEmpty) email.trim().toLowerCase(),
      ],
    );
  }

  /// Motivo per cui il coupon non si può usare, o `null` se è valido.
  String? motivoNonValido({
    required List<RigaScontrino> righe,
    String? emailCliente,
    DateTime? adesso,
  }) {
    final ora = (adesso ?? DateTime.now()).toUtc();
    if (tipo == WooCouponDiscountType.unknown || valore <= 0) {
      return 'tipo di sconto non supportato';
    }
    if (scadenza != null && scadenza!.toUtc().isBefore(ora)) {
      return 'coupon scaduto';
    }
    final limite = limiteUtilizzi;
    if (limite != null && limite > 0 && utilizzi >= limite) {
      return 'limite di utilizzi raggiunto';
    }
    if (emailConsentite.isNotEmpty) {
      final email = (emailCliente ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return 'coupon riservato a clienti specifici: seleziona il cliente';
      }
      if (!emailConsentite.any((regola) => _emailCorrisponde(email, regola))) {
        return 'coupon non valido per questo cliente';
      }
    }
    final totale = _totaleVendite(righe);
    if (importoMinimo != null && totale < importoMinimo!) {
      return 'spesa minima di €${importoMinimo!.toStringAsFixed(2)}';
    }
    if (importoMassimo != null && totale > importoMassimo!) {
      return 'spesa massima di €${importoMassimo!.toStringAsFixed(2)}';
    }
    if (!righe.any(_rigaIdonea)) {
      return 'nessun articolo dello scontrino è idoneo';
    }
    return null;
  }

  /// Sconto del coupon sulle righe attuali, al centesimo.
  ///
  /// Si applica solo alle righe di vendita idonee e non supera mai il loro
  /// importo. Con un limite di articoli lo sconto copre solo i primi pezzi
  /// idonei nell'ordine dello scontrino.
  double calcolaSconto(List<RigaScontrino> righe) {
    final totale = _totaleVendite(righe);
    if (importoMinimo != null && totale < importoMinimo!) return 0;
    if (importoMassimo != null && totale > importoMassimo!) return 0;

    double sconto = 0;
    double baseIdonea = 0;
    int pezziRimasti = limiteArticoli ?? 1 << 30;

    for (final riga in righe) {
      if (pezziRimasti <= 0) break;
      if (!_rigaIdonea(riga) || riga.quantita <= 0) continue;

      final pezzi = riga.quantita < pezziRimasti ? riga.quantita : pezziRimasti;
      pezziRimasti -= pezzi;
      final nettoUnitario = riga.subtotale / riga.quantita;
      final base = nettoUnitario * pezzi;
      baseIdonea += base;

      switch (tipo) {
        case WooCouponDiscountType.percent:
          sconto += base * (valore.clamp(0, 100) / 100);
        case WooCouponDiscountType.fixedProduct:
          final perPezzo = valore < nettoUnitario ? valore : nettoUnitario;
          sconto += perPezzo * pezzi;
        case WooCouponDiscountType.fixedCart:
        case WooCouponDiscountType.unknown:
          break;
      }
    }

    if (tipo == WooCouponDiscountType.fixedCart) {
      sconto = valore < baseIdonea ? valore : baseIdonea;
    }
    return (sconto * 100).round() / 100;
  }

  bool _rigaIdonea(RigaScontrino riga) {
    if (riga.tipoMovimento != TipoRigaCassa.vendita) return false;

    final idProdotto = riga.prodotto.id;
    final idVariante = riga.variante?.id;
    final ids = {?idProdotto, ?idVariante};
    final idCategorie = {
      for (final categoria in riga.prodotto.categoria ?? const []) categoria.id,
    };

    if (ids.any(prodottiEsclusi.contains)) return false;
    if (idCategorie.any(categorieEscluse.contains)) return false;
    if (escludiInSaldo && _inSaldo(riga)) return false;

    // Senza restrizioni di prodotto o categoria il coupon vale su tutto;
    // con entrambe basta rientrare in una delle due, come in WooCommerce.
    if (prodotti.isEmpty && categorie.isEmpty) return true;
    return ids.any(prodotti.contains) || idCategorie.any(categorie.contains);
  }

  static bool _inSaldo(RigaScontrino riga) {
    final variante = riga.variante;
    final normale = variante?.prezzo ?? riga.prodotto.prezzoNormale ?? 0;
    final scontato = variante != null
        ? variante.prezzoScontato
        : riga.prodotto.prezzoScontato;
    return scontato != null && scontato > 0 && scontato < normale;
  }

  static double _totaleVendite(List<RigaScontrino> righe) => righe
      .where((riga) => riga.tipoMovimento == TipoRigaCassa.vendita)
      .fold(0.0, (somma, riga) => somma + riga.subtotale);

  /// Confronta un'email con una regola WooCommerce, che ammette `*`.
  static bool _emailCorrisponde(String email, String regola) {
    if (!regola.contains('*')) return email == regola;
    final pattern = regola.split('*').map(RegExp.escape).join('.*');
    return RegExp('^$pattern\$').hasMatch(email);
  }
}
