import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../cassa/fiscal_register/fiscal_register_repository.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'cassa_settings.dart';

/// Vista impostazioni del modulo Cassa: nome/numero cassa fisica e turno.
class CassaSettingsTab extends StatefulWidget {
  const CassaSettingsTab({super.key});

  @override
  State<CassaSettingsTab> createState() => _CassaSettingsTabState();
}

class _CassaSettingsTabState extends State<CassaSettingsTab> {
  late final TextEditingController _cassaController;
  late final TextEditingController _posIdentifierController;

  @override
  void initState() {
    super.initState();
    _cassaController = TextEditingController(text: cassaSettings.nomeCassa);
    _posIdentifierController = TextEditingController(
      text: cassaSettings.posIdentifier,
    );
  }

  @override
  void dispose() {
    _cassaController.dispose();
    _posIdentifierController.dispose();
    super.dispose();
  }

  /// Valida e salva l'identificativo digitato dall'esercente.
  /// Validates and stores the identifier typed by the merchant.
  Future<void> _salvaIdentificatorePos(BuildContext context) async {
    final value = _posIdentifierController.text;
    final error = cassaSettings.validatePosIdentifier(value);
    if (error != null) {
      final motivo = switch (error) {
        'empty' => context.l10n.cassaPosIdentifierNonValido(
            context.l10n.cassaPosIdentifierVuoto,
          ),
        _ => context.l10n.cassaPosIdentifierNonValido(
            context.l10n.cassaPosIdentifierAiuto,
          ),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(motivo)),
      );
      return;
    }
    await cassaSettings.setPosIdentifier(value);
    _posIdentifierController.text = cassaSettings.posIdentifier;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cassaSalvato)),
    );
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
              context.l10n.cassaFisica,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.cassaNomeDescrizione,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cassaController,
              decoration: InputDecoration(
                labelText: context.l10n.cassaNomeNumero,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.point_of_sale),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.cassaPosIdentifierTitolo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.cassaPosIdentifierDescrizione,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _posIdentifierController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.l10n.cassaPosIdentifierEtichetta,
                helperText: context.l10n.cassaPosIdentifierAiuto,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: IconButton(
                  tooltip: context.l10n.cassaPosIdentifierCopia,
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: cassaSettings.posIdentifier),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.cassaPosIdentifierCopiato),
                      ),
                    );
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(
                    settings.posIdentifierIsGenerated
                        ? context.l10n.cassaPosIdentifierGenerato
                        : context.l10n.cassaPosIdentifierPersonalizzato,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _salvaIdentificatorePos(context),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.l10n.commonSave),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await settings.regeneratePosIdentifier();
                    _posIdentifierController.text = settings.posIdentifier;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.cassaPosIdentifierRigenerato),
                      ),
                    );
                  },
                  icon: const Icon(Icons.autorenew),
                  label: Text(context.l10n.cassaPosIdentifierRigenera),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.cassaRegistratoreTitolo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.cassaRegistratoreDescrizione,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ChangeNotifierProvider.value(
              value: fiscalRegisterRepository,
              child: Consumer<FiscalRegisterRepository>(
                builder: (context, fiscal, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: fiscal.activeDriverId,
                      decoration: InputDecoration(
                        labelText: context.l10n.cassaRegistratoreModalita,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                      ),
                      items: fiscal.availableDrivers
                          .map(
                            (driver) => DropdownMenuItem<String>(
                              value: driver.id,
                              child: Text(
                                driver.isFiscalDevice
                                    ? driver.displayName
                                    : context.l10n.cassaRegistratoreSimulazione,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        fiscal.setActiveDriver(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fiscal.isFiscalDevice
                          ? fiscal.activeDriver.displayName
                          : context.l10n.cassaRegistratoreSimulazioneDettaglio,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.turnoObbligatorio,
              title: Text(context.l10n.cassaTurnoObbligatorio),
              subtitle: Text(context.l10n.cassaTurnoSubtitle),
              secondary: const Icon(Icons.lock_clock),
              onChanged: (value) async {
                try {
                  await settings.setTurnoObbligatorio(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? context.l10n.cassaTurnoAttivato
                            : context.l10n.cassaTurnoDisattivato),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.cassaSalvataggioFallito(
                            '$error')),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await settings.setValori(nomeCassa: _cassaController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.cassaSalvato)),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: Text(context.l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
