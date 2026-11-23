import 'package:material_ui/material_ui.dart';
import 'dart:io';

/// Utility per rilevare il tipo di dispositivo
class DeviceUtils {
  /// Rileva se il dispositivo è uno smartphone basandosi sulla larghezza dello schermo
  static bool isSmartphone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final shortestSide = width < height ? width : height;

    // Considera smartphone se la dimensione più corta è < 600dp
    return shortestSide < 600;
  }

  /// Rileva se il dispositivo è un tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final shortestSide = width < height ? width : height;

    // Considera tablet se la dimensione più corta è tra 600dp e 900dp
    return shortestSide >= 600 && shortestSide < 900;
  }

  /// Rileva se il dispositivo è desktop
  static bool isDesktop(BuildContext context) {
    // Su piattaforme desktop native
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final shortestSide = width < height ? width : height;

    // Considera desktop se la dimensione più corta è >= 900dp
    return shortestSide >= 900;
  }

  /// Rileva se è una piattaforma mobile (Android/iOS)
  static bool isMobilePlatform() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Rileva se è una piattaforma desktop (Windows/Linux/macOS)
  static bool isDesktopPlatform() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }
}
