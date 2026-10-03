import '../../cassa/class_scontrino.dart';

/// Contract every fiscal register integration must respect.
abstract class FiscalRegisterDriver {
  /// Technical driver id, persisted as the merchant selection.
  String get id;

  /// Readable name shown in the settings.
  String get displayName;

  /// `true` only when the driver talks to a real fiscal device.
  bool get isFiscalDevice;

  /// Checks whether the device is reachable right now.
  Future<bool> isAvailable();

  /// Issues the sale document on the fiscal device.
  ///
  Future<FiscalIssueResult> issueReceipt(Scontrino scontrino);

  /// Prints a closing or summary document.
  Future<FiscalPrintResult> printDocument(FiscalPrintRequest request);

  /// Closes the business day on the fiscal device.
  Future<void> closeDay();
}

/// Receipt issuance result.
///
/// A null `deviceReceiptNumber` is the normal simulation outcome: no device
/// issued a number, so the app keeps its own sequence.
class FiscalIssueResult {
  /// Number assigned by the fiscal device, `null` in simulation mode.
  final String? deviceReceiptNumber;

  /// `true` when the device printed the document.
  final bool printed;

  const FiscalIssueResult({this.deviceReceiptNumber, this.printed = false});
}

/// Document print request.
class FiscalPrintRequest {
  /// Plain document type, shown to the operator.
  final String documentType;

/// Lines already computed by the POS module.
  final List<String> lines;

  const FiscalPrintRequest({required this.documentType, required this.lines});
}

///
/// Document print result.
class FiscalPrintResult {
  final bool printed;

/// Error shown to the operator, `null` on success.
  final String? error;

  const FiscalPrintResult({required this.printed, this.error});
}
