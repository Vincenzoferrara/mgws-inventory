import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../log_viewer/app_logger.dart';
import '../class_scontrino.dart';
import 'drivers/simulation_driver.dart';
import 'fiscal_register_driver.dart';

/// Scelta e stato del registratore telematico usato dalla cassa.
///
/// Finche' non c'e' un dispositivo la cassa lavora in modalita' simulazione,
/// che e' un modo dichiarato e non un errore.
///
/// Cash register fiscal device selection and state.
final fiscalRegisterRepository = FiscalRegisterRepository();

class FiscalRegisterRepository extends ChangeNotifier {
  static const _driverKey = 'cassa_fiscal_driver';

  /// Registratori noti. Ogni produttore richiede un adapter proprio: qui
  /// c'e' solo la simulazione, gli adapter vendor si aggiungono quando si
  /// sceglie la macchina.
  /// Known registers: every vendor needs its own adapter, so only simulation
  /// exists today.
  final List<FiscalRegisterDriver> _drivers = [SimulationDriver()];

  String _activeDriverId = 'simulation';
  bool _initialized = false;

  String get activeDriverId => _activeDriverId;

  /// `true` se la cassa sta emettendo tramite un dispositivo fiscale reale.
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
    // invece di lasciare la cassa senza un driver valido.
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

  /// Verifica se il dispositivo del driver attivo e' raggiungibile.
  /// Checks whether the active driver's device is reachable.
  Future<bool> isDeviceAvailable() => activeDriver.isAvailable();

  /// Emette lo scontrino tramite il driver attivo.
  ///
  /// In simulazione non viene emesso nulla e `deviceReceiptNumber` resta
  /// `null`: il chiamante conserva quindi la sequenza che gia' usa oggi.
  /// Issues the receipt through the active driver. In simulation nothing is
  /// issued and the number stays `null`, so the caller keeps today's sequence.
  Future<FiscalIssueResult> issueReceipt(Scontrino scontrino) async {
    await init();
    try {
      return await activeDriver.issueReceipt(scontrino);
    } catch (error) {
      AppLogger().w('Emissione scontrino fallita: $error');
      // Un driver che fallisce non deve bloccare la cassa: si registra la
      // vendita e si segnala, senza perdere il documento.
      // A failing driver must not block the till: the sale is recorded and
      // flagged, never lost.
      return const FiscalIssueResult(
        deviceReceiptNumber: null,
        printed: false,
      );
    }
  }
}