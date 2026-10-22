import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/extensions.dart';
import '../theme/theme.dart';

final GlobalKey<ScaffoldMessengerState> notificationMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  void messageBar(String type, String nameTab, String message) {
    final messenger = notificationMessengerKey.currentState;
    final context = notificationMessengerKey.currentContext;
    if (messenger == null || context == null) return;

    final style = _resolveStyle(context, type);
    final cleanMessage = _cleanMessage(message);
    final title = _sectionTitle(context, nameTab);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(style.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '\n$cleanMessage',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      selectionControls: materialTextSelectionControls,
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: context.l10n.sharedCopia,
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cleanMessage));
            },
          ),
          backgroundColor: style.color,
          behavior: SnackBarBehavior.fixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: style.duration,
          // Con un'azione (Copia) Flutter tiene lo SnackBar a schermo finche
          // non lo si chiude: il messaggio restava sopra la barra delle
          // pagine. Deve sparire dopo `duration` come gli altri.
          persist: false,
        ),
      );
  }

  /// Il titolo del messaggio: `nameTab` e un tag interno della sezione
  /// (es. 'cassa', 'prodotti_crea'), qui diventa il nome tradotto.
  String _sectionTitle(BuildContext context, String nameTab) {
    final l10n = context.l10n;
    switch (nameTab) {
      case 'cassa':
        return l10n.homeTitoloCassa;
      case 'prodotti_crea':
        return l10n.homeTitoloNuovoProdotto;
      case 'prodotti':
      case 'prodotti_gestisci':
      case 'woocommerce_custom_fields':
        return l10n.homeTitoloProdotti;
      case 'media_selector_dialog':
        return l10n.notificationSourceMedia;
      case 'dashboard':
      case 'ads_comment_dialog':
        return l10n.homeTitoloDashboard;
      case 'log_viewer':
        return l10n.notificationSourceLogs;
      case 'carta_fedelta':
        return l10n.homeTitoloCarteFedelta;
      case 'coupon_gestisci':
        return l10n.homeTitoloCoupon;
      case 'rfid_settings':
        return l10n.settingsRfidTitle;
      case 'ai_settings':
        return l10n.settingsAiTitle;
      case 'ordini':
      case 'ordini_gestisci':
      case 'ordini_crea':
      case 'ordini_in_arrivo':
        return l10n.homeTitoloOrdini;
      case 'home':
        return l10n.homeTitoloHome;
      case 'report':
        return l10n.homeTitoloReport;
      default:
        return nameTab;
    }
  }

  _MessageBarStyle _resolveStyle(BuildContext context, String type) {
    final appColors = Theme.of(context).extension<AppColorExtension>();
    final normalizedType = type.trim().toLowerCase();

    switch (normalizedType) {
      case 'successo':
        return _MessageBarStyle(
          color: appColors?.successColor ?? Colors.green,
          icon: Icons.check_circle,
          duration: const Duration(seconds: 4),
        );
      case 'warning':
      case 'partial':
        return _MessageBarStyle(
          color: appColors?.warningColor ?? Colors.orange,
          icon: Icons.warning_amber_rounded,
          duration: const Duration(seconds: 6),
        );
      case 'info':
        return _MessageBarStyle(
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.info,
          duration: const Duration(seconds: 4),
        );
      case 'errore':
      default:
        return _MessageBarStyle(
          color: appColors?.errorColorStatus ?? Colors.red,
          icon: Icons.error_outline,
          duration: const Duration(seconds: 6),
        );
    }
  }

  String _cleanMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.startsWith('Exception:')) {
      return trimmed.substring('Exception:'.length).trim();
    }
    return trimmed;
  }
}

class _MessageBarStyle {
  const _MessageBarStyle({
    required this.color,
    required this.icon,
    required this.duration,
  });

  final Color color;
  final IconData icon;
  final Duration duration;
}
