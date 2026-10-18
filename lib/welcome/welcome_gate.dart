import 'package:flutter/material.dart';

import '../home/home.gui.dart';
import '../log_viewer/app_logger.dart';
import 'welcome.gui.dart';
import 'welcome_preferences.dart';
import 'welcome_tour_ids.dart';

/// Where the startup decision currently points.
///
/// The gate starts on [loading] so the home is never built before the
/// persisted state is known: a synchronous `false` first frame would show the
/// home for one frame and then replace it with the welcome, which reads as a
/// flash of a screen the user must not see yet.
enum _WelcomeGateTarget {
  /// The persisted state is still being read.
  loading,

  /// The overview has not been seen yet, so the welcome flow is the entry point.
  welcome,

  /// The overview is already done, so the app opens on the home.
  home,
}

/// Startup decision between the first-run welcome flow and the home screen.
///
/// This widget is the `home` of the app and owns one question: has the user
/// already seen the overview? The answer is read exactly once, in
/// [initState], from [WelcomePreferences] under the versioned
/// [WelcomeTourId.overview] key.
///
/// Three rules drive the implementation:
///
/// - The read happens once and only once. Re-reading it on every rebuild would
///   make the entry point depend on a platform channel round trip each time
///   something rebuilds the subtree, and could switch screens under the user.
/// - While the read is in flight the gate shows a neutral loading scaffold, so
///   [HomeScreen] is never built and never flashes before the welcome.
/// - Every failure resolves to the welcome. An unreadable state must replay
///   onboarding instead of silently bypassing it, which is also what
///   [WelcomePreferences.isCompleted] does; the guard here makes sure the gate
///   itself can never be the reason onboarding is skipped, for example if the
///   store throws for a reason it does not know about yet.
///
/// The gate does not start the overview as a tour: showing the welcome pages
/// and persisting the outcome belong to [WelcomeLogic], through the actions of
/// [WelcomeScreen]. The gate only decides which screen the app starts on.
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  /// Versioned local store of the tour completion flags.
  ///
  /// A standalone store is enough here: [WelcomePreferences] resolves the
  /// shared `SharedPreferences` instance lazily and reads the same
  /// `welcome.v1.*` keys, so the gate observes the flag that [WelcomeLogic]
  /// writes without the widget tree having to expose the store.
  final WelcomePreferences _preferences = WelcomePreferences();

  /// Entry point resolved so far.
  _WelcomeGateTarget _target = _WelcomeGateTarget.loading;

  @override
  void initState() {
    super.initState();
    _resolveTarget();
  }

  /// Reads the overview flag once and moves to the resulting screen.
  ///
  /// The result is applied only while the gate is still mounted: the read
  /// crosses a platform channel, so the widget can be disposed in between, and
  /// calling `setState` after that would throw.
  Future<void> _resolveTarget() async {
    // Fail-safe default: onboarding stays the entry point until the read proves
    // the user already saw the overview.
    var showWelcome = true;

    try {
      final isCompleted = await _preferences.isCompleted(
        WelcomeTourId.overview,
      );
      showWelcome = !isCompleted;
    } catch (error, stackTrace) {
      // Never reached through WelcomePreferences, which swallows its own
      // failures, but a gate that could throw here would leave the app on the
      // loading scaffold forever. Log it and show the welcome.
      log.d(
        'Error reading the welcome overview state: $error',
        error,
        stackTrace,
      );
      showWelcome = true;
    }

    if (!mounted) return;

    setState(() {
      _target = showWelcome
          ? _WelcomeGateTarget.welcome
          : _WelcomeGateTarget.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_target) {
      _WelcomeGateTarget.welcome => const WelcomeScreen(),
      _WelcomeGateTarget.home => const HomeScreen(),
      // Neutral on purpose: no title, no message and no action, only the wait
      // for the decision, so nothing here can be mistaken for a real screen.
      _WelcomeGateTarget.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
