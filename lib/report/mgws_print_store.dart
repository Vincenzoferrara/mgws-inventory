import 'package:report_flutter/report_flutter.dart';

import '../login/mgws/query/query_mgws_print.dart';

/// Keeps the print library of the shop on MGWS (`/print` routes), shared by
/// every device. Only the transport lives here: the rules are in the
/// report_flutter `PrintLibrary`.
class MgwsPrintStore implements PrintStore {
  MgwsPrintStore({QueryMgwsPrint? client})
    : _client = client ?? QueryMgwsPrint();

  final QueryMgwsPrint _client;

  static MgwsPrintCollection _collection(PrintCollection collection) =>
      switch (collection) {
        PrintCollection.templates => MgwsPrintCollection.templates,
        PrintCollection.paperFormats => MgwsPrintCollection.paperFormats,
        PrintCollection.categories => MgwsPrintCollection.categories,
      };

  static PrintStoreItem _fromMgws(MgwsPrintItem item) =>
      PrintStoreItem(id: item.id, name: item.name, data: item.data);

  static MgwsPrintItem _toMgws(PrintStoreItem item) =>
      MgwsPrintItem(id: item.id, name: item.name, data: item.data);

  static PrintStoreSnapshot _snapshot(MgwsPrintLibrary library) =>
      PrintStoreSnapshot(
        canManage: library.canManage,
        defaultsLoaded: library.defaultsLoaded,
        templates: library.templates.map(_fromMgws).toList(),
        paperFormats: library.paperFormats.map(_fromMgws).toList(),
        categories: library.categories.map(_fromMgws).toList(),
      );

  @override
  Future<PrintStoreSnapshot> load() async => _snapshot(await _client.library());

  @override
  Future<PrintStoreSnapshot> loadDefaults({
    required List<PrintStoreItem> templates,
    required List<PrintStoreItem> paperFormats,
    required List<PrintStoreItem> categories,
  }) async {
    return _snapshot(
      await _client.loadDefaults(
        templates: templates.map(_toMgws).toList(),
        paperFormats: paperFormats.map(_toMgws).toList(),
        categories: categories.map(_toMgws).toList(),
      ),
    );
  }

  @override
  Future<void> save(PrintCollection collection, PrintStoreItem item) =>
      _client.save(_collection(collection), _toMgws(item));

  @override
  Future<void> delete(PrintCollection collection, String itemId) =>
      _client.delete(_collection(collection), itemId);
}
