import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../l10n/extensions.dart';

/// Nomi dei provider IA mostrati nella richiesta di consenso.
const _providerNames = {
  'openai': 'OpenAI',
  'anthropic': 'Anthropic (Claude)',
  'google': 'Google AI (Gemini)',
  'mistral': 'Mistral AI',
};

/// Chiede una volta sola, per ogni provider cloud, il consenso a inviare
/// i dati del prodotto al servizio esterno. Ollama gira in locale e non
/// lo richiede. Restituisce `true` se la chiamata può partire.
Future<bool> ensureAiConsent(BuildContext context, AppSettings settings) async {
  final provider = await settings.getAiToken('ai_active_provider') ?? 'openai';
  if (provider == 'ollama') return true;

  final consentKey = 'ai_cloud_consent_$provider';
  if (await settings.getAiToken(consentKey) == 'true') return true;
  if (!context.mounted) return false;

  final l10n = context.l10n;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: Text(l10n.aiConsentTitle),
      content: Text(l10n.aiConsentBody(_providerNames[provider] ?? provider)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.aiConsentDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.aiConsentAccept),
        ),
      ],
    ),
  );

  if (accepted != true) return false;
  await settings.setAiToken(consentKey, 'true');
  return true;
}
