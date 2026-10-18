import 'package:flutter/material.dart';

import '../notification/notification_service.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'paper_formats.gui.dart';
import 'print_designer.gui.dart';
import 'print_library.dart';
import 'print_template.dart';
import 'print_template_catalog.dart';
import 'print_widgets.gui.dart';

/// Template tab: every template of the shop grouped by category, with the
/// tools to create, edit, move and delete templates and categories and to
/// manage the paper formats. Only shop managers can change anything.
class TemplateTab extends StatelessWidget {
  const TemplateTab({super.key, required this.library});

  final PrintLibrary library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canManage = library.canManage;
    return ListView(
      padding: context.spacing.iL,
      children: [
        if (!canManage) ...[
          InfoBox(icon: Icons.lock_outline, text: l10n.reportManagersOnly),
          SizedBox(height: context.spacing.s),
        ] else
          Wrap(
            spacing: context.spacing.s,
            runSpacing: context.spacing.s,
            children: [
              FilledButton.icon(
                onPressed: () => _createTemplate(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.reportNewTemplate),
              ),
              OutlinedButton.icon(
                onPressed: () => _createCategory(context),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l10n.reportNewCategory),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaperFormatsPage(library: library),
                  ),
                ),
                icon: const Icon(Icons.straighten),
                label: Text(l10n.reportPaperFormats),
              ),
            ],
          ),
        PrintTemplateGroups(
          library: library,
          showEmptyCategories: canManage,
          onTap: (template) => canManage ? _edit(context, template) : null,
          cardMenu: canManage
              ? (template) => _templateMenu(context, template)
              : null,
          categoryActions: canManage
              ? (category) => _categoryMenu(context, category)
              : null,
        ),
      ],
    );
  }

  // --- Templates --------------------------------------------------------------

  Widget _templateMenu(BuildContext context, PrintTemplate template) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.reportTemplateActions,
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _edit(context, template);
          case 'rename':
            _rename(context, template);
          case 'duplicate':
            _duplicate(context, template);
          case 'move':
            _move(context, template);
          case 'delete':
            _delete(context, template);
        }
      },
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_outlined, l10n.reportEditDesign),
        _menuItem('rename', Icons.drive_file_rename_outline, l10n.reportRename),
        _menuItem('duplicate', Icons.copy_outlined, l10n.reportDuplicate),
        _menuItem(
          'move',
          Icons.drive_file_move_outline,
          l10n.reportMoveToCategory,
        ),
        _menuItem(
          'delete',
          Icons.delete_outline,
          l10n.commonDelete,
          color: context.colors.errorColorStatus,
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _edit(BuildContext context, PrintTemplate template) async {
    final edited = await openPrintTemplateDesigner(context, template);
    if (edited == null || !context.mounted) return;
    await _save(
      context,
      () => library.saveTemplate(edited),
      context.l10n.reportTemplateSaved(edited.name),
    );
  }

  Future<void> _rename(BuildContext context, PrintTemplate template) async {
    final l10n = context.l10n;
    final name = await askPrintName(
      context,
      title: l10n.reportRename,
      label: l10n.reportTemplateNameLabel,
      initial: template.name,
    );
    if (name == null || !context.mounted) return;
    await _save(
      context,
      () => library.saveTemplate(template.copyWith(name: name)),
      l10n.reportTemplateSaved(name),
    );
  }

  Future<void> _duplicate(BuildContext context, PrintTemplate template) async {
    final l10n = context.l10n;
    final copy = template.copyWith(
      id: PrintTemplate.newId(),
      name: l10n.reportCopyOf(template.name),
    );
    await _save(
      context,
      () => library.saveTemplate(copy),
      l10n.reportTemplateSaved(copy.name),
    );
  }

  Future<void> _move(BuildContext context, PrintTemplate template) async {
    final l10n = context.l10n;
    const none = '';
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.reportMoveToCategory),
        children: [
          for (final category in library.categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, category.id),
              child: Text(category.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, none),
            child: Text(l10n.reportNoCategory),
          ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final moved = chosen == none
        ? template.copyWith(clearCategory: true)
        : template.copyWith(categoryId: chosen);
    await _save(
      context,
      () => library.saveTemplate(moved),
      l10n.reportTemplateSaved(template.name),
    );
  }

  Future<void> _delete(BuildContext context, PrintTemplate template) async {
    final l10n = context.l10n;
    final confirmed = await confirmPrintDelete(
      context,
      title: l10n.reportDeleteTemplateTitle,
      message: l10n.reportDeleteTemplateMessage(template.name),
    );
    if (!confirmed || !context.mounted) return;
    await _save(
      context,
      () => library.deleteTemplate(template.id),
      l10n.reportTemplateDeleted(template.name),
    );
  }

  Future<void> _createTemplate(BuildContext context) async {
    final setup = await showDialog<_NewTemplateSetup>(
      context: context,
      builder: (_) => _NewTemplateDialog(library: library),
    );
    if (setup == null || !context.mounted) return;
    final paper = setup.paper;
    final blank = PrintDesign(paper.cellWidthMm, paper.cellHeightMm);
    final id = PrintTemplate.newId();
    final template = PrintTemplate(
      id: id,
      name: setup.name,
      kind: setup.kind,
      categoryId: setup.categoryId,
      paperFormatId: paper.id,
      design: blank.build(id: id, name: setup.name, kind: setup.kind),
    );
    final edited = await openPrintTemplateDesigner(context, template);
    if (edited == null || !context.mounted) return;
    await _save(
      context,
      () => library.saveTemplate(edited),
      context.l10n.reportTemplateSaved(edited.name),
    );
  }

  // --- Categories -------------------------------------------------------------

  Widget _categoryMenu(BuildContext context, PrintCategory category) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.reportCategoryActions,
      onSelected: (action) {
        switch (action) {
          case 'rename':
            _renameCategory(context, category);
          case 'up':
            _save(context, () => library.moveCategory(category, -1), null);
          case 'down':
            _save(context, () => library.moveCategory(category, 1), null);
          case 'delete':
            _deleteCategory(context, category);
        }
      },
      itemBuilder: (_) => [
        _menuItem('rename', Icons.drive_file_rename_outline, l10n.reportRename),
        _menuItem('up', Icons.arrow_upward, l10n.reportMoveUp),
        _menuItem('down', Icons.arrow_downward, l10n.reportMoveDown),
        _menuItem(
          'delete',
          Icons.delete_outline,
          l10n.commonDelete,
          color: context.colors.errorColorStatus,
        ),
      ],
    );
  }

  Future<void> _createCategory(BuildContext context) async {
    final l10n = context.l10n;
    final name = await askPrintName(
      context,
      title: l10n.reportNewCategory,
      label: l10n.reportCategoryNameLabel,
    );
    if (name == null || !context.mounted) return;
    final category = PrintCategory(
      id: PrintCategory.newId(),
      name: name,
      position: library.nextCategoryPosition,
    );
    await _save(
      context,
      () => library.saveCategory(category),
      l10n.reportCategorySaved(name),
    );
  }

  Future<void> _renameCategory(
    BuildContext context,
    PrintCategory category,
  ) async {
    final l10n = context.l10n;
    final name = await askPrintName(
      context,
      title: l10n.reportRename,
      label: l10n.reportCategoryNameLabel,
      initial: category.name,
    );
    if (name == null || !context.mounted) return;
    await _save(
      context,
      () => library.saveCategory(category.copyWith(name: name)),
      l10n.reportCategorySaved(name),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    PrintCategory category,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmPrintDelete(
      context,
      title: l10n.reportDeleteCategoryTitle,
      message: l10n.reportDeleteCategoryMessage(category.name),
    );
    if (!confirmed || !context.mounted) return;
    await _save(
      context,
      () => library.deleteCategory(category.id),
      l10n.reportCategoryDeleted(category.name),
    );
  }

  /// Runs a change on the server and reports the outcome.
  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
    String? success,
  ) async {
    final l10n = context.l10n;
    try {
      await action();
      if (success != null) {
        NotificationService.instance.messageBar('successo', 'report', success);
      }
    } catch (error) {
      NotificationService.instance.messageBar(
        'errore',
        'report',
        l10n.reportSaveError(error.toString()),
      );
    }
  }
}

