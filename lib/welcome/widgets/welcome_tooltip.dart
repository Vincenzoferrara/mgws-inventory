import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/theme.dart';
import '../../l10n/extensions.dart';
import '../welcome_tour_controller.dart';
import '../welcome_tour_ids.dart';

/// Tooltip of a single step of a contextual guided tour.
///
/// The widget is passed as the custom tooltip of a `Showcase`, so every step of
/// every tour looks and behaves the same:
///
/// - the step title, the step body and a "Step X of Y" progress line,
/// - **Skip** on the left, which closes the whole tour as a deliberate user
///   outcome,
/// - **Back**, hidden on the first step because there is nothing to go back to,
/// - **Next**, which becomes **Finish** on the last step.
///
/// ## Who decides what an action means
///
/// Moving the overlay belongs to the screen that owns the targets, so [onNext],
/// [onBack], [onSkip] and [onDone] only drive the overlay. The *persisted
/// outcome* belongs here, and it always goes through
/// [WelcomeTourController.endIfActive], never through a bare `end`:
///
/// - **Finish** records [WelcomeTourEndReason.finished],
/// - **Skip** records [WelcomeTourEndReason.skipped],
/// - Escape and route disposal record nothing: they are handled by the showcase
///   scope, which closes the tour with [WelcomeTourEndReason.dismissed].
///
/// `endIfActive` also checks that [tourId] is really the tour on screen, so a
/// late tap cannot mark a different tour complete.
class WelcomeTooltip extends StatelessWidget {
  const WelcomeTooltip({
    super.key,
    required this.tourId,
    required this.title,
    required this.description,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onDone,
  });

  /// Tour this step belongs to, used to guard the completion writes.
  final WelcomeTourId tourId;

  /// Step title, already localized by the caller.
  final String title;

  /// Step body, already localized by the caller.
  final String description;

  /// Position of this step, starting at one.
  final int stepNumber;

  /// Total number of steps of the tour.
  final int totalSteps;

  /// Advances one step.
  final VoidCallback onNext;

  /// Returns to the previous step.
  final VoidCallback onBack;

  /// Closes the whole tour.
  final VoidCallback onSkip;

  /// Closes the tour after the last step.
  final VoidCallback onDone;

  /// Whether this is the last step, where the primary action becomes Finish.
  bool get _isLastStep => stepNumber >= totalSteps;

  /// Whether this is the first step, where Back has nothing to go back to.
  bool get _isFirstStep => stepNumber <= 1;

  /// Records the deliberate skip and then lets the caller close the overlay.
  ///
  /// The write happens before the overlay goes away: a tour that disappears
  /// before its outcome is stored could lose the skip to a fast second press on
  /// another Help button.
  Future<void> _skip(BuildContext context) async {
    await _recordOutcome(context, WelcomeTourEndReason.skipped);
    onSkip();
  }

  /// Records the deliberate completion and then closes the overlay.
  Future<void> _finish(BuildContext context) async {
    await _recordOutcome(context, WelcomeTourEndReason.finished);
    onDone();
  }

  /// Persists the outcome of [tourId] through the app-wide coordinator.
  ///
  /// Only [WelcomeTourEndReason.finished] and [WelcomeTourEndReason.skipped]
  /// write a completion flag, so an interrupted tour is still offered by the
  /// next automatic start. The flag is written by the coordinator itself: the
  /// tooltip never touches the preference store directly.
  Future<void> _recordOutcome(
    BuildContext context,
    WelcomeTourEndReason reason,
  ) {
    final controller = context.read<WelcomeTourController>();
    return controller.endIfActive(tourId, reason);
  }

  /// Press handler of the primary action: Finish on the last step, Next on
  /// every other one.
  void _handlePrimaryPressed(BuildContext context) {
    if (_isLastStep) {
      unawaited(_finish(context));
      return;
    }
    onNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isLastStep = _isLastStep;

    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        // The package sizes the tooltip from the intrinsic width of its
        // content, so this constraint is what keeps a long step from becoming
        // one very wide line and a short one from collapsing.
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: context.spacing.iL,
          decoration: BoxDecoration(
            // colorScheme.surface follows the light and dark themes, so the
            // tooltip stays readable in both.
            color: theme.colorScheme.surface,
            borderRadius: context.shapes.m,
            border: Border.all(color: context.colors.dividerColor),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.colors.subtitleColor,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                // The visible line reads "Step 2 of 5"; the semantic node says
                // the same as a sentence, and the visible text is excluded so a
                // screen reader does not announce it a second time.
                label: l10n.welcomeProgressSemantic(stepNumber, totalSteps),
                child: ExcludeSemantics(
                  child: Text(
                    l10n.welcomeStepOf(stepNumber, totalSteps),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Flexible children keep a long translation from overflowing the
              // tooltip instead of stretching it.
              Row(
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: l10n.welcomeTourSkipSemantic,
                        child: TextButton(
                          onPressed: () => unawaited(_skip(context)),
                          child: _ActionLabel(l10n.welcomeSkip),
                        ),
                      ),
                    ),
                  ),
                  if (!_isFirstStep) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: l10n.welcomeTourBackSemantic,
                          child: TextButton(
                            onPressed: onBack,
                            child: _ActionLabel(l10n.welcomeBack),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        button: true,
                        label: isLastStep
                            ? l10n.welcomeTourFinishSemantic
                            : l10n.welcomeTourNextSemantic,
                        child: ElevatedButton(
                          onPressed: () => _handlePrimaryPressed(context),
                          child: _ActionLabel(
                            isLastStep
                                ? l10n.welcomeTourFinish
                                : l10n.welcomeNext,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-line label of a tooltip action.
///
/// The ellipsis keeps an unexpectedly long translation inside the button
/// instead of overflowing the tooltip, which the package lays out against the
/// available screen width.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
