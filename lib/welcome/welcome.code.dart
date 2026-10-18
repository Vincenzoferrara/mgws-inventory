import 'package:flutter/foundation.dart';

import '../log_viewer/app_logger.dart';
import 'welcome_preferences.dart';
import 'welcome_tour_controller.dart';
import 'welcome_tour_ids.dart';

/// Screen logic of the first-run welcome flow.
///
/// The class owns the single decision that has to survive a rebuild: once the
/// user finishes or skips the welcome, the flow is over and the app is opened
/// exactly once. A double tap on Start, a Skip that arrives while a write is
/// still pending, or a rebuild in between cannot open the home twice.
///
/// Navigation is injected as a callback instead of being performed here, so the
/// logic never holds a `BuildContext` and can never use a disposed one. That
/// keeps the completion rules testable in isolation and leaves the widget free
/// to decide how the home is pushed.
class WelcomeLogic {
  /// Coordinator that owns the runtime state of the guided tours.
  final WelcomeTourController _tourController;

  /// Versioned local store of the tour completion flags.
  ///
  /// Defaults to a standalone store: the class resolves the shared
  /// `SharedPreferences` instance lazily, so an unwired store reads and writes
  /// exactly the same `welcome.v1.*` keys. A caller that already owns the
  /// shared instance can pass it to keep a single object in memory.
  final WelcomePreferences _preferences;

  /// Opens the home, replacing the welcome route.
  final VoidCallback _openHome;

  /// Set by the first completion and never reset: the welcome ends only once.
  bool _isCompleting = false;

  /// Creates the logic.
  ///
  /// [tourController] is the app-wide coordinator, [preferences] the store that
  /// owns the versioned completion keys and [openHome] the navigation the
  /// widget performs once the flow is over.
  WelcomeLogic({
    required WelcomeTourController tourController,
    required VoidCallback openHome,
    WelcomePreferences? preferences,
  }) : _tourController = tourController,
       _preferences = preferences ?? WelcomePreferences(),
       _openHome = openHome;

  /// Records the welcome as read and opens the home screen.
  ///
  /// Called by the Done action on the last welcome page. Only
  /// [WelcomeTourId.overview] is marked complete: the welcome is not a tour of
  /// any other screen, so no other flag is written.
  Future<void> completeOverview() => _complete(WelcomeTourEndReason.finished);

  /// Records the welcome as deliberately skipped and opens the home screen.
  ///
  /// Skipping is a real outcome, not an interruption, so it marks the same
  /// single flag as [completeOverview] with the reason that tells the logs the
  /// user chose not to read the pages.
  Future<void> skipOverview() => _complete(WelcomeTourEndReason.skipped);

  /// Shared body of the two deliberate endings.
  ///
  /// [reason] is the only difference between them: both persist the same flag,
  /// because the welcome cannot be resumed once the user left it.
  Future<void> _complete(WelcomeTourEndReason reason) async {
    // A second call would repeat the writes and push a second home route on top
    // of the first one, so the first completion wins and the rest are no-ops.
    if (_isCompleting) return;
    _isCompleting = true;

    // The coordinator is told the tour is over, so no overlay state survives
    // the route. It only writes the flag when the overview really was the
    // active tour.
    await _tourController.endIfActive(WelcomeTourId.overview, reason);

    // The overview pages are not a showcase sequence, so the flag is written
    // here: Task 5's gate decides what to show by reading it back, and a gate
    // that opened the welcome need not have started the overview as a tour.
    await _preferences.markCompleted(WelcomeTourId.overview);

    log.d('Welcome flow completed ($reason).');
    _openHome();
  }
}