class _NewTemplateSetup {
  final String name;
  final PrintTemplateKind kind;
  final String? categoryId;
  final PaperFormat paper;

  const _NewTemplateSetup({
    required this.name,
    required this.kind,
    required this.categoryId,
    required this.paper,
  });
}

/// Name, type, category and paper format of a new template. The layout is
/// then drawn in the designer.
class _NewTemplateDialog extends StatefulWidget {
  const _NewTemplateDialog({required this.library});

  final PrintLibrary library;

  @override
  State<_NewTemplateDialog> createState() => _NewTemplateDialogState();
}

class _NewTemplateDialogState extends State<_NewTemplateDialog> {
  final TextEditingController _nameController = TextEditingController();
  PrintTemplateKind _kind = PrintTemplateKind.productLabel;
  String? _categoryId;
  String? _paperId;

  @override
  void initState() {
    super.initState();
    final categories = widget.library.categories;
    _categoryId = categories.isEmpty ? null : categories.first.id;
    _paperId = widget.library.paperFormatsFor(_kind).firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setKind(PrintTemplateKind kind) {
    setState(() {
      _kind = kind;
      _paperId = widget.library.paperFormatsFor(kind).firstOrNull?.id;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final paper = widget.library
        .paperFormatsFor(_kind)
        .where((format) => format.id == _paperId)
        .firstOrNull;
    if (name.isEmpty || paper == null) return;
    Navigator.pop(
      context,
      _NewTemplateSetup(
        name: name,
        kind: _kind,
        categoryId: _categoryId,
        paper: paper,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = widget.library.paperFormatsFor(_kind);
    return AlertDialog(
      title: Text(l10n.reportNewTemplate),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.reportTemplateNameLabel,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: context.spacing.l),
            Text(l10n.reportTemplateKindLabel, style: context.text.labelLarge),
            SizedBox(height: context.spacing.xs),
            SegmentedButton<PrintTemplateKind>(
              showSelectedIcon: false,
              segments: [
                for (final kind in PrintTemplateKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text(kindLabel(l10n, kind)),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => _setKind(selection.first),
            ),
            SizedBox(height: context.spacing.l),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: InputDecoration(labelText: l10n.reportCategoryLabel),
              items: [
                for (final category in widget.library.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.reportNoCategory),
                ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            SizedBox(height: context.spacing.l),
            if (formats.isEmpty)
              Text(
                l10n.reportPaperMissing,
                style: TextStyle(color: context.colors.errorColorStatus),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey(_kind),
                initialValue: _paperId,
                decoration: InputDecoration(labelText: l10n.reportSectionPaper),
                items: [
                  for (final format in formats)
                    DropdownMenuItem(
                      value: format.id,
                      child: Text(format.displayName(l10n)),
                    ),
                ],
                onChanged: (value) => setState(() => _paperId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty || formats.isEmpty
              ? null
              : _submit,
          child: Text(l10n.reportOpenDesigner),
        ),
      ],
    );
  }
}
