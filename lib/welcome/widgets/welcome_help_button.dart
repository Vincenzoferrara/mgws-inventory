import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../traduzioni/estensioni.dart';
import '../welcome_tour_controller.dart';
import '../welcome_tour_ids.dart';

/// Button that replays the guided tour of the screen it is placed on.
///
/// This is the manual entry point the user was missing: every screen that ships
/// a tour exposes one of these, so a guide can always be seen again, even after
/// it was completed or skipped and even when it never started by itself.
///
/// The button is deliberately dumb about tours:
///
/// - It starts **only** [tourId], never a global chain. Which targets are shown
///   and in which order belongs to the screen, which decides that in [onStart].
/// - It replays unconditionally. The completion flag is not consulted: a Help
///   action always shows the guide again, which is exactly what the user asked
///   for by pressing it.
/// - It is a visible, labelled control, not a hidden gesture, and it carries a
///   semantic label so a screen reader announces what it does.
///
/// ## What the press does, in order
///
/// 1. Publishes [tourId] with [WelcomeTourController.requestManualStart], so a
///    screen that is not the owner of the tour (for example a list in Settings)
///    can hand the request over through the coordinator.
/// 2. Calls [onStart], which the owner wires to
///    `begin(..., mode: manual)` plus `ShowcaseView.startShowCase(...)`.
/// 3. Takes the published request back when [onStart] already started this
///    tour. The pending slot is single shot, so leaving it filled would make
///    some later rebuild consume it and replay the tour a second time.
///
/// The controller is read with a nullable type, so the button also works in a
/// preview or in a screen mounted outside the app providers: in that case only
/// [onStart] runs.
class WelcomeHelpButton extends StatelessWidget {
  const WelcomeHelpButton({
    super.key,
    required this.tourId,
    required this.onStart,
  });

  /// Tour of this screen, the only one this button can replay.
  final WelcomeTourId tourId;

  /// Starts the tour of this screen.
  ///
  /// Expected to start it synchronously, so the button can withdraw the
  /// published request in step 3. An [onStart] that starts the tour later, after
  /// an await, leaves the request pending for whoever consumes it.
  final VoidCallback onStart;

  void _handlePressed(BuildContext context) {
    // Nullable read on purpose: a missing coordinator must not turn a Help
    // button into a crash.
    final controller = context.read<WelcomeTourController?>();

    controller?.requestManualStart(tourId);
    onStart();

    // The owner of the tour usually starts it right away. In that case the
    // published request is already satisfied, so it is withdrawn here: it is a
    // single pending slot and leaving it filled would let any later rebuild
    // treat it as a new request.
    if (controller?.activeTour == tourId) {
      controller?.takeManualStartRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final primaryColor = theme.primaryColor;

    return Semantics(
      button: true,
      label: l10n.welcomeHelpButtonSemantic,
      child: TextButton.icon(
        onPressed: () => _handlePressed(context),
        icon: const Icon(Icons.help_outline),
        label: Text(l10n.welcomeHelpButton),
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          // The label carries the meaning, so the icon only repeats it: an icon
          // tinted with the primary colour on a light surface would drop below
          // the contrast ratio.
          iconColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // Keeps the touch target usable on a phone without making the
          // control dominate an AppBar on a desktop layout.
          minimumSize: const Size(48, 40),
        ),
      ),
    );
  }
}
