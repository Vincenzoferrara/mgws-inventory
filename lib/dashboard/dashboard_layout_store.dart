// Dashboard layout storage.
//
// MGWS is the source of truth: it keeps personal dashboards per user and the
// shared ones (visible to everyone or only to shop managers) for the whole
// shop. Without MGWS the app keeps personal dashboards on this device, and
// shared dashboards are not available.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import 'dashboard_layout.dart';

/// Dashboards the current user can open.
class DashboardCatalog {
  const DashboardCatalog({
    required this.dashboards,
    required this.canManageShared,
    required this.storedOnServer,
  });

  final List<DashboardLayout> dashboards;

  /// True when the user may create and change shared dashboards.
  final bool canManageShared;

  /// False when MGWS is not reachable and dashboards live on this device.
  final bool storedOnServer;
}

/// Storage contract used by the dashboard page and by tests.
abstract interface class DashboardLayoutStore {
  Future<DashboardCatalog> load();

  Future<DashboardLayout> save(DashboardLayout layout);

  Future<void> delete(DashboardLayout layout);

  Future<String?> selectedId();

  Future<void> setSelectedId(String id);
}

class MgwsDashboardLayoutStore implements DashboardLayoutStore {
  static const _localKey = 'dashboard_layouts_local_v1';
  static const _selectedKey = 'dashboard_selected_id';

  bool _storedOnServer = false;

  @override
  Future<DashboardCatalog> load() async {
    if (await _serverAvailable()) {
      try {
        final response = await PlatformManager.dashboards.list();
        final items = response['dashboards'];
        _storedOnServer = true;
        return DashboardCatalog(
          dashboards: [
            if (items is List)
              for (final item in items)
                if (item is Map)
                  DashboardLayout.fromJson(Map<String, dynamic>.from(item)),
          ],
          canManageShared: response['can_manage_shared'] == true,
          storedOnServer: true,
        );
      } catch (error) {
        log.w('MGWS dashboards not available, using local copy: $error');
      }
    }
    _storedOnServer = false;
    return DashboardCatalog(
      dashboards: await _readLocal(),
      canManageShared: false,
      storedOnServer: false,
    );
  }

  @override
  Future<DashboardLayout> save(DashboardLayout layout) async {
    if (_storedOnServer) {
      final response = await PlatformManager.dashboards.save(
        dashboardId: layout.id,
        name: layout.name,
        visibility: layout.visibility.name,
        layout: layout.layoutJson(),
      );
      final saved = response['dashboard'];
      if (saved is Map) {
        return DashboardLayout.fromJson(Map<String, dynamic>.from(saved));
      }
      return layout;
    }
    // On this device only personal dashboards make sense.
    final local = layout.copyWith(visibility: DashboardVisibility.personal);
    final all = await _readLocal();
    final index = all.indexWhere((item) => item.id == local.id);
    if (index >= 0) {
      all[index] = local;
    } else {
      all.add(local);
    }
    await _writeLocal(all);
    return local;
  }

  @override
  Future<void> delete(DashboardLayout layout) async {
    if (_storedOnServer) {
      await PlatformManager.dashboards.delete(layout.id);
      return;
    }
    final all = await _readLocal();
    all.removeWhere((item) => item.id == layout.id);
    await _writeLocal(all);
  }

  @override
  Future<String?> selectedId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setSelectedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedKey, id);
    } catch (_) {
      // Remembering the last dashboard is a convenience only.
    }
  }

  Future<bool> _serverAvailable() async {
    try {
      return await PlatformManager.ensureCanUseMgws();
    } catch (_) {
      return false;
    }
  }

  Future<List<DashboardLayout>> _readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            DashboardLayout.fromJson(
              Map<String, dynamic>.from(item),
            ).copyWith(editable: true),
      ];
    } catch (error) {
      log.w('Local dashboards unreadable: $error');
      return [];
    }
  }

  Future<void> _writeLocal(List<DashboardLayout> layouts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(layouts.map((layout) => layout.toJson()).toList()),
    );
  }
}
