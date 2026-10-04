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

  Future<bool> checkForUpdates() async {
    _ensureSupported();
    return isUpdateAvailable(url: updateUrl);
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
    if (!isDesktopUpdateSupported) return null;

    try {
      final installed = await installedVersion();
      final currentVersion = _normalizeVersion(installed);
      final response = await http.get(Uri.parse(_repoApiLatestRelease));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final tag = (data['tag_name'] as String? ?? '').trim();
      final releaseVersion = _normalizeVersion(tag);
      if (!_matchesInstalledVersion(releaseVersion, currentVersion)) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastShownReleaseNotesKey) == releaseVersion) {
        return null;
      }

      await prefs.setString(_lastShownReleaseNotesKey, releaseVersion);
      final htmlUrl = (data['html_url'] as String? ?? '').trim();
      return UpdaterReleaseNotes(
        version: releaseVersion,
        title: (data['name'] as String? ?? tag).trim(),
        body: (data['body'] as String? ?? '').trim(),
        url: Uri.tryParse(htmlUrl) ?? Uri.parse(_repoApiLatestRelease),
      );
    } catch (error) {
      log.d('Release notes check failed: $error');
      return null;
    }
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
