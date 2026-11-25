import '../../login/mgws/query/query_mgws_inventory.dart';

/// One EPC shown by the editor. [raw] is what the operator sees; [epc] is the
/// normalized registry key.
class _RfidTagAssignmentEntry {
  const _RfidTagAssignmentEntry({
    required this.raw,
    required this.epc,
    this.isNew = false,
  });

  final String raw;
  final String epc;
  final bool isNew;

  _RfidTagAssignmentEntry confirmed() =>
      _RfidTagAssignmentEntry(raw: raw, epc: epc);
}

/// Local state of one assignment target.
///
/// A positive key is a saved WooCommerce variation id, `0` is the product
/// itself, and a negative key is an unsaved variation index (`-(index + 1)`).
class _RfidTagAssignmentState {
  _RfidTagAssignmentState({required this.key});

  final int key;
  final List<_RfidTagAssignmentEntry> entries = <_RfidTagAssignmentEntry>[];
  final Map<String, String> serverRawByEpc = <String, String>{};
  final Set<String> pendingDeletes = <String>{};

  int? productId;
  bool loaded = false;

  /// True once the operator changed this target. A late successful read must
  /// not overwrite those changes.
  bool dirty = false;

  /// A saved variation that no longer exists may still need its staged
  /// deletions, but must not receive new EPCs.
  bool allowInserts = true;
}

/// Stages EPC assignments while the product editor is open and writes them
/// through the MGWS registry only after the WooCommerce product has an id.
class RfidTagAssignmentController {
  RfidTagAssignmentController({MgwsInventoryGateway? gateway})
    : _gateway = gateway ?? QueryMgwsInventory();

  final MgwsInventoryGateway _gateway;
  final Map<int, _RfidTagAssignmentState> _states =
      <int, _RfidTagAssignmentState>{};
  int _activeKey = 0;

  /// Same normalization as the RFID panel: uppercase, no prefixes, no spaces
  /// and no hyphens. An empty result is not a valid EPC.
  static String? normalizeEpc(String raw) {
    var epc = raw.trim().toUpperCase();
    for (final prefix in const <String>[
      'URN:EPC:TAG:SGTIN-96:',
      'URN:EPC:RAW:',
    ]) {
      if (epc.startsWith(prefix)) {
        epc = epc.substring(prefix.length).trim();
        break;
      }
    }
    epc = epc.replaceAll(RegExp(r'[\s-]'), '');
    return epc.isEmpty ? null : epc;
  }

  /// Raw strings displayed by the section, in insertion order.
  List<String> epcsFor(int key) => List<String>.unmodifiable(
    _stateFor(key).entries.map((entry) => entry.raw),
  );

  /// True when the operator changed at least one assignment. The product
  /// editor uses this to avoid reloading variations after an unrelated save.
  bool get hasStagedChanges => _states.values.any(
    (state) =>
        state.dirty ||
        state.pendingDeletes.isNotEmpty ||
        state.entries.any((entry) => entry.isNew),
  );

  /// Selects the target used by [addEpc] and [removeEpc].
  void selectTarget(int key) {
    _activeKey = key;
  }

  /// Selects a saved variation id. `0` maps to the product itself.
  void selectVariation(int variationId) {
    selectTarget(variationId > 0 ? variationId : 0);
  }

  void reset() {
    _states.clear();
    _activeKey = 0;
  }

