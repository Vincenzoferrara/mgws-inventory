import 'package:flutter/foundation.dart';

import '../log_viewer/app_logger.dart';
import 'welcome_preferences.dart';
import 'welcome_tour_ids.dart';

/// How a tour was started.
///
/// The mode tells the coordinator why an overlay is opening, so the automatic
/// sequence and an explicit user request never confuse each other.
enum WelcomeTourStartMode {
  /// The tour starts by itself on its own screen, only on first use.
  automatic,

  /// The user asked for the tour through a Help action or the Guides list.
  manual,
}

/// Why the active tour stopped.
///
/// Only [finished] and [skipped] are a deliberate user outcome, so only those
/// two reasons may write the completion flag.
enum WelcomeTourEndReason {
  /// The user walked through the last step of the tour.
  finished,

  /// The user used the Skip action.
  skipped,

  /// The overlay went away without a user decision, for example because the
  /// route was disposed or the showcase failed to render.
  dismissed,

  /// The tour dismissed itself to run a real navigation callback.
  navigation,

  /// The tour cannot run, for example because no usable target is mounted.
  unavailable,
}

/// Logical position of a tour that has to resume on another screen.
///
/// Showcase scopes are screen specific, so a cross-screen tour stores where it
/// stopped here instead of keeping an overlay alive across a disposed route.
class WelcomeTourCheckpoint {
  /// Tour that owns this position.
  final WelcomeTourId tourId;

  /// Identifier of the step the tour must resume from.
  final String stepId;

