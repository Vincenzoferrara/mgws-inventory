import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';

import '../home/home.gui.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'welcome.code.dart';
import 'welcome_tour_controller.dart';
import 'widgets/welcome_appearance_page.dart';
import 'widgets/welcome_language_page.dart';

/// First-run welcome flow of the app.
///
/// The flow explains what the app is for, then immediately guides the user
/// through real choices for language and appearance. It is driven by
/// `introduction_screen` and shows three pages in a fixed order:
///
/// 1. purpose of the app,
/// 2. language, applied immediately,
/// 3. appearance, entirely optional.
///
/// The language and appearance pages are real interactive widgets rather than
/// illustrations, so the choices are made on the same controls the settings use
/// and every change is visible on the page that is currently on screen.
///
/// The screen is expected to be pushed by the welcome gate as the
/// [WelcomeTourId.overview] tour. It never starts a tour by itself: the gate owns
/// the decision to show it and [WelcomeLogic] ends it.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  /// Rules of the flow, including the single completion and the navigation.
  late final WelcomeLogic _welcomeLogic;

  @override
  void initState() {
    super.initState();
    _welcomeLogic = WelcomeLogic(
      // read() on purpose: the coordinator is used for commands only, and
      // subscribing here would rebuild the whole flow on tour state changes.
      tourController: context.read<WelcomeTourController>(),
      openHome: _openHome,
    );
  }

  /// Replaces the welcome route with the home screen.
  ///
  /// `pushReplacement` instead of `push`, because Back from the home must not
  /// bring onboarding back on a route the user already completed.
  void _openHome() {
    // The call arrives after the asynchronous completion writes, so the route
    // may already be gone. Opening the home is the whole point of the flow, but
    // a dead context cannot push anything, so there is nothing to do.
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        // startGuidedLogin asks Home for the guided login right after the
        // welcome, so the user is not left on an empty authenticated screen.
        builder: (context) => const HomeScreen(startGuidedLogin: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // `introduction_screen` draws its Scaffold and buttons with the standalone
    // `material_ui` package, which never sees this app's Theme and falls back
    // to the default purple palette. Background and button labels are passed
    // explicitly so the flow follows the chosen colour and light/dark mode.
    final buttonLabel = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return IntroductionScreen(
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      // The two configurable pages are custom widgets, so every page is a raw
      // page: the package accepts either a list of PageViewModel or a list of
      // widgets, never a mix.
      rawPages: const [
        _WelcomePurposePage(),
        WelcomeLanguagePage(),
        WelcomeAppearancePage(),
      ],

      // Skip is offered on the first page and Back on every later one, which is
      // exactly what the package does with both flags enabled: the left slot
      // carries Skip on page one and Back afterwards.
      showSkipButton: true,
      showBackButton: true,
      skip: Text(l10n.welcomeSkip, style: buttonLabel),
      back: Text(l10n.welcomeBack, style: buttonLabel),
      next: Text(l10n.welcomeNext, style: buttonLabel),
      done: Text(l10n.welcomeStart, style: buttonLabel),

      // The package exposes one semantic label per action, so every action of
      // the flow is announced with a sentence instead of the bare label.
      skipSemantic: l10n.welcomeSkipSemantic,
      backSemantic: l10n.welcomeBackSemantic,
      nextSemantic: l10n.welcomeNextSemantic,
      doneSemantic: l10n.welcomeStartSemantic,
      progressSemantic: (current, total) =>
          l10n.welcomeProgressSemantic(current, total),

      // Nothing on these pages is required, so both actions end the flow the
      // same way: the welcome is recorded and the app opens.
      onDone: () => _welcomeLogic.completeOverview(),
      onSkip: () => _welcomeLogic.skipOverview(),

      dotsDecorator: DotsDecorator(
        color: context.colors.subtitleColor.withValues(alpha: 0.35),
        activeColor: theme.primaryColor,
      ),
    );
  }
}

/// First welcome page: what the app is for.
///
/// Copy only, on purpose: the page introduces the purpose of the app and names
/// the areas it covers without pretending to show them.
class _WelcomePurposePage extends StatelessWidget {
  const _WelcomePurposePage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _WelcomeCopyPage(
      icon: Icons.storefront,
      title: l10n.welcomePurposeTitle,
      body: l10n.welcomePurposeBody,
      points: [
        (icon: Icons.checkroom, text: l10n.welcomePurposePointCatalogue),
        (icon: Icons.inventory_2, text: l10n.welcomePurposePointStock),
        (icon: Icons.point_of_sale, text: l10n.welcomePurposePointTill),
      ],
    );
  }
}

/// Layout of the pages that only carry explanatory copy.
///
/// The bottom padding leaves room for the navigation bar of the welcome flow,
/// which the package draws over the page instead of reserving space for it.
class _WelcomeCopyPage extends StatelessWidget {
  const _WelcomeCopyPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<({IconData icon, String text})> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The transparent Material is required, not decoration: the pages of
    // `introduction_screen` live inside the standalone `material_ui` package,
    // whose `Material` class is not the one Flutter widgets look up.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 104),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: context.shapes.xl,
                        ),
                        child: Icon(icon, size: 42, color: theme.primaryColor),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.subtitleColor,
                  ),
                ),
                const SizedBox(height: 28),
                for (final point in points) ...[
                  _WelcomePointRow(icon: point.icon, text: point.text),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One explanatory point of a copy page: an icon, the text and a divider line.
class _WelcomePointRow extends StatelessWidget {
  const _WelcomePointRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: context.shapes.s,
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
