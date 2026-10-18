import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:report_flutter/report_flutter.dart';

import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_library.dart';
import 'print_sample_data.dart';
import 'print_template.dart';

/// Opens the drag-and-drop designer on [template] and returns the template
/// with the edited layout, paper format and colour/size separator, or null
/// when the user leaves without applying them.
Future<PrintTemplate?> openPrintTemplateDesigner(
  BuildContext context,
  PrintTemplate template,
) {
  return Navigator.of(context).push<PrintTemplate>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _TemplateDesignerPage(template: template),
    ),
  );
}

/// Drag-and-drop designer from the `report_flutter` package: rulers, canvas
/// in millimetres and the data fields on the left, ready to be dragged onto
/// the label, sign or report page. The bar above it chooses the paper format
/// (the canvas takes the size of one cell) and, for labels and signs, what
/// is printed between colour and size in the `coloreTaglia` field.
class _TemplateDesignerPage extends StatefulWidget {
  const _TemplateDesignerPage({required this.template});

  final PrintTemplate template;

  @override
  State<_TemplateDesignerPage> createState() => _TemplateDesignerPageState();
}

class _TemplateDesignerPageState extends State<_TemplateDesignerPage> {
  late ReportTemplate _design = ReportTemplate.fromJson(
    widget.template.design.toJson(),
  );
  late final String _initialJson = jsonEncode(widget.template.design.toJson());
  late String _separator = widget.template.variantSeparator;
  late String _paperFormatId = widget.template.paperFormatId;

  /// Changes when the canvas size changes, so the designer starts again on
  /// the resized layout.
  int _canvasGeneration = 0;

  bool get _changed =>
      jsonEncode(_design.toJson()) != _initialJson ||
      _separator != widget.template.variantSeparator ||
      _paperFormatId != widget.template.paperFormatId;

  bool get _hasVariantFields =>
      widget.template.kind != PrintTemplateKind.report;

  void _apply([ReportTemplate? design]) {
    Navigator.of(context).pop(
      widget.template.copyWith(
        design: design ?? _design,
        variantSeparator: _separator,
        paperFormatId: _paperFormatId,
      ),
    );
  }

  /// The canvas takes the size of one cell of the new paper format; the
  /// elements keep their position.
  void _changePaper(PaperFormat format) {
    final resized = ReportTemplate.fromJson(_design.toJson())
      ..itemWidth = format.cellWidthMm
      ..itemHeight = format.cellHeightMm
      ..pageWidth = format.cellWidthMm
      ..pageHeight = format.cellHeightMm;
    setState(() {
      _paperFormatId = format.id;
      _design = resized;
      _canvasGeneration++;
    });
  }

  Future<void> _close() async {
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reportDiscardDesignTitle),
        content: Text(l10n.reportDiscardDesignMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.reportKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.reportDiscardDesign),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final template = widget.template.copyWith(variantSeparator: _separator);
    final sampleData = PrintSampleData.forTemplate(
      template,
      l10n,
      l10n.localeName,
    );
    final formats = printLibrary.paperFormatsFor(widget.template.kind);
    final selectedFormat = formats
        .where((format) => format.id == _paperFormatId)
        .firstOrNull;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            onPressed: _close,
          ),
          title: Text(l10n.reportDesignerTitle(widget.template.name)),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: context.spacing.m),
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: Text(l10n.reportApplyDesign),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Material(
              color: context.theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.l,
                  vertical: context.spacing.s,
                ),
                child: Wrap(
                  spacing: context.spacing.xl,
                  runSpacing: context.spacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 20,
                          color: context.theme.colorScheme.primary,
                        ),
                        SizedBox(width: context.spacing.s),
                        Text(
                          l10n.reportSectionPaper,
                          style: context.text.bodyMedium,
                        ),
                        SizedBox(width: context.spacing.s),
                        DropdownButton<String>(
                          value: selectedFormat?.id,
                          hint: Text(l10n.reportPaperMissing),
                          items: [
                            for (final format in formats)
                              DropdownMenuItem(
                                value: format.id,
                                child: Text(format.displayName(l10n)),
                              ),
                          ],
                          onChanged: (id) {
                            final format = formats
                                .where((entry) => entry.id == id)
                                .firstOrNull;
                            if (format != null) _changePaper(format);
                          },
                        ),
                      ],
                    ),
                    if (_hasVariantFields)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 20,
                            color: context.theme.colorScheme.primary,
                          ),
                          SizedBox(width: context.spacing.s),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: _SeparatorPicker(
                              value: _separator,
                              onChanged: (value) =>
                                  setState(() => _separator = value),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ReportBuilder(
                key: ValueKey('canvas-$_canvasGeneration'),
                template: _design,
                sampleData: sampleData,
                onTemplateChanged: (design) => _design = design,
                onSave: _apply,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chooses the text printed between colour and size ("Navy blue - M").
class _SeparatorPicker extends StatefulWidget {
  const _SeparatorPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SeparatorPicker> createState() => _SeparatorPickerState();
}

class _SeparatorPickerState extends State<_SeparatorPicker> {
  static const List<String> _presets = [' - ', ' / ', ' · ', ' | ', ', ', ' '];

  late final TextEditingController _customController = TextEditingController(
    text: _presets.contains(widget.value) ? '' : widget.value,
  );

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _presetLabel(AppLocalizations l10n, String preset) =>
      preset == ' ' ? l10n.reportSeparatorSpace : preset.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final example = PrintSampleData.colorAndSize(
      l10n.reportSampleColorNavy,
      'M',
      widget.value,
    );
    final chips = [
      for (final preset in _presets)
        ChoiceChip(
          visualDensity: VisualDensity.compact,
          label: Text(
            _presetLabel(l10n, preset),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          selected: widget.value == preset,
          onSelected: (_) {
            _customController.clear();
            widget.onChanged(preset);
          },
        ),
    ];
    final customField = TextField(
      controller: _customController,
      decoration: InputDecoration(
        labelText: l10n.reportSeparatorCustom,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        if (value.isNotEmpty) widget.onChanged(value);
      },
    );
    final exampleText = Text(
      l10n.reportSeparatorExample(example),
      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
    );
    return Wrap(
      spacing: context.spacing.s,
      runSpacing: context.spacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.reportSeparatorQuestion, style: context.text.bodyMedium),
        ...chips,
        SizedBox(width: 190, child: customField),
        exampleText,
      ],
    );
  }
}
