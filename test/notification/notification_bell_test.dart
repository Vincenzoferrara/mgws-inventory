import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/notification/app_notification.dart';
import 'package:mgws_inventory/notification/notification_bell.gui.dart';
import 'package:mgws_inventory/notification/notification_center.dart';
import 'package:mgws_inventory/notification/providers/notification_provider.dart';
import 'package:mgws_inventory/traduzioni/estensioni.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StaticProvider extends NotificationProvider {
  _StaticProvider(this.result);

  final List<AppNotification> result;

  @override
  Set<AppNotificationKind> get kinds => AppNotificationKind.values.toSet();

  @override
  Duration get interval => const Duration(hours: 1);

  @override
  Future<List<AppNotification>> fetch() async => result;
}

void main() {
  testWidgets('badge, pannello e apertura della sezione', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final center = NotificationCenter(
      providers: [
        _StaticProvider(const [
          AppNotification(
            id: 'orders:unpaid',
            kind: AppNotificationKind.ordersUnpaid,
            priority: AppNotificationPriority.warning,
            revision: 2,
            count: 2,
            sectionId: 'ordini',
          ),
        ]),
      ],
    );
    await center.refresh();
    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBell(
                center: center,
                onOpenSection: (id) => opened = id,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Ordini non pagati'), findsOneWidget);
    expect(find.textContaining('non ancora pagati'), findsOneWidget);

    await tester.tap(find.text('Ordini non pagati'));
    await tester.pumpAndSettle();
    expect(opened, 'ordini');
    expect(center.unreadCount, 0);
    expect(find.text('1'), findsNothing);
  });
}
