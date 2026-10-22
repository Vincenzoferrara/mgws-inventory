// barcode_scanner.dart
//
// Modulo centralizzato per barcode/QR.
// Gestisce grafica, fotocamera, permessi/errori e restituisce al chiamante
// solo String? per compatibilita con le schermate esistenti.

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../../theme/theme.dart';
import '../../l10n/extensions.dart';

/// Schermata fullscreen per lo scanner di barcode/QR
class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final TextEditingController _manualController = TextEditingController();

  bool _isScanning = true;
  String? _scannerError;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _submitManualCode() {
    final code = _manualController.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  void _onBarcodeDetected(Code code) {
    if (!_isScanning) return;

    final String? value = code.text?.trim();

    if (code.isValid && value != null && value.isNotEmpty) {
      setState(() {
        _isScanning = false;
      });

      // Restituisci il codice e chiudi
      Navigator.of(context).pop(value);
    }
  }

  String _scannerErrorMessage(Object error) {
    final errorCode = _readErrorCodeName(error);
    return switch (errorCode) {
      'CameraAccessDenied' => context.l10n.scannerPermissionDenied,
      'permissionDenied' => context.l10n.scannerPermissionDenied,
      'unsupported' => context.l10n.scannerUnsupported,
      'controllerInitializing' => context.l10n.scannerInitializing,
      'controllerNotAttached' => context.l10n.scannerNotReady,
      'controllerDisposed' => context.l10n.scannerDisposed,
      'controllerUninitialized' => context.l10n.scannerUninitialized,
      _ => context.l10n.scannerUnavailable,
    };
  }

  String _readErrorCodeName(Object error) {
    try {
      final dynamic dyn = error;
      final dynamic code = dyn.errorCode ?? dyn.code;
      final dynamic name = code.name;
      return name?.toString() ?? code.toString().split('.').last;
    } catch (_) {
      return error.toString();
    }
  }

  void _onControllerCreated(CameraController? _, Exception? error) {
    if (!mounted || error == null) return;
    setState(() {
      _scannerError = _scannerErrorMessage(error);
    });
  }

  void _onScanFailure(Code code) {
    if (!mounted || code.error == null || code.error!.isEmpty) return;
    setState(() {
      _scannerError = _scannerErrorMessage(code.error!);
    });
  }

  Widget _buildManualFallback(String message) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.sharedBarcodeManuale,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitManualCode(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.commonCancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _submitManualCode,
                        icon: const Icon(Icons.keyboard_return),
                        label: Text(context.l10n.sharedUsaCodice),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.scannerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scanner view
            Expanded(
              child: _scannerError != null
                  ? _buildManualFallback(_scannerError!)
                  : Stack(
                      children: [
                        ReaderWidget(
                          onScan: _onBarcodeDetected,
                          onScanFailure: _onScanFailure,
                          onControllerCreated: _onControllerCreated,
                          codeFormat: Format.any,
                          tryHarder: true,
                          tryRotate: true,
                          cropPercent: 0.7,
                          resolution: ResolutionPreset.high,
                          showScannerOverlay: false,
                          showToggleCamera: false,
                          showGallery: false,
                          showFlashlight: true,
                          loading: const ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // Overlay con area di scansione
                        CustomPaint(
                          painter: ScannerOverlayPainter(
                            primaryColor: theme.primaryColor,
                          ),
                          child: Container(),
                        ),

                        // Indicatore stato
                        if (!_isScanning)
                          Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppTheme.successColor,
                                    size: 64,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    context.l10n.scannerCodeDetected,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // Footer con controlli
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.scannerHint,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
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
}

/// Painter per l'overlay dello scanner con area di scansione
class ScannerOverlayPainter extends CustomPainter {
  final Color primaryColor;

  ScannerOverlayPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final Rect scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Disegna l'overlay scuro
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path scanAreaPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(16)));

    final Path overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanAreaPath,
    );

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Disegna il bordo dell'area di scansione
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      paint,
    );

    // Disegna gli angoli
    const double cornerLength = 30;
    final cornerPaint = Paint()
      ..color = AppTheme.successColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Angolo in alto a sinistra
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // Angolo in alto a destra
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );

    // Angolo in basso a sinistra
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );

    // Angolo in basso a destra
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Funzione helper per aprire lo scanner a schermo intero.
Future<String?> showBarcodeScanner(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (context) => const BarcodeScannerDialog(),
    ),
  );
}
