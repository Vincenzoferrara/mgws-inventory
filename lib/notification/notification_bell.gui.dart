import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'app_notification.dart';
import 'notification_center.dart';

/// Campanella in AppBar con il numero di notifiche non lette.
///
/// Su desktop apre un pannello a tendina, su smartphone ([compact]) un
/// bottom sheet. Toccando una notifica la si segna letta e si apre la
/// sezione collegata tramite [onOpenSection].
class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.onOpenSection,
    this.compact = false,
    NotificationCenter? center,
  }) : _center = center;

  final void Function(String sectionId) onOpenSection;
  final bool compact;
  final NotificationCenter? _center;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final MenuController _menuController = MenuController();

  NotificationCenter get _center =>
      widget._center ?? NotificationCenter.instance;

  void _toggle() {
    _center.refresh();
    if (widget.compact) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: _NotificationPanel(
              center: _center,
              onSelect: (notification) {
                Navigator.of(sheetContext).pop();
                _select(notification);
              },
            ),
          ),
        ),
      );
      return;
    }
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
  }

  void _select(AppNotification notification) {
    _center.markRead(notification);
    final sectionId = notification.sectionId;
    if (sectionId != null) widget.onOpenSection(sectionId);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-300, 4),
      menuChildren: [
        SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: _NotificationPanel(
              center: _center,
              onSelect: (notification) {
                _menuController.close();
                _select(notification);
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => ListenableBuilder(
        listenable: _center,
        builder: (context, _) {
          final unread = _center.unreadCount;
          return IconButton(
            tooltip: context.l10n.notificationsTooltip,
            onPressed: _toggle,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: context.colors.errorColorStatus,
              child: Icon(
                unread > 0
                    ? Icons.notifications_active
                    : Icons.notifications_none,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.center, required this.onSelect});

  final NotificationCenter center;
  final void Function(AppNotification notification) onSelect;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final notifications = center.notifications;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.notificationsTitle,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (center.isRefreshing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  TextButton(
                    onPressed: center.unreadCount > 0
                        ? center.markAllRead
                        : null,
                    child: Text(context.l10n.notificationsMarkAllRead),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 32,
                      color: context.colors.subtitleColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.notificationsEmpty,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.subtitleColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Niente ListView: MenuAnchor misura le dimensioni intrinseche
              // del contenuto, che un viewport pigro non sa calcolare. Le
              // notifiche sono poche, una colonna scorrevole basta.
              Flexible(
                child: SingleChildScrollView(
                  // Il menu ha gia il suo scroll: senza primary false entrambi
                  // prenderebbero il PrimaryScrollController.
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, notification)
                          in notifications.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        _NotificationTile(
                          notification: notification,
                          unread: center.isUnread(notification),
                          onTap: () => onSelect(notification),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.onTap,
  });

  final AppNotification notification;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.priority) {
      AppNotificationPriority.urgent => context.colors.errorColorStatus,
      AppNotificationPriority.warning => context.colors.warningColor,
      AppNotificationPriority.info => context.colors.infoColor,
    };
    final (title, message) = _texts(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(_icon, color: color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (unread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
      subtitle: Text(
        [message, ...notification.details].join('\n'),
        style: context.text.bodySmall,
      ),
      isThreeLine: notification.details.isNotEmpty,
    );
  }

  IconData get _icon => switch (notification.kind) {
    AppNotificationKind.update => Icons.system_update,
    AppNotificationKind.ordersToFulfil => Icons.local_shipping_outlined,
    AppNotificationKind.ordersUnpaid => Icons.money_off,
    AppNotificationKind.lowStock => Icons.inventory_2_outlined,
    AppNotificationKind.fiscalRegister => Icons.point_of_sale,
  };

  (String, String) _texts(BuildContext context) {
    final l10n = context.l10n;
    final count = notification.count ?? 0;
    final value = notification.value ?? '';
    return switch (notification.kind) {
      AppNotificationKind.update => (
        l10n.notificationsUpdateTitle,
        l10n.notificationsUpdateMessage(value),
      ),
      AppNotificationKind.ordersToFulfil => (
        l10n.notificationsOrdersToFulfilTitle,
        l10n.notificationsOrdersToFulfilMessage(count),
      ),
      AppNotificationKind.ordersUnpaid => (
        l10n.notificationsOrdersUnpaidTitle,
        l10n.notificationsOrdersUnpaidMessage(count),
      ),
      AppNotificationKind.lowStock => (
        l10n.notificationsLowStockTitle,
        l10n.notificationsLowStockMessage(count),
      ),
      AppNotificationKind.fiscalRegister => (
        l10n.notificationsFiscalRegisterTitle,
        l10n.notificationsFiscalRegisterMessage(value),
      ),
    };
  }
}

/// Etichetta del tipo di notifica, usata negli interruttori delle impostazioni.
String notificationKindLabel(AppLocalizations l10n, AppNotificationKind kind) {
  return switch (kind) {
    AppNotificationKind.update => l10n.notificationsUpdateTitle,
    AppNotificationKind.ordersToFulfil => l10n.notificationsOrdersToFulfilTitle,
    AppNotificationKind.ordersUnpaid => l10n.notificationsOrdersUnpaidTitle,
    AppNotificationKind.lowStock => l10n.notificationsLowStockTitle,
    AppNotificationKind.fiscalRegister => l10n.notificationsFiscalRegisterTitle,
  };
}
