// Modelli dati per statistiche e report vendite.
// Indipendenti dal backend: le query della piattaforma li costruiscono.

/// Classe per le statistiche
class Statistiche {
  final int totaleProdotti;
  final int prodottiPubblicati;
  final int prodottiBozza;
  final int prodottiConVarianti;
  final int prodottiInStock;
  final int prodottiOutOfStock;
  final double valoreInventarioTotale;
  final Map<String, int> prodottiPerCategoria;
  final Map<String, int> prodottiPerTag;

  Statistiche({
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

/// Report vendite
class ReportVendite {
  final DateTime periodo;
  final double totaleVendite;
  final int numeroOrdini;
  final double ticketMedio;
  final Map<String, double> venditePerCategoria;
  final Map<String, int> prodottiPiuVenduti;
  final List<VenditaGiornaliera> venditeGiornaliere;

  ReportVendite({
    required this.periodo,
    required this.totaleVendite,
    required this.numeroOrdini,
    required this.ticketMedio,
    required this.venditePerCategoria,
    required this.prodottiPiuVenduti,
    required this.venditeGiornaliere,
  });
}

/// Vendita giornaliera per grafici
class VenditaGiornaliera {
  final DateTime data;
  final double totale;
  final int ordini;

  VenditaGiornaliera({
    required this.data,
    required this.totale,
    required this.ordini,
  });
}
