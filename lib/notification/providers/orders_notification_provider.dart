import '../../login/jwt_api/adapter/platform_manager.dart';
import '../app_notification.dart';
import 'notification_provider.dart';

/// Ordini WooCommerce da evadere e ordini non ancora pagati.
///
/// "Da evadere" sono gli ordini `processing` (pagati, da preparare).
/// "Non pagati" sono `pending` (in attesa di pagamento) e `on-hold` (es.
/// bonifico non ancora confermato): non vanno spediti finche non risultano
/// incassati.
class OrdersNotificationProvider extends NotificationProvider {
  @override
  Set<AppNotificationKind> get kinds => {
    AppNotificationKind.ordersToFulfil,
    AppNotificationKind.ordersUnpaid,
  };

  @override
  Duration get interval => const Duration(minutes: 3);

  @override
  bool get isAvailable => PlatformManager.isReady;

  @override
  Future<List<AppNotification>> fetch() async {
    final ordini = PlatformManager.ordini;
    final counts = await Future.wait<int>([
      ordini.countOrdersByStatus('processing'),
      ordini.countOrdersByStatus('pending'),
      ordini.countOrdersByStatus('on-hold'),
    ]);
    final daEvadere = counts[0];
    final nonPagati = counts[1] + counts[2];
    return [
      if (daEvadere > 0)
        AppNotification(
          id: 'orders:processing',
          kind: AppNotificationKind.ordersToFulfil,
          priority: AppNotificationPriority.warning,
          revision: daEvadere,
          count: daEvadere,
          sectionId: 'ordini',
        ),
      if (nonPagati > 0)
        AppNotification(
          id: 'orders:unpaid',
          kind: AppNotificationKind.ordersUnpaid,
          priority: AppNotificationPriority.warning,
          revision: nonPagati,
          count: nonPagati,
          sectionId: 'ordini',
        ),
    ];
  }
}