  /// Reads the registry for one product or one of its variations.
  ///
  /// A failed read leaves the local list empty: the editor stays usable when
  /// MGWS is unavailable.
  Future<void> load(int productId, int variationId) async {
    if (productId <= 0) return;
    final key = variationId > 0 ? variationId : 0;
    final state = _stateFor(key);
    if (state.loaded && state.productId == productId) return;

    try {
      final result = await _gateway.listRfidTags(
        productId: productId,
        variationId: variationId > 0 ? variationId : null,
      );
      state.productId = productId;
      if (!result.success || state.dirty) return;

      final loadedEntries = <_RfidTagAssignmentEntry>[];
      final loadedRaw = <String, String>{};
      for (final item in _rows(result.data)) {
        final serverText = _field(item, 'epc')?.toString().trim() ?? '';
        final epc = normalizeEpc(serverText);
        if (epc == null || loadedRaw.containsKey(epc)) continue;
        loadedRaw[epc] = serverText.isEmpty ? epc : serverText;
        loadedEntries.add(_RfidTagAssignmentEntry(raw: loadedRaw[epc]!, epc: epc));
      }

      state.entries
        ..clear()
        ..addAll(loadedEntries);
      state.serverRawByEpc
        ..clear()
        ..addAll(loadedRaw);
      state.pendingDeletes.clear();
      state.loaded = true;
    } catch (_) {
      // The registry is optional for the product save: an unavailable backend
      // must not stop the editor from loading the product.
    }
  }

  /// Stages one EPC. Returns false for an invalid or duplicate value; the
  /// section chooses which localized validation message to show.
  bool addEpc(String raw) {
    final epc = normalizeEpc(raw);
    if (epc == null || _containsEpc(epc)) return false;

    final state = _stateFor(_activeKey);
    if (state.pendingDeletes.remove(epc)) {
      state.entries.add(
        _RfidTagAssignmentEntry(raw: state.serverRawByEpc[epc] ?? epc, epc: epc),
      );
      state.dirty = true;
      return true;
    }

    state.entries.add(
      _RfidTagAssignmentEntry(raw: raw.trim(), epc: epc, isNew: true),
    );
    state.dirty = true;
    return true;
  }

  /// Removes one EPC from the visible list. A server-backed EPC is queued for
  /// deletion; a locally staged one never reached the registry.
  void removeEpc(String raw) {
    final epc = normalizeEpc(raw);
    if (epc == null) return;
    final state = _stateFor(_activeKey);
    final index = state.entries.indexWhere((entry) => entry.epc == epc);
    if (index < 0) return;
    final removed = state.entries.removeAt(index);
    if (!removed.isNew && state.serverRawByEpc.containsKey(epc)) {
      state.pendingDeletes.add(epc);
    }
    state.dirty = true;
  }

  /// Matches staged variation keys to saved ids by their normalized attribute
  /// signature. Only unambiguous matches are returned, so a reordered server
  /// response cannot move an EPC to the wrong variation.
  static Map<int, int?> matchVariationIdsBySignature({
    required Map<int, Set<String>> stagedSignatures,
    required Map<int, Set<String>> savedSignatures,
  }) {
    final result = <int, int?>{};
    for (final staged in stagedSignatures.entries) {
      final matches = savedSignatures.entries
          .where((saved) => _sameSignature(staged.value, saved.value))
          .map((saved) => saved.key)
          .toList();
      if (matches.length == 1) result[staged.key] = matches.single;
    }
    return result;
  }

