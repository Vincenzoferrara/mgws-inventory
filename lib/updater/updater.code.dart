import 'package:flutter/material.dart';

import 'updater_service.dart';
import '../traduzioni/estensioni.dart';

enum UpdaterStatus {
  idle,
  unsupported,
  checking,
  updateAvailable,
  upToDate,
  installing,
  error,
}

class UpdaterLogic extends ChangeNotifier {
  final UpdaterService _service;

  UpdaterStatus _status = UpdaterStatus.idle;
  String _installedVersion = '';
  String _message = '';
  String? _error;

  UpdaterLogic({UpdaterService? service})
    : _service = service ?? UpdaterService();

  UpdaterStatus get status => _status;
  String get installedVersion => _installedVersion;
  String get message => _message;
  String? get error => _error;
  String platformLabel(AppLocalizations l10n) =>
      UpdaterService.platformLabel(l10n);
  String get updateUrl => UpdaterService.updateUrl;
  bool get isSupported => UpdaterService.canCheckForUpdates;

  /// Su Android l'app avvisa soltanto: l'installazione spetta a F-Droid,
  /// Obtainium o allo store.
  bool get isNotifyOnly => UpdaterService.isNotifyOnlyPlatform;
  bool get canInstall =>
      !isNotifyOnly && _status == UpdaterStatus.updateAvailable;
  bool get isBusy =>
      _status == UpdaterStatus.checking || _status == UpdaterStatus.installing;

  Future<void> init(AppLocalizations l10n) async {
    try {
      _installedVersion = await _service.installedVersion();
    } catch (_) {
      _installedVersion = l10n.updaterUnknown;
    }

    if (!isSupported) {
      _status = UpdaterStatus.unsupported;
      _message = l10n.updaterUnsupportedMessage;
    } else {
      _status = UpdaterStatus.idle;
      _message = isNotifyOnly
          ? l10n.updaterReadyNotifyOnlyMessage
          : l10n.updaterReadyMessage;
    }
    notifyListeners();
  }

  Future<void> checkForUpdates(AppLocalizations l10n) async {
    if (!isSupported || isBusy) return;
    _status = UpdaterStatus.checking;
    _message = l10n.updaterCheckingMessage;
    _error = null;
    notifyListeners();

    try {
      if (isNotifyOnly) {
        final release = await _service.latestNewerRelease();
        if (release != null) {
          _status = UpdaterStatus.updateAvailable;
          _message = l10n.updaterUpdateAvailableNotifyOnlyMessage(
            release.version,
          );
        } else {
          _status = UpdaterStatus.upToDate;
          _message = l10n.updaterUpToDateMessage;
        }
        notifyListeners();
        return;
      }

      final available = await _service.checkForUpdates();
      if (available) {
        _status = UpdaterStatus.updateAvailable;
        _message = l10n.updaterUpdateAvailableMessage;
      } else {
        _status = UpdaterStatus.upToDate;
        _message = l10n.updaterUpToDateMessage;
      }
    } catch (error) {
      _status = UpdaterStatus.error;
      _error = error.toString();
      _message = l10n.updaterCheckFailedMessage;
    }
    notifyListeners();
  }

  Future<void> installAndRestart(AppLocalizations l10n) async {
    if (!isSupported || isNotifyOnly || isBusy) return;
    _status = UpdaterStatus.installing;
    _message = l10n.updaterInstallingMessage;
    _error = null;
    notifyListeners();

    try {
      await _service.installAndRestart();
    } catch (error) {
      _status = UpdaterStatus.error;
      _error = error.toString();
      _message = l10n.updaterInstallFailedMessage;
      notifyListeners();
    }
  }
}
