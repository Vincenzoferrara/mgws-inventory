import 'package:flutter/foundation.dart';

import '../app_notification.dart';

/// Sorgente di notifiche per la campanella.
///
/// Per aggiungere un nuovo tipo di notifica basta un nuovo provider
/// registrato in [NotificationCenter]: la campanella non va toccata.
abstract class NotificationProvider {
  /// Tipi che questo provider puo produrre. Se sono tutti spenti nelle
  /// impostazioni il provider non viene interrogato.
  Set<AppNotificationKind> get kinds;

  /// Ogni quanto interrogare la sorgente.
  Duration get interval;

  /// `false` quando la sorgente non e utilizzabile adesso (es. utente non
  /// collegato): il provider viene saltato e le sue notifiche spariscono,
  /// senza attendere [interval] per riprovare.
  bool get isAvailable => true;

  /// Se notifica, il centro interroga subito il provider (es. cambio del
  /// nome cassa nelle impostazioni).
  Listenable? get trigger => null;

  Future<List<AppNotification>> fetch();
}