  static bool _sameSignature(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  /// Moves locally staged entries from stable unsaved keys onto the real
  /// variation ids returned by the product save. Keys with no saved id are
  /// dropped instead of being promoted to the product level.
  void applySavedVariationIds(Map<int, int?> savedIdsByKey) {
    final validKeys = <int>{0, ...savedIdsByKey.keys};

    for (final entry in _states.entries.toList()) {
      final key = entry.key;
      if (key < 0) {
        final realId = savedIdsByKey[key] ?? 0;
        if (realId <= 0) {
          _states.remove(key);
          if (_activeKey == key) _activeKey = 0;
          continue;
        }

        final source = entry.value;
        final target = _stateFor(realId);
        if (!identical(source, target)) {
          for (final staged in source.entries) {
            if (!target.entries.any((existing) => existing.epc == staged.epc)) {
              target.entries.add(staged);
            }
          }
          target.serverRawByEpc.addAll(source.serverRawByEpc);
          target.pendingDeletes.addAll(source.pendingDeletes);
          target.productId ??= source.productId;
          target.loaded = target.loaded || source.loaded;
          target.dirty = target.dirty || source.dirty;
          _states.remove(key);
        }
        if (_activeKey == key) _activeKey = realId;
        continue;
      }

      // A saved variation removed by the operator keeps its pending deletes,
      // but must not receive new EPCs after the product has been saved.
      if (key > 0 && !validKeys.contains(key)) {
        entry.value.allowInserts = false;
      }
    }
  }

  /// Writes every staged change with the real product id. Returns a failure
  /// message when at least one EPC could not be written, or null on success.
  ///
  /// Successful operations are consumed; failed ones stay staged so the
  /// operator can retry without re-typing them.
  Future<String?> save(int productId, int variationId) async {
    selectVariation(variationId);
    if (productId <= 0) return null;
    final errors = <String>[];
    final failedKeys = <int>{};

    for (final state in _states.values.toList()) {
      for (final epc in state.pendingDeletes.toList()) {
        try {
          final result = await _gateway.deleteRfidTag(epc);
          if (result.success) {
            state.pendingDeletes.remove(epc);
            state.serverRawByEpc.remove(epc);
          } else {
            failedKeys.add(state.key);
            errors.add(result.message);
          }
        } catch (error) {
          failedKeys.add(state.key);
          errors.add('$error');
        }
      }
    }

    for (final state in _states.values.toList()) {
      // An unresolved unsaved target is never written as a product-level EPC.
      if (state.key < 0 || !state.allowInserts) continue;
      final targetVariationId = state.key > 0 ? state.key : null;
      for (final entry in state.entries.where((item) => item.isNew).toList()) {
        try {
          final result = await _gateway.upsertRfidTag(
            epc: entry.epc,
            productId: productId,
            variationId: targetVariationId,
          );
          if (result.success) {
            final index = state.entries.indexOf(entry);
            if (index >= 0) state.entries[index] = entry.confirmed();
            state.serverRawByEpc[entry.epc] = entry.raw;
          } else {
            failedKeys.add(state.key);
            errors.add(result.message);
          }
        } catch (error) {
          failedKeys.add(state.key);
          errors.add('$error');
        }
      }
    }

    for (final state in _states.values) {
      if (!failedKeys.contains(state.key)) state.dirty = false;
    }

    final messages = errors.where((message) => message.trim().isNotEmpty);
    return messages.isEmpty ? null : messages.join(' ');
  }

  bool _containsEpc(String epc) =>
      _states.values.any(
        (state) => state.entries.any((entry) => entry.epc == epc),
      );

  _RfidTagAssignmentState _stateFor(int key) =>
      _states.putIfAbsent(key, () => _RfidTagAssignmentState(key: key));

  /// The gateway returns plain maps; a few test doubles return typed rows or
  /// a JSON map. Both shapes are accepted so this controller does not impose a
  /// new result type on the connector.
  static Iterable<Object?> _rows(Object? data) {
    if (data is Iterable) return data;
    for (final key in const <String>['items', 'data', 'tags', 'results']) {
      final value = _field(data, key);
      if (value is Iterable) return value;
    }
    return const <Object?>[];
  }

  static Object? _field(Object? item, String name) {
    if (item == null) return null;
    if (item is Map) {
      for (final entry in item.entries) {
        if (entry.key.toString() == name) return entry.value;
      }
    }
    final dynamic candidate = item;
    try {
      if (name == 'epc') return candidate.epc;
    } catch (_) {
      // Not a typed row: the JSON shape below is the remaining option.
    }
    try {
      final json = candidate.toJson();
      if (json is Map) {
        for (final entry in json.entries) {
          if (entry.key.toString() == name) return entry.value;
        }
      }
    } catch (_) {
      // No JSON shape either: the field is absent.
    }
    return null;
  }
}
