import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_settings.dart';
import 'product_image_settings.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

class ProdottiSettingsTab extends StatefulWidget {
  const ProdottiSettingsTab({super.key});

  @override
  State<ProdottiSettingsTab> createState() => _ProdottiSettingsTabState();
}

class _ProdottiSettingsTabState extends State<ProdottiSettingsTab> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  bool _didInitControllers = false;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppSettings, ProductImageWarningSettings>(
      builder: (context, appSettings, imageSettings, child) {
        if (!_didInitControllers) {
          _widthController.text = imageSettings.thresholdWidth.toString();
          _heightController.text = imageSettings.thresholdHeight.toString();
          _didInitControllers = true;
        }

        return ListView(
          padding: context.spacing.iL,
          children: [
            _buildSectionHeader(context, context.l10n.settingsProdottiDeletion),
            _buildForceDeleteSwitch(context, appSettings),
            const SizedBox(height: 8),
            _buildConfirmDeleteSwitch(context, appSettings),
            const SizedBox(height: 8),
            _buildAttributeCaseModeCard(context, appSettings),
            const SizedBox(height: 8),
            _buildPersistFiltersSwitch(context, appSettings),
            const SizedBox(height: 8),
            _buildHideOutOfStockSwitch(context, appSettings),
            const Divider(height: 32),
            _buildSectionHeader(context, context.l10n.settingsProdottiImages),
            _buildImageWarningSwitch(context, imageSettings),
            const SizedBox(height: 8),
            _buildWarningThresholdsCard(context, imageSettings),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.l),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildForceDeleteSwitch(BuildContext context, AppSettings settings) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.settingsProdottiForceDelete),
        subtitle: Text(
          settings.forceDelete
              ? context.l10n.settingsProdottiForceDeleteOn
              : context.l10n.settingsProdottiForceDeleteOff,
        ),
        secondary: Icon(
          settings.forceDelete ? Icons.delete_forever : Icons.delete,
          color: Theme.of(context).primaryColor,
        ),
        value: settings.forceDelete,
        onChanged: (value) => settings.setForceDelete(value),
      ),
    );
  }

  Widget _buildConfirmDeleteSwitch(BuildContext context, AppSettings settings) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.settingsProdottiConfirmDelete),
        subtitle: Text(
          settings.confirmDelete
              ? context.l10n.settingsProdottiConfirmDeleteOn
              : context.l10n.settingsProdottiConfirmDeleteOff,
        ),
        secondary: Icon(Icons.warning, color: Theme.of(context).primaryColor),
        value: settings.confirmDelete,
        onChanged: (value) => settings.setConfirmDelete(value),
      ),
    );
  }

  Widget _buildAttributeCaseModeCard(
    BuildContext context,
    AppSettings settings,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.text_fields),
        title: Text(context.l10n.settingsProdottiAttributeCase),
        subtitle: DropdownButtonFormField<String>(
          initialValue: settings.attributeCaseMode,
          decoration: const InputDecoration(isDense: true),
          items: [
            DropdownMenuItem(
              value: 'upper',
              child: Text(context.l10n.settingsProdottiCaseUpper),
            ),
            DropdownMenuItem(
              value: 'lower',
              child: Text(context.l10n.settingsProdottiCaseLower),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            settings.setAttributeCaseMode(value);
          },
        ),
      ),
    );
  }

  Widget _buildPersistFiltersSwitch(
    BuildContext context,
    AppSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.settingsProdottiPersistFilters),
        subtitle: Text(
          settings.persistProductFilters
              ? context.l10n.settingsProdottiPersistFiltersOn
              : context.l10n.settingsProdottiPersistFiltersOff,
        ),
        secondary: Icon(
          Icons.filter_alt,
          color: Theme.of(context).primaryColor,
        ),
        value: settings.persistProductFilters,
        onChanged: (value) => settings.setPersistProductFilters(value),
      ),
    );
  }

  Widget _buildHideOutOfStockSwitch(
    BuildContext context,
    AppSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.settingsProdottiHideOutOfStock),
        subtitle: Text(context.l10n.settingsProdottiHideOutOfStockDescription),
        secondary: Icon(
          Icons.visibility_off,
          color: Theme.of(context).primaryColor,
        ),
        value: settings.hideOutOfStockProducts,
        onChanged: (value) => settings.setHideOutOfStockProducts(value),
      ),
    );
  }

  Widget _buildImageWarningSwitch(
    BuildContext context,
    ProductImageWarningSettings settings,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(context.l10n.settingsProdottiImageWarning),
        subtitle: Text(
          settings.warningsEnabled
              ? context.l10n.settingsProdottiImageWarningOn
              : context.l10n.settingsProdottiImageWarningOff,
        ),
        secondary: Icon(
          Icons.warning_amber_outlined,
          color: Theme.of(context).primaryColor,
        ),
        value: settings.warningsEnabled,
        onChanged: (value) => settings.setWarningsEnabled(value),
      ),
    );
  }

  Widget _buildWarningThresholdsCard(
    BuildContext context,
    ProductImageWarningSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.settingsProdottiThresholds,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsProdottiThresholdsDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.settingsProdottiWidthThreshold,
                      suffixText: 'px',
                      isDense: true,
                    ),
                    onFieldSubmitted: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null) settings.setThresholdWidth(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.settingsProdottiHeightThreshold,
                      suffixText: 'px',
                      isDense: true,
                    ),
                    onFieldSubmitted: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null) settings.setThresholdHeight(parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  final width = int.tryParse(_widthController.text.trim());
                  final height = int.tryParse(_heightController.text.trim());
                  if (width != null) await settings.setThresholdWidth(width);
                  if (height != null) await settings.setThresholdHeight(height);
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(context.l10n.settingsProdottiSaveThresholds),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
