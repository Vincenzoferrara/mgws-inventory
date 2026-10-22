import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';

/// Impostazioni del modulo Cassa: nome/numero cassa fisica, sede e
/// identificativo univoco del POS.
/// Restano opzionali: se vuote, lo storico POS usa i fallback neutri e la
/// giornata operativa non inventa ubicazioni.
///
/// Cash register settings: register name, location and the unique POS
/// identifier required by the Italian POS/registratore telematico pairing.
final cassaSettings = CassaSettings();

class CassaSettings extends ChangeNotifier {
  static const _nomeCassaKey = 'cassa_nome_cassa';
  static const _sedeKey = 'cassa_sede';
  static const _turnoObbligatorioKey = 'cassa_turno_obbligatorio';
  static const _posIdentifierKey = 'cassa_pos_identifier';

  /// Alfabeto senza caratteri ambigui (0/O, 1/I/L): l'identificativo viene
  /// digitato a mano nel portale "Fatture e Corrispettivi".
  /// Ambiguity-free alphabet: the identifier is typed by hand in the portal.
  static const _identifierAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const _identifierLength = 6;
  static const _identifierPrefix = 'POS';
  static const _identifierMaxLength = 32;

  /// Pattern ammesso per l'identificativo: lettere, cifre e trattino.
  /// Allowed pattern for the identifier: letters, digits and hyphen.
  static final _identifierPattern = RegExp(r'^[A-Z0-9-]+$');

  String _nomeCassa = '';
  String _sede = '';
  bool _turnoObbligatorio = false;
  String _posIdentifier = '';
  bool _initialized = false;

  String get nomeCassa => _nomeCassa;
  String get sede => _sede;
  bool get turnoObbligatorio => _turnoObbligatorio;
  bool get hasCassa => _nomeCassa.trim().isNotEmpty;
  bool get hasSede => _sede.trim().isNotEmpty;

  /// Identificativo univoco del POS, usato per l'abbinamento con il
  /// registratore telematico nel portale "Fatture e Corrispettivi".
  /// Unique POS identifier used for the register pairing in the AdE portal.
  String get posIdentifier => _posIdentifier;

  bool get hasPosIdentifier => _posIdentifier.isNotEmpty;

  /// Indica se l'identificativo e' stato generato dall'app o impostato
  /// manualmente dall'esercente.
  /// Whether the identifier was generated or set by the merchant.
  bool get posIdentifierIsGenerated =>
      _posIdentifier.startsWith('$_identifierPrefix-');

  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    final prefs = await SharedPreferences.getInstance();
    _nomeCassa = (prefs.getString(_nomeCassaKey) ?? '').trim();
    _sede = (prefs.getString(_sedeKey) ?? '').trim();
    _turnoObbligatorio = prefs.getBool(_turnoObbligatorioKey) ?? false;
    _posIdentifier = (prefs.getString(_posIdentifierKey) ?? '').trim();
    // Genera l'identificativo al primo avvio, così l'esercente non deve
    // inventarlo e l'app ha subito un valore da abbinare nel portale.
    // Generates the identifier on first run so the merchant has a value to
    // pair in the portal without inventing one.
    if (_posIdentifier.isEmpty) {
      _posIdentifier = generatePosIdentifier();
      await prefs.setString(_posIdentifierKey, _posIdentifier);
    }
    _initialized = true;
    await syncTurnoObbligatorioFromServer();
    notifyListeners();
  }

  /// Genera un identificativo casuale nel formato `POS-XXXXXX`.
  /// Generates a random identifier shaped as `POS-XXXXXX`.
  String generatePosIdentifier() {
    final random = Random.secure();
    final buffer = StringBuffer(_identifierPrefix);
    for (var i = 0; i < _identifierLength; i++) {
      buffer.write(
        _identifierAlphabet[random.nextInt(_identifierAlphabet.length)],
      );
    }
    return buffer.toString();
  }

  /// Valida e salva un identificativo impostato dall'esercente.
  /// Validates and stores an identifier set by the merchant.
  /// Restituisce `null` se il valore e' valido, altrimenti il motivo.
  /// Returns `null` when valid, otherwise the failure reason.
  String? validatePosIdentifier(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return 'empty';
    if (normalized.length > _identifierMaxLength) return 'tooLong';
    if (!_identifierPattern.hasMatch(normalized)) return 'invalid';
    return null;
  }

  Future<void> setPosIdentifier(String value) async {
    final error = validatePosIdentifier(value);
    if (error != null) {
      throw ArgumentError('Identificativo POS non valido: $error');
    }
    _posIdentifier = value.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_posIdentifierKey, _posIdentifier);
    notifyListeners();
  }

  /// Sostituisce l'identificativo con uno nuovo casuale.
  /// Replaces the identifier with a new random one.
  Future<void> regeneratePosIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    _posIdentifier = generatePosIdentifier();
    await prefs.setString(_posIdentifierKey, _posIdentifier);
    notifyListeners();
  }

  Future<void> setValori({String? nomeCassa, String? sede}) async {
    _nomeCassa = (nomeCassa ?? _nomeCassa).trim();
    _sede = (sede ?? _sede).trim();
    final prefs = await SharedPreferences.getInstance();
    if (_nomeCassa.isEmpty) {
      await prefs.remove(_nomeCassaKey);
    } else {
      await prefs.setString(_nomeCassaKey, _nomeCassa);
    }
    if (_sede.isEmpty) {
      await prefs.remove(_sedeKey);
    } else {
      await prefs.setString(_sedeKey, _sede);
    }
    notifyListeners();
  }

  Future<void> setTurnoObbligatorio(
    bool value, {
    bool syncServer = true,
  }) async {
    final previousValue = _turnoObbligatorio;
    var effectiveValue = value;
    final prefs = await SharedPreferences.getInstance();

    if (syncServer && (await PlatformManager.refreshCanUseMgws())) {
      try {
        final response = await PlatformManager.pos.updateSettings(
          turnoObbligatorio: value,
        );
        if (response['success'] == false || response['ok'] == false) {
          throw Exception(
            response['message']?.toString() ??
                'Impostazione turno cassa non salvata sul server',
          );
        }
        final remoteValue = response['turno_obbligatorio'];
        if (remoteValue is bool) {
          effectiveValue = remoteValue;
        }
      } catch (error) {
        _turnoObbligatorio = previousValue;
        await prefs.setBool(_turnoObbligatorioKey, previousValue);
        notifyListeners();
        log.d('Sync turno cassa obbligatorio fallita: $error');
        rethrow;
      }
    }

    _turnoObbligatorio = effectiveValue;
    await prefs.setBool(_turnoObbligatorioKey, effectiveValue);
    notifyListeners();
  }

  Future<void> syncTurnoObbligatorioFromServer() async {
    if (!(await PlatformManager.refreshCanUseMgws())) return;
    try {
      final response = await PlatformManager.pos.getSettings();
      final remoteValue = response['turno_obbligatorio'];
      if (remoteValue is! bool) return;
      _turnoObbligatorio = remoteValue;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_turnoObbligatorioKey, remoteValue);
    } catch (error) {
      log.d('Lettura impostazioni POS MGWS saltata: $error');
    }
  }
}
