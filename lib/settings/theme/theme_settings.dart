import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/theme.dart';
import '../../log_viewer/app_logger.dart';

/// Manager per le impostazioni del tema
/// Gestisce la modalità tema (light/dark/system) e i colori personalizzati
class ThemeSettings extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _primaryColorKey = 'primary_color';
  static const String _useDockingOnMobileKey = 'use_docking_on_mobile';
  static const String _showHomeReportKey = 'show_home_report';
  static const String _backgroundFollowsThemeKey = 'background_follows_theme';

  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = AppTheme.primaryColor;
  bool _useDockingOnMobile = false; // Default: disabilitato su smartphone
  bool _showHomeReport = true; // Default: mostra il report nella home
  bool _backgroundFollowsTheme = true;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  bool get useDockingOnMobile => _useDockingOnMobile;
  bool get showHomeReport => _showHomeReport;
  bool get backgroundFollowsTheme => _backgroundFollowsTheme;

  /// Inizializza il theme manager caricando le preferenze salvate
  Future<void> init() async {
    await _loadPreferences();
  }

  /// Carica le preferenze dal storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Carica theme mode
      final themeModeIndex = prefs.getInt(_themeModeKey);
      if (themeModeIndex != null) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }

      // Carica colore primario
      final primaryColorValue = prefs.getInt(_primaryColorKey);
      if (primaryColorValue != null) {
        _primaryColor = Color(primaryColorValue);
      }

      // Carica impostazione docking su mobile
      _useDockingOnMobile = prefs.getBool(_useDockingOnMobileKey) ?? false;

      // Carica impostazione visualizzazione report nella home
      _showHomeReport = prefs.getBool(_showHomeReportKey) ?? true;

      // Carica impostazione sfondo: false mantiene il colore primario scelto.
      // Il default e true, quindi chi non ha mai toccato l'impostazione segue
      // il tema chiaro/scuro. Un false gia salvato viene rispettato.
      _backgroundFollowsTheme =
          prefs.getBool(_backgroundFollowsThemeKey) ?? true;

      notifyListeners();
    } catch (e) {
      log.d('Error loading theme preferences: $e');
    }
  }

  /// Salva le preferenze nel storage
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, _themeMode.index);
      await prefs.setInt(_primaryColorKey, _primaryColor.toARGB32());
      await prefs.setBool(_useDockingOnMobileKey, _useDockingOnMobile);
      await prefs.setBool(_showHomeReportKey, _showHomeReport);
      await prefs.setBool(_backgroundFollowsThemeKey, _backgroundFollowsTheme);
    } catch (e) {
      log.d('Error saving theme preferences: $e');
    }
  }

  /// Cambia la modalità del tema
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Toggle rapido tra light e dark
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// Imposta il colore primario personalizzato
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor != color) {
      _primaryColor = color;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Ripristina il colore predefinito
  Future<void> resetColor() async {
    _primaryColor = AppTheme.primaryColor;
    await _savePreferences();
    notifyListeners();
  }

  /// Imposta la visualizzazione del report nella home
  Future<void> setShowHomeReport(bool show) async {
    if (_showHomeReport != show) {
      _showHomeReport = show;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Imposta se gli sfondi decorativi seguono il tema chiaro/scuro.
  Future<void> setBackgroundFollowsTheme(bool followsTheme) async {
    if (_backgroundFollowsTheme != followsTheme) {
      _backgroundFollowsTheme = followsTheme;
      await _savePreferences();
      notifyListeners();
    }
  }

  /// Restituisce l'elenco delle estensioni del tema base con
  /// [AppColorExtension] aggiornata sul colore primario scelto.
  ///
  /// Preserva le altre estensioni registrate in [AppTheme] (shape, spacing,
  /// ecc.) invece di sostituirle: `ThemeData.copyWith(extensions: ...)`
  /// sovrascrive l'intera lista.
  List<ThemeExtension<dynamic>> _withPrimaryColor(ThemeData base) {
    final baseExtension = base.extension<AppColorExtension>();
    if (baseExtension == null) return base.extensions.values.toList();
    final isDark = base.brightness == Brightness.dark;

    final updated = baseExtension.copyWith(
      gradientStart: _backgroundFollowsTheme
          ? baseExtension.gradientStart
          : _primaryColor.withValues(alpha: isDark ? 0.34 : 0.18),
      gradientEnd: _backgroundFollowsTheme
          ? baseExtension.gradientEnd
          : base.colorScheme.surface,
      cardIconColor: _primaryColor,
      fabGradientStart: _primaryColor,
      fabGradientEnd: _primaryColor.withValues(alpha: 0.9),
      headerGradientStart: _primaryColor,
      headerGradientEnd: _primaryColor.withValues(alpha: 0.9),
      selectedCardBackground: _primaryColor.withValues(
        alpha: isDark ? 0.30 : 0.14,
      ),
      variantSelectedBackground: _primaryColor.withValues(
        alpha: isDark ? 0.24 : 0.10,
      ),
      chipSelectedBackground: _primaryColor.withValues(
        alpha: isDark ? 0.28 : 0.12,
      ),
    );

    return [
      for (final ext in base.extensions.values)
        if (ext is AppColorExtension) updated else ext,
    ];
  }

  /// Ottiene il tema light con il colore personalizzato
  ThemeData get customLightTheme {
    final base = AppTheme.lightTheme;

    return base.copyWith(
      primaryColor: _primaryColor,
      colorScheme: AppTheme.colorSchemeFor(_primaryColor, base.brightness),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: _primaryColor),
      // Aggiorna InputDecorationTheme con il nuovo colore primario
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primaryColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      // Aggiorna TextSelectionTheme con il nuovo colore primario
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _primaryColor,
        selectionColor: _primaryColor.withValues(alpha: 0.3),
        selectionHandleColor: _primaryColor,
      ),
      // Aggiorna le estensioni mantenendo shape/spacing intatti
      extensions: _withPrimaryColor(base),
    );
  }

  /// Ottiene il tema dark con il colore personalizzato
  ThemeData get customDarkTheme {
    final base = AppTheme.darkTheme;

    return base.copyWith(
      primaryColor: _primaryColor,
      colorScheme: AppTheme.colorSchemeFor(_primaryColor, base.brightness),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _primaryColor.withValues(alpha: 0.9),
      ),
      // Aggiorna InputDecorationTheme con il nuovo colore primario
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primaryColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      // Aggiorna TextSelectionTheme con il nuovo colore primario
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _primaryColor,
        selectionColor: _primaryColor.withValues(alpha: 0.3),
        selectionHandleColor: _primaryColor,
      ),
      // Aggiorna le estensioni mantenendo shape/spacing intatti
      extensions: _withPrimaryColor(base),
    );
  }
}
