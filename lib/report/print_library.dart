import 'package:flutter/foundation.dart';

import '../log_viewer/app_logger.dart';
import '../login/mgws/query/query_mgws_print.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_template.dart';
import 'print_template_catalog.dart';

final printLibrary = PrintLibrary();

/// The print library of the shop: templates, their categories and the paper
/// formats, all stored by MGWS and shared by every device.
///
/// Nothing is kept on the device: every change goes to the server first and
/// the local lists change only when the server accepted it.
class PrintLibrary extends ChangeNotifier {
  PrintLibrary({QueryMgwsPrint? client}) : _client = client ?? QueryMgwsPrint();

  final QueryMgwsPrint _client;

  List<PrintTemplate> _templates = const [];
  List<PrintCategory> _categories = const [];
  List<PaperFormat> _paperFormats = const [];
  bool _canManage = false;
  bool _defaultsLoaded = false;
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  List<PrintTemplate> get templates => List.unmodifiable(_templates);
  List<PaperFormat> get paperFormats => List.unmodifiable(_paperFormats);
  bool get canManage => _canManage;
  bool get defaultsLoaded => _defaultsLoaded;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;

  /// Categories sorted by position, then by name.
  List<PrintCategory> get categories {
    final sorted = List<PrintCategory>.of(_categories);
    sorted.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0
          ? byPosition
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  /// Templates grouped by category, in category order. Templates whose
  /// category does not exist any more are listed under a null key at the end.
  List<({PrintCategory? category, List<PrintTemplate> templates})> grouped({
    bool Function(PrintTemplate template)? where,
  }) {
    final visible = _templates.where(where ?? (_) => true).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final knownIds = _categories.map((category) => category.id).toSet();
    return [
      for (final category in categories)
        (
          category: category,
          templates: visible
              .where((template) => template.categoryId == category.id)
              .toList(),
        ),
      (
        category: null,
        templates: visible
            .where((template) => !knownIds.contains(template.categoryId))
            .toList(),
      ),
    ];
  }

  List<PaperFormat> paperFormatsFor(PrintTemplateKind kind) =>
      _paperFormats.where((format) => format.kind == kind).toList();

  /// The paper format of [template]. When it was deleted, the first format of
  /// the same kind is used, or a single page as big as the design.
  PaperFormat paperFormatOf(PrintTemplate template, {String? overrideId}) {
    final wanted = overrideId ?? template.paperFormatId;
    for (final format in _paperFormats) {
      if (format.id == wanted && format.kind == template.kind) return format;
    }
    final sameKind = paperFormatsFor(template.kind);
    if (sameKind.isNotEmpty) return sameKind.first;
    return PaperFormat.single(
      kind: template.kind,
      widthMm: template.design.itemWidth,
      heightMm: template.design.itemHeight,
    );
  }

  /// Reads the library from MGWS. The first time a manager opens it on a
  /// site, the default library is loaded on the server.
  Future<void> load(AppLocalizations l10n, {bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      var library = await _client.library();
      if (!library.defaultsLoaded && library.canManage) {
        library = await _client.loadDefaults(
          templates: PrintTemplateCatalog.defaultTemplates(
            l10n,
          ).map((item) => item.toItem()).toList(),
          paperFormats: PaperFormatDefaults.all(
            l10n,
          ).map((item) => item.toItem()).toList(),
          categories: PrintTemplateCatalog.defaultCategories(
            l10n,
          ).map((item) => item.toItem()).toList(),
        );
      }
      _apply(library);
      _loaded = true;
    } catch (error, stack) {
      AppLogger().w('Print library not loaded', error, stack);
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _apply(MgwsPrintLibrary library) {
    _canManage = library.canManage;
    _defaultsLoaded = library.defaultsLoaded;
    _templates = library.templates
        .map(PrintTemplate.tryFromItem)
        .whereType<PrintTemplate>()
        .toList();
    _paperFormats = library.paperFormats
        .map(PaperFormat.tryFromItem)
        .whereType<PaperFormat>()
        .toList();
    _categories = library.categories.map(PrintCategory.fromItem).toList();
  }

  Future<void> saveTemplate(PrintTemplate template) async {
    await _client.save(MgwsPrintCollection.templates, template.toItem());
    _templates = [
      for (final entry in _templates)
        if (entry.id != template.id) entry,
      template,
    ];
    notifyListeners();
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client.delete(MgwsPrintCollection.templates, templateId);
    _templates = _templates.where((entry) => entry.id != templateId).toList();
    notifyListeners();
  }

  Future<void> saveCategory(PrintCategory category) async {
    await _client.save(MgwsPrintCollection.categories, category.toItem());
    _categories = [
      for (final entry in _categories)
        if (entry.id != category.id) entry,
      category,
    ];
    notifyListeners();
  }

  /// Deletes the category. Its templates stay and are listed without a
  /// category until they are moved.
  Future<void> deleteCategory(String categoryId) async {
    await _client.delete(MgwsPrintCollection.categories, categoryId);
    _categories = _categories.where((entry) => entry.id != categoryId).toList();
    notifyListeners();
  }

  /// Moves [category] one place up (-1) or down (+1) and stores the new
  /// positions of every category.
  Future<void> moveCategory(PrintCategory category, int direction) async {
    final ordered = categories;
    final index = ordered.indexWhere((entry) => entry.id == category.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    for (var position = 0; position < ordered.length; position++) {
      if (ordered[position].position != position) {
        await saveCategory(ordered[position].copyWith(position: position));
      }
    }
  }

  int get nextCategoryPosition => _categories.isEmpty
      ? 0
      : _categories
                .map((entry) => entry.position)
                .reduce((a, b) => a > b ? a : b) +
            1;

  Future<void> savePaperFormat(PaperFormat format) async {
    await _client.save(MgwsPrintCollection.paperFormats, format.toItem());
    _paperFormats = [
      for (final entry in _paperFormats)
        if (entry.id != format.id) entry,
      format,
    ];
    notifyListeners();
  }

  Future<void> deletePaperFormat(String formatId) async {
    await _client.delete(MgwsPrintCollection.paperFormats, formatId);
    _paperFormats = _paperFormats
        .where((entry) => entry.id != formatId)
        .toList();
    notifyListeners();
  }

  /// Templates that print on [formatId], shown before deleting a format.
  int templatesUsing(String formatId) =>
      _templates.where((template) => template.paperFormatId == formatId).length;

  static String newPaperFormatId() =>
      'paper_${DateTime.now().microsecondsSinceEpoch}';
}
