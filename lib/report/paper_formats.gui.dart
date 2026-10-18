import 'package:flutter/material.dart';

import '../notification/notification_service.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_library.dart';
import 'print_template.dart';
import 'print_widgets.gui.dart';

/// Paper formats of the shop, grouped by template type. Shop managers can
/// add, change and delete them, defaults included.
class PaperFormatsPage extends StatelessWidget {
  const PaperFormatsPage({super.key, required this.library});

  final PrintLibrary library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.reportPaperFormats)),
        floatingActionButton: library.canManage
            ? FloatingActionButton.extended(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: Text(l10n.reportNewPaperFormat),
              )
            : null,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            context.spacing.l,
            context.spacing.l,
            context.spacing.l,
            96,
          ),
          children: [
            Text(
              l10n.reportPaperFormatsHelp,
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
            for (final kind in PrintTemplateKind.values) ...[
              SizedBox(height: context.spacing.l),
              Text(
                kindLabel(l10n, kind),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 16),
              if (library.paperFormatsFor(kind).isEmpty)
                Text(
                  l10n.reportPaperMissing,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.subtitleColor,
                  ),
                ),
              for (final format in library.paperFormatsFor(kind))
                Card(
                  child: ListTile(
                    leading: Icon(
                      format.feed == PaperFeed.roll
                          ? Icons.receipt_long_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(format.displayName(l10n)),
                    subtitle: Text(format.describe(l10n)),
                    onTap: library.canManage
                        ? () => _edit(context, format)
                        : null,
                    trailing: library.canManage
                        ? IconButton(
                            tooltip: l10n.commonDelete,
                            icon: Icon(
                              Icons.delete_outline,
                              color: context.colors.errorColorStatus,
                            ),
                            onPressed: () => _delete(context, format),
                          )
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, PaperFormat? format) async {
    final l10n = context.l10n;
    final edited = await showDialog<PaperFormat>(
      context: context,
      builder: (_) => _PaperFormatDialog(initial: format),
    );
    if (edited == null || !context.mounted) return;
    try {
      await library.savePaperFormat(edited);
      NotificationService.instance.messageBar(
        'successo',
        'report',
        l10n.reportPaperFormatSaved(edited.displayName(l10n)),
      );
    } catch (error) {
      NotificationService.instance.messageBar(
        'errore',
        'report',
        l10n.reportSaveError(error.toString()),
      );
    }
  }

  Future<void> _delete(BuildContext context, PaperFormat format) async {
    final l10n = context.l10n;
    final used = library.templatesUsing(format.id);
    final confirmed = await confirmPrintDelete(
      context,
      title: l10n.reportDeletePaperFormatTitle,
      message: used == 0
          ? l10n.reportDeletePaperFormatMessage(format.displayName(l10n))
          : l10n.reportDeletePaperFormatUsedMessage(
              format.displayName(l10n),
              used,
            ),
    );
    if (!confirmed || !context.mounted) return;
    try {
      await library.deletePaperFormat(format.id);
    } catch (error) {
      NotificationService.instance.messageBar(
        'errore',
        'report',
        l10n.reportSaveError(error.toString()),
      );
    }
  }
}

/// Every measure of a paper format, in millimetres.
class _PaperFormatDialog extends StatefulWidget {
  const _PaperFormatDialog({this.initial});

  final PaperFormat? initial;

  @override
  State<_PaperFormatDialog> createState() => _PaperFormatDialogState();
}

class _PaperFormatDialogState extends State<_PaperFormatDialog> {
  late PrintTemplateKind _kind =
      widget.initial?.kind ?? PrintTemplateKind.productLabel;
  late PaperFeed _feed = widget.initial?.feed ?? PaperFeed.sheet;
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final Map<String, TextEditingController> _numbers = {
    'pageWidth': _numberController(widget.initial?.pageWidthMm ?? 210),
    'pageHeight': _numberController(widget.initial?.pageHeightMm ?? 297),
    'columns': _numberController((widget.initial?.columns ?? 3).toDouble()),
    'rows': _numberController((widget.initial?.rows ?? 8).toDouble()),
    'cellWidth': _numberController(widget.initial?.cellWidthMm ?? 70),
    'cellHeight': _numberController(widget.initial?.cellHeightMm ?? 37),
    'marginTop': _numberController(widget.initial?.marginTopMm ?? 0),
    'marginLeft': _numberController(widget.initial?.marginLeftMm ?? 0),
    'gapX': _numberController(widget.initial?.gapXMm ?? 0),
    'gapY': _numberController(widget.initial?.gapYMm ?? 0),
  };
  PaperFormatError? _error;

  static TextEditingController _numberController(double value) =>
      TextEditingController(text: PaperFormat.formatMm(value));

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(String key) =>
      double.tryParse(_numbers[key]!.text.trim().replaceAll(',', '.')) ?? 0;

  PaperFormat _build() {
    final isRoll = _feed == PaperFeed.roll;
    final cellWidth = _value('cellWidth');
    final cellHeight = _value('cellHeight');
    return PaperFormat(
      id: widget.initial?.id ?? PrintLibrary.newPaperFormatId(),
      name: _name.text.trim(),
      kind: _kind,
      feed: _feed,
      // A roll prints one label per page: the page is the label.
      pageWidthMm: isRoll ? cellWidth : _value('pageWidth'),
      pageHeightMm: isRoll ? cellHeight : _value('pageHeight'),
      columns: isRoll ? 1 : _value('columns').round(),
      rows: isRoll ? 1 : _value('rows').round(),
      cellWidthMm: cellWidth,
      cellHeightMm: cellHeight,
      marginTopMm: isRoll ? 0 : _value('marginTop'),
      marginLeftMm: isRoll ? 0 : _value('marginLeft'),
      gapXMm: isRoll ? 0 : _value('gapX'),
      gapYMm: isRoll ? 0 : _value('gapY'),
    );
  }

  void _submit() {
    final format = _build();
    final error = format.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, format);
  }

  String _errorText(AppLocalizations l10n, PaperFormatError error) =>
      switch (error) {
        PaperFormatError.sizeMissing => l10n.reportPaperErrorSize,
        PaperFormatError.gridOutOfRange => l10n.reportPaperErrorGrid,
        PaperFormatError.cellsOutsidePage => l10n.reportPaperErrorOutside,
      };

  Widget _field(String key, String label) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _numbers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (_) => setState(() => _error = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isRoll = _feed == PaperFeed.roll;
    final spacing = context.spacing.m;
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? l10n.reportNewPaperFormat
            : l10n.reportEditPaperFormat,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.reportPaperNameLabel,
                  helperText: l10n.reportPaperNameHelp,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                l10n.reportTemplateKindLabel,
                style: context.text.labelLarge,
              ),
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
                onSelectionChanged: (selection) =>
                    setState(() => _kind = selection.first),
              ),
              SizedBox(height: spacing),
              SegmentedButton<PaperFeed>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PaperFeed.sheet,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l10n.reportPaperFeedSheet),
                  ),
                  ButtonSegment(
                    value: PaperFeed.roll,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.reportPaperFeedRoll),
                  ),
                ],
                selected: {_feed},
                onSelectionChanged: (selection) =>
                    setState(() => _feed = selection.first),
              ),
              SizedBox(height: spacing),
              Text(
                isRoll
                    ? l10n.reportPaperLabelSizeTitle
                    : l10n.reportPaperCellSizeTitle,
                style: context.text.labelLarge,
              ),
              Wrap(
                spacing: spacing,
                children: [
                  _field('cellWidth', l10n.reportPaperWidth),
                  _field('cellHeight', l10n.reportPaperHeight),
                ],
              ),
              if (!isRoll) ...[
                SizedBox(height: spacing),
                Text(l10n.reportPaperPageTitle, style: context.text.labelLarge),
                Wrap(
                  spacing: spacing,
                  children: [
                    _field('pageWidth', l10n.reportPaperWidth),
                    _field('pageHeight', l10n.reportPaperHeight),
                  ],
                ),
                SizedBox(height: spacing),
                Text(l10n.reportPaperGridTitle, style: context.text.labelLarge),
                Wrap(
                  spacing: spacing,
                  children: [
                    _field('columns', l10n.reportPaperColumns),
                    _field('rows', l10n.reportPaperRows),
                    _field('marginTop', l10n.reportPaperMarginTop),
                    _field('marginLeft', l10n.reportPaperMarginLeft),
                    _field('gapX', l10n.reportPaperGapX),
                    _field('gapY', l10n.reportPaperGapY),
                  ],
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: spacing),
                Text(
                  _errorText(l10n, _error!),
                  style: TextStyle(color: context.colors.errorColorStatus),
                ),
              ],
            ],
          ),
        ),
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
