// Avviso "MGWS non disponibile", condiviso dal dialog della home e dalle
// schermate che mostrano una parte MGWS dentro una pagina che si apre anche
// senza (Impostazioni).

import 'package:flutter/material.dart';

import '../../l10n/extensions.dart';
import '../../login/mgws/connection/mgws_auth.dart';
import '../../login/mgws/connection/mgws_connection.dart';

/// Testo dell'avviso per il motivo dato.
///
/// Rete irraggiungibile, servizio spento, plugin vecchio e sessione assente
/// chiedono interventi diversi, quindi ognuno ha la sua frase.
String mgwsUnavailableMessage(
  AppLocalizations l10n,
  MgwsUnavailableReason reason,
) {
  return switch (reason) {
    MgwsUnavailableReason.noSession => l10n.mgwsNonDisponibileMessaggio,
    MgwsUnavailableReason.unreachable => l10n.mgwsNonRaggiungibile,
    MgwsUnavailableReason.serviceDisabled => l10n.mgwsServizioSpento,
    MgwsUnavailableReason.pluginOutdated => l10n.mgwsPluginDaAggiornare(
      MgwsConnection.instance.pluginVersion ?? '?',
      MgwsAuth.minPluginVersion,
    ),
    MgwsUnavailableReason.unknown => l10n.mgwsNonDisponibileMessaggio,
  };
}

/// Riquadro con lo stesso titolo e testo del dialog della home, da mettere al
/// posto della parte che senza MGWS non funziona.
class MgwsUnavailableNotice extends StatelessWidget {
  const MgwsUnavailableNotice({super.key, required this.reason, this.onRetry});

  final MgwsUnavailableReason reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('mgws-unavailable-notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.mgwsNonDisponibileTitolo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(mgwsUnavailableMessage(l10n, reason)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.sedeRiprova),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
