import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unica istanza condivisa: la home la ascolta per mostrare o nascondere il
/// bottone log in AppBar, le impostazioni la modificano.
final homeUiSettings = HomeUiSettings();

/// Preferenze di aspetto della home salvate su questa macchina.
///
/// Il visualizzatore log si apre sempre dalla card e dal drawer; qui si sceglie
/// solo se tenere anche la scorciatoia in alto nella barra.
class HomeUiSettings extends ChangeNotifier {
  static const _logButtonInAppBarKey = 'home_log_button_in_app_bar';

  bool _logButtonInAppBar = false;
  bool _initialized = false;

  bool get logButtonInAppBar => _logButtonInAppBar;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _logButtonInAppBar = prefs.getBool(_logButtonInAppBarKey) ?? false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLogButtonInAppBar(bool value) async {
    if (_logButtonInAppBar == value) return;
    _logButtonInAppBar = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logButtonInAppBarKey, value);
  }
}
