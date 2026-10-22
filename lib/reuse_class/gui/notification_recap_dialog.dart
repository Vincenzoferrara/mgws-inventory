import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/extensions.dart';

/// Recap uniforme per tutte le operazioni persistenti.
///
/// Le API [delete] ed [edit] definiscono titoli, testi e bottoni standard.
/// Il chiamante fornisce esclusivamente gli elementi coinvolti e, quando
/// serve, la specifica chiamata dati da eseguire dopo la conferma.
class NotificationRecapDialog {
  NotificationRecapDialog._();

  static Future<bool> delete<T>(
    BuildContext context, {
    required Iterable<T> items,
    required String Function(T item) itemLabel,
    required bool isDestructive,
  }) {
    final labels = items.map(itemLabel).toList(growable: false);
    final isBulk = labels.length > 1;
    final l10n = context.l10n;
    return _show(
      context,
      title: isBulk
          ? l10n.sharedRecapDeleteBulkTitle
          : l10n.sharedRecapDeleteTitle,
      summary: isBulk
          ? l10n.sharedRecapDeleteBulkSummary(labels.length)
          : l10n.sharedRecapDeleteSummary,
      changes: labels,
      confirmLabel: l10n.commonDelete,
      isDestructive: isDestructive,
    );
  }

  static Future<bool> edit(
    BuildContext context, {
    required Iterable<String> changes,
    required int affectedItemsCount,
    Iterable<String> missingFields = const <String>[],
    Iterable<String> blockingMissingFields = const <String>[],
    bool isDestructive = false,
  }) {
    final isBulk = affectedItemsCount > 1;
    final l10n = context.l10n;
    return _show(
      context,
      title: isBulk ? l10n.sharedRecapEditBulkTitle : l10n.sharedRecapEditTitle,
      summary: isBulk
          ? l10n.sharedRecapEditBulkSummary(affectedItemsCount)
          : l10n.sharedRecapEditSummary,
      changes: changes.toList(growable: false),
      missingFields: missingFields.toList(growable: false),
      blockingMissingFields: blockingMissingFields.toList(growable: false),
      confirmLabel: isBulk
          ? l10n.sharedRecapApplyMany
          : l10n.sharedRecapApplyOne,
      isDestructive: isDestructive,
    );
  }

  static Future<bool> _show(
    BuildContext context, {
    required String title,
    required String summary,
    required List<String> changes,
    List<String> missingFields = const <String>[],
    List<String> blockingMissingFields = const <String>[],
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final hasBlocking = blockingMissingFields.isNotEmpty;
    final recapText = _buildRecapText(
      context.l10n,
      title: title,
      summary: summary,
      changes: changes,
      missingFields: missingFields,
      blockingMissingFields: blockingMissingFields,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: SelectableText(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(summary),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (changes.isNotEmpty) ...[
                        Text(
                          dialogContext.l10n.sharedRecapNewValues,
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        ...changes.map(
                          (change) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SelectableText('• $change'),
                          ),
                        ),
                      ],
                      if (blockingMissingFields.isNotEmpty ||
                          missingFields.isNotEmpty) ...[
                        if (changes.isNotEmpty) const SizedBox(height: 12),
                        Text(
                          dialogContext.l10n.sharedCampiMancanti,
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        if (blockingMissingFields.isNotEmpty) ...[
                          Text(
                            dialogContext.l10n.sharedDaCorreggerePrima,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...blockingMissingFields.map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText('• $field'),
                            ),
                          ),
                        ],
                        if (missingFields.isNotEmpty) ...[
                          if (blockingMissingFields.isNotEmpty)
                            const SizedBox(height: 8),
                          SelectableText(dialogContext.l10n.sharedAvvisi),
                          const SizedBox(height: 4),
                          ...missingFields.map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText('• $field'),
                            ),
                          ),
                        ],
                      ],
                      if (changes.isEmpty &&
                          missingFields.isEmpty &&
                          blockingMissingFields.isEmpty)
                        SelectableText(
                          dialogContext.l10n.sharedNessunaModifica,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recapText));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(context.l10n.sharedRecapCopiato)),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(context.l10n.sharedCopia),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          if (!hasBlocking)
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.sharedCorreggi),
            ),
        ],
      ),
    );
    return confirmed == true;
  }

  static String _buildRecapText(
    AppLocalizations l10n, {
    required String title,
    required String summary,
    required List<String> changes,
    required List<String> missingFields,
    required List<String> blockingMissingFields,
  }) {
    final lines = <String>[title, summary];
    if (changes.isNotEmpty) {
      lines
        ..add('')
        ..add(l10n.sharedRecapNewValues)
        ..addAll(changes.map((change) => '- $change'));
    }
    if (blockingMissingFields.isNotEmpty || missingFields.isNotEmpty) {
      lines
        ..add('')
        ..add(l10n.sharedCampiMancanti);
      if (blockingMissingFields.isNotEmpty) {
        lines
          ..add(l10n.sharedDaCorreggerePrima)
          ..addAll(blockingMissingFields.map((field) => '- $field'));
      }
      if (missingFields.isNotEmpty) {
        lines
          ..add(l10n.sharedAvvisi)
          ..addAll(missingFields.map((field) => '- $field'));
      }
    }
    if (changes.isEmpty &&
        missingFields.isEmpty &&
        blockingMissingFields.isEmpty) {
      lines
        ..add('')
        ..add(l10n.sharedRecapNoChange);
    }
    return lines.join('\n');
  }
}
