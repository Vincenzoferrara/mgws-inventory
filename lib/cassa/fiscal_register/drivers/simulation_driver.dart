import '../../class_scontrino.dart';
import '../fiscal_register_driver.dart';

/// Simulation mode: no fiscal register attached.
///
/// This is not a fallback but a declared way of working, like in Odoo. No
/// device issues the document, so no receipt number is returned and the app
/// keeps its own sequence.
class SimulationDriver implements FiscalRegisterDriver {
  @override
  String get id => 'simulation';

  @override
  String get displayName => 'Simulation mode';

  @override
  bool get isFiscalDevice => false;

  @override
  Future<bool> isAvailable() async => true;

  /// Issues nothing: no device, no number.
  @override
  Future<FiscalIssueResult> issueReceipt(Scontrino receipt) async {
    return const FiscalIssueResult(deviceReceiptNumber: null, printed: false);
  }

  @override
  Future<FiscalPrintResult> printDocument(FiscalPrintRequest request) async {
    return const FiscalPrintResult(printed: false);
  }

  @override
  Future<void> closeDay() async {}
}
