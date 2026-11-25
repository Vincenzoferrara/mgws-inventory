import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_auth.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_connection.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';

class _FakeTransport implements MgwsInventoryTransport {
  _FakeTransport(this.response);

  final MgwsInventoryResponse response;

  String? patchedPath;
  Map<String, Object?>? patchedData;

  @override
  Future<MgwsInventoryResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async => response;

  @override
  Future<MgwsInventoryResponse> post(
    String path, {
    Map<String, Object?>? data,
  }) async => response;

  @override
  Future<MgwsInventoryResponse> patch(
    String path, {
    Map<String, Object?>? data,
  }) async {
    patchedPath = path;
    patchedData = data;
    return response;
  }

  @override
  Future<MgwsInventoryResponse> delete(String path) async => response;
}

class _ConnectedConnection extends MgwsConnection {
  @override
  Future<bool> ensureConnected() async => true;
}

void main() {
  test('PATCH sends the absolute quantity, not a delta', () {
    const request = MgwsMovementEditRequest(
      quantity: 0,
      note: 'riveduto',
      unitCost: '12.50',
    );

    expect(request.toJson(), <String, Object?>{
      'quantity': 0,
      'note': 'riveduto',
      'unit_cost': '12.50',
    });
  });

  test('the audited PATCH response is parsed', () {
    final edit = MgwsMovementEdit.fromMap(<String, Object?>{
      'operation': 'movement_edit',
      'movement_id': 6,
      'ledger_movement_id': 6,
      'product_id': 43,
      'variation_id': 0,
      'quantity': 0,
      'previous_quantity': 2,
      'quantity_delta': -2,
      'previous_stock': 3,
      'current_stock': 1,
      'noop': false,
    });

    expect(edit, isNotNull);
    expect(edit!.movementId, 6);
    expect(edit.quantity, 0);
    expect(edit.previousQuantity, 2);
    expect(edit.quantityDelta, -2);
    expect(edit.previousStock, 3);
    expect(edit.currentStock, 1);
    expect(edit.noop, isFalse);
  });

  test('patchMovement uses the ledger row path and the PATCH verb', () async {
    final transport = _FakeTransport(
      MgwsInventoryResponse(
        data: <String, Object?>{
          'ok': true,
          'operation': 'movement_edit',
          'movement_id': 6,
          'product_id': 43,
          'variation_id': 0,
          'quantity': 0,
          'previous_quantity': 2,
          'quantity_delta': -2,
          'previous_stock': 3,
          'current_stock': 1,
        },
        statusCode: 200,
      ),
    );
    final query = QueryMgwsInventory(
      transport: transport,
      mgwsConnection: _ConnectedConnection(),
    );

    final result = await query.patchMovement(
      6,
      const MgwsMovementEditRequest(quantity: 0),
    );

    expect(transport.patchedPath, QueryMgwsInventory.movementPath(6));
    expect(transport.patchedData, <String, Object?>{'quantity': 0});
    expect(result.success, isTrue);
    expect(result.data?.quantity, 0);
    expect(result.data?.previousQuantity, 2);
  });

  test('the app refuses a plugin without the movement edit route', () {
    expect(
      MgwsAuth.isVersionAtLeast('2.14.1', MgwsAuth.minPluginVersion),
      isFalse,
    );
  });
}
