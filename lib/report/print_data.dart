import 'package:flutter/material.dart';
import 'package:report_flutter/report_flutter.dart';

import '../notification/notification_service.dart';
import '../products/product_list/product_picker.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'mgws_print_store.dart';
import 'print_job.dart';
import 'print_sample_data.dart';
import 'print_template_catalog.dart';

/// The print library of the shop, kept on MGWS. The first time a manager
/// opens it on a site, the ready-made templates, categories and paper
/// formats are stored once.
final printLibrary = PrintLibrary(
  store: MgwsPrintStore(),
  options: PrintLibraryOptions(
    loadDefaultPaperFormats: true,
    defaultTemplates: (context) =>
        PrintTemplateCatalog.defaultTemplates(context.l10n),
    defaultCategories: (context) =>
        PrintTemplateCatalog.defaultCategories(context.l10n),
  ),
);

/// What the shop tells the print library about its data: example values,
/// the products picker and the colour/size separator of labels and signs.
class ShopPrintDataProvider extends PrintDataProvider {
  const ShopPrintDataProvider();

  @override
  Map<String, dynamic> sampleData(
    BuildContext context,
    PrintTemplate template,
  ) => PrintSampleData.forTemplate(
    template,
    context.l10n,
    context.l10n.localeName,
  );

  /// Reports are filled with example figures until real data is connected.
  @override
  String? pageNotice(BuildContext context, PrintTemplate template) =>
      template.shopKind == ShopTemplateKind.report
      ? context.l10n.reportSampleDataNotice
      : null;

  /// Only product labels print products.
  @override
  bool acceptsRows(PrintTemplate template) =>
      template.shopKind == ShopTemplateKind.productLabel;

  @override
  bool get canPickRows => true;

  /// Opens the products picker shared with the till and the inventory.
  @override
  Future<PrintJob?> pickRows(BuildContext context) async {
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final picked = await openProdottoPicker(context);
    if (picked == null || picked.isEmpty) return null;
    final job = labelJobFromProducts(picked, localeName);
    if (job.rows.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'report',
        l10n.productsPrintLabelsNoStock,
      );
      return null;
    }
    return job;
  }

  /// Labels and signs choose what is printed between colour and size in the
  /// `coloreTaglia` field.
  @override
  Widget? designerSettings(
    BuildContext context,
    PrintTemplate template,
    ValueChanged<PrintTemplate> onChanged,
  ) {
    if (template.shopKind == ShopTemplateKind.report) return null;
    return Row(
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
            value: PrintSampleData.variantSeparatorOf(template),
            onChanged: (value) => onChanged(
              template.withSetting(PrintSampleData.variantSeparatorKey, value),
            ),
          ),
        ),
      ],
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
