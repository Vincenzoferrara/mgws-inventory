// inventory_product_section.gui.dart
//
// Sezione "Prodotti e quantita'" condivisa dai moduli Aggiungi, Rettifica e
// Sposta.
//
// Tutti e tre hanno la stessa identica esigenza: scegliere dei prodotti, con
// il barcode o dal catalogo, e tenere sotto gli occhi la lista di quello che
// si sta per toccare. Cambia solo cosa succede dopo la scelta, e quello resta
// al pannello.
//
// Qui vivono anche la barra barcode in stile cassa, il bottone del selettore e
// la spunta "1 pezzo senza chiedere": l'operatore impara una schermata sola e
// non tre.

import 'package:flutter/material.dart';

import '../reuse_class/barcode/barcode_scanner.dart';
import '../reuse_class/datagridview/datagridview_image_preview.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory_quick_load.code.dart';

typedef InventoryProductSectionBarcodeLauncher =
    Future<String?> Function(BuildContext context);

/// Riga prodotta dalla sezione: dice che il prodotto e' stato scelto e con
/// quale barcode.
///
/// [InventoryQuickLoadLineDraft] riusa cosi' il modulo Aggiungi non deve
/// tradurre nulla e i tre pannelli parlano lo stesso dato.
typedef InventoryProductSectionLine = InventoryQuickLoadLineDraft;

/// Sezione di scelta dei prodotti.
///
/// Il pannello decide cosa fare con [lines] tramite [onBarcodeEntered],
/// [onPickExisting], [onRemoveLine] e [trailingBuilder]. La sezione non sa
/// nulla di magazzino: si limita a raccogliere prodotti e a lasciarli leggere.
class InventoryProductSection extends StatefulWidget {
  const InventoryProductSection({
    super.key,
    required this.title,
    required this.lines,
    required this.autoAdd,
    required this.onAutoAddChanged,
    required this.onBarcodeEntered,
    required this.onPickExisting,
    required this.onRemoveLine,
    this.icon = Icons.inventory_2_outlined,
    this.trailingBuilder,
    this.autoAddTrailing,
    this.barcodeLauncher,
    this.busy = false,
    this.emptyHint,
    this.autoAddLabel,
    this.askQuantityLabel,
    this.keyPrefix = 'inventory-section',
  });

  /// Numero e titolo della sezione, es. '3. Prodotti e quantita'.
  final String title;
  final IconData icon;
  final List<InventoryProductSectionLine> lines;

  /// Spunta "1 pezzo senza chiedere". Ogni modulo le da' il nome adatto, ma
  /// il significato e' sempre lo stesso: se e' attiva si va con la quantita'
  /// minima, se no l'operatore la dice.
  final bool autoAdd;
  final ValueChanged<bool> onAutoAddChanged;

  /// Etichette della spunta. Sono nullable perche' il testo vive nelle
  /// traduzioni: il default si risolve in `build`, dove il contesto esiste.
  final String? autoAddLabel;
  final String? askQuantityLabel;

  /// Risolve un barcode e aggiunge il prodotto. Risponde true se il prodotto
  /// e' entrato: e' il segnale che il campo puo' svuotarsi, cosi' un barcode
  /// gia' letto non resta scritto e non invites a raddoppiare i pezzi.
  final Future<bool> Function(String code) onBarcodeEntered;

  /// "Aggiungi prodotto esistente": apre il selettore condiviso con la cassa.
  final Future<void> Function() onPickExisting;

  final void Function(String key) onRemoveLine;

  /// Controlli che il singolo prodotto si porta dietro: quantita', verso della
  /// correzione, magazzino di partenza. Null se al prodotto non serve altro
  /// che la quantita' di default.
  final Widget Function(BuildContext context, InventoryProductSectionLine line)?
  trailingBuilder;

  /// Altro controllo della sezione, accanto alla spunta.
  ///
  /// Sta qui perche' la spunta e' gia' la risposta alla domanda "che faccio
  /// quando scanno un barcode", e nei moduli dove la domanda ha due parti
  /// (per esempio "quanti pezzi" e "in aumento o in diminuzione") la seconda
  /// parte va letta insieme alla prima, non riga per riga: se sta nella riga
  /// compare solo dopo la scansione, e cioe' quando ormai serve.
  final Widget? autoAddTrailing;

