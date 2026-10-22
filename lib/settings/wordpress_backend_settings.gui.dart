import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../l10n/extensions.dart';

class WordPressBackendSettingsTab extends StatelessWidget {
  const WordPressBackendSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: context.spacing.iL,
      children: [
        Text(
          context.l10n.settingsWordpressBackendTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(context.l10n.settingsWordpressBackendDescription),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.settingsWordpressBackendTileTitle),
          subtitle: Text(context.l10n.settingsWordpressBackendTileSubtitle),
        ),
        Card(
          child: Padding(
            padding: context.spacing.iM,
            child: Text(context.l10n.settingsWordpressBackendStatus),
          ),
        ),
      ],
    );
  }
}
