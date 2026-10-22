import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../../settings/theme/theme_settings.dart';
import '../../theme/theme.dart';
import '../../l10n/extensions.dart';
import 'welcome_page_frame.dart';

/// Fourth welcome page: the appearance of the app.
///
/// The page reuses the visual language of the existing appearance settings, the
/// same coloured options, the same colour picker dialog and the same switch,
/// so what the user sees here is what the settings screen does afterwards.
///
/// Every field is optional and no field is enabled on its own. The page only
/// reads the current [ThemeSettings] state and writes it back through the same
/// setters, which means leaving the page untouched changes nothing at all and
/// the Next action stays enabled.
class WelcomeAppearancePage extends StatelessWidget {
  const WelcomeAppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // watch() rebuilds the page on every theme change, so a tap is reflected
    // immediately both in the selection and in the colours of this page.
    final themeSettings = context.watch<ThemeSettings>();
    final primaryColor = themeSettings.primaryColor;

    return WelcomePageFrame(
      icon: Icons.palette_outlined,
      title: l10n.welcomeAppearanceTitle,
      body: l10n.welcomeAppearanceBody,
      children: [
        _WelcomeSectionLabel(label: l10n.welcomeAppearancePrimaryColor),
        const SizedBox(height: 8),
        _WelcomeColorRow(
          label: l10n.welcomeAppearancePrimaryColor,
          currentColor: primaryColor,
          onColorSelected: themeSettings.setPrimaryColor,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: themeSettings.resetColor,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.welcomeAppearanceResetColor),
          style: OutlinedButton.styleFrom(foregroundColor: primaryColor),
        ),
        const SizedBox(height: 28),
        _WelcomeSectionLabel(label: l10n.welcomeAppearanceThemeMode),
        const SizedBox(height: 8),
        _WelcomeModeOption(
          title: l10n.welcomeAppearanceModeLight,
          subtitle: l10n.welcomeAppearanceModeLightDescription,
          icon: Icons.wb_sunny,
          mode: ThemeMode.light,
          themeSettings: themeSettings,
        ),
        const SizedBox(height: 12),
        _WelcomeModeOption(
          title: l10n.welcomeAppearanceModeDark,
          subtitle: l10n.welcomeAppearanceModeDarkDescription,
          icon: Icons.nightlight_round,
          mode: ThemeMode.dark,
          themeSettings: themeSettings,
        ),
        const SizedBox(height: 12),
        _WelcomeModeOption(
          title: l10n.welcomeAppearanceModeSystem,
          subtitle: l10n.welcomeAppearanceModeSystemDescription,
          icon: Icons.settings_system_daydream,
          mode: ThemeMode.system,
          themeSettings: themeSettings,
        ),
        const SizedBox(height: 28),
        _WelcomeSectionLabel(label: l10n.welcomeAppearanceBackground),
        const SizedBox(height: 8),
        SwitchListTile(
          value: themeSettings.backgroundFollowsTheme,
          onChanged: themeSettings.setBackgroundFollowsTheme,
          title: Text(l10n.welcomeAppearanceBackgroundFollowsTheme),
          subtitle: Text(
            l10n.welcomeAppearanceBackgroundFollowsThemeDescription,
          ),
          secondary: Icon(Icons.gradient, color: primaryColor),
          activeThumbColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: context.shapes.s,
            side: BorderSide(color: context.colors.dividerColor),
          ),
        ),
      ],
    );
  }
}

/// Label of one group of appearance options.
class _WelcomeSectionLabel extends StatelessWidget {
  const _WelcomeSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// One selectable theme mode, styled like the appearance options of the
/// settings: the whole row is the tap target and the active one is outlined
/// and carries a check mark.
class _WelcomeModeOption extends StatelessWidget {
  const _WelcomeModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.themeSettings,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final ThemeSettings themeSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final primaryColor = themeSettings.primaryColor;
    final isSelected = themeSettings.themeMode == mode;

    return Semantics(
      selected: isSelected,
      label: title,
      hint: subtitle,
      child: InkWell(
        onTap: () => themeSettings.setThemeMode(mode),
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
                icon,
                color: isSelected ? primaryColor : context.colors.subtitleColor,
                size: 32,
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
                    Text(
                      subtitle,
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

/// Row that shows the current primary colour and opens the colour picker.
class _WelcomeColorRow extends StatelessWidget {
  const _WelcomeColorRow({
    required this.label,
    required this.currentColor,
    required this.onColorSelected,
  });

  final String label;
  final Color currentColor;
  final Future<void> Function(Color) onColorSelected;

  /// Hexadecimal form of [color], shown so the exact colour is readable.
  String get _hexValue =>
      '#${currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      value: _hexValue,
      button: true,
      child: InkWell(
        onTap: () => _showColorPickerDialog(context),
        borderRadius: context.shapes.s,
        child: Container(
          padding: context.spacing.iL,
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.dividerColor),
            borderRadius: context.shapes.s,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: context.shapes.s,
                  border: Border.all(
                    color: context.colors.dividerColor,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _hexValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: context.colors.subtitleColor,
                  ),
                ),
              ),
              Icon(Icons.color_lens, color: theme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the shared colour picker dialog.
  ///
  /// The chosen colour is applied only on confirmation, so the theme does not
  /// change while the user is still moving around in the picker. The dialog is
  /// the same one the appearance settings use, on purpose: the user does not
  /// have to learn two different pickers.
  Future<void> _showColorPickerDialog(BuildContext context) async {
    Color pickerColor = currentColor;
    final hexController = TextEditingController(text: _hexValue);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.l10n.welcomeAppearancePickColor),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (color) {
                    setDialogState(() {
                      pickerColor = color.withValues(alpha: 1);
                    });
                  },
                  enableAlpha: false,
                  displayThumbColor: true,
                  portraitOnly: true,
                  paletteType: PaletteType.hsvWithHue,
                  pickerAreaBorderRadius: context.shapes.s,
                  labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
                  hexInputBar: true,
                  hexInputController: hexController,
                  colorPickerWidth: 320,
                  pickerAreaHeightPercent: 0.8,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonAnnulla),
                ),
                ElevatedButton(
                  onPressed: () {
                    onColorSelected(pickerColor);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(context.l10n.commonConfirm),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      hexController.dispose();
    }
  }
}