  final InventoryProductSectionBarcodeLauncher? barcodeLauncher;
  final bool busy;

  /// Testo del riquadro "nessun prodotto". `null` = testo predefinito localized.
  final String? emptyHint;

  /// Anticipo delle chiavi dei widget. Ogni modulo mantiene il proprio, cosi'
  /// ogni pannello e' rintracciabile nei test anche dentro la sezione
  /// condivisa.
  final String keyPrefix;

  @override
  State<InventoryProductSection> createState() =>
      _InventoryProductSectionState();
}

class _InventoryProductSectionState extends State<InventoryProductSection> {
  final _barcodeController = TextEditingController();
  bool _scanning = false;

  // Chiavi dei widget interni. Ogni modulo ha il proprio anticipo, cosi'
  // ogni pannello resta rintracciabile nei test anche dentro la sezione
  // condivisa.

  /// Chiave del campo barcode, es. 'inventory-add-barcode-field'.
  String get _barcodeFieldKey => '${widget.keyPrefix}-barcode-field';

  /// Chiave del bottone "Aggiungi prodotto esistente".
  String get _openExistingKey => '${widget.keyPrefix}-open-existing';

  /// Chiave della spunta del modo rapido.
  String get _autoCheckboxKey => '${widget.keyPrefix}-auto-checkbox';

  /// Chiave dell'etichetta che cambia a seconda della spunta.
  String get _autoLabelKey => '${widget.keyPrefix}-auto-label';

  /// Chiave del riquadro "nessun prodotto".
  String get _emptyKey => '${widget.keyPrefix}-empty';

  /// Chiave della riga prodotto, [key] e' l'identita' del prodotto.
  String _lineKey(String key) => '${widget.keyPrefix}-line-$key';

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  /// Aggiunge il barcode scritto nel campo.
  ///
  /// Viene da Invio sulla tastiera: e' l'unico modo per usare il campo a mano,
  /// dato che il campo non ha un bottone dedicato.
  Future<void> _addFromField() async {
    final value = _barcodeController.text.trim();
    if (value.isEmpty) return;
    await _add(value);
  }

