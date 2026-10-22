import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'checkout_settings.dart';
import '../notification/app_notification.dart';
import '../notification/notification_bell.gui.dart';
import '../notification/notification_center.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import '../l10n/locale_settings.dart';

/// Impostazioni generali operative dell'app.
class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  late final TextEditingController _sedeController;

  @override
  void initState() {
    super.initState();
    _sedeController = TextEditingController(text: cassaSettings.sede);
  }

  @override
  void dispose() {
    _sedeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider.value(
      value: cassaSettings,
      child: Consumer<CassaSettings>(
        builder: (context, settings, _) => ListView(
          padding: context.spacing.iL,
          children: [
            Text(
              context.l10n.settingsGeneral,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsGeneralDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const _SezioneLingua(),
            const SizedBox(height: 20),
            TextField(
              controller: _sedeController,
              decoration: InputDecoration(
                labelText: context.l10n.settingsGeneralSede,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.store),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsGeneralSedeDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await settings.setValori(sede: _sedeController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.settingsGeneralSaved)),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: Text(context.l10n.commonSave),
            ),
            const SizedBox(height: 28),
            const _SezioneNotifiche(),
          ],
        ),
      ),
    );
  }
}

/// Selettore della lingua dell'interfaccia.
///
/// E' una combobox con la lingua di sistema in cima, poi le lingue supportate.
/// Sulla voce di sistema viene mostrata anche la lingua effettiva, cosi si vede
/// su cosa cade la scelta quando il sistema usa una lingua non supportata.
/// Cambiare lingua ricostruisce l'intera interfaccia senza riavviare l'app.
class _SezioneLingua extends StatelessWidget {
  const _SezioneLingua();

  /// Valore interno della combobox per "segui il sistema".
  ///
  /// Non si usa `null` come valore della dropdown perche' con `null`
  /// l'opzione selezionata non viene renderizzata e il campo resta vuoto.
  static const String _valoreSistema = '__sistema__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impostazioni = context.watch<LocaleSettings>();
    final attuale = impostazioni.lingua?.languageCode ?? _valoreSistema;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.translate, size: 18),
            const SizedBox(width: 8),
            Text(
              context.l10n.settingsLanguage,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.settingsLanguageDescription,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: attuale,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.translate),
          ),
          items: [
            DropdownMenuItem(
              value: _valoreSistema,
              child: Text(
                // Con il sistema l'utente non vede a cosa si risolve la scelta,
                // quindi mostriamo la lingua effettiva accanto all'opzione.
                '${context.l10n.settingsLanguageSystem} '
                '(${impostazioni.nomeLinguaAttiva})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final locale in LocaleSettings.supportate)
              DropdownMenuItem(
                value: locale.languageCode,
                child: Text(
                  LocaleSettings.nomiNativi[locale.languageCode] ??
                      locale.languageCode,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (valore) {
            if (valore == null) return;
            impostazioni.impostaLingua(
              valore == _valoreSistema ? null : Locale(valore),
            );
          },
        ),
      ],
    );
  }
}

/// Interruttori dei tipi di notifica mostrati nella campanella in AppBar.
class _SezioneNotifiche extends StatelessWidget {
  const _SezioneNotifiche();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = NotificationCenter.instance;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.notificationsSettingsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.notificationsSettingsDescription,
            style: theme.textTheme.bodySmall,
          ),
          for (final kind in AppNotificationKind.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(notificationKindLabel(context.l10n, kind)),
              value: center.isEnabled(kind),
              onChanged: (enabled) => center.setEnabled(kind, enabled),
            ),
        ],
      ),
    );
  }
}
