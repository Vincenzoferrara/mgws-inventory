import '../../cassa/class_scontrino.dart';

/// Contratto che ogni integrazione con un registratore telematico deve
/// rispettare.
///
/// L'app non conosce il protocollo del produttore: conosce solo questo
/// contratto. Ogni produttore espone infatti API o protocolli propri, quindi
/// non esiste un driver universale.
///
/// La modalita' simulazione e' un'implementazione come le altre, non un
/// ripiego: e' il modo dichiarato di lavorare quando in cassa non c'e' un
/// registratore.
///
/// Contract every telematic register integration must respect.
abstract class FiscalRegisterDriver {
  /// Identificatore tecnico del driver, usato per persistire la scelta.
  /// Technical driver id, persisted as the merchant selection.
  String get id;

  /// Nome leggibile mostrato nelle impostazioni.
  /// Readable name shown in the settings.
  String get displayName;

  /// `true` solo se il driver parla con un dispositivo fiscale reale.
  /// `true` only when the driver talks to a real fiscal device.
  bool get isFiscalDevice;

  /// Verifica se il dispositivo e' raggiungibile in questo momento.
  /// Checks whether the device is reachable right now.
  Future<bool> isAvailable();

  /// Emette il documento di vendita sul dispositivo fiscale.
  /// Issues the sale document on the fiscal device.
  ///
  /// In simulazione nessun numero viene emesso: la sequenza resta app
  /// responsibility e il chiamante decide. Questo mantiene il checkout
  /// identico a com'e' quando la cassa non c'e'.
  Future<FiscalIssueResult> issueReceipt(Scontrino scontrino);

  /// Stampa un documento di chiusura o riepilogo.
  /// Prints a closing or summary document.
  Future<FiscalPrintResult> printDocument(FiscalPrintRequest request);

  /// Chiude la giornata sul dispositivo fiscale.
  /// Closes the business day on the fiscal device.
  Future<void> closeDay();
}

/// Esito dell'emissione di uno scontrino.
///
/// `deviceReceiptNumber` e' `null` quando nessun dispositivo ha emesso il
/// numero: e' il caso normale della modalita' simulazione, e in quel caso
/// l'app non deve sovrascrivere il progressivo gia' assegnato.
///
/// Receipt issuance result.
class FiscalIssueResult {
  /// Numero assegnato dal dispositivo fiscale, `null` in simulazione.
  /// Number assigned by the fiscal device, `null` in simulation mode.
  final String? deviceReceiptNumber;

  /// `true` se il dispositivo ha stampato il documento.
  /// `true` when the device printed the document.
  final bool printed;

  const FiscalIssueResult({this.deviceReceiptNumber, this.printed = false});
}

/// Richiesta di stampa di un documento.
///
/// Document print request.
class FiscalPrintRequest {
  /// Tipo documento in chiaro, mostrato all'operatore.
  /// Plain document type, shown to the operator.
  final String documentType;

  /// Righe gia' calcolate dal modulo cassa.
  /// Lines already computed by the POS module.
  final List<String> lines;

  const FiscalPrintRequest({required this.documentType, required this.lines});
}

/// Esito della stampa di un documento.
///
/// Document print result.
class FiscalPrintResult {
  final bool printed;

  /// Messaggio d'errore mostrato all'operatore, `null` se tutto bene.
  /// Error shown to the operator, `null` on success.
  final String? error;

  const FiscalPrintResult({required this.printed, this.error});
}