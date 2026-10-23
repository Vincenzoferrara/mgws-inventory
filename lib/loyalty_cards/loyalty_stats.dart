/// Totali del programma fedeltà, indipendenti dalla piattaforma che li fornisce.
class LoyaltyStats {
  const LoyaltyStats({
    this.customers = 0,
    this.cards = 0,
    this.pointsBalance = 0,
    this.pointsIssued,
    this.tierCounts,
  });

  static const empty = LoyaltyStats();

  /// Clienti iscritti al programma.
  final int customers;

  /// Clienti con un numero di carta assegnato.
  final int cards;

  /// Punti ancora da spendere, sommati su tutti i clienti.
  final int pointsBalance;

  /// Punti assegnati da sempre; null se il backend non li riporta.
  final int? pointsIssued;

  /// Carte per livello (bronze, silver, gold, platinum); null se il backend
  /// non li riporta.
  final Map<String, int>? tierCounts;

  int tierCount(String tier) => tierCounts?[tier] ?? 0;
}
