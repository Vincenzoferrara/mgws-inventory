/// Tipi di notifica mostrati nella campanella.
///
/// Ogni tipo si puo spegnere dalle impostazioni generali. Il testo visibile
/// non sta nel modello: la campanella lo compone dalle traduzioni, cosi un
/// cambio lingua aggiorna anche le notifiche gia caricate.
enum AppNotificationKind {
  update,
  ordersToFulfil,
  ordersUnpaid,
  lowStock,
  fiscalRegister,
}

enum AppNotificationPriority { info, warning, urgent }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.priority,
    this.revision = 0,
    this.count,
    this.value,
    this.details = const <String>[],
    this.sectionId,
  });

  /// Identificativo stabile: la stessa situazione mantiene lo stesso id tra
  /// un controllo e l'altro, cosi lo stato letto non si perde.
  final String id;
  final AppNotificationKind kind;
  final AppNotificationPriority priority;

  /// Livello della notifica (di solito il conteggio). Se sale oltre quello
  /// gia letto la notifica torna non letta: un ordine nuovo riaccende il
  /// badge, uno evaso no.
  final int revision;

  final int? count;

  /// Valore libero mostrato nel testo: versione, nome cassa.
  final String? value;

  /// Righe di dettaglio sotto il testo (es. prodotti sotto scorta).
  final List<String> details;

  /// Sezione della home da aprire al tocco.
  final String? sectionId;
}
