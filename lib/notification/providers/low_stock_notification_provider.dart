import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../login/jwt_api/query_woocommerce/woo_query_products.dart';
import '../app_notification.dart';
import 'notification_provider.dart';

/// Prodotti e varianti sotto la soglia "scorte basse" impostata sul prodotto
/// in WooCommerce. I prodotti senza soglia propria non vengono segnalati.
class LowStockNotificationProvider extends NotificationProvider {
  static const _maxDettagli = 5;

  @override
  Set<AppNotificationKind> get kinds => {AppNotificationKind.lowStock};

  @override
  Duration get interval => const Duration(minutes: 15);

  @override
  bool get isAvailable => PlatformManager.isReady;

  @override
  Future<List<AppNotification>> fetch() async {
    final List<ProdottoSottoScorta> prodotti = await PlatformManager.prodotti
        .getProdottiSottoScorta();
    if (prodotti.isEmpty) return const [];
    prodotti.sort((a, b) => a.giacenza.compareTo(b.giacenza));
    return [
      AppNotification(
        id: 'low-stock',
        kind: AppNotificationKind.lowStock,
        priority: AppNotificationPriority.warning,
        revision: prodotti.length,
        count: prodotti.length,
        details: [
          for (final prodotto in prodotti.take(_maxDettagli))
            '${prodotto.nome}: ${prodotto.giacenza} / ${prodotto.soglia}',
        ],
        sectionId: 'prodotti',
      ),
    ];
  }
}
