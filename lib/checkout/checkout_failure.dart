/// Motivi per cui un'operazione di cassa viene rifiutata.
///
/// Il codice di cassa non conosce la lingua dell'interfaccia: restituisce un
/// [CassaFailure] e la GUI lo traduce con `CassaFailureText.testo`
/// (checkout_failure_text.dart).
enum CassaFailureCode {
  shiftAlreadyOpen,
  shiftNotFound,
  shiftAlreadyClosed,
  noOpenShift,
  openShiftBeforeAdding,
  closeReceiptBeforeShiftClose,
  differenceReasonRequired,
  invalidServerResponse,
  shiftOperationFailed,
  invalidLine,
  insufficientStock,
  returnNotAllowed,
  saleLineNotFound,
  lineFullyReturned,
  invalidReturnQuantity,
  returnReasonRequired,
  returnExceedsRemaining,
  originReceiptNotFound,
  originReceiptCancelled,
  receiptNotFound,
  receiptAlreadyCancelled,
  onlyClosedReceiptsCancellable,
  cancelReasonRequired,
  adjustmentNoteRequired,
  couponNotFound,
  couponCheckFailed,
  couponUnsupportedType,
  couponExpired,
  couponUsageLimitReached,
  couponCustomerRequired,
  couponNotForCustomer,
  couponMinimumSpend,
  couponMaximumSpend,
  couponNoEligibleItems,

  /// Messaggio restituito dal backend, mostrato cosi com'e.
  server,
}

/// Errore di cassa con i dati che servono al testo tradotto.
class CassaFailure {
  final CassaFailureCode code;

  /// Pezzi disponibili (stock o residuo rendibile).
  final int? disponibili;

  /// Pezzi richiesti dall'operatore.
  final int? richiesti;

  /// Pezzi venduti e gia resi della riga, per i resi.
  final int? venduti;
  final int? giaResi;

  /// Importo di riferimento, ad esempio la spesa minima di un coupon.
  final double? importo;

  /// Testo del server per [CassaFailureCode.server].
  final String? messaggio;

  const CassaFailure(
    this.code, {
    this.disponibili,
    this.richiesti,
    this.venduti,
    this.giaResi,
    this.importo,
    this.messaggio,
  });

  const CassaFailure.server(String this.messaggio)
    : code = CassaFailureCode.server,
      disponibili = null,
      richiesti = null,
      venduti = null,
      giaResi = null,
      importo = null;

  /// Descrizione per i log, non per l'interfaccia.
  @override
  String toString() {
    final dettagli = <String>[
      if (disponibili != null) 'available=$disponibili',
      if (richiesti != null) 'requested=$richiesti',
      if (venduti != null) 'sold=$venduti',
      if (giaResi != null) 'returned=$giaResi',
      if (importo != null) 'amount=$importo',
      if (messaggio != null) messaggio!,
    ];
    return dettagli.isEmpty
        ? code.name
        : '${code.name} (${dettagli.join(', ')})';
  }
}
