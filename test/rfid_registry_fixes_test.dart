import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_connection.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/rfid/uhf/uhf_tag_assignment.code.dart';

class _NoopTransport implements MgwsInventoryTransport {
  const _NoopTransport();

  @override
  Future<MgwsInventoryResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async => const MgwsInventoryResponse(data: <dynamic>[], statusCode: 200);

  @override
  Future<MgwsInventoryResponse> post(
    String path, {
    Map<String, Object?>? data,
  }) async => const MgwsInventoryResponse(data: <dynamic>[], statusCode: 200);

  @override
  Future<MgwsInventoryResponse> patch(
    String path, {
    Map<String, Object?>? data,
  }) async => const MgwsInventoryResponse(data: <dynamic>[], statusCode: 200);

  @override
  Future<MgwsInventoryResponse> delete(String path) async =>
      const MgwsInventoryResponse(data: <dynamic>[], statusCode: 200);
}

class _RecordingTransport extends _NoopTransport {
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastData;

  @override
  Future<MgwsInventoryResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    lastQuery = queryParameters;
    return super.get(path, queryParameters: queryParameters);
  }

  @override
  Future<MgwsInventoryResponse> post(
    String path, {
    Map<String, Object?>? data,
  }) async {
    lastData = data;
    return const MgwsInventoryResponse(
      data: <String, Object?>{'epc': 'ABC', 'product_id': 9},
      statusCode: 200,
    );
  }
}

class _ConnectedConnection extends MgwsConnection {
  @override
  Future<bool> ensureConnected() async => true;
}

class _RfidGatewaySpy extends QueryMgwsInventory {
  _RfidGatewaySpy({MgwsRestockResult<dynamic>? listResponse})
    : super(
        transport: const _NoopTransport(),
        mgwsConnection: _ConnectedConnection(),
      ) {
    _listResponse =
        listResponse ?? MgwsRestockResult.success(<dynamic>[], message: 'ok');
  }

  late final MgwsRestockResult<dynamic> _listResponse;
  Completer<MgwsRestockResult<dynamic>>? pendingList;
  final List<Map<String, Object?>> upserts = <Map<String, Object?>>[];
  final List<String> deletes = <String>[];

  @override
  Future<MgwsRestockResult<dynamic>> listRfidTags({
    String? epc,
    int? productId,
    int? variationId,
  }) async {
    final pending = pendingList;
    return pending != null ? pending.future : _listResponse;
  }

  @override
  Future<MgwsRestockResult<dynamic>> upsertRfidTag({
    required String epc,
    int? productId,
    int? variationId,
  }) async {
    upserts.add(<String, Object?>{
      'epc': epc,
      'product_id': productId,
      'variation_id': variationId,
    });
    return MgwsRestockResult.success(<String, Object?>{}, message: 'ok');
  }

  @override
  Future<MgwsRestockResult<dynamic>> deleteRfidTag(String epc) async {
    deletes.add(epc);
    return MgwsRestockResult.success(<String, Object?>{}, message: 'ok');
  }
}

