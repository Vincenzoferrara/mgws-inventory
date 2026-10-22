import 'package:flutter/foundation.dart';

import '../../checkout/fiscal_register/fiscal_register_repository.dart';
import '../../settings/checkout_settings.dart';
import '../app_notification.dart';
import 'notification_provider.dart';

/// Registratore di cassa non raggiungibile.
///
/// Attivo solo se in Impostazioni > Cassa e impostato il nome/numero cassa:
/// senza cassa configurata non c'e nessun registratore da controllare.
class FiscalRegisterNotificationProvider extends NotificationProvider {
  @override
  Set<AppNotificationKind> get kinds => {AppNotificationKind.fiscalRegister};

  @override
  Duration get interval => const Duration(minutes: 5);

  /// Impostare o cancellare il nome cassa aggiorna subito la campanella.
  @override
  Listenable? get trigger => cassaSettings;

  @override
  Future<List<AppNotification>> fetch() async {
    await cassaSettings.init();
    if (!cassaSettings.hasCassa) return const [];
    await fiscalRegisterRepository.init();
    if (await fiscalRegisterRepository.isDeviceAvailable()) return const [];
    final nomeCassa = cassaSettings.nomeCassa;
    return [
      AppNotification(
        id: 'fiscal-register:$nomeCassa',
        kind: AppNotificationKind.fiscalRegister,
        priority: AppNotificationPriority.urgent,
        value: nomeCassa,
        sectionId: 'cassa',
      ),
    ];
  }
}
