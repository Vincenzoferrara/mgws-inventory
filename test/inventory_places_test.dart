import 'package:flutter_test/flutter_test.dart';

import 'package:mgws_inventory/inventory/inventory_adjustment.code.dart';
import 'package:mgws_inventory/inventory/inventory_move.code.dart';
import 'package:mgws_inventory/l10n/generated/app_localizations_it.dart';

void main() {
  final l10n = AppLocalizationsIt();
  const places = InventoryLocationDirectory(
    warehouses: <InventoryPlace>[
      InventoryPlace(id: 206, name: 'sottopiedi', siteId: 205),
    ],
  );

  test(
    'a level names its warehouse even when the shop list does not have it',
    () {
      final unassigned = InventoryStockLevel.fromRecord(<String, dynamic>{
        'site_id': 205,
        'warehouse_id': 11767,
        'qty': 2,
        'warehouse_name': 'Unassigned',
      });
      expect(unassigned.warehouseName, 'Unassigned');
      expect(places.levelWarehouseLabel(l10n, unassigned), 'Non assegnato');

      const known = InventoryStockLevel(
        siteId: 205,
        warehouseId: 206,
        qty: 3,
        warehouseName: 'x',
      );
      expect(places.levelWarehouseLabel(l10n, known), 'sottopiedi');

      const other = InventoryStockLevel(
        siteId: 205,
        warehouseId: 300,
        qty: 1,
        warehouseName: 'Retro',
      );
      expect(places.levelWarehouseLabel(l10n, other), 'Retro');

      const nameless = InventoryStockLevel(
        siteId: 205,
        warehouseId: 301,
        qty: 1,
        warehouseName: '#301',
      );
      expect(places.levelWarehouseLabel(l10n, nameless), 'Magazzino 301');
    },
  );
}