  /// Scansiona con la fotocamera e aggiunge quello che esce.
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final code = widget.barcodeLauncher == null
        ? await showBarcodeScanner(context)
        : await widget.barcodeLauncher!(context);
    if (!mounted) return;
    setState(() => _scanning = false);
    final value = code?.trim();
    if (value == null || value.isEmpty) return;
    await _add(value);
  }

  Future<void> _add(String code) async {
    final added = await widget.onBarcodeEntered(code);
    if (added) _barcodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return InventorySectionCard(
      icon: widget.icon,
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBarRow(context),
          const SizedBox(height: 8),
          _buildAutoAddRow(context),
          const SizedBox(height: 10),
          if (widget.lines.isEmpty)
            _EmptySelection(
              keyName: _emptyKey,
              hint:
                  widget.emptyHint ?? context.l10n.inventoryVuotoNessunProdotto,
            )
          else
            Column(
              children: [
                for (final line in widget.lines) _buildLine(context, line),
              ],
            ),
        ],
      ),
    );
  }

  /// Barra barcode in stile cassa: un solo campo, la scansione con la
  /// fotocamera e affianco il pulsante per scegliere i prodotti a mano. Il
  /// barcode scritto a mano si conferma con Invio, quindi il campo non ha
  /// bisogno di un bottone che lo aggiunga.
  Widget _buildBarRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final affiancato = constraints.maxWidth >= 460;
        final busy = widget.busy || _scanning;
        final field = TextField(
          key: ValueKey(_barcodeFieldKey),
          controller: _barcodeController,
          style: Theme.of(context).textTheme.bodyMedium,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.l10n.inventoryHintInserisciOscansionaBarcode,
            prefixIcon: const Icon(Icons.qr_code),
            suffixIcon: IconButton(
              tooltip: context.l10n.inventoryTooltipScansionaBarcode,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: busy ? null : _scan,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSubmitted: (_) => _addFromField(),
        );
        final button = FilledButton.tonalIcon(
          key: ValueKey(_openExistingKey),
          onPressed: widget.busy ? null : widget.onPickExisting,
          icon: const Icon(Icons.playlist_add_check),
          label: Text(context.l10n.inventoryAggiungiProdottoEsistente),
        );
        // Affiancati quando c'e' spazio, uno sotto l'altro quando no: il campo
        // barcode non deve diventare una fessura per far spazio all'etichetta
        // del pulsante.
        if (!affiancato) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 8), button],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }

  Widget _buildAutoAddRow(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          key: ValueKey(_autoCheckboxKey),
          value: widget.autoAdd,
          onChanged: widget.busy
              ? null
              : (value) => widget.onAutoAddChanged(value ?? true),
        ),
        Flexible(
          child: Text(
            widget.autoAdd
                ? widget.autoAddLabel ??
                      context.l10n.inventoryAutoAddUnPezzoSenzaChiedere
                : widget.askQuantityLabel ??
                      context.l10n.inventoryAutoAddChiediQuantita,
            key: ValueKey(_autoLabelKey),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (widget.autoAddTrailing != null) ...[
          const SizedBox(width: 12),
          // Flexible e' obbligatorio: la Row padre non da' larghezza infinita,
          // ma senza vincolo il trailing prenderebbe tutto lo spazio residuo
          // come infinito e i suoi controlli non avrebbero dove andare.
          Flexible(child: widget.autoAddTrailing!),
        ],
      ],
    );
  }

  Widget _buildLine(BuildContext context, InventoryProductSectionLine line) {
    final theme = Theme.of(context);
    final trailing = widget.trailingBuilder?.call(context, line);
    return Container(
      key: ValueKey(_lineKey(line.key)),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DataGridViewImagePreview(
                imageUrl: line.imageUrl,
                semanticLabel: context.l10n.inventorySemanticaCopertina(
                  line.label,
                ),
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (line.barcodeInterno?.trim().isNotEmpty == true)
                      Text(
                        context.l10n.inventoryBarcodeValore(
                          line.barcodeInterno!,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonDelete,
                onPressed: () => widget.onRemoveLine(line.key),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 8), trailing],
        ],
      ),
    );
  }
}

/// Riga vuota: dice che manca ancora un prodotto, senza far sembrare che il
/// pannello sia rotto.
class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.keyName, required this.hint});

  final String keyName;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Container(
      key: ValueKey(keyName),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 28, color: colors.subtitleColor),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Controlli +/- sulla quantita' di un prodotto.
class InventoryInlineQuantity extends StatelessWidget {
  const InventoryInlineQuantity({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.decreaseKey,
    this.increaseKey,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;

  /// Chiavi dei due tasti, per chi ha bisogno di reachingli da fuori (test, o
  /// un pannello che ricostruisce la riga).
  final Key? decreaseKey;
  final Key? increaseKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: decreaseKey,
          tooltip: context.l10n.inventoryTooltipRiduciQuantita,
          visualDensity: VisualDensity.compact,
          onPressed: quantity <= min ? null : () => onChanged(quantity - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$quantity', style: Theme.of(context).textTheme.titleSmall),
        IconButton(
          key: increaseKey,
          tooltip: context.l10n.inventoryTooltipAumentaQuantita,
          visualDensity: VisualDensity.compact,
          onPressed: max != null && quantity >= max!
              ? null
              : () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

/// Intestazione di sezione numerata, identica in tutti i pannelli di
/// magazzino.
///
/// Sezione piatta, senza box di contorno: icona, titolo e un sottile divisore,
/// con i campi direttamente sotto. E' l'unica forma di sezione del pannello,
/// cosi' le card non si annidano piu' l'una dentro l'altra.
class InventorySectionCard extends StatelessWidget {
  const InventorySectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.6)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
