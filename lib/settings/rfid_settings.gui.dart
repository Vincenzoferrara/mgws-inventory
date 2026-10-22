import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './app_settings.dart';
import '../notification/notification_service.dart';
import '../rfid/rfid.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

/// Tab delle impostazioni RFID
class RFIDSettingsTab extends StatefulWidget {
  const RFIDSettingsTab({super.key});

  @override
  State<RFIDSettingsTab> createState() => _RFIDSettingsTabState();
}

class _RFIDSettingsTabState extends State<RFIDSettingsTab> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _timeoutController = TextEditingController();
  String _connectionType = 'USB'; // USB, WiFi
  String _selectedDevice = 'Nessuno'; // Lista dispositivi

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final appSettings = Provider.of<AppSettings>(context, listen: false);
    _ipController.text = await appSettings.getRFIDSetting('ip') ?? '';
    _portController.text = await appSettings.getRFIDSetting('port') ?? '8080';
    _timeoutController.text =
        await appSettings.getRFIDSetting('timeout') ?? '5000';
    _connectionType =
        await appSettings.getRFIDSetting('connection_type') ?? 'USB';
    _selectedDevice =
        await appSettings.getRFIDSetting('selected_device') ?? 'Nessuno';
    setState(() {});
  }

  Future<void> _saveSettings() async {
    final appSettings = Provider.of<AppSettings>(context, listen: false);
    await appSettings.setRFIDSetting('ip', _ipController.text);
    await appSettings.setRFIDSetting('port', _portController.text);
    await appSettings.setRFIDSetting('timeout', _timeoutController.text);
    await appSettings.setRFIDSetting('connection_type', _connectionType);
    await appSettings.setRFIDSetting('selected_device', _selectedDevice);
    NotificationService.instance.messageBar(
      'successo',
      'rfid_settings',
      context.l10n.settingsRfidSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.settingsRfidTitle,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _connectionType,
            decoration: InputDecoration(
              labelText: context.l10n.settingsRfidConnectionType,
              border: const OutlineInputBorder(),
            ),
            items: ['USB', 'WiFi']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _connectionType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_connectionType == 'WiFi') ...[
            TextFormField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: context.l10n.settingsRfidIpAddress,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: context.l10n.settingsRfidPort,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _timeoutController,
            decoration: InputDecoration(
              labelText: context.l10n.settingsRfidTimeout,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDevice,
            decoration: InputDecoration(
              labelText: context.l10n.settingsRfidSelectedDevice,
              border: const OutlineInputBorder(),
            ),
            items: ['Nessuno', 'Zebra FX7500', 'Chainway C72', 'Altro']
                .map(
                  (device) => DropdownMenuItem(
                    value: device,
                    child: Text(switch (device) {
                      'Nessuno' => context.l10n.settingsRfidDeviceNone,
                      'Altro' => context.l10n.settingsRfidDeviceOther,
                      _ => device,
                    }),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedDevice = value!;
              });
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              await _saveSettings();
              // Test connessione usando RFIDManager
              NotificationService.instance.messageBar(
                'info',
                'rfid_settings',
                context.l10n.settingsRfidTestRunning,
              );
              final rfidManager = RFIDManager();
              await rfidManager.init();
              final connected = await rfidManager.connect();
              if (connected) {
                final testResult = await rfidManager.testConnection();
                NotificationService.instance.messageBar(
                  testResult ? 'successo' : 'errore',
                  'rfid_settings',
                  testResult
                      ? context.l10n.settingsRfidTestOk
                      : context.l10n.settingsRfidTestFailed,
                );
              } else {
                NotificationService.instance.messageBar(
                  'errore',
                  'rfid_settings',
                  context.l10n.settingsRfidConnectionFailed,
                );
              }
            },
            child: Text(context.l10n.settingsRfidTestButton),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }
}
