import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/notification/app_notification.dart';
import 'package:mgws_inventory/notification/notification_center.dart';
import 'package:mgws_inventory/notification/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProvider extends NotificationProvider {
  _FakeProvider(this.kinds, {this.trigger});

  @override
  final Set<AppNotificationKind> kinds;
  @override
  Duration get interval => const Duration(minutes: 5);
  @override
  final Listenable? trigger;

  bool available = true;
  Object? error;
  List<AppNotification> result = const [];
  int calls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<List<AppNotification>> fetch() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

AppNotification _orders(int count) => AppNotification(
  id: 'orders:processing',
  kind: AppNotificationKind.ordersToFulfil,
  priority: AppNotificationPriority.warning,
  revision: count,
  count: count,
);

const _update = AppNotification(
  id: 'update:1.0.30',
  kind: AppNotificationKind.update,
  priority: AppNotificationPriority.info,
  value: '1.0.30',
);

const _register = AppNotification(
  id: 'fiscal-register:Cassa 1',
  kind: AppNotificationKind.fiscalRegister,
  priority: AppNotificationPriority.urgent,
  value: 'Cassa 1',
);

void main() {
  late DateTime now;
  late _FakeProvider orders;
  late _FakeProvider updates;
  late NotificationCenter center;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 18, 9);
    orders = _FakeProvider({AppNotificationKind.ordersToFulfil});
    updates = _FakeProvider({AppNotificationKind.update});
    center = NotificationCenter(providers: [orders, updates], clock: () => now);
  });

  test('unisce i provider e mette in cima i piu urgenti', () async {
    final register = _FakeProvider({AppNotificationKind.fiscalRegister})
      ..result = const [_register];
    updates.result = const [_update];
    orders.result = [_orders(3)];
    center = NotificationCenter(
      providers: [updates, orders, register],
      clock: () => now,
    );

    await center.refresh();

    expect(center.notifications.map((n) => n.id), [
      'fiscal-register:Cassa 1',
      'orders:processing',
      'update:1.0.30',
    ]);
    expect(center.unreadCount, 3);
  });

  test('letta resta letta finche il conteggio non sale', () async {
    orders.result = [_orders(3)];
    await center.refresh();
    await center.markRead(center.notifications.single);
    expect(center.unreadCount, 0);

    // Un ordine evaso: niente badge.
    orders.result = [_orders(2)];
    await center.refresh(force: true);
    expect(center.unreadCount, 0);

    // Un ordine nuovo rispetto all'ultimo controllo: badge di nuovo acceso.
    orders.result = [_orders(3)];
    await center.refresh(force: true);
    expect(center.unreadCount, 1);
  });

  test('lo stato letto sopravvive al riavvio', () async {
    updates.result = const [_update];
    await center.refresh();
    await center.markAllRead();

    final restarted = NotificationCenter(
      providers: [updates],
      clock: () => now,
    );
    await restarted.refresh();
    expect(restarted.notifications, hasLength(1));
    expect(restarted.unreadCount, 0);
  });

  test('una notifica sparita e poi ricomparsa torna non letta', () async {
    updates.result = const [_update];
    await center.refresh();
    await center.markAllRead();

    updates.result = const [];
    await center.refresh(force: true);
    updates.result = const [_update];
    await center.refresh(force: true);

    expect(center.unreadCount, 1);
  });

  test('un provider in errore tiene le ultime notifiche', () async {
    orders.result = [_orders(4)];
    updates.result = const [_update];
    await center.refresh();

    orders.error = Exception('rete giu');
    await center.refresh(force: true);

    expect(
      center.notifications.map((n) => n.id),
      contains('orders:processing'),
    );
    expect(center.notifications, hasLength(2));
  });

  test('rispetta l intervallo di ogni provider', () async {
    await center.refresh();
    expect(orders.calls, 1);

    now = now.add(const Duration(minutes: 2));
    await center.refresh();
    expect(orders.calls, 1);

    now = now.add(const Duration(minutes: 4));
    await center.refresh();
    expect(orders.calls, 2);
  });

  test('provider non disponibile: saltato e notifiche tolte', () async {
    orders.result = [_orders(2)];
    await center.refresh();
    expect(center.notifications, hasLength(1));

    orders.available = false;
    await center.refresh();
    expect(center.notifications, isEmpty);

    // Appena torna disponibile viene interrogato subito.
    orders.available = true;
    await center.refresh();
    expect(orders.calls, 2);
    expect(center.notifications, hasLength(1));
  });

  test('un tipo spento non viene mostrato ne interrogato', () async {
    orders.result = [_orders(2)];
    await center.setEnabled(AppNotificationKind.ordersToFulfil, false);
    await center.refresh(force: true);

    expect(center.notifications, isEmpty);
    expect(orders.calls, 0);

    await center.setEnabled(AppNotificationKind.ordersToFulfil, true);
    expect(center.notifications, hasLength(1));
  });

  test('il trigger interroga subito solo il suo provider', () async {
    final trigger = ChangeNotifier();
    final register = _FakeProvider({
      AppNotificationKind.fiscalRegister,
    }, trigger: trigger);
    center = NotificationCenter(
      providers: [orders, register],
      clock: () => now,
    );
    await center.start();
    expect(register.calls, 1);
    expect(orders.calls, 1);

    register.result = const [_register];
    trigger.notifyListeners();
    await pumpEventQueue();

    expect(register.calls, 2);
    expect(orders.calls, 1);
    expect(center.notifications.single.id, 'fiscal-register:Cassa 1');
    center.stop();
  });
}
