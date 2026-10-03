import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../log_viewer/app_logger.dart';
import '../class_scontrino.dart';
import 'drivers/simulation_driver.dart';
import 'fiscal_register_driver.dart';

/// Owns the fiscal register selection for the till.
///
/// While no device is attached the till runs in simulation mode, which is a
/// declared working mode rather than an error state.
final fiscalRegisterRepository = FiscalRegisterRepository();

class FiscalRegisterRepository extends ChangeNotifier {
  static const _driverKey = 'cassa_fiscal_driver';

  /// Known registers. Every vendor needs its own adapter, so simulation is
  /// the only entry until a device is chosen.
  final List<FiscalRegisterDriver> _drivers = [SimulationDriver()];

  String _activeDriverId = 'simulation';
  bool _initialized = false;

  String get activeDriverId => _activeDriverId;

  /// `true` when the till issues through a real fiscal device.
  bool get isFiscalDevice => activeDriver.isFiscalDevice;

  List<FiscalRegisterDriver> get availableDrivers =>
      List.unmodifiable(_drivers);

  FiscalRegisterDriver get activeDriver {
    return _drivers.firstWhere(
      (driver) => driver.id == _activeDriverId,
      orElse: () => _drivers.first,
    );
  }

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    final prefs = await SharedPreferences.getInstance();
    _activeDriverId = prefs.getString(_driverKey) ?? 'simulation';
    // Se il driver salvato non e' piu' disponibile si torna in simulazione
    // An unknown saved driver falls back to simulation rather than leaving
    // the till without a valid driver.
    if (!_drivers.any((driver) => driver.id == _activeDriverId)) {
      _activeDriverId = 'simulation';
      await prefs.setString(_driverKey, _activeDriverId);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setActiveDriver(String driverId) async {
    if (!_drivers.any((driver) => driver.id == driverId)) {
      throw ArgumentError('Driver registratore sconosciuto: $driverId');
    }
    _activeDriverId = driverId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverKey, driverId);
    AppLogger().i('Driver registratore attivo: $driverId');
    notifyListeners();
  }

  /// Checks whether the active driver's device is reachable.
  Future<bool> isDeviceAvailable() => activeDriver.isAvailable();

  ///
  /// In simulazione non viene emesso nulla e `deviceReceiptNumber` resta
  /// Issues the receipt through the active driver. In simulation nothing is
  /// issued and the number stays `null`, so the caller keeps today's sequence.
  Future<FiscalIssueResult> issueReceipt(Scontrino receipt) async {
    await init();
    try {
      return await activeDriver.issueReceipt(receipt);
    } catch (error) {
      AppLogger().w('Emissione scontrino fallita: $error');
      // A failing driver must not block the till: the sale is recorded and
      // flagged, never lost.
      return const FiscalIssueResult(
        deviceReceiptNumber: null,
        printed: false,
      );
    }
  }
}
