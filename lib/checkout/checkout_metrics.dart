/// Contatori della cassa per un turno o una giornata.
///
/// Si ricavano dagli scontrini registrati su MGWS: un contatore salvato sul
/// dispositivo si perderebbe con il dispositivo e non vedrebbe le altre casse.
/// Till counters for a shift or a business day, derived from the receipts
/// recorded on MGWS rather than from a device-local counter.
class CassaMetricheSnapshot {
  final int numeroVendite;
  final int numeroResi;
  final int numeroCambi;
  final double valoreVendite;
  final double valoreResi;
  final double saldoNetto;
  final double conguagliPositivi;
  final double conguagliNegativi;

  const CassaMetricheSnapshot({
    this.numeroVendite = 0,
    this.numeroResi = 0,
    this.numeroCambi = 0,
    this.valoreVendite = 0,
    this.valoreResi = 0,
    this.saldoNetto = 0,
    this.conguagliPositivi = 0,
    this.conguagliNegativi = 0,
  });

  /// Somma gli scontrini restituiti da `GET /pos/receipts`.
  ///
  /// Gli annullati non contano: un annullo non e' un incasso. Il saldo di un
  /// cambio va nei conguagli, positivo se il cliente ha pagato la differenza
  /// e negativo se l'ha ricevuta.
  /// Sums the receipts from `GET /pos/receipts`, cancelled ones excluded.
  factory CassaMetricheSnapshot.fromServerReceipts(
    Iterable<Map<String, dynamic>> receipts,
  ) {
    double numero(Object? valore) =>
        valore is num ? valore.toDouble() : double.tryParse('$valore') ?? 0;

    var vendite = 0;
    var resi = 0;
    var cambi = 0;
    var valoreVendite = 0.0;
    var valoreResi = 0.0;
    var saldo = 0.0;
    var conguagliPositivi = 0.0;
    var conguagliNegativi = 0.0;
    for (final receipt in receipts) {
      if (receipt['status'] == 'cancelled') continue;
      final saldoDocumento = numero(receipt['net_total']);
      switch (receipt['operation_type']) {
        case 'return':
          resi++;
        case 'exchange':
          cambi++;
          if (saldoDocumento > 0) conguagliPositivi += saldoDocumento;
          if (saldoDocumento < 0) conguagliNegativi += saldoDocumento.abs();
        default:
          vendite++;
      }
      valoreVendite += numero(receipt['sales_total']);
      valoreResi += numero(receipt['returns_total']);
      saldo += saldoDocumento;
    }
    return CassaMetricheSnapshot(
      numeroVendite: vendite,
      numeroResi: resi,
      numeroCambi: cambi,
      valoreVendite: valoreVendite,
      valoreResi: valoreResi,
      saldoNetto: saldo,
      conguagliPositivi: conguagliPositivi,
      conguagliNegativi: conguagliNegativi,
    );
  }
}
