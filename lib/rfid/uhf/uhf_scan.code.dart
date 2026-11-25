// lib/rfid/uhf/uhf_scan.code.dart
//
// Lista in RAM dei tag letti. Nessuna tabella locale, nessuna scrittura di
// stock: qui si conserva cio' che ha detto il lettore e il risultato della
// risoluzione MGWS, fino a quando l'operatore non sceglie di inviare le righe
// associate alla lista di carico.

import '../../inventory/inventory_movement_key.code.dart';
import '../../inventory/inventory_quick_load.code.dart';
import '../../login/mgws/query/query_mgws_inventory_models.dart';
import 'rfid_gs1.dart';

enum RfidResolutionSource { gs1, table, none }

class RfidTagScanRow {
  const RfidTagScanRow({
    required this.raw,
    required this.epc,
    this.gtin,
    this.serial,
    this.productId,
    this.variationId,
    this.productName,
    this.resolution = RfidResolutionSource.none,
    this.reason,
  });

  /// Valore esatto ricevuto dal lettore: non viene mai riscritto.
  final String raw;

  /// Chiave di dedup e di lookup, derivata da [raw].
  final String epc;

  /// Dettagli GS1 decodificati localmente, conservati anche senza associazione.
  final String? gtin;
  final String? serial;

  final int? productId;
  final int? variationId;
  final String? productName;
  final RfidResolutionSource resolution;

  /// Codice del motivo quando non c'e' associazione. I codici sono those
  /// usati dal backend e tradotti nella GUI.
  final String? reason;

  bool get isAssociated => productId != null && productId! > 0;

  static String normalizeEpc(String raw) {
    var value = raw.trim().toUpperCase();
    const prefixes = <String>['URN:EPC:TAG:SGTIN-96:', 'URN:EPC:RAW:'];
    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        break;
      }
    }
    return value.replaceAll(RegExp(r'[\s-]'), '');
  }

  static const Object _unset = Object();

  RfidTagScanRow copyWith({
    String? raw,
    String? epc,
    Object? gtin = _unset,
    Object? serial = _unset,
    Object? productId = _unset,
    Object? variationId = _unset,
    Object? productName = _unset,
    RfidResolutionSource? resolution,
    Object? reason = _unset,
  }) {
    return RfidTagScanRow(
      raw: raw ?? this.raw,
      epc: epc ?? this.epc,
      gtin: identical(gtin, _unset) ? this.gtin : gtin as String?,
      serial: identical(serial, _unset) ? this.serial : serial as String?,
      productId: identical(productId, _unset)
          ? this.productId
          : productId as int?,
      variationId: identical(variationId, _unset)
          ? this.variationId
          : variationId as int?,
      productName: identical(productName, _unset)
          ? this.productName
          : productName as String?,
      resolution: resolution ?? this.resolution,
      reason: identical(reason, _unset) ? this.reason : reason as String?,
    );
  }
}

class InventoryRfidScanController {
  final List<RfidTagScanRow> _rows = <RfidTagScanRow>[];

  List<RfidTagScanRow> get rows => List<RfidTagScanRow>.unmodifiable(_rows);

  List<RfidTagScanRow> get associatedRows =>
      List<RfidTagScanRow>.unmodifiable(_rows.where((row) => row.isAssociated));

  List<RfidTagScanRow> get unassociatedRows =>
      List<RfidTagScanRow>.unmodifiable(
        _rows.where((row) => !row.isAssociated),
      );

  /// Aggiunge i tag grezzi deduplicando sull'EPC normalizzato. L'ordine e'
  /// quello della prima lettura: un tag rivisto non sposta la riga.
  void addRawTags(Iterable<String> rawTags) {
    for (final raw in rawTags) {
      final epc = RfidTagScanRow.normalizeEpc(raw);
      if (epc.isEmpty) continue;
      if (_rows.any((row) => row.epc == epc)) continue;
      final decoded = RfidGs1Decoder.decodeSgtin96(epc);
      _rows.add(
        RfidTagScanRow(
          raw: raw,
          epc: epc,
          gtin: decoded?.gtin,
          serial: decoded?.serial,
        ),
      );
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= _rows.length) return;
    _rows.removeAt(index);
  }

  /// Chiede a MGWS la catena `split`: GTIN prima, tabella EPC come fallback.
  /// I GTIN sono quelli decodificati in locale. In caso di errore le righe
  /// restano tutte non associate, ma il testo letto e i dettagli GS1 restano.
  Future<void> resolve({required MgwsInventoryGateway gateway}) async {
    if (_rows.isEmpty) return;

    final tagIds = _rows.map((row) => row.epc).toList(growable: false);
    final gtinHints = <String, String>{
      for (final row in _rows)
        if (row.gtin != null) row.epc: row.gtin!,
    };

    late final MgwsRfidScanResult result;
    try {
      result = await gateway.resolveRfidScan(
        tagIds: tagIds,
        gtinHints: gtinHints,
        lookup: 'split',
      );
    } catch (_) {
      _markUnavailable();
      rethrow;
    }

    if (!result.success) {
      _markUnavailable();
      return;
    }

    final resolvedByTag = <String, MgwsResolvedTag>{
      for (final entry in result.resolved)
        RfidTagScanRow.normalizeEpc(entry.tag): entry,
    };

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final entry = resolvedByTag[row.epc];
      if (entry == null || entry.productId == null || entry.productId! <= 0) {
        _rows[index] = _withoutAssociation(row);
        continue;
      }
      _rows[index] = row.copyWith(
        productId: entry.productId,
        variationId: entry.variationId,
        productName: entry.productName,
        resolution: _resolution(entry.resolution),
        reason: null,
      );
    }
  }

  /// Una riga per prodotto associato. La chiave di idempotenza e' nuova per
  /// ogni riga: due EPC dello stesso prodotto diventano quantita' 2 in Add.
  List<InventoryQuickLoadLineDraft> toLoadLines() {
    return List<InventoryQuickLoadLineDraft>.unmodifiable(
      associatedRows.map(
        (row) => InventoryQuickLoadLineDraft(
          productId: row.productId!,
          variationId: row.variationId ?? 0,
          label: (row.productName ?? '').trim().isEmpty
              ? row.epc
              : row.productName!.trim(),
          quantity: 1,
          idempotencyKey: newInventoryMovementKey(),
          barcode: row.epc,
        ),
      ),
    );
  }

  void _markUnavailable() {
    for (var index = 0; index < _rows.length; index++) {
      _rows[index] = _rows[index].copyWith(
        productId: null,
        variationId: null,
        productName: null,
        resolution: RfidResolutionSource.none,
        reason: 'mgws_unavailable',
      );
    }
  }

  RfidTagScanRow _withoutAssociation(RfidTagScanRow row) {
    return row.copyWith(
      productId: null,
      variationId: null,
      productName: null,
      resolution: RfidResolutionSource.none,
      reason: row.gtin != null ? 'not_associated' : 'epc_not_registered',
    );
  }

  RfidResolutionSource _resolution(String? value) {
    switch (value) {
      case 'gs1':
        return RfidResolutionSource.gs1;
      case 'table':
      case 'barcode':
        return RfidResolutionSource.table;
      default:
        return RfidResolutionSource.none;
    }
  }
}
