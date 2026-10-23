import '../../l10n/error_text.dart';
import 'package:flutter/material.dart';
import 'smartcard_service.dart';
import '../../l10n/extensions.dart';
import '../../theme/theme.dart';
import '../gui/login.code.dart';
import '../../log_viewer/app_logger.dart';

/// Widget per il login tramite smartcard
class SmartcardLoginWidget extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const SmartcardLoginWidget({super.key, this.onLoginSuccess});

  @override
  State<SmartcardLoginWidget> createState() => _SmartcardLoginWidgetState();
}

class _SmartcardLoginWidgetState extends State<SmartcardLoginWidget> {
  final _smartcard = SmartcardService();
  final log = AppLogger();

  bool _isReading = false;
  bool _nfcAvailable = false;
  bool _usbAvailable = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _statusMessage = context.l10n.smartcardPreparazione;
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final nfc = await _smartcard.isNfcAvailable();
    final usb = await _smartcard.isUsbReaderAvailable();

    setState(() {
      _nfcAvailable = nfc;
      _usbAvailable = usb;
    });
  }

  Future<void> _readFromCard() async {
    setState(() {
      _isReading = true;
      _statusMessage = context.l10n.smartcardAvvicina;
    });

    try {
      final data = await _smartcard.readFromAnyCard();

      if (data != null) {
        // Usa le credenziali lette per fare login
        await loginCode.performLogin(
          siteUrl: data.siteUrl,
          username: data.username,
          password: data.password,
          customJwtEndpoint: data.customJwtEndpoint,
        );

        setState(() {
          _statusMessage = '✅ ${context.l10n.smartcardLoginOk}';
        });

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      } else {
        setState(() {
          _statusMessage = '❌ ${context.l10n.smartcardNoData}';
        });
      }
    } catch (e) {
      log.e('Error reading smartcard', e);
      setState(() {
        _statusMessage =
            '❌ ${context.l10n.smartcardErroreLettura(localizedErrorText(context.l10n, e))}';
      });
    } finally {
      setState(() {
        _isReading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_nfcAvailable && !_usbAvailable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.credit_card_off,
                size: 48,
                color: context.colors.neutralColor,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.smartcardNonDisponibile,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.smartcardNonSupportato,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.credit_card, color: theme.primaryColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.smartcardTitoloLogin,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.l10n.smartcardSottotitolo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colors.neutralColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Indicatori disponibilità
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_nfcAvailable)
                  _buildAvailabilityChip(
                    icon: Icons.nfc,
                    label: 'NFC',
                    available: true,
                  ),
                if (_usbAvailable)
                  _buildAvailabilityChip(
                    icon: Icons.usb,
                    label: 'USB',
                    available: true,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Bottone lettura
            ElevatedButton.icon(
              onPressed: _isReading ? null : _readFromCard,
              icon: _isReading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.tap_and_play),
              label: Text(
                _isReading
                    ? context.l10n.smartcardLetturaInCorso
                    : context.l10n.smartcardLeggi,
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // Messaggio di stato
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage!.startsWith('✅')
                      ? context.colors.successColor.withValues(alpha: 0.1)
                      : _statusMessage!.startsWith('❌')
                      ? context.colors.errorColorStatus.withValues(alpha: 0.1)
                      : context.colors.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage!.startsWith('✅')
                        ? context.colors.successColor
                        : _statusMessage!.startsWith('❌')
                        ? context.colors.errorColorStatus
                        : context.colors.infoColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage!.startsWith('✅')
                          ? Icons.check_circle
                          : _statusMessage!.startsWith('❌')
                          ? Icons.error
                          : Icons.info,
                      color: _statusMessage!.startsWith('✅')
                          ? context.colors.successColor
                          : _statusMessage!.startsWith('❌')
                          ? context.colors.errorColorStatus
                          : context.colors.infoColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Info aggiuntive
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.neutralColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.smartcardIstruzioneSalvataggio,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityChip({
    required IconData icon,
    required String label,
    required bool available,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: available
          ? context.colors.successColor.withValues(alpha: 0.2)
          : context.colors.neutralColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: available
            ? context.colors.successColor
            : context.colors.neutralColor,
      ),
    );
  }
}

/// Dialog per salvare le credenziali su smartcard
class SaveToSmartcardDialog extends StatefulWidget {
  final String siteUrl;
  final String username;
  final String password;
  final String? customJwtEndpoint;

  const SaveToSmartcardDialog({
    super.key,
    required this.siteUrl,
    required this.username,
    required this.password,
    this.customJwtEndpoint,
  });

  @override
  State<SaveToSmartcardDialog> createState() => _SaveToSmartcardDialogState();
}

class _SaveToSmartcardDialogState extends State<SaveToSmartcardDialog> {
  final _smartcard = SmartcardService();
  final log = AppLogger();

  bool _isWriting = false;
  String _statusMessage = '';
  CardType _selectedType = CardType.nfc;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final nfc = await _smartcard.isNfcAvailable();
    final usb = await _smartcard.isUsbReaderAvailable();

    setState(() {
      if (nfc) {
        _selectedType = CardType.nfc;
        _statusMessage = context.l10n.smartcardAvvicinaNfc;
      } else if (usb) {
        _selectedType = CardType.usb;
        _statusMessage = context.l10n.smartcardInserisciUsb;
      } else {
        _statusMessage = context.l10n.smartcardNessunLettore;
      }
    });
  }

  Future<void> _writeToCard() async {
    setState(() {
      _isWriting = true;
      _statusMessage = context.l10n.smartcardScritturaInCorso;
    });

    try {
      final data = SmartcardData(
        siteUrl: widget.siteUrl,
        username: widget.username,
        password: widget.password,
        customJwtEndpoint: widget.customJwtEndpoint,
      );

      bool success = false;

      switch (_selectedType) {
        case CardType.nfc:
          success = await _smartcard.writeToNfcCard(data);
          break;
        case CardType.usb:
          success = await _smartcard.writeToUsbCard(data);
          break;
        case CardType.rfid:
          // TODO: Implementa RFID
          break;
      }

      if (success && mounted) {
        setState(() {
          _statusMessage = '✅ Credenziali salvate sulla smartcard!';
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (mounted) {
        setState(() {
          _statusMessage = '❌ ${context.l10n.smartcardSaveFailed}';
        });
      }
    } catch (e) {
      log.e('Error writing to smartcard', e);
      if (mounted) {
        setState(() {
          _statusMessage =
              '❌ ${context.l10n.smartcardErroreLettura(localizedErrorText(context.l10n, e))}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWriting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.credit_card),
          const SizedBox(width: 12),
          Text(context.l10n.loginSalvaSuSmartcard),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusMessage,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_isWriting)
            const CircularProgressIndicator()
          else
            Icon(Icons.tap_and_play, size: 64, color: theme.primaryColor),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isWriting ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _isWriting ? null : _writeToCard,
          child: Text(context.l10n.loginScriviSuSmartcard),
        ),
      ],
    );
  }
}
