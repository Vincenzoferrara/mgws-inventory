import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mgws_inventory/inventory/inventory_add_products.code.dart';
import 'package:mgws_inventory/inventory/inventory_add_products.gui.dart';
import 'package:mgws_inventory/inventory/inventory_module.code.dart';
import 'package:mgws_inventory/inventory/inventory_movement_groups.code.dart';
import 'package:mgws_inventory/inventory/inventory_quick_load.code.dart';
import 'package:mgws_inventory/inventory/inventory_restock_feedback.code.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_connection.dart';
import 'package:mgws_inventory/login/mgws/query/query_mgws_inventory.dart';
import 'package:mgws_inventory/theme/theme.dart';

class _FakeTransport implements MgwsInventoryTransport {
  final List<Map<String, Object?>?> patched = [];

  @override
  Future<MgwsInventoryResponse> get(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async => const MgwsInventoryResponse(data: <String, Object?>{});

  @override
  Future<MgwsInventoryResponse> post(
    String path, {
    Map<String, Object?>? data,
  }) async => const MgwsInventoryResponse(data: <String, Object?>{});

  @override
  Future<MgwsInventoryResponse> patch(
    String path, {
    Map<String, Object?>? data,
  }) async {
    patched.add(data);
    return MgwsInventoryResponse(
      data: <String, Object?>{
        'ok': true,
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
      },
      statusCode: 200,
    );
  }

  @override
  Future<MgwsInventoryResponse> delete(String path) async =>
      const MgwsInventoryResponse(data: <String, Object?>{});
}

class _ConnectedConnection extends MgwsConnection {
  @override
  Future<bool> ensureConnected() async => true;
}

MgwsMovement _seedMovement(int id) => MgwsMovement(
  id: id,
  movementId: id + 1,
  occurredAtGmt: '2026-11-24T10:00:00Z',
  type: 'load',
  stockEffect: 'load',
  productId: 43,
  variationId: 0,
  quantityDelta: 2,
  stockBefore: 1,
  stockAfter: 3,
  location: const MgwsLocation(
    siteId: 1,
    warehouseId: 0,
    room: '',
    rack: '',
    shelf: '',
  ),
  warehouseFrom: 0,
  warehouseTo: 0,
  operatorUserId: 1,
  reasonCode: 'quick_load',
  note: '',
  sourceType: 'quick_load',
  sourceId: 0,
  sourceLineId: 0,
  sourceLinks: const {},
);

void main() {
  test('an edit plan keeps an absolute zero quantity', () {
    const plan = InventoryMovementEditPlan(
      lines: [
        InventoryMovementEditLine(movementId: 6, quantity: 0),
      ],
    );

    final parsed = plan.parse();
    expect(parsed, isA<InventoryFormValid<List<InventoryMovementEditTarget>>>());
    final targets = (parsed as InventoryFormValid<
      List<InventoryMovementEditTarget>
    >)
        .value;
    expect(targets.single.movementId, 6);
    expect(targets.single.request.toJson()['quantity'], 0);
  });

  test('an edit plan rejects a negative quantity', () {
    const plan = InventoryMovementEditPlan(
      lines: [
        InventoryMovementEditLine(movementId: 6, quantity: -1),
      ],
    );

    expect(plan.parse(), isA<InventoryFormInvalid<dynamic>>());
  });

  test('submitEditPlan sends PATCH with the absolute quantity', () async {
    final transport = _FakeTransport();
    final controller = InventoryAddProductsController(
      quickLoadController: InventoryQuickLoadController(
        gateway: QueryMgwsInventory(
          transport: transport,
          mgwsConnection: _ConnectedConnection(),
        ),
      ),
    );

    final feedback = await controller.submitEditPlan(
      const InventoryMovementEditPlan(
        lines: [InventoryMovementEditLine(movementId: 6, quantity: 0)],
      ),
    );

    expect(feedback.success, isTrue);
    expect(transport.patched, [
      <String, Object?>{'quantity': 0},
    ]);
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a seeded Add panel loads the movement quantity, even zero', (
    tester,
  ) async {
    final seed = InventoryPanelSeed(
      module: InventoryModule.add,
      movements: [
        MgwsMovement(
          id: 6,
          movementId: 3,
          occurredAtGmt: '2026-11-24T10:00:00Z',
          type: 'load',
          stockEffect: 'load',
          productId: 43,
          variationId: 0,
          quantityDelta: 2,
          stockBefore: 1,
          stockAfter: 3,
          location: const MgwsLocation(
            siteId: 1,
            warehouseId: 0,
            room: '',
            rack: '',
            shelf: '',
          ),
          warehouseFrom: 0,
          warehouseTo: 0,
          operatorUserId: 1,
          reasonCode: 'quick_load',
          note: 'riveduto',
          sourceType: 'quick_load',
          sourceId: 0,
          sourceLineId: 0,
          sourceLinks: const {},
        ),
      ],
      products: const [],
      reason: 'quick_load',
      details: 'riveduto',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('it'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InventoryAddProductsPanel(
            seed: seed,
            controller: InventoryAddProductsController(
              quickLoadController: InventoryQuickLoadController(
                gateway: QueryMgwsInventory(
                  transport: _FakeTransport(),
                  mgwsConnection: _ConnectedConnection(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('inventory-add-edit-badge')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('the seeded Add panel can lower a quantity to zero', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('it'));
    final seed = InventoryPanelSeed(
      module: InventoryModule.add,
      movements: [
        MgwsMovement(
          id: 6,
          movementId: 3,
          occurredAtGmt: '2026-11-24T10:00:00Z',
          type: 'load',
          stockEffect: 'load',
          productId: 43,
          variationId: 0,
          quantityDelta: 2,
          stockBefore: 1,
          stockAfter: 3,
          location: const MgwsLocation(
            siteId: 1,
            warehouseId: 0,
            room: '',
            rack: '',
            shelf: '',
          ),
          warehouseFrom: 0,
          warehouseTo: 0,
          operatorUserId: 1,
          reasonCode: 'quick_load',
          note: '',
          sourceType: 'quick_load',
          sourceId: 0,
          sourceLineId: 0,
          sourceLinks: const {},
        ),
      ],
      products: const [],
      reason: 'quick_load',
      details: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('it'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InventoryAddProductsPanel(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decrease = find.byTooltip(l10n.inventoryTooltipRiduciQuantita);
    expect(decrease, findsOneWidget);
    await tester.tap(decrease);
    await tester.pump();
    await tester.tap(decrease);
    await tester.pump();

    expect(find.text('0'), findsWidgets);
    expect(find.byKey(const ValueKey('inventory-add-edit-badge')), findsOneWidget);
  });

  test('the seed stamp identifies the exact movement being reopened', () {
    InventoryPanelSeed seedFor(int id) => InventoryPanelSeed(
      module: InventoryModule.add,
      movements: [_seedMovement(id)],
      products: const [],
      reason: 'quick_load',
      details: '',
    );

    expect(seedFor(6).stamp, seedFor(6).stamp);
    expect(seedFor(6).stamp, isNot(seedFor(7).stamp));
  });
}
