import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velopack_flutter/velopack_flutter.dart';
import '../log_viewer/app_logger.dart';
import '../traduzioni/estensioni.dart';

class UpdaterReleaseNotes {
  final String version;
  final String title;
  final String body;
  final Uri url;

  const UpdaterReleaseNotes({
    required this.version,
    required this.title,
    required this.body,
    required this.url,
  });
}

class UpdaterService {
  static const String _repoApiLatestRelease =
      'https://api.github.com/repos/Vincenzoferrara/mgws-inventory/releases/latest';
  static const String _lastShownReleaseNotesKey =
      'updater_last_shown_release_notes_version';
  static const String _lastNotifiedUpdateKey =
      'updater_last_notified_update_version';
  static const String _defaultUpdateUrl = String.fromEnvironment(
    'UPDATE_URL',
    defaultValue:
        'https://github.com/Vincenzoferrara/mgws-inventory/releases/latest/download/',
  );

  static bool _runtimeInitialized = false;

  static bool get isDesktopUpdateSupported {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  /// Le build per F-Droid e per gli store si compilano con
  /// `--dart-define=UPDATE_CHECK=false`: lì gli aggiornamenti li porta lo
  /// store, e Google Play non accetta avvisi che rimandano a download esterni.
  static const bool _updateCheckEnabled = bool.fromEnvironment(
    'UPDATE_CHECK',
    defaultValue: true,
  );

  /// Android riceve gli aggiornamenti da F-Droid, Obtainium o dallo store:
  /// l'app non scarica ne installa nulla, avvisa soltanto che esiste una
  /// versione piu recente.
  static bool get isNotifyOnlyPlatform {
    if (kIsWeb || !_updateCheckEnabled) return false;
    return Platform.isAndroid;
  }

  /// La piattaforma ha almeno un controllo aggiornamenti, con installazione
  /// (desktop Velopack) o con il solo avviso (Android).
  static bool get canCheckForUpdates =>
      isDesktopUpdateSupported || isNotifyOnlyPlatform;

  static String platformLabel(AppLocalizations l10n) {
    if (kIsWeb) return 'Web';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return l10n.updaterUnknown;
  }

  static String get updateUrl => _defaultUpdateUrl;

  static Future<void> initializeVelopackRuntime(List<String> args) async {
    if (!isDesktopUpdateSupported || _runtimeInitialized) return;

    try {
      await RustLib.init();
      _runtimeInitialized = true;
      if (_isVelopackLifecycleCommand(args)) {
        exit(0);
      }
    } catch (error) {
      log.d('Velopack runtime initialization failed: $error');
    }
  }

  static bool _isVelopackLifecycleCommand(List<String> args) {
    const commands = {
      '--veloapp-install',
      '--veloapp-updated',
      '--veloapp-obsolete',
      '--veloapp-uninstall',
    };
    return args.any(commands.contains);
  }

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Controlla se esiste una versione piu recente di quella installata.
  ///
  /// Su desktop chiede a Velopack; su Android confronta la versione installata
  /// con l'ultima release GitHub, che e' la stessa da cui partono F-Droid e
  /// Obtainium.
  Future<bool> checkForUpdates() async {
    if (isNotifyOnlyPlatform) {
      return await latestNewerRelease() != null;
    }
    _ensureSupported();
    return isUpdateAvailable(url: updateUrl);
  }

  /// Ultima release GitHub se e' piu recente della versione installata.
  Future<UpdaterReleaseNotes?> latestNewerRelease() async {
    final release = await _fetchLatestRelease();
    if (release == null) return null;
    final installed = _normalizeVersion(await installedVersion());
    if (!isNewerVersion(release.version, installed)) return null;
    return release;
  }

  /// Versione piu recente installabile, o `null` se l'app e aggiornata o la
  /// piattaforma non prevede aggiornamenti. Non ricorda nulla: la usa anche
  /// la campanella notifiche, che resta accesa finche non si aggiorna.
  Future<String?> availableUpdateVersion() async {
    if (!canCheckForUpdates) return null;
    if (isNotifyOnlyPlatform) {
      return (await latestNewerRelease())?.version;
    }
    if (!_runtimeInitialized) return null;
    if (!await isUpdateAvailable(url: updateUrl)) return null;
    // Il numero di versione serve per l'avviso e per non ripeterlo.
    return (await _fetchLatestRelease())?.version;
  }

  /// Controllo silenzioso all'avvio: restituisce la versione da segnalare
  /// solo la prima volta che compare, cosi l'avviso non si ripete a ogni
  /// apertura dell'app per la stessa release.
  Future<String?> pendingUpdateNotice() async {
    try {
      final version = await availableUpdateVersion();
      if (version == null) return null;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastNotifiedUpdateKey) == version) return null;
      await prefs.setString(_lastNotifiedUpdateKey, version);
      return version;
    } catch (error) {
      log.d('Startup update check failed: $error');
      return null;
    }
  }

  Future<void> installAndRestart() async {
    _ensureSupported();
    await waitExitThenUpdate(url: updateUrl, silent: false, restart: true);
    exit(0);
  }

  Future<void> installAfterExit({
    bool silent = false,
    bool restart = true,
  }) async {
    _ensureSupported();
    await waitExitThenUpdate(url: updateUrl, silent: silent, restart: restart);
  }

  Future<UpdaterReleaseNotes?> releaseNotesForInstalledUpdate() async {
    if (!canCheckForUpdates) return null;

    try {
      final currentVersion = _normalizeVersion(await installedVersion());
      final release = await _fetchLatestRelease();
      if (release == null ||
          !_matchesInstalledVersion(release.version, currentVersion)) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString(_lastShownReleaseNotesKey);
      await prefs.setString(_lastShownReleaseNotesKey, release.version);
      // Prima installazione: non c'e' stato alcun aggiornamento da raccontare.
      if (lastShown == null || lastShown == release.version) return null;
      return release;
    } catch (error) {
      log.d('Release notes check failed: $error');
      return null;
    }
  }

  Future<UpdaterReleaseNotes?> _fetchLatestRelease() async {
    try {
      final response = await http
          .get(
            Uri.parse(_repoApiLatestRelease),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final tag = (data['tag_name'] as String? ?? '').trim();
      final version = _normalizeVersion(tag);
      if (version.isEmpty) return null;
      final htmlUrl = (data['html_url'] as String? ?? '').trim();
      return UpdaterReleaseNotes(
        version: version,
        title: (data['name'] as String? ?? tag).trim(),
        body: (data['body'] as String? ?? '').trim(),
        url: Uri.tryParse(htmlUrl) ?? Uri.parse(_repoApiLatestRelease),
      );
    } catch (error) {
      log.d('Latest release fetch failed: $error');
      return null;
    }
  }

  /// `true` se [candidate] e' una versione successiva a [current].
  ///
  /// Confronta i segmenti numerici uno a uno (`1.0.10` > `1.0.9`); i
  /// segmenti mancanti valgono zero e quelli non numerici vengono ignorati.
  @visibleForTesting
  static bool isNewerVersion(String candidate, String current) {
    final a = _versionParts(_normalizeVersion(candidate));
    final b = _versionParts(_normalizeVersion(current));
    if (a.isEmpty || b.isEmpty) return false;
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _versionParts(String version) {
    final core = version.split('-').first;
    return [
      for (final part in core.split('.'))
        if (int.tryParse(part) != null) int.parse(part),
    ];
  }

  static String _normalizeVersion(String version) {
    var normalized = version.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final buildSeparator = normalized.indexOf('+');
    if (buildSeparator >= 0) {
      normalized = normalized.substring(0, buildSeparator);
    }
    return normalized;
  }

  static bool _matchesInstalledVersion(
    String releaseVersion,
    String currentVersion,
  ) {
    if (releaseVersion.isEmpty || currentVersion.isEmpty) return false;
    return releaseVersion == currentVersion ||
        releaseVersion.startsWith('$currentVersion.');
  }

  void _ensureSupported() {
    if (!isDesktopUpdateSupported) {
      throw UnsupportedError(
        'Velopack updates are available only on Windows and Linux.',
      );
    }
    if (!_runtimeInitialized) {
      throw StateError('Velopack runtime is not initialized.');
    }
  }
}
