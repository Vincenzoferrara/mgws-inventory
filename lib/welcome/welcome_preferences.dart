import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import 'welcome_tour_ids.dart';

/// Local-only persistence of the guided tour completion state.
///
/// The state belongs to this device: it is stored in SharedPreferences under
/// versioned keys owned by the welcome module and is never synchronized
/// through MGWS, because onboarding progress is not shared business data.
///
/// Every operation degrades gracefully. A failed read reports the tour as not
/// completed, a failed write is only logged, and nothing here throws to the
/// caller: a persistence problem must never break a screen and must never
/// block application startup.
class WelcomePreferences {
  /// Optional instance supplied by the caller.
  ///
  /// When null, the instance is resolved lazily through
  /// [SharedPreferences.getInstance] on every use. Resolution is lazy so that
  /// constructing this class never touches the platform channel.
  final SharedPreferences? _injectedPreferences;

  /// Creates the store, optionally on top of an existing preferences instance.
  WelcomePreferences({SharedPreferences? preferences})
    : _injectedPreferences = preferences;

  /// Reports whether [tourId] has already been completed or skipped.
  ///
  /// Returns `false` when the flag is missing and also when it cannot be read,
  /// so an unreadable state replays the tour instead of hiding it.
  Future<bool> isCompleted(WelcomeTourId tourId) async {
    final preferences = await _resolvePreferences();
    if (preferences == null) return false;

    try {
      return preferences.getBool(tourId.preferenceKey) ?? false;
    } catch (error, stackTrace) {
      log.d(
        'Error reading welcome tour preference "${tourId.preferenceKey}": $error',
        error,
        stackTrace,
      );
      return false;
    }
  }

  /// Marks [tourId] as completed, so it is not started automatically again.
  ///
  /// Manual replay does not go through here: it does not alter the flag.
  Future<void> markCompleted(WelcomeTourId tourId) async {
    final preferences = await _resolvePreferences();
    if (preferences == null) return;

    try {
      await preferences.setBool(tourId.preferenceKey, true);
    } catch (error, stackTrace) {
      log.d(
        'Error writing welcome tour preference "${tourId.preferenceKey}": $error',
        error,
        stackTrace,
      );
    }
  }

  /// Clears the completion flag of a single [tourId] without touching others.
  Future<void> reset(WelcomeTourId tourId) async {
    final preferences = await _resolvePreferences();
    if (preferences == null) return;

    try {
      await preferences.remove(tourId.preferenceKey);
    } catch (error, stackTrace) {
      log.d(
        'Error removing welcome tour preference "${tourId.preferenceKey}": $error',
        error,
        stackTrace,
      );
    }
  }

  /// Clears the completion flag of every known tour.
  ///
  /// Only the keys owned by [WelcomeTourId] are removed. SharedPreferences is
  /// never cleared as a whole, so unrelated settings and modules survive.
  ///
  /// Delegates to [reset] so the per-key behavior, including the failure
  /// handling, lives in exactly one place.
  Future<void> resetAll() async {
    for (final tourId in WelcomeTourId.values) {
      await reset(tourId);
    }
  }

  /// Completion state of every known tour, for the Guides settings section.
  ///
  /// The map always contains every value of [WelcomeTourId]; unreadable tours
  /// are reported as not completed.
  ///
  /// Delegates to [isCompleted] so the read behavior and the key derivation
  /// cannot drift between the single-tour and the all-tours path.
  Future<Map<WelcomeTourId, bool>> completionSnapshot() async {
    final snapshot = <WelcomeTourId, bool>{};

    for (final tourId in WelcomeTourId.values) {
      snapshot[tourId] = await isCompleted(tourId);
    }

    return snapshot;
  }

  /// Returns the injected instance, or resolves the shared one.
  ///
  /// Returns null when SharedPreferences cannot be opened, which makes every
  /// operation a no-op instead of an exception.
  Future<SharedPreferences?> _resolvePreferences() async {
    final injected = _injectedPreferences;
    if (injected != null) return injected;

    try {
      return await SharedPreferences.getInstance();
    } catch (error, stackTrace) {
      log.d(
        'Error opening SharedPreferences for the welcome guides: $error',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