void main() {
  test('registry reads omit variation_id for a simple product', () async {
    final transport = _RecordingTransport();
    final query = QueryMgwsInventory(
      transport: transport,
      mgwsConnection: _ConnectedConnection(),
    );

    await query.listRfidTags(productId: 9, variationId: 0);

    expect(transport.lastQuery, <String, Object?>{'product_id': 9});
  });

  test('registry writes omit variation_id for a simple product', () async {
    final transport = _RecordingTransport();
    final query = QueryMgwsInventory(
      transport: transport,
      mgwsConnection: _ConnectedConnection(),
    );

    await query.upsertRfidTag(epc: 'ABC', productId: 9, variationId: 0);

    expect(transport.lastData, <String, Object?>{'epc': 'ABC', 'product_id': 9});
  });

  test('a failed scan request returns an unavailable result', () async {
    // No site is connected in this test isolate, so QueryMgwsBase.post throws
    // before any HTTP call is made.
    final query = QueryMgwsInventory(mgwsConnection: _ConnectedConnection());

    final result = await query.resolveRfidScan(tagIds: const <String>['ABC']);

    expect(result.success, isFalse);
    expect(result.resolved, isEmpty);
    expect(result.errors, isNotEmpty);
    expect(result.mode, 'resolve_only');
  });

  test('a staged unsaved variation is saved to its real variation id', () async {
    final gateway = _RfidGatewaySpy();
    final controller = RfidTagAssignmentController(gateway: gateway);

    controller.selectTarget(-1);
    expect(controller.addEpc('NEW-1'), isTrue);
    controller.applySavedVariationIds(const <int, int?>{-1: 77});
    await controller.save(10, 77);

    final upsert = gateway.upserts.singleWhere((row) => row['epc'] == 'NEW1');
    expect(upsert['product_id'], 10);
    expect(upsert['variation_id'], 77);
  });

  test('an unresolved unsaved variation is never saved as product level',
      () async {
    final gateway = _RfidGatewaySpy();
    final controller = RfidTagAssignmentController(gateway: gateway);

    controller.selectTarget(-2);
    expect(controller.addEpc('ORPHAN-1'), isTrue);
    controller.applySavedVariationIds(const <int, int?>{-1: 77});
    await controller.save(10, 0);

    expect(gateway.upserts.where((row) => row['epc'] == 'ORPHAN1'), isEmpty);
  });

  test('a late successful read keeps locally staged EPCs', () async {
    final gateway = _RfidGatewaySpy();
    final completer = Completer<MgwsRestockResult<dynamic>>();
    gateway.pendingList = completer;
    final controller = RfidTagAssignmentController(gateway: gateway);

    final load = controller.load(10, 0);
    await Future<void>.delayed(Duration.zero);
    expect(controller.addEpc('LOCAL-1'), isTrue);
    completer.complete(
      MgwsRestockResult.success(<dynamic>[<String, Object?>{'epc': 'SERVER-1'}]),
    );
    await load;

    expect(controller.epcsFor(0), contains('LOCAL-1'));
  });

  test('a removed saved variation deletes but does not insert EPCs', () async {
    final gateway = _RfidGatewaySpy(
      listResponse: MgwsRestockResult.success(<dynamic>[
        <String, Object?>{'epc': 'DEL-1'},
      ]),
    );
    final controller = RfidTagAssignmentController(gateway: gateway);

    await controller.load(10, 55);
    controller.selectTarget(55);
    controller.removeEpc('DEL-1');
    expect(controller.addEpc('ADD-1'), isTrue);
    controller.applySavedVariationIds(const <int, int?>{});
    await controller.save(10, 0);

    expect(gateway.deletes, contains('DEL1'));
    expect(gateway.upserts.where((row) => row['epc'] == 'ADD1'), isEmpty);
  });

  test('new variations are matched by attributes, not by response order',
      () async {
    final stagedSignatures = <int, Set<String>>{
      -1: const <String>{'size=m'},
      -2: const <String>{'size=l'},
    };
    // The server returns the two variations in the opposite order.
    final savedSignatures = <int, Set<String>>{
      88: const <String>{'size=l'},
      99: const <String>{'size=m'},
    };
    final idsByKey =
        RfidTagAssignmentController.matchVariationIdsBySignature(
      stagedSignatures: stagedSignatures,
      savedSignatures: savedSignatures,
    );

    expect(idsByKey, <int, int?>{-1: 99, -2: 88});

    final gateway = _RfidGatewaySpy();
    final controller = RfidTagAssignmentController(gateway: gateway);
    controller.selectTarget(-1);
    expect(controller.addEpc('NEW1'), isTrue);
    controller.selectTarget(-2);
    expect(controller.addEpc('NEW2'), isTrue);
    controller.applySavedVariationIds(idsByKey);
    await controller.save(10, 0);

    final first = gateway.upserts.singleWhere((row) => row['epc'] == 'NEW1');
    final second = gateway.upserts.singleWhere((row) => row['epc'] == 'NEW2');
    expect(first['variation_id'], 99);
    expect(second['variation_id'], 88);
  });

  test('an ambiguous attribute match is not assigned to a variation', () {
    final idsByKey = RfidTagAssignmentController.matchVariationIdsBySignature(
      stagedSignatures: const <int, Set<String>>{
        -1: <String>{'size=m'},
      },
      savedSignatures: const <int, Set<String>>{
        88: <String>{'size=m'},
        99: <String>{'size=m'},
      },
    );

    expect(idsByKey, isEmpty);
  });
}
