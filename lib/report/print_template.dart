import 'package:report_flutter/report_flutter.dart';

import '../login/mgws/query/query_mgws_print.dart';

/// What a print template produces. It decides which data the template is
/// bound to and which paper formats it can print on.
enum PrintTemplateKind { productLabel, shopSign, report }

/// A label, sign or report template of the shop, stored by MGWS.
///
/// [design] is the drag-and-drop layout edited in the `report_flutter`
/// designer: one label, one sign or one report page, measured in millimetres.
/// [paperFormatId] says how many of them fit on the printed page.
class PrintTemplate {
  /// Separator printed between colour and size when none was chosen.
  static const String defaultVariantSeparator = ' - ';

  final String id;
  final String name;
  final PrintTemplateKind kind;
  final String? categoryId;
  final String paperFormatId;
  final ReportTemplate design;

  /// Text between colour and size in the `coloreTaglia` field, e.g. the
  /// " - " in "Navy blue - M". Chosen in the designer for each template.
  final String variantSeparator;

  const PrintTemplate({
    required this.id,
    required this.name,
    required this.kind,
    this.categoryId,
    required this.paperFormatId,
    required this.design,
    this.variantSeparator = defaultVariantSeparator,
  });

  PrintTemplate copyWith({
    String? id,
    String? name,
    PrintTemplateKind? kind,
    String? categoryId,
    bool clearCategory = false,
    String? paperFormatId,
    ReportTemplate? design,
    String? variantSeparator,
  }) {
    return PrintTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      paperFormatId: paperFormatId ?? this.paperFormatId,
      design: design ?? this.design,
      variantSeparator: variantSeparator ?? this.variantSeparator,
    );
  }

  MgwsPrintItem toItem() => MgwsPrintItem(
    id: id,
    name: name,
    data: {
      'kind': kind.name,
      'category_id': categoryId,
      'paper_format': paperFormatId,
      'variant_separator': variantSeparator,
      'design': design.toJson(),
    },
  );

  /// Returns null when the stored entry cannot be read, so a corrupted or
  /// future entry is skipped instead of breaking the template list.
  static PrintTemplate? tryFromItem(MgwsPrintItem item) {
    final data = item.data;
    final kind = PrintTemplateKind.values
        .where((value) => value.name == data['kind'])
        .firstOrNull;
    final design = data['design'];
    if (kind == null || design is! Map) return null;
    try {
      return PrintTemplate(
        id: item.id,
        name: item.name,
        kind: kind,
        categoryId: data['category_id']?.toString(),
        paperFormatId: data['paper_format']?.toString() ?? '',
        design: ReportTemplate.fromJson(Map<String, dynamic>.from(design)),
        variantSeparator:
            data['variant_separator']?.toString() ?? defaultVariantSeparator,
      );
    } catch (_) {
      return null;
    }
  }

  static String newId() => 'template_${DateTime.now().microsecondsSinceEpoch}';
}

/// A group of templates, e.g. "Labels" or "Sales". Categories only order the
/// list: the shop creates, renames, reorders and deletes them freely.
class PrintCategory {
  final String id;
  final String name;
  final int position;

  const PrintCategory({
    required this.id,
    required this.name,
    this.position = 0,
  });

  PrintCategory copyWith({String? name, int? position}) => PrintCategory(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
  );

  MgwsPrintItem toItem() =>
      MgwsPrintItem(id: id, name: name, data: {'position': position});

  static PrintCategory fromItem(MgwsPrintItem item) => PrintCategory(
    id: item.id,
    name: item.name,
    position: (item.data['position'] as num?)?.toInt() ?? 0,
  );

  static String newId() => 'category_${DateTime.now().microsecondsSinceEpoch}';
}
