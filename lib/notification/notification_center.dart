import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import 'app_notification.dart';
import 'providers/fiscal_register_notification_provider.dart';
import 'providers/low_stock_notification_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/orders_notification_provider.dart';
import 'providers/update_notification_provider.dart';

/// Raccoglie le notifiche di tutti i provider per la campanella in AppBar.
///
/// Ogni minuto interroga i provider scaduti (ognuno ha il suo intervallo),
/// ricorda in [SharedPreferences] cosa e gia stato letto e quali tipi sono
/// spenti. Un provider in errore mantiene le notifiche dell'ultimo controllo
/// riuscito e non blocca gli altri.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter({
    required List<NotificationProvider> providers,
    DateTime Function()? clock,
  }) : _providers = List.unmodifiable(providers),
       _clock = clock ?? DateTime.now;

  static final NotificationCenter instance = NotificationCenter(
    providers: [
      UpdateNotificationProvider(),
      OrdersNotificationProvider(),
      LowStockNotificationProvider(),
      FiscalRegisterNotificationProvider(),
    ],
  );

  static const _readKey = 'notifications_read_revisions';
  static const _disabledKey = 'notifications_disabled_kinds';
  static const _tick = Duration(minutes: 1);

  final List<NotificationProvider> _providers;
  final DateTime Function() _clock;

  final Map<NotificationProvider, List<AppNotification>> _results = {};
  final Map<NotificationProvider, DateTime> _lastRun = {};
  final Map<Listenable, VoidCallback> _triggers = {};

  /// Provider da interrogare al prossimo giro anche se non scaduti.
  final Set<NotificationProvider> _forced = {};

  /// id notifica -> livello letto (vedi [AppNotification.revision]).
  Map<String, int> _read = {};
  Set<AppNotificationKind> _disabled = {};

  bool _loaded = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _forceAgain = false;
  Timer? _timer;

  bool get isRefreshing => _refreshing;

  /// Notifiche dei tipi attivi, le piu urgenti in cima.
  List<AppNotification> get notifications {
    final list = [
      for (final results in _results.values)
        for (final notification in results)
          if (isEnabled(notification.kind)) notification,
    ];
    list.sort((a, b) {
      final byPriority = b.priority.index.compareTo(a.priority.index);
      if (byPriority != 0) return byPriority;
      return a.kind.index.compareTo(b.kind.index);
    });
    return list;
  }

  int get unreadCount => notifications.where(isUnread).length;

  bool isUnread(AppNotification notification) {
    final read = _read[notification.id];
    return read == null || notification.revision > read;
  }

  bool isEnabled(AppNotificationKind kind) => !_disabled.contains(kind);

  /// Avvia il controllo periodico. Chiamate ripetute non creano altri timer.
  Future<void> start() async {
    await _load();
    for (final provider in _providers) {
      final trigger = provider.trigger;
      if (trigger == null || _triggers.containsKey(trigger)) continue;
      void listener() {
        _forced.add(provider);
        refresh();
      }

      trigger.addListener(listener);
      _triggers[trigger] = listener;
    }
    _timer ??= Timer.periodic(_tick, (_) => refresh());
    await refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _triggers.forEach((trigger, listener) => trigger.removeListener(listener));
    _triggers.clear();
  }

  /// Interroga i provider scaduti, o tutti con [force].
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) {
      _refreshAgain = true;
      _forceAgain = _forceAgain || force;
      return;
    }
    _refreshing = true;
    notifyListeners();
    try {
      await _load();
      final now = _clock();
      await Future.wait(_providers.map((p) => _run(p, now, force)));
      await _syncReadState();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
    if (_refreshAgain) {
      final again = _forceAgain;
      _refreshAgain = false;
      _forceAgain = false;
      await refresh(force: again);
    }
  }

  Future<void> markRead(AppNotification notification) async {
    _read[notification.id] = notification.revision;
    notifyListeners();
    await _saveRead();
  }

  Future<void> markAllRead() async {
    for (final notification in notifications) {
      _read[notification.id] = notification.revision;
    }
    notifyListeners();
    await _saveRead();
  }

  Future<void> setEnabled(AppNotificationKind kind, bool enabled) async {
    await _load();
    if (enabled) {
      _disabled.remove(kind);
    } else {
      _disabled.add(kind);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _disabledKey,
      _disabled.map((kind) => kind.name).toList(),
    );
    if (enabled) await refresh(force: true);
  }

  Future<void> _run(
    NotificationProvider provider,
    DateTime now,
    bool force,
  ) async {
    if (!provider.kinds.any(isEnabled) || !provider.isAvailable) {
      _results.remove(provider);
      _lastRun.remove(provider);
      return;
    }
    final last = _lastRun[provider];
    final forced = _forced.remove(provider) || force;
    if (!forced && last != null && now.difference(last) < provider.interval) {
      return;
    }
    _lastRun[provider] = now;
    try {
      _results[provider] = await provider.fetch();
    } catch (error) {
      log.w('Notifiche: ${provider.runtimeType} non disponibile: $error');
    }
  }

  /// Allinea lo stato letto alle notifiche attuali: dimentica quelle sparite
  /// (se ricompaiono tornano non lette) e abbassa il livello letto quando il
  /// conteggio scende, cosi il prossimo aumento riaccende il badge.
  Future<void> _syncReadState() async {
    final current = {
      for (final results in _results.values)
        for (final notification in results) notification.id: notification,
    };
    var changed = false;
    for (final id in _read.keys.toList()) {
      final notification = current[id];
      if (notification == null) {
        _read.remove(id);
        changed = true;
      } else if (notification.revision < _read[id]!) {
        _read[id] = notification.revision;
        changed = true;
      }
    }
    if (changed) await _saveRead();
  }

  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _read = {};
    for (final entry in prefs.getStringList(_readKey) ?? const <String>[]) {
      final separator = entry.lastIndexOf('|');
      if (separator <= 0) continue;
      final revision = int.tryParse(entry.substring(separator + 1));
      if (revision != null) _read[entry.substring(0, separator)] = revision;
    }
    final disabledNames = prefs.getStringList(_disabledKey) ?? const [];
    _disabled = {
      for (final kind in AppNotificationKind.values)
        if (disabledNames.contains(kind.name)) kind,
    };
    _loaded = true;
  }

  Future<void> _saveRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, [
      for (final entry in _read.entries) '${entry.key}|${entry.value}',
    ]);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
