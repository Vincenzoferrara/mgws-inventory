import '../../updater/updater_service.dart';
import '../app_notification.dart';
import 'notification_provider.dart';

/// Segnala una versione dell'app piu recente di quella installata.
///
/// Resta nella campanella finche non si aggiorna; l'avviso a comparsa
/// all'avvio continua a uscire una sola volta per release.
class UpdateNotificationProvider extends NotificationProvider {
  UpdateNotificationProvider({UpdaterService? service})
    : _service = service ?? UpdaterService();

  final UpdaterService _service;

  @override
  Set<AppNotificationKind> get kinds => {AppNotificationKind.update};

  /// Le API GitHub limitano le chiamate anonime: basta qualche controllo al
  /// giorno.
  @override
  Duration get interval => const Duration(hours: 6);

  @override
  bool get isAvailable => UpdaterService.canCheckForUpdates;

  @override
  Future<List<AppNotification>> fetch() async {
    final version = await _service.availableUpdateVersion();
    if (version == null) return const [];
    return [
      AppNotification(
        id: 'update:$version',
        kind: AppNotificationKind.update,
        priority: AppNotificationPriority.info,
        value: version,
        sectionId: 'aggiornamenti',
      ),
    ];
  }
}
