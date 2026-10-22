import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/theme.dart';
import '../../l10n/extensions.dart';
import 'welcome_page_frame.dart';
import '../../l10n/locale_settings.dart';

/// Third welcome page: the language of the interface.
///
/// The page offers the three choices the app can actually run with, the system
/// language and the two supported locales, and applies every tap immediately
/// through [LocaleSettings.impostaLingua]. Nothing else is configurable here,
/// and no choice is required: the current language stays valid, so the user can
/// continue without touching anything.
///
/// Reading the locale from the widget that is on screen is what re-renders this
/// page in the new language as soon as the change is applied, instead of waiting
/// for the next page.
class WelcomeLanguagePage extends StatelessWidget {
  const WelcomeLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // watch() rebuilds the page when the language changes, so the option that
    // is now active and the text just switched language are both up to date.
    final localeSettings = context.watch<LocaleSettings>();

    return WelcomePageFrame(
      icon: Icons.translate,
      title: l10n.welcomeLanguageTitle,
      body: l10n.welcomeLanguageBody,
      children: [
        // The system option passes LocaleSettings.sistema, which is null: that
        // is how the app is told to follow the operating system again.
        _WelcomeLanguageOption(
          title: l10n.welcomeLanguageSystem,
          subtitle: l10n.welcomeLanguageSystemDescription(
            localeSettings.nomeLinguaAttiva,
          ),
          isSelected: localeSettings.segueSistema,
          onTap: () => localeSettings.impostaLingua(LocaleSettings.sistema),
        ),
        const SizedBox(height: 12),
        for (final locale in LocaleSettings.supportate) ...[
          _WelcomeLanguageOption(
            // Native names, exactly like the settings selector: the user
            // recognises the language even without reading it.
            title:
                LocaleSettings.nomiNativi[locale.languageCode] ??
                locale.languageCode,
            isSelected: localeSettings.lingua == locale,
            onTap: () => localeSettings.impostaLingua(locale),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One selectable language, styled like the appearance options of the settings.
///
/// The whole row is the tap target and carries the check mark of the active
/// choice, so the state is readable without relying on the border alone.
class _WelcomeLanguageOption extends StatelessWidget {
  const _WelcomeLanguageOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final primaryColor = theme.primaryColor;

    return Semantics(
      selected: isSelected,
      label: title,
      hint: subtitle,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.shapes.s,
        child: Container(
          padding: context.spacing.iL,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? primaryColor : context.colors.dividerColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: context.shapes.s,
            color: isSelected
                ? primaryColor.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.language,
                color: isSelected ? primaryColor : context.colors.subtitleColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? primaryColor : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colors.subtitleColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Semantics(
                  label: l10n.welcomeSelected,
                  child: Icon(Icons.check_circle, color: primaryColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
