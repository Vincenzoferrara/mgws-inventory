import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color primaryColorDark = Color(0xFF1565C0);
  static const Color accentColor = Color(0xFF29B6F6);
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFB00020);

  static const Color lightGradientStart = Color(0xFFE3F2FD);
  static const Color lightGradientEnd = Color(0xFFFFFFFF);
  static const Color darkGradientStart = Color(0xFF121212);
  static const Color darkGradientEnd = Color(0xFF0A1929);

  // Status colors (semantic)
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColorSemantic = Color(0xFFF44336);

  /// Schema colori Material 3 generato dal colore del brand.
  ///
  /// La variante predefinita di `ColorScheme.fromSeed` (tonalSpot) desatura il
  /// seme: con #1E88E5 il `primary` diventava un blu-grigio (#39608F) e
  /// `secondary`/`surfaceTint` tendevano al grigio, per cui header e app bar
  /// che leggono lo schema non mostravano il colore scelto. `fidelity` resta
  /// fedele alla tinta del seme e `primary` viene fissato sul seme stesso.
  /// Usato anche da `ThemeSettings` quando l'utente sceglie un altro colore.
  static ColorScheme colorSchemeFor(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: seed,
    );
  }

  // ✅ TEMA LIGHT CORRETTO
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,

      colorScheme: colorSchemeFor(primaryColor, Brightness.light),

      // ✅ IMPORTANTE: Registra SEMPRE l'estensione
      extensions: <ThemeExtension<dynamic>>[
        const AppColorExtension(
          gradientStart: lightGradientStart,
          gradientEnd: lightGradientEnd,
          cardIconColor: primaryColor,
          subtitleColor: Color(0xFF757575),
          fabGradientStart: primaryColor,
          fabGradientEnd: Color(0xFF1976D2),
          headerGradientStart: primaryColor,
          headerGradientEnd: Color(0xFF1976D2),
          selectedCardBackground: Color(0xFFE1F5FE),
          variantSelectedBackground: Color(0xFFE3F2FD),
          priceBackground: Color(0xFFE8F5E8),
          stockAvailable: Color(0xFF4CAF50),
          stockUnavailable: Color(0xFFF44336),
          successColor: successColor,
          warningColor: warningColor,
          errorColorStatus: errorColorSemantic,
          infoColor: Color(0xFF2196F3),
          neutralColor: Color(0xFF9E9E9E),
          surfaceVariantColor: Color(0xFFF5F5F5),
          onSurfaceVariantColor: Color(0xFF616161),
          dividerColor: Color(0xFFE0E0E0),
          shadowColor: Color(0x1F000000),
          chipBackground: Color(0xFFF5F5F5),
          chipSelectedBackground: Color(0xFFE3F2FD),
          badgeBackground: primaryColor,
          overlayColor: Color(0x66000000),
          tierGold: Color(0xFFFFD700),
          tierSilver: Color(0xFFC0C0C0),
          tierBronze: Color(0xFFCD7F32),
          tierPlatinum: Color(0xFFE5E4E2),
          onColoredSurface: Colors.white,
          pdfExport: Color(0xFFF44336),
          spreadsheetExport: Color(0xFF4CAF50),
          cameraBackground: Colors.black,
          cameraScrim: Color(0x99000000),
          cameraPanel: Color(0xFF212121),
        ),
        const AppShapeExtension(),
        const AppSpacingExtension(),
        AppAccentExtension.light,
        AppChartExtension.light,
      ],

      primarySwatch: Colors.blue,
      primaryColor: primaryColor,

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceColor,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: primaryColor,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      iconTheme: const IconThemeData(color: primaryColor, size: 24),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          inherit: true,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineMedium: TextStyle(
          inherit: true,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineSmall: TextStyle(
          inherit: true,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          inherit: true,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleMedium: TextStyle(
          inherit: true,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        titleSmall: TextStyle(
          inherit: true,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          inherit: true,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        bodySmall: TextStyle(
          inherit: true,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.black54,
        ),
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  // ✅ TEMA DARK CORRETTO
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,

      colorScheme: colorSchemeFor(primaryColor, Brightness.dark),

      // ✅ IMPORTANTE: Registra SEMPRE l'estensione
      extensions: <ThemeExtension<dynamic>>[
        const AppColorExtension(
          gradientStart: darkGradientStart,
          gradientEnd: darkGradientEnd,
          cardIconColor: primaryColor,
          subtitleColor: Color(0xFFBDBDBD),
          fabGradientStart: primaryColor,
          fabGradientEnd: Color(0xFF1976D2),
          headerGradientStart: primaryColor,
          headerGradientEnd: Color(0xFF1976D2),
          selectedCardBackground: Color(0xFF0A1929),
          variantSelectedBackground: Color(0xFF1B2533),
          priceBackground: Color(0xFF1B2A1B),
          stockAvailable: Color(0xFF4CAF50),
          stockUnavailable: Color(0xFFF44336),
          successColor: successColor,
          warningColor: warningColor,
          errorColorStatus: errorColorSemantic,
          infoColor: Color(0xFF64B5F6),
          neutralColor: Color(0xFF9E9E9E),
          surfaceVariantColor: Color(0xFF2C2C2C),
          onSurfaceVariantColor: Color(0xFFBDBDBD),
          dividerColor: Color(0xFF3D3D3D),
          shadowColor: Color(0x33000000),
          chipBackground: Color(0xFF3D3D3D),
          chipSelectedBackground: Color(0xFF243447),
          badgeBackground: primaryColor,
          overlayColor: Color(0x80000000),
          tierGold: Color(0xFFFFD700),
          tierSilver: Color(0xFFC0C0C0),
          tierBronze: Color(0xFFCD7F32),
          tierPlatinum: Color(0xFFE5E4E2),
          onColoredSurface: Colors.white,
          pdfExport: Color(0xFFF44336),
          spreadsheetExport: Color(0xFF4CAF50),
          cameraBackground: Colors.black,
          cameraScrim: Color(0x99000000),
          cameraPanel: Color(0xFF212121),
        ),
        const AppShapeExtension(),
        const AppSpacingExtension(),
        AppAccentExtension.dark,
        AppChartExtension.dark,
      ],

      primarySwatch: Colors.blue,
      primaryColor: primaryColor,

      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColorDark,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.grey.shade900,
        elevation: 8,
      ),

      cardTheme: CardThemeData(
        elevation: 4,
        color: Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: primaryColor,
        textColor: Colors.white,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade600, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          inherit: true,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          inherit: true,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineSmall: TextStyle(
          inherit: true,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          inherit: true,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          inherit: true,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleSmall: TextStyle(
          inherit: true,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          inherit: true,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          inherit: true,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        bodySmall: TextStyle(
          inherit: true,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

// ✅ ESTENSIONE CORRETTA - Rimossa la gestione degli stati light/dark
@immutable
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  const AppColorExtension({
    required this.gradientStart,
    required this.gradientEnd,
    required this.cardIconColor,
    required this.subtitleColor,
    required this.fabGradientStart,
    required this.fabGradientEnd,
    required this.headerGradientStart,
    required this.headerGradientEnd,
    required this.selectedCardBackground,
    required this.variantSelectedBackground,
    required this.priceBackground,
    required this.stockAvailable,
    required this.stockUnavailable,
    required this.successColor,
    required this.warningColor,
    required this.errorColorStatus,
    required this.infoColor,
    required this.neutralColor,
    required this.surfaceVariantColor,
    required this.onSurfaceVariantColor,
    required this.dividerColor,
    required this.shadowColor,
    required this.chipBackground,
    required this.chipSelectedBackground,
    required this.badgeBackground,
    required this.overlayColor,
    required this.tierGold,
    required this.tierSilver,
    required this.tierBronze,
    required this.tierPlatinum,
    required this.onColoredSurface,
    required this.pdfExport,
    required this.spreadsheetExport,
    required this.cameraBackground,
    required this.cameraScrim,
    required this.cameraPanel,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color cardIconColor;
  final Color subtitleColor;
  final Color fabGradientStart;
  final Color fabGradientEnd;
  final Color headerGradientStart;
  final Color headerGradientEnd;
  final Color selectedCardBackground;
  final Color variantSelectedBackground;
  final Color priceBackground;
  final Color stockAvailable;
  final Color stockUnavailable;
  final Color successColor;
  final Color warningColor;
  final Color errorColorStatus;
  final Color infoColor;
  final Color neutralColor;
  final Color surfaceVariantColor;
  final Color onSurfaceVariantColor;
  final Color dividerColor;
  final Color shadowColor;
  final Color chipBackground;
  final Color chipSelectedBackground;
  final Color badgeBackground;
  final Color overlayColor;
  final Color tierGold;
  final Color tierSilver;
  final Color tierBronze;
  final Color tierPlatinum;

  /// Testo e icone sopra fondi saturi: header a gradiente, banner di stato,
  /// badge. Resta chiaro anche in dark mode perche' il fondo resta saturo.
  final Color onColoredSurface;

  /// Colori identificativi dei formati di esportazione.
  final Color pdfExport;
  final Color spreadsheetExport;

  /// Superfici della vista fotocamera, scure in entrambi i temi.
  final Color cameraBackground;
  final Color cameraScrim;
  final Color cameraPanel;

  @override
  AppColorExtension copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    Color? cardIconColor,
    Color? subtitleColor,
    Color? fabGradientStart,
    Color? fabGradientEnd,
    Color? headerGradientStart,
    Color? headerGradientEnd,
    Color? selectedCardBackground,
    Color? variantSelectedBackground,
    Color? priceBackground,
    Color? stockAvailable,
    Color? stockUnavailable,
    Color? successColor,
    Color? warningColor,
    Color? errorColorStatus,
    Color? infoColor,
    Color? neutralColor,
    Color? surfaceVariantColor,
    Color? onSurfaceVariantColor,
    Color? dividerColor,
    Color? shadowColor,
    Color? chipBackground,
    Color? chipSelectedBackground,
    Color? badgeBackground,
    Color? overlayColor,
    Color? tierGold,
    Color? tierSilver,
    Color? tierBronze,
    Color? tierPlatinum,
    Color? onColoredSurface,
    Color? pdfExport,
    Color? spreadsheetExport,
    Color? cameraBackground,
    Color? cameraScrim,
    Color? cameraPanel,
  }) {
    return AppColorExtension(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      cardIconColor: cardIconColor ?? this.cardIconColor,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      fabGradientStart: fabGradientStart ?? this.fabGradientStart,
      fabGradientEnd: fabGradientEnd ?? this.fabGradientEnd,
      headerGradientStart: headerGradientStart ?? this.headerGradientStart,
      headerGradientEnd: headerGradientEnd ?? this.headerGradientEnd,
      selectedCardBackground:
          selectedCardBackground ?? this.selectedCardBackground,
      variantSelectedBackground:
          variantSelectedBackground ?? this.variantSelectedBackground,
      priceBackground: priceBackground ?? this.priceBackground,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      stockUnavailable: stockUnavailable ?? this.stockUnavailable,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      errorColorStatus: errorColorStatus ?? this.errorColorStatus,
      infoColor: infoColor ?? this.infoColor,
      neutralColor: neutralColor ?? this.neutralColor,
      surfaceVariantColor: surfaceVariantColor ?? this.surfaceVariantColor,
      onSurfaceVariantColor:
          onSurfaceVariantColor ?? this.onSurfaceVariantColor,
      dividerColor: dividerColor ?? this.dividerColor,
      shadowColor: shadowColor ?? this.shadowColor,
      chipBackground: chipBackground ?? this.chipBackground,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      overlayColor: overlayColor ?? this.overlayColor,
      tierGold: tierGold ?? this.tierGold,
      tierSilver: tierSilver ?? this.tierSilver,
      tierBronze: tierBronze ?? this.tierBronze,
      tierPlatinum: tierPlatinum ?? this.tierPlatinum,
      onColoredSurface: onColoredSurface ?? this.onColoredSurface,
      pdfExport: pdfExport ?? this.pdfExport,
      spreadsheetExport: spreadsheetExport ?? this.spreadsheetExport,
      cameraBackground: cameraBackground ?? this.cameraBackground,
      cameraScrim: cameraScrim ?? this.cameraScrim,
      cameraPanel: cameraPanel ?? this.cameraPanel,
    );
  }

  @override
  AppColorExtension lerp(ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) {
      return this;
    }
    return AppColorExtension(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      cardIconColor: Color.lerp(cardIconColor, other.cardIconColor, t)!,
      subtitleColor: Color.lerp(subtitleColor, other.subtitleColor, t)!,
      fabGradientStart: Color.lerp(
        fabGradientStart,
        other.fabGradientStart,
        t,
      )!,
      fabGradientEnd: Color.lerp(fabGradientEnd, other.fabGradientEnd, t)!,
      headerGradientStart: Color.lerp(
        headerGradientStart,
        other.headerGradientStart,
        t,
      )!,
      headerGradientEnd: Color.lerp(
        headerGradientEnd,
        other.headerGradientEnd,
        t,
      )!,
      selectedCardBackground: Color.lerp(
        selectedCardBackground,
        other.selectedCardBackground,
        t,
      )!,
      variantSelectedBackground: Color.lerp(
        variantSelectedBackground,
        other.variantSelectedBackground,
        t,
      )!,
      priceBackground: Color.lerp(priceBackground, other.priceBackground, t)!,
      stockAvailable: Color.lerp(stockAvailable, other.stockAvailable, t)!,
      stockUnavailable: Color.lerp(
        stockUnavailable,
        other.stockUnavailable,
        t,
      )!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      errorColorStatus: Color.lerp(
        errorColorStatus,
        other.errorColorStatus,
        t,
      )!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      neutralColor: Color.lerp(neutralColor, other.neutralColor, t)!,
      surfaceVariantColor: Color.lerp(
        surfaceVariantColor,
        other.surfaceVariantColor,
        t,
      )!,
      onSurfaceVariantColor: Color.lerp(
        onSurfaceVariantColor,
        other.onSurfaceVariantColor,
        t,
      )!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipSelectedBackground: Color.lerp(
        chipSelectedBackground,
        other.chipSelectedBackground,
        t,
      )!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,
      tierGold: Color.lerp(tierGold, other.tierGold, t)!,
      tierSilver: Color.lerp(tierSilver, other.tierSilver, t)!,
      tierBronze: Color.lerp(tierBronze, other.tierBronze, t)!,
      tierPlatinum: Color.lerp(tierPlatinum, other.tierPlatinum, t)!,
      onColoredSurface: Color.lerp(
        onColoredSurface,
        other.onColoredSurface,
        t,
      )!,
      pdfExport: Color.lerp(pdfExport, other.pdfExport, t)!,
      spreadsheetExport: Color.lerp(
        spreadsheetExport,
        other.spreadsheetExport,
        t,
      )!,
      cameraBackground: Color.lerp(
        cameraBackground,
        other.cameraBackground,
        t,
      )!,
      cameraScrim: Color.lerp(cameraScrim, other.cameraScrim, t)!,
      cameraPanel: Color.lerp(cameraPanel, other.cameraPanel, t)!,
    );
  }
}

/// Palette categoriale per le icone delle sezioni della Home.
///
/// Non sono colori semantici (success/error/warning): ogni sezione ha un
/// accento proprio per rendere la griglia leggibile a colpo d'occhio. Stanno
/// qui dentro cosi' restano centralizzate e sostituibili in un punto solo
/// invece di essere sparse nel widget.
@immutable
class AppAccentExtension extends ThemeExtension<AppAccentExtension> {
  const AppAccentExtension({
    required this.cassa,
    required this.prodotti,
    required this.inventario,
    required this.nuovoProdotto,
    required this.coupon,
    required this.ordini,
    required this.clienti,
    required this.fornitori,
    required this.carteFedelta,
    required this.report,
    required this.dashboard,
    required this.impostazioni,
    required this.aggiornamenti,
    required this.caldav,
    required this.dipendenti,
    required this.rfid,
  });

  final Color cassa;
  final Color prodotti;
  final Color inventario;
  final Color nuovoProdotto;
  final Color coupon;
  final Color ordini;
  final Color clienti;
  final Color fornitori;
  final Color carteFedelta;
  final Color report;
  final Color dashboard;
  final Color impostazioni;
  final Color aggiornamenti;
  final Color caldav;
  final Color dipendenti;
  final Color rfid;

  static const AppAccentExtension light = AppAccentExtension(
    cassa: Color(0xFF2E7D32),
    prodotti: Color(0xFF3949AB),
    inventario: AppTheme.primaryColor,
    nuovoProdotto: Color(0xFF6A1B9A),
    coupon: Color(0xFFEF6C00),
    ordini: Color(0xFFC62828),
    clienti: Color(0xFF00838F),
    fornitori: Color(0xFF00695C),
    carteFedelta: Color(0xFF4527A0),
    report: Color(0xFF00796B),
    dashboard: Color(0xFFFF8F00),
    impostazioni: Color(0xFF546E7A),
    aggiornamenti: Color(0xFF0288D1),
    caldav: Color(0xFF6D4C41),
    dipendenti: Color(0xFFAD1457),
    rfid: Color(0xFF455A64),
  );

  /// In dark mode le tinte si schiariscono per mantenere il contrasto sui
  /// fondi scuri.
  static const AppAccentExtension dark = AppAccentExtension(
    cassa: Color(0xFF66BB6A),
    prodotti: Color(0xFF9FA8DA),
    inventario: AppTheme.primaryColor,
    nuovoProdotto: Color(0xFFCE93D8),
    coupon: Color(0xFFFFB74D),
    ordini: Color(0xFFEF9A9A),
    clienti: Color(0xFF4DD0E1),
    fornitori: Color(0xFF4DB6AC),
    carteFedelta: Color(0xFFB39DDB),
    report: Color(0xFF4DB6AC),
    dashboard: Color(0xFFFFCA28),
    impostazioni: Color(0xFF90A4AE),
    aggiornamenti: Color(0xFF4FC3F7),
    caldav: Color(0xFFA1887F),
    dipendenti: Color(0xFFF06292),
    rfid: Color(0xFF78909C),
  );

  @override
  AppAccentExtension copyWith({
    Color? cassa,
    Color? prodotti,
    Color? inventario,
    Color? nuovoProdotto,
    Color? coupon,
    Color? ordini,
    Color? clienti,
    Color? fornitori,
    Color? carteFedelta,
    Color? report,
    Color? dashboard,
    Color? impostazioni,
    Color? aggiornamenti,
    Color? caldav,
    Color? dipendenti,
    Color? rfid,
  }) {
    return AppAccentExtension(
      cassa: cassa ?? this.cassa,
      prodotti: prodotti ?? this.prodotti,
      inventario: inventario ?? this.inventario,
      nuovoProdotto: nuovoProdotto ?? this.nuovoProdotto,
      coupon: coupon ?? this.coupon,
      ordini: ordini ?? this.ordini,
      clienti: clienti ?? this.clienti,
      fornitori: fornitori ?? this.fornitori,
      carteFedelta: carteFedelta ?? this.carteFedelta,
      report: report ?? this.report,
      dashboard: dashboard ?? this.dashboard,
      impostazioni: impostazioni ?? this.impostazioni,
      aggiornamenti: aggiornamenti ?? this.aggiornamenti,
      caldav: caldav ?? this.caldav,
      dipendenti: dipendenti ?? this.dipendenti,
      rfid: rfid ?? this.rfid,
    );
  }

  @override
  AppAccentExtension lerp(ThemeExtension<AppAccentExtension>? other, double t) {
    if (other is! AppAccentExtension) return this;
    return AppAccentExtension(
      cassa: Color.lerp(cassa, other.cassa, t)!,
      prodotti: Color.lerp(prodotti, other.prodotti, t)!,
      inventario: Color.lerp(inventario, other.inventario, t)!,
      nuovoProdotto: Color.lerp(nuovoProdotto, other.nuovoProdotto, t)!,
      coupon: Color.lerp(coupon, other.coupon, t)!,
      ordini: Color.lerp(ordini, other.ordini, t)!,
      clienti: Color.lerp(clienti, other.clienti, t)!,
      fornitori: Color.lerp(fornitori, other.fornitori, t)!,
      carteFedelta: Color.lerp(carteFedelta, other.carteFedelta, t)!,
      report: Color.lerp(report, other.report, t)!,
      dashboard: Color.lerp(dashboard, other.dashboard, t)!,
      impostazioni: Color.lerp(impostazioni, other.impostazioni, t)!,
      aggiornamenti: Color.lerp(aggiornamenti, other.aggiornamenti, t)!,
      caldav: Color.lerp(caldav, other.caldav, t)!,
      dipendenti: Color.lerp(dipendenti, other.dipendenti, t)!,
      rfid: Color.lerp(rfid, other.rfid, t)!,
    );
  }
}

/// Palette dei grafici della dashboard.
///
/// Le tinte di serie e categoriali sono validate per contrasto e daltonismo su
/// fondi chiari e scuri; i colori di stato (good/warning/critical) sono
/// riservati agli indicatori e accompagnati sempre da un'icona. Il tooltip dei
/// grafici resta scuro in entrambi i temi.
@immutable
class AppChartExtension extends ThemeExtension<AppChartExtension> {
  const AppChartExtension({
    required this.series,
    required this.categorical,
    required this.good,
    required this.warning,
    required this.critical,
    required this.deltaUp,
    required this.deltaDown,
    required this.tooltipBackground,
    required this.tooltipText,
    required this.tooltipMutedText,
    required this.tooltipValue,
    required this.tooltipHighlight,
  });

  final Color series;
  final List<Color> categorical;
  final Color good;
  final Color warning;
  final Color critical;
  final Color deltaUp;
  final Color deltaDown;
  final Color tooltipBackground;
  final Color tooltipText;
  final Color tooltipMutedText;

  /// Valore principale nel tooltip (es. importo venduto).
  final Color tooltipValue;

  /// Valore secondario evidenziato nel tooltip.
  final Color tooltipHighlight;

  static const AppChartExtension light = AppChartExtension(
    series: Color(0xFF2A78D6),
    categorical: [
      Color(0xFF2A78D6),
      Color(0xFFEB6834),
      Color(0xFF1BAF7A),
      Color(0xFFEDA100),
      Color(0xFFE87BA4),
      Color(0xFF008300),
      Color(0xFF6250D6),
    ],
    good: Color(0xFF0CA30C),
    warning: Color(0xFFC98500),
    critical: Color(0xFFD03B3B),
    deltaUp: Color(0xFF006300),
    deltaDown: Color(0xFFD03B3B),
    tooltipBackground: Color(0xDD000000),
    tooltipText: Colors.white,
    tooltipMutedText: Color(0xB3FFFFFF),
    tooltipValue: Color(0xFF69F0AE),
    tooltipHighlight: Color(0xFF40C4FF),
  );

  static const AppChartExtension dark = AppChartExtension(
    series: Color(0xFF3987E5),
    categorical: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
      Color(0xFF9085E9),
    ],
    good: Color(0xFF0CA30C),
    warning: Color(0xFFFAB219),
    critical: Color(0xFFD03B3B),
    deltaUp: Color(0xFF0CA30C),
    deltaDown: Color(0xFFE66767),
    tooltipBackground: Color(0xDD000000),
    tooltipText: Colors.white,
    tooltipMutedText: Color(0xB3FFFFFF),
    tooltipValue: Color(0xFF69F0AE),
    tooltipHighlight: Color(0xFF40C4FF),
  );

  @override
  AppChartExtension copyWith({
    Color? series,
    List<Color>? categorical,
    Color? good,
    Color? warning,
    Color? critical,
    Color? deltaUp,
    Color? deltaDown,
    Color? tooltipBackground,
    Color? tooltipText,
    Color? tooltipMutedText,
    Color? tooltipValue,
    Color? tooltipHighlight,
  }) {
    return AppChartExtension(
      series: series ?? this.series,
      categorical: categorical ?? this.categorical,
      good: good ?? this.good,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      deltaUp: deltaUp ?? this.deltaUp,
      deltaDown: deltaDown ?? this.deltaDown,
      tooltipBackground: tooltipBackground ?? this.tooltipBackground,
      tooltipText: tooltipText ?? this.tooltipText,
      tooltipMutedText: tooltipMutedText ?? this.tooltipMutedText,
      tooltipValue: tooltipValue ?? this.tooltipValue,
      tooltipHighlight: tooltipHighlight ?? this.tooltipHighlight,
    );
  }

  @override
  AppChartExtension lerp(ThemeExtension<AppChartExtension>? other, double t) {
    if (other is! AppChartExtension) return this;
    return AppChartExtension(
      series: Color.lerp(series, other.series, t)!,
      // Le liste hanno la stessa lunghezza in entrambi i temi.
      categorical: [
        for (var i = 0; i < categorical.length; i++)
          i < other.categorical.length
              ? Color.lerp(categorical[i], other.categorical[i], t)!
              : categorical[i],
      ],
      good: Color.lerp(good, other.good, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      deltaUp: Color.lerp(deltaUp, other.deltaUp, t)!,
      deltaDown: Color.lerp(deltaDown, other.deltaDown, t)!,
      tooltipBackground: Color.lerp(
        tooltipBackground,
        other.tooltipBackground,
        t,
      )!,
      tooltipText: Color.lerp(tooltipText, other.tooltipText, t)!,
      tooltipMutedText: Color.lerp(
        tooltipMutedText,
        other.tooltipMutedText,
        t,
      )!,
      tooltipValue: Color.lerp(tooltipValue, other.tooltipValue, t)!,
      tooltipHighlight: Color.lerp(
        tooltipHighlight,
        other.tooltipHighlight,
        t,
      )!,
    );
  }
}

/// Raggi di arrotondamento centralizzati.
/// Sostituisce i BorderRadius.circular(N) sparsi in tutta l'app.
@immutable
class AppShapeExtension extends ThemeExtension<AppShapeExtension> {
  const AppShapeExtension({
    this.radiusXS = 4,
    this.radiusS = 8,
    this.radiusM = 12,
    this.radiusL = 16,
    this.radiusXL = 20,
    this.radiusFull = 999,
  });

  final double radiusXS;
  final double radiusS;
  final double radiusM;
  final double radiusL;
  final double radiusXL;
  final double radiusFull;

  BorderRadius get xs => BorderRadius.circular(radiusXS);
  BorderRadius get s => BorderRadius.circular(radiusS);
  BorderRadius get m => BorderRadius.circular(radiusM);
  BorderRadius get l => BorderRadius.circular(radiusL);
  BorderRadius get xl => BorderRadius.circular(radiusXL);
  BorderRadius get full => BorderRadius.circular(radiusFull);

  /// Raggio con angoli solo in alto, per header e sheet.
  BorderRadius get topL => BorderRadius.vertical(top: Radius.circular(radiusL));

  @override
  AppShapeExtension copyWith({
    double? radiusXS,
    double? radiusS,
    double? radiusM,
    double? radiusL,
    double? radiusXL,
    double? radiusFull,
  }) {
    return AppShapeExtension(
      radiusXS: radiusXS ?? this.radiusXS,
      radiusS: radiusS ?? this.radiusS,
      radiusM: radiusM ?? this.radiusM,
      radiusL: radiusL ?? this.radiusL,
      radiusXL: radiusXL ?? this.radiusXL,
      radiusFull: radiusFull ?? this.radiusFull,
    );
  }

  @override
  AppShapeExtension lerp(ThemeExtension<AppShapeExtension>? other, double t) {
    if (other is! AppShapeExtension) return this;
    return AppShapeExtension(
      radiusXS: lerpDouble(radiusXS, other.radiusXS, t)!,
      radiusS: lerpDouble(radiusS, other.radiusS, t)!,
      radiusM: lerpDouble(radiusM, other.radiusM, t)!,
      radiusL: lerpDouble(radiusL, other.radiusL, t)!,
      radiusXL: lerpDouble(radiusXL, other.radiusXL, t)!,
      radiusFull: lerpDouble(radiusFull, other.radiusFull, t)!,
    );
  }
}

/// Scala di spaziature centralizzata.
/// Sostituisce gli EdgeInsets.all/symmetric(N) sparsi in tutta l'app.
@immutable
class AppSpacingExtension extends ThemeExtension<AppSpacingExtension> {
  const AppSpacingExtension({
    this.xs = 4,
    this.s = 8,
    this.m = 12,
    this.l = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  EdgeInsets get iXS => EdgeInsets.all(xs);
  EdgeInsets get iS => EdgeInsets.all(s);
  EdgeInsets get iM => EdgeInsets.all(m);
  EdgeInsets get iL => EdgeInsets.all(l);
  EdgeInsets get iXL => EdgeInsets.all(xl);
  EdgeInsets get iXXL => EdgeInsets.all(xxl);

  EdgeInsets get hS => EdgeInsets.symmetric(horizontal: s);
  EdgeInsets get vS => EdgeInsets.symmetric(vertical: s);
  EdgeInsets get hM => EdgeInsets.symmetric(horizontal: m);
  EdgeInsets get vM => EdgeInsets.symmetric(vertical: m);
  EdgeInsets get hL => EdgeInsets.symmetric(horizontal: l);
  EdgeInsets get vL => EdgeInsets.symmetric(vertical: l);

  @override
  AppSpacingExtension copyWith({
    double? xs,
    double? s,
    double? m,
    double? l,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingExtension(
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  AppSpacingExtension lerp(
    ThemeExtension<AppSpacingExtension>? other,
    double t,
  ) {
    if (other is! AppSpacingExtension) return this;
    return AppSpacingExtension(
      xs: lerpDouble(xs, other.xs, t)!,
      s: lerpDouble(s, other.s, t)!,
      m: lerpDouble(m, other.m, t)!,
      l: lerpDouble(l, other.l, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

/// Accessori comodi per leggere il tema senza ripetere
/// `Theme.of(context).extension<T>()` in ogni widget.
///
/// Uso tipico:
///
/// ```dart
/// Container(
///   color: context.colors.surfaceVariantColor,
///   padding: context.spacing.iL,
/// )
/// ```
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  /// Estensione dei colori semantici dell'app.
  ///
  /// Fallback intenzionale: alcuni widget riusabili possono essere montati in
  /// test, dialog o route con un `ThemeData` grezzo. In quel caso non devono
  /// esplodere con `Null check operator used on a null value`, ma usare i
  /// colori base coerenti con la brightness corrente.
  AppColorExtension get colors {
    final theme = Theme.of(this);
    return theme.extension<AppColorExtension>() ??
        (theme.brightness == Brightness.dark
            ? AppTheme.darkTheme.extension<AppColorExtension>()!
            : AppTheme.lightTheme.extension<AppColorExtension>()!);
  }

  /// Raggi di arrotondamento condivisi.
  AppShapeExtension get shapes =>
      Theme.of(this).extension<AppShapeExtension>() ??
      const AppShapeExtension();

  /// Scala di spaziature condivisa.
  AppSpacingExtension get spacing =>
      Theme.of(this).extension<AppSpacingExtension>() ??
      const AppSpacingExtension();

  /// Accenti categoriali delle sezioni della Home.
  AppAccentExtension get accents {
    final theme = Theme.of(this);
    return theme.extension<AppAccentExtension>() ??
        (theme.brightness == Brightness.dark
            ? AppAccentExtension.dark
            : AppAccentExtension.light);
  }

  /// Palette dei grafici della dashboard.
  AppChartExtension get charts {
    final theme = Theme.of(this);
    return theme.extension<AppChartExtension>() ??
        (theme.brightness == Brightness.dark
            ? AppChartExtension.dark
            : AppChartExtension.light);
  }

  TextTheme get text => Theme.of(this).textTheme;
}