  /// Creates an immutable position of [tourId] at [stepId].
  const WelcomeTourCheckpoint({required this.tourId, required this.stepId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WelcomeTourCheckpoint &&
          other.tourId == tourId &&
          other.stepId == stepId;

  @override
  int get hashCode => Object.hash(tourId, stepId);

  @override
  String toString() => 'WelcomeTourCheckpoint(${tourId.name}, $stepId)';
}

/// Single owner of "which guided tour is active right now".
///
/// The coordinator is the only stateful piece of the welcome module. Screens,
/// settings and Home publish intents through it and read the resulting state
/// from it, so no widget keeps a private copy of the tour state that could
/// disagree with the others.
///
/// Three invariants drive the whole design:
///
/// - At most one tour is active. [begin] refuses every new start while an
///   overlay is up, which makes a double call from a rebuilding screen
///   harmless.
/// - Only a deliberate user outcome persists. [end] writes the completion flag
///   for [WelcomeTourEndReason.finished] and [WelcomeTourEndReason.skipped]
///   only; every other reason clears the runtime state and leaves the flag
///   exactly as it was, so a route disposal, a logout or a failed render never
///   silently hides a tour from the next automatic start.
/// - The manual start request is single shot. [takeManualStartRequest] hands
///   the tour over once and clears it, so Home cannot start the same tour
///   twice from two rebuilds.
///
/// Completion is never stored here: it lives in [WelcomePreferences], which
/// owns the versioned keys.
class WelcomeTourController extends ChangeNotifier {
  /// Versioned local store of the completion flags.
  final WelcomePreferences _preferences;

  WelcomeTourId? _activeTour;
  WelcomeTourId? _requestedManualTour;
  WelcomeTourCheckpoint? _pendingCheckpoint;

  /// Creates the coordinator on top of [preferences].
  ///
  /// The caller owns the preferences instance, so one store is shared by every
  /// screen instead of each screen resolving its own.
  WelcomeTourController({required WelcomePreferences preferences})
    : _preferences = preferences;

  /// Tour whose overlay is currently up, or `null` when none is active.
  WelcomeTourId? get activeTour => _activeTour;

  /// Tour published by a Help action or by the Guides list and not yet taken.
  ///
  /// This is the read-only view of the pending request; [takeManualStartRequest]
  /// is the only way to consume it.
  WelcomeTourId? get requestedManualTour => _requestedManualTour;

  /// Position saved by a tour that left for another screen, if any.
  WelcomeTourCheckpoint? get pendingCheckpoint => _pendingCheckpoint;

  /// Reports whether [tourId] may start by itself right now.
  ///
  /// Returns `true` only when the tour is not already completed or skipped,
  /// which is what keeps automatic starts off a tour the user already saw.
  /// An unreadable flag is reported as not completed, so the tour replays
  /// rather than disappearing.
  ///
  /// Manual replay deliberately does not use this method: a Help action always
  /// starts the tour of the current screen, even after completion.
  Future<bool> shouldStartAutomatically(WelcomeTourId tourId) async {
    final completed = await _preferences.isCompleted(tourId);
    return !completed;
  }

  /// Starts [tourId] and returns `true` when the tour may run.
  ///
  /// Returns `false` when a tour is already active, so a repeated call can
  /// never activate a second overlay. Callers are expected to pair this with
  /// [shouldStartAutomatically] for an automatic start; a manual start ignores
  /// the completed state on purpose. [mode] is recorded for diagnostics only:
  /// the completion gate lives in [shouldStartAutomatically], because reading
  /// the persisted flag is asynchronous while this call is not.
  ///
  /// Every caller that starts an automatic tour MUST await
  /// [shouldStartAutomatically] first and start only on `true`. Calling this
  /// with [WelcomeTourStartMode.automatic] without that check silently replays
  /// a tour the user already completed.
  bool begin(WelcomeTourId tourId, {required WelcomeTourStartMode mode}) {
    final activeTour = _activeTour;
    if (activeTour != null) {
      log.d(
        'Refusing to start the tour "$tourId" ($mode) because the tour '
        '"$activeTour" is already active.',
      );
      return false;
    }

    _activeTour = tourId;
    log.d('Tour "$tourId" started ($mode).');
    notifyListeners();
    return true;
  }

  /// Publishes a manual start request for [tourId].
  ///
  /// The request is a single pending slot: a newer request replaces an older
  /// one instead of queueing, because the user asked for one tour of one
  /// screen, not for a list.
  void requestManualStart(WelcomeTourId tourId) {
    if (_activeTour != null) {
      // Another tour is already on screen, so the request could not be taken
      // right away. Keeping it would start the wrong tour later, once this
      // one ends, as if the user had asked for it from the screen it runs on.
      log.d(
        'Ignoring the manual request for "$tourId": the tour '
        '"$_activeTour" is already active.',
      );
      return;
    }

    _requestedManualTour = tourId;
    notifyListeners();
  }

  /// Consumes the pending manual start request and returns the tour.
  ///
  /// Returns `null` when nothing is pending. The request is cleared before it
  /// is returned, so two consecutive calls can never receive the same tour and
  /// a rebuild cannot restart it.
  WelcomeTourId? takeManualStartRequest() {
    final requestedTour = _requestedManualTour;
    if (requestedTour == null) return null;

    _requestedManualTour = null;
    notifyListeners();
    return requestedTour;
  }

  /// Saves [checkpoint] as the position to resume from on the next screen.
  ///
  /// Only one position is kept, because only one tour can be active.
  void saveCheckpoint(WelcomeTourCheckpoint checkpoint) {
    if (_activeTour != checkpoint.tourId) {
      // A checkpoint of a tour that is not on screen would survive the next
      // end() and be resumed much later, in the wrong place.
      log.d(
        'Ignoring the checkpoint for "${checkpoint.tourId.name}": '
        'the active tour is ${_activeTour?.name ?? 'none'}.',
      );
      return;
    }

    _pendingCheckpoint = checkpoint;
    notifyListeners();
  }

  /// Consumes the saved checkpoint when it belongs to [tourId].
  ///
  /// Returns `null` when no checkpoint is pending or when the pending one
  /// belongs to another tour, so a tour can never resume at a foreign step. The
  /// checkpoint is cleared before it is returned, so it is resumed once.
  WelcomeTourCheckpoint? takeCheckpoint(WelcomeTourId tourId) {
    final checkpoint = _pendingCheckpoint;
    if (checkpoint == null || checkpoint.tourId != tourId) return null;

    _pendingCheckpoint = null;
    notifyListeners();
    return checkpoint;
  }

  /// Ends the active tour for [reason] and persists what the reason allows.
  ///
  /// The runtime state is cleared first and listeners are notified
  /// immediately, so the overlay disappears even when the persisted write is
  /// slow. Only [WelcomeTourEndReason.finished] and
  /// [WelcomeTourEndReason.skipped] write the completion flag: every other
  /// reason leaves the persisted state untouched, so an interrupted tour is
  /// still offered by the next automatic start.
  ///
  /// The saved checkpoint of the same tour survives
  /// [WelcomeTourEndReason.navigation], because that is exactly the case a
  /// checkpoint exists for. It is dropped for every other reason, since a
  /// finished, skipped or abandoned tour must not resume later.
  ///
  /// Does nothing when no tour is active, so a stray call cannot mark an
  /// arbitrary tour as completed.
  Future<void> end(WelcomeTourEndReason reason) async {
    final tourId = _activeTour;
    if (tourId == null) {
      log.d('Ignoring the tour end ($reason): no tour is active.');
      return;
    }

    _activeTour = null;

    final checkpoint = _pendingCheckpoint;
    if (checkpoint != null &&
        checkpoint.tourId == tourId &&
        reason != WelcomeTourEndReason.navigation) {
      _pendingCheckpoint = null;
    }

    notifyListeners();

    if (reason == WelcomeTourEndReason.finished ||
        reason == WelcomeTourEndReason.skipped) {
      await _preferences.markCompleted(tourId);
    }
  }

  /// Ends [tourId] only when it is the tour that is actually on screen.
  ///
  /// This is the entry point every overlay callback must use. [end] takes no
  /// tour id, because the brief's signature identifies the tour through the
  /// active state; that also means a callback firing late, after the route was
  /// disposed and another tour already started, would otherwise mark the new
  /// tour completed. Checking the identity here turns that mistake into a
  /// logged no-op instead of a silently lost or wrongly completed guide.
  Future<void> endIfActive(
    WelcomeTourId tourId,
    WelcomeTourEndReason reason,
  ) async {
    if (_activeTour != tourId) {
      log.d(
        'Ignoring the tour end ($reason) for "${tourId.name}": '
        'the active tour is ${_activeTour?.name ?? 'none'}.',
      );
      return;
    }

    await end(reason);
  }

  /// Drops the runtime tour state after a session change.
  ///
  /// Logout, session replacement and credential revocation must not leave an
  /// overlay behind, and must not replay a tour of the previous session. The
  /// active tour, the pending manual request and the saved checkpoint are
  /// cleared, while the persisted completion flags stay exactly as they are:
  /// onboarding progress belongs to the device, not to the session.
  void dismissForSessionChange() {
    if (_activeTour == null &&
        _requestedManualTour == null &&
        _pendingCheckpoint == null) {
      return;
    }

    _activeTour = null;
    _requestedManualTour = null;
    _pendingCheckpoint = null;
    log.d('Tour state cleared after a session change.');
    notifyListeners();
  }
}
