import 'package:flutter/material.dart';

import '../l10n/extensions.dart';
import '../reuse_class/barcode/barcode_scanner.dart';
import '../theme/theme.dart';

/// Barcode or article-code field of the till.
///
/// A USB/Bluetooth scanner types the code and an Enter, then the next code
/// right away: the field keeps the focus after each Enter and clears itself
/// once the item is in the cart. Article codes have letters ("MGWS-T-1"), so
/// the keyboard is a text one.
class CassaBarcodeField extends StatefulWidget {
  const CassaBarcodeField({super.key, required this.onCodice});

  /// Looks the code up and adds it; returns true when the field can be
  /// cleared (the item went into the cart).
  final Future<bool> Function(String codice) onCodice;

  @override
  State<CassaBarcodeField> createState() => _CassaBarcodeFieldState();
}

class _CassaBarcodeFieldState extends State<CassaBarcodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _invia([String? letto]) async {
    final codice = (letto ?? _controller.text).trim();
    if (codice.isEmpty || _busy) {
      _focus.requestFocus();
      return;
    }
    _busy = true;
    try {
      final aggiunto = await widget.onCodice(codice);
      if (!mounted) return;
      if (aggiunto) _controller.clear();
    } finally {
      _busy = false;
      if (mounted) _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colore = context.colors.onColoredSurface;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      style: TextStyle(color: colore),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        hintText: context.l10n.inventoryHintInserisciOscansionaBarcode,
        hintStyle: TextStyle(color: colore.withValues(alpha: 0.7)),
        prefixIcon: Icon(Icons.qr_code, color: colore),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.l10n.cassaAggiungiBarcode,
              icon: Icon(Icons.add_shopping_cart, color: colore),
              onPressed: _invia,
            ),
            IconButton(
              tooltip: context.l10n.cassaCancellaBarcode,
              icon: Icon(Icons.clear, color: colore),
              onPressed: () {
                _controller.clear();
                _focus.requestFocus();
              },
            ),
            IconButton(
              tooltip: context.l10n.cassaScansiona,
              icon: Icon(Icons.qr_code_scanner, color: colore),
              onPressed: () async {
                final letto = await showBarcodeScanner(context);
                if (letto != null && letto.isNotEmpty) await _invia(letto);
              },
            ),
          ],
        ),
        filled: true,
        fillColor: colore.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      // Without onEditingComplete Flutter drops the focus on Enter.
      onEditingComplete: () {},
      onSubmitted: (_) => _invia(),
    );
  }
}
