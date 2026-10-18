import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../traduzioni/estensioni.dart';

/// Shared layout of the welcome pages that offer a set of options.
///
/// The language page, the appearance page and the welcome itself all present
/// the same shape: an icon, a title, an explanation and a list of choices. Only
/// the options change, so the frame lives here instead of being repeated in
/// every page.
///
/// The column is scrollable because the option list plus the header can exceed
/// the height of a phone once the navigation bar of the welcome flow is
/// accounted for. The bottom padding leaves room for that navigation bar.
class WelcomePageFrame extends StatelessWidget {
  const WelcomePageFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.children,
  });

  /// Icon shown above the title.
  final IconData icon;

  /// Page title, already localized by the caller.
  final String title;

  /// Short explanation under the title, already localized by the caller.
  final String body;

  /// The options of this page.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // The transparent Material is not decoration: it is required.
    //
    // `introduction_screen` renders its pages inside the standalone
    // `material_ui` package, which ships its own `Material` class. A Flutter
    // `InkWell` looks up a Flutter `Material` ancestor and does not accept the
    // one from that package, so every option row here would throw
    // "No Material widget found" without this. The frame supplies the Flutter
    // ancestor for all the pages built on it.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 104),
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
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: context.shapes.xl,
                        ),
                        child: Icon(icon, size: 34, color: theme.primaryColor),
                      ),
                      const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.subtitleColor,
                  ),
                ),
                const SizedBox(height: 24),
                ...children,
                // The note repeats that nothing here is required: it is the
                // reason the Next action stays enabled with no selection at
                // all.
                Text(
                  l10n.welcomeOptionalNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
