import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import '../log_viewer/app_logger.dart';
import 'welcome_tour_controller.dart';

/// Owner of one named showcase scope, one screen at a time.
///
/// Every screen that ships a guided tour wraps its content in this widget. The
/// scope is the unit that showcaseview understands: the `Showcase` targets of a
/// screen and the overlay that highlights them belong together, and a screen
/// that leaves must take its overlay with it, otherwise an invisible barrier
/// would keep swallowing taps on the screen underneath.
///
/// What this widget guarantees:
///
/// - **Registration happens before anything can start.** The [ShowcaseView] is
///   registered in [initState], which runs before the first build of [child], so
///   every `Showcase` target below is registered against an already existing
///   scope. A tour can therefore never start against a half-built screen.
/// - **Disposal dismisses without persisting anything.** [dispose] removes the
///   overlay and closes the active tour with
///   [WelcomeTourEndReason.dismissed], which clears the runtime state and leaves
///   the completion flags untouched. A route that goes away, a logout or a
///   session change can never be mistaken by the next automatic start as a
///   deliberate Finish or Skip.
/// - **Escape always leaves.** The Escape key closes a running tour with
///   [WelcomeTourEndReason.dismissed]. The handler is registered on the
///   [HardwareKeyboard] instead of on a focus node, so it also works while a
///   text field of the screen holds the focus.
///
/// The scope deliberately does not start any tour. The screen that owns the
/// targets decides when to open, with [WelcomeHelpButton] or with an explicit
/// call, and it resolves this scope with [viewForScope].
class WelcomeShowcaseScope extends StatefulWidget {
  const WelcomeShowcaseScope({
    super.key,
    required this.scopeName,
    required this.child,
    this.enableAutoScroll = true,
  });

  /// Stable name of the scope, unique per screen.
  ///
  /// The name is the handle used to start a tour from anywhere in the app, so
  /// it must not change while the screen is mounted: a `Showcase` target binds
  /// itself to the scope that is current when it is built.
  final String scopeName;

  /// Screen content the scope registers and, when needed, dims.
  final Widget child;

  /// Whether a target that is out of view is scrolled into view automatically.
  ///
  /// Default `true`, because a tour that points at a control the user cannot
  /// see teaches nothing.
  final bool enableAutoScroll;

  /// Returns the showcase view of [scopeName], or `null` when it is not
  /// mounted.
  ///
  /// This is the supported way for the owner of a screen to start its own tour
  /// without holding the [ShowcaseView] in a field:
  ///
  /// ```dart
  /// final view = WelcomeShowcaseScope.viewForScope(myScopeName);
  /// view?.startShowCase(myKeys);
  /// ```
  ///
  /// Returns `null` instead of throwing when the scope is absent, so a Help
  /// action pressed on a screen whose scope is not mounted yet is a logged
  /// no-op rather than a crash.
  static ShowcaseView? viewForScope(String scopeName) {
    try {
      return ShowcaseView.getNamed(scopeName);
    } catch (_) {
      return null;
    }
  }

  @override
  State<WelcomeShowcaseScope> createState() => _WelcomeShowcaseScopeState();
}

class _WelcomeShowcaseScopeState extends State<WelcomeShowcaseScope> {
  /// Showcase controller of this scope, registered for the whole life of the
  /// state.
  late final ShowcaseView _showcaseView;

  /// App-wide coordinator of the guided tours.
  late final WelcomeTourController _tourController;

  @override
  void initState() {
    super.initState();

    // Registration first, so no `Showcase` target below can look for a scope
    // that does not exist yet and no tour can start against a missing scope.
    _showcaseView = ShowcaseView.register(
      scope: widget.scopeName,
      enableAutoScroll: widget.enableAutoScroll,
      // The overlay is built outside the screen widget tree, so the package
      // only adds semantic nodes when it is asked to. The welcome module ships
      // its own labels, this keeps the highlighted target reachable too.
      semanticEnable: true,
    );

    // The coordinator is registered above the whole app in main.dart, exactly
    // like for WelcomeScreen. A guide cannot run without it.
    _tourController = context.read<WelcomeTourController>();

    // Escape is handled outside the focus tree on purpose: a tour that can only
    // be left by clicking a button is a trap when the button is behind the
    // pointer or the screen has a focused text field.
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(covariant WelcomeShowcaseScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A target binds to the scope that is current when it is built, so
    // renaming a scope while it is mounted would orphan the targets.
    assert(
      oldWidget.scopeName == widget.scopeName,
      'The scope name of a WelcomeShowcaseScope cannot change while it is '
      'mounted, because the Showcase targets below are bound to it.',
    );

    // Auto scroll is a mutable setting of the view, so a rebuild with a
    // different value is applied without re-registering the scope.
    _showcaseView.enableAutoScroll = widget.enableAutoScroll;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);

    // Take the overlay down and close the tour as an interruption. Without
    // this the barrier of the overlay would stay in the root overlay and keep
    // eating every tap of the next screen.
    _dismiss(WelcomeTourEndReason.dismissed, deferTourEnd: true);

    try {
      // Removes the overlay of a running scope, unregisters the scope name and
      // stops every later start on this instance.
      _showcaseView.unregister();
    } catch (error, stackTrace) {
      // The package keeps its scope names in a stack and pops them by name, so
      // an unbalanced registration could make it throw here. Dispose must
      // never throw: a failing unregister would leave the overlay up.
      log.d(
        'Error unregistering the welcome showcase scope '
        '"${widget.scopeName}": $error',
        error,
        stackTrace,
      );
    }

    super.dispose();
  }

  /// Closes a running tour when Escape is pressed.
  ///
  /// Returns `true` only while this scope owns a running tour, so Escape keeps
  /// its normal meaning everywhere else in the app.
  ///
  /// The signature is the one of `HardwareKeyboard.addHandler`. Note that the
  /// framework invokes every handler regardless of the returned value and keeps
  /// delivering the event to the focused widget, so Escape closes the tour and
  /// can still reach a dialog or a text field that is focused underneath it.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!_showcaseView.isShowcaseRunning) return false;

    _dismiss(WelcomeTourEndReason.dismissed);
    return true;
  }

  /// Removes the overlay and closes the active tour as an interruption.
  ///
  /// [reason] is always [WelcomeTourEndReason.dismissed] today; the parameter
  /// exists so the intent is visible at every call site. A dismissal never
  /// writes a completion flag, so the tour is offered again later.
  ///
  /// [deferTourEnd] postpones the controller notification to a microtask. It is
  /// required on the disposal path: notifying listeners while the route tree is
  /// being unmounted would ask widgets that are already defunct to rebuild.
  void _dismiss(WelcomeTourEndReason reason, {bool deferTourEnd = false}) {
    if (_showcaseView.isShowcaseRunning) {
      // Removes the overlay, so the interaction barrier goes away immediately.
      _showcaseView.dismiss();
    }

    final activeTour = _tourController.activeTour;
    if (activeTour == null) return;

    if (deferTourEnd) {
      unawaited(
        Future<void>.microtask(
          () => _tourController.endIfActive(activeTour, reason),
        ),
      );
      return;
    }

    unawaited(_tourController.endIfActive(activeTour, reason));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
