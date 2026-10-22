import 'dart:convert';

import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

/// Collections of the MGWS print library.
enum MgwsPrintCollection {
  templates('templates', 'templates'),
  paperFormats('paper-formats', 'paper_formats'),
  categories('categories', 'categories');

  const MgwsPrintCollection(this.path, this.listKey);

  /// Segment used in `/print/{collection}/{id}`.
  final String path;

  /// Key of the list in the `/print/library` response.
  final String listKey;
}

/// One stored item: the server keeps [data] as an opaque JSON object.
class MgwsPrintItem {
  final String id;
  final String name;
  final Map<String, dynamic> data;

  const MgwsPrintItem({
    required this.id,
    required this.name,
    required this.data,
  });

  /// Returns null when the entry is unreadable, so one bad item does not
  /// hide the rest of the library.
  static MgwsPrintItem? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    final raw = json['data_json'];
    if (id is! String || raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MgwsPrintItem(
        id: id,
        name: json['name']?.toString() ?? '',
        data: Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toRequest() => {
    'id': id,
    'name': name,
    // Sent as a string: WordPress decodes JSON bodies into PHP arrays, where
    // an empty object would come back as an empty list.
    'data_json': jsonEncode(data),
  };
}

/// The whole print library of the site.
class MgwsPrintLibrary {
  final bool canManage;
  final bool defaultsLoaded;
  final List<MgwsPrintItem> templates;
  final List<MgwsPrintItem> paperFormats;
  final List<MgwsPrintItem> categories;

  const MgwsPrintLibrary({
    required this.canManage,
    required this.defaultsLoaded,
    required this.templates,
    required this.paperFormats,
    required this.categories,
  });

  factory MgwsPrintLibrary.fromJson(Map<String, dynamic> json) {
    List<MgwsPrintItem> items(MgwsPrintCollection collection) {
      final raw = json[collection.listKey];
      if (raw is! List) return const [];
      return raw
          .map(MgwsPrintItem.tryFromJson)
          .whereType<MgwsPrintItem>()
          .toList();
    }

    return MgwsPrintLibrary(
      canManage: json['can_manage'] == true,
      defaultsLoaded: json['defaults_loaded'] == true,
      templates: items(MgwsPrintCollection.templates),
      paperFormats: items(MgwsPrintCollection.paperFormats),
      categories: items(MgwsPrintCollection.categories),
    );
  }
}

/// Print templates, their categories and paper formats stored by MGWS and
/// shared by every device of the shop. Only shop managers can change them;
/// the server reports it as `can_manage`.
class QueryMgwsPrint {
  QueryMgwsPrint();

  final QueryMgwsBase _base = QueryMgwsBase();

  Future<bool> isAvailable() => MgwsConnection.instance.ensureConnected();

  Future<MgwsPrintLibrary> library() async {
    final response = await _base.get('/wp-json/mgws/v1/print/library');
    return MgwsPrintLibrary.fromJson(_map(response.data, 'library'));
  }

  /// Loads the default library. The server accepts it once per site.
  Future<MgwsPrintLibrary> loadDefaults({
    required List<MgwsPrintItem> templates,
    required List<MgwsPrintItem> paperFormats,
    required List<MgwsPrintItem> categories,
  }) async {
    final response = await _base.post(
      '/wp-json/mgws/v1/print/defaults',
      data: {
        MgwsPrintCollection.templates.listKey: templates
            .map((item) => item.toRequest())
            .toList(),
        MgwsPrintCollection.paperFormats.listKey: paperFormats
            .map((item) => item.toRequest())
            .toList(),
        MgwsPrintCollection.categories.listKey: categories
            .map((item) => item.toRequest())
            .toList(),
      },
    );
    return MgwsPrintLibrary.fromJson(_map(response.data, 'defaults'));
  }

  Future<void> save(MgwsPrintCollection collection, MgwsPrintItem item) async {
    await _base.put(
      '/wp-json/mgws/v1/print/${collection.path}/${Uri.encodeComponent(item.id)}',
      data: item.toRequest(),
    );
  }

  Future<void> delete(MgwsPrintCollection collection, String itemId) async {
    await _base.delete(
      '/wp-json/mgws/v1/print/${collection.path}/${Uri.encodeComponent(itemId)}',
    );
  }

  Map<String, dynamic> _map(dynamic data, String what) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Unexpected MGWS print $what response');
  }
}
