import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

class ShortcutsSettingsTab extends StatelessWidget {
  const ShortcutsSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return ListView(
          padding: context.spacing.iL,
          children: [
            Text(
              context.l10n.settingsShortcutsTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _ShortcutField(
              label: context.l10n.settingsShortcutToggleEdit,
              value: settings.shortcutToggleEdit,
              onSave: settings.setShortcutToggleEdit,
            ),
            _ShortcutField(
              label: context.l10n.commonSave,
              value: settings.shortcutSave,
              onSave: settings.setShortcutSave,
            ),
            _ShortcutField(
              label: context.l10n.settingsShortcutSelectAll,
              value: settings.shortcutSelectAll,
              onSave: settings.setShortcutSelectAll,
            ),
            _ShortcutField(
              label: context.l10n.settingsShortcutDelete,
              value: settings.shortcutDelete,
              onSave: settings.setShortcutDelete,
            ),
            _ShortcutField(
              label: context.l10n.settingsShortcutEscape,
              value: settings.shortcutEscape,
              onSave: settings.setShortcutEscape,
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                title: Text(context.l10n.settingsForceDelete),
                subtitle: Text(context.l10n.settingsForceDeleteDescription),
                value: settings.forceDelete,
                onChanged: (v) => settings.setForceDelete(v),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: settings.resetShortcutsToDefault,
                icon: const Icon(Icons.restart_alt),
                label: Text(context.l10n.settingsShortcutsReset),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShortcutField extends StatefulWidget {
  final String label;
  final String value;
  final Future<void> Function(String value) onSave;

  const _ShortcutField({
    required this.label,
    required this.value,
    required this.onSave,
  });

  @override
  State<_ShortcutField> createState() => _ShortcutFieldState();
}

class _ShortcutFieldState extends State<_ShortcutField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ShortcutField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.label),
        subtitle: TextField(
          controller: _controller,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.l10n.settingsShortcutHint,
          ),
          onSubmitted: (value) => widget.onSave(value),
        ),
        trailing: IconButton(
          onPressed: () => widget.onSave(_controller.text),
          icon: const Icon(Icons.save_outlined),
          tooltip: context.l10n.settingsShortcutSaveTooltip,
        ),
      ),
    );
  }
}
