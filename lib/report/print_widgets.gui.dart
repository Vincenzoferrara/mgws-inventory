import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_library.dart';
import 'print_preview.gui.dart';
import 'print_template.dart';

/// Every template on one screen, grouped by category: each group has its
/// title and a dividing line. Templates without a category close the list.
class PrintTemplateGroups extends StatelessWidget {
  const PrintTemplateGroups({
    super.key,
    required this.library,
    required this.onTap,
    this.where,
    this.showEmptyCategories = false,
    this.cardMenu,
    this.categoryActions,
    this.emptyText,
  });

  final PrintLibrary library;
  final ValueChanged<PrintTemplate> onTap;
  final bool Function(PrintTemplate template)? where;
  final bool showEmptyCategories;
  final Widget Function(PrintTemplate template)? cardMenu;
  final Widget Function(PrintCategory category)? categoryActions;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = library
        .grouped(where: where)
        .where(
          (group) =>
              group.templates.isNotEmpty ||
              (showEmptyCategories && group.category != null),
        );
    if (groups.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xxl),
        child: Center(
          child: Text(
            emptyText ?? l10n.reportNoTemplates,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.subtitleColor,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          SizedBox(height: context.spacing.l),
          Row(
            children: [
              Expanded(
                child: Text(
                  group.category?.name ?? l10n.reportNoCategory,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (group.category != null && categoryActions != null)
                categoryActions!(group.category!),
            ],
          ),
          const Divider(height: 16),
          if (group.templates.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: context.spacing.s),
              child: Text(
                l10n.reportEmptyCategory,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.subtitleColor,
                ),
              ),
            )
          else
            _TemplateGrid(
              templates: group.templates,
              library: library,
              onTap: onTap,
              cardMenu: cardMenu,
            ),
        ],
      ],
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({
    required this.templates,
    required this.library,
    required this.onTap,
    this.cardMenu,
  });

  final List<PrintTemplate> templates;
  final PrintLibrary library;
  final ValueChanged<PrintTemplate> onTap;
  final Widget Function(PrintTemplate template)? cardMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing.m;
        final columns = (constraints.maxWidth / 230).floor().clamp(2, 6);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final template in templates)
              SizedBox(
                width: width,
                child: PrintTemplateCard(
                  template: template,
                  paper: library.paperFormatOf(template),
                  onTap: () => onTap(template),
                  menu: cardMenu?.call(template),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Preview, name and paper format of a template.
class PrintTemplateCard extends StatelessWidget {
  const PrintTemplateCard({
    super.key,
    required this.template,
    required this.paper,
    required this.onTap,
    this.menu,
  });

  final PrintTemplate template;
  final PaperFormat paper;
  final VoidCallback onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              color: context.theme.colorScheme.surfaceContainerHighest,
              padding: context.spacing.iM,
              child: PrintTemplateThumbnail(template: template),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.m,
                context.spacing.s,
                context.spacing.xs,
                context.spacing.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: context.spacing.xs),
                        Text(
                          '${kindLabel(l10n, template.kind)} · ${paper.displayName(l10n)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?menu,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String kindLabel(AppLocalizations l10n, PrintTemplateKind kind) =>
    switch (kind) {
      PrintTemplateKind.productLabel => l10n.reportKindLabelsTitle,
      PrintTemplateKind.shopSign => l10n.reportKindSignsTitle,
      PrintTemplateKind.report => l10n.reportKindReportsTitle,
    };

class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(top: context.spacing.m),
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: context.theme.colorScheme.primary),
                SizedBox(width: context.spacing.s),
                Expanded(
                  child: Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.m),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Container(
      padding: context.spacing.iM,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: context.shapes.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onPrimaryContainer),
          SizedBox(width: context.spacing.s),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.theme.dividerColor),
        borderRadius: context.shapes.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.reportDecrease,
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.reportIncrease,
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Paper formats of one kind, sheets and rolls listed separately.
class PaperPicker extends StatelessWidget {
  const PaperPicker({
    super.key,
    required this.formats,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PaperFormat> formats;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (formats.isEmpty) {
      return Text(l10n.reportPaperMissing, style: context.text.bodyMedium);
    }
    final sheets = formats
        .where((format) => format.feed == PaperFeed.sheet)
        .toList();
    final rolls = formats
        .where((format) => format.feed == PaperFeed.roll)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sheets.isNotEmpty) ...[
          _groupTitle(
            context,
            Icons.description_outlined,
            l10n.reportPaperGroupSheets,
          ),
          for (final format in sheets) _tile(context, format),
        ],
        if (rolls.isNotEmpty) ...[
          SizedBox(height: context.spacing.s),
          _groupTitle(
            context,
            Icons.receipt_long_outlined,
            l10n.reportPaperGroupRolls,
          ),
          for (final format in rolls) _tile(context, format),
        ],
      ],
    );
  }

  Widget _groupTitle(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.subtitleColor),
          SizedBox(width: context.spacing.xs),
          Expanded(
            child: Text(
              title,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, PaperFormat format) {
    final selected = format.id == selectedId;
    final scheme = context.theme.colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: context.shapes.s),
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : null,
      ),
      title: Text(format.displayName(context.l10n)),
      subtitle: format.name.trim().isEmpty
          ? null
          : Text(format.describe(context.l10n)),
      onTap: () => onSelected(format.id),
    );
  }
}

/// Asks for a short text such as a template or category name.
Future<String?> askPrintName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, label: label, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

/// Asks to confirm a deletion. Returns true when confirmed.
Future<bool> confirmPrintDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.errorColorStatus,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return confirmed == true;
}
