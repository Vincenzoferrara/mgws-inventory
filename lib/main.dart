import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:report_flutter/report_flutter.dart' show ReportLocalizations;
import 'updater/updater_service.dart';
import 'log_viewer/app_logger.dart';
import 'notification/notification_service.dart';
import 'settings/theme/theme_settings.dart';
import 'l10n/extensions.dart';
import 'l10n/locale_settings.dart';
import 'welcome/welcome_gate.dart';
import 'welcome/welcome_preferences.dart';
import 'welcome/welcome_tour_controller.dart';

Future<void> main(List<String> args) async {
  // Assicurati che Flutter sia inizializzato
  WidgetsFlutterBinding.ensureInitialized();

  await UpdaterService.initializeVelopackRuntime(args);

  // Inizializza il logger
  await log.init();

  // Inizializza il theme manager
  final themeSettings = ThemeSettings();
  await themeSettings.init();

  // Inizializza la gestione della lingua dell'interfaccia
  final localeSettings = LocaleSettings();
  await localeSettings.init();

  // Welcome guides share one versioned local store and one coordinator, so a
  // single instance of each owns the guided tour state for the whole app.
  final welcomePreferences = WelcomePreferences();
  final welcomeTourController = WelcomeTourController(
    preferences: welcomePreferences,
  );

  log.d('Application started');

  // La funzione runApp avvia l'applicazione Flutter con il widget radice.
  runApp(
    MyApp(
      themeSettings: themeSettings,
      localeSettings: localeSettings,
      welcomeTourController: welcomeTourController,
    ),
  );
}

// MyApp è il widget radice (root) della tua intera applicazione.
class MyApp extends StatelessWidget {
  final ThemeSettings themeSettings;
  final LocaleSettings localeSettings;
  final WelcomeTourController welcomeTourController;

  const MyApp({
    super.key,
    required this.themeSettings,
    required this.localeSettings,
    required this.welcomeTourController,
  });

  @override
  Widget build(BuildContext context) {
    // Wrappa l'app con ChangeNotifierProvider per rendere ThemeSettings disponibile ovunque
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeSettings>.value(value: themeSettings),
        ChangeNotifierProvider<LocaleSettings>.value(value: localeSettings),
        ChangeNotifierProvider<WelcomeTourController>.value(
          value: welcomeTourController,
        ),
      ],
      child: Consumer<ThemeSettings>(
        builder: (context, themeSettings, child) {
          return Consumer<LocaleSettings>(
            builder: (context, localeSettings, _) {
              return MaterialApp(
                onGenerateTitle: (context) => context.l10n.appTitle,
                scaffoldMessengerKey: notificationMessengerKey,

                // Traduce anche i widget interni di Material e Cupertino,
                // non solo le stringhe dell'app.
                // The report_flutter print screens bring their own texts.
                localizationsDelegates: const [
                  ...AppLocalizations.localizationsDelegates,
                  ReportLocalizations.delegate,
                ],

                // Con locale null l'app segue l'impostazione del sistema.
                supportedLocales: LocaleSettings.supportate,
                locale: localeSettings.lingua,

                // Usa i temi personalizzati con i colori scelti dall'utente
                theme: themeSettings.customLightTheme,
                darkTheme: themeSettings.customDarkTheme,

                // Usa il themeMode gestito dal ThemeSettings
                themeMode: themeSettings.themeMode,

                // The gate decides at startup between the first-run welcome
                // flow and the home, so HomeScreen is never the first screen
                // built when the overview has not been seen yet.
                home: const WelcomeGate(),
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}
