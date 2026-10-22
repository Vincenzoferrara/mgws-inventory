// inventory_adjustment.gui.dart
//
// Pannello "Rettifica": allinea la quantita reale del magazzino a quella che
// MGWS ha registrato.
//
// La scelta dei prodotti e' la stessa sezione di Aggiungi e Sposta: si
// scansiona il barcode o si prende dal catalogo, e la lista mostra tutto quello
// che si sta per toccare. Poi ogni prodotto riceve la sua correzione.
//
// La spunta in testa alla sezione sceglie il modo di correggere:
//  - spuntata: l'operatore sceglie il verso con le due radio (incremento o
//    diminuzione) e poi quanti pezzi
//  - non spuntata: l'operatore scrive la quantita' davvero contata

import 'dart:async';

import 'package:flutter/material.dart';

import '../login/mgws/query/query_mgws_inventory.dart';
import '../products/product_list/product_picker.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';
import 'inventory.code.dart';
import 'inventory_module.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_product_section.gui.dart';

class InventoryRettificaPanel extends StatefulWidget {
  const InventoryRettificaPanel({
    super.key,
    this.controller,
    this.catalogController,
    this.barcodeLauncher,
    this.detailsController,
    this.siteController,
    this.seed,
  });

  final InventoryRettificaController? controller;
  final InventoryQuickLoadCatalogController? catalogController;
  final InventoryProductSectionBarcodeLauncher? barcodeLauncher;

  /// Sede del movimento, di proprieta' della pagina: il campo sta sopra i
  /// dettagli e vale per tutti i moduli che la usano. Il pannello la legge
  /// per costruire il piano e non la scrive; quando e' valorizzata dalla
  /// pagina la sede e' gia' decisa, perche' il backend accetta solo quella
  /// per l'operatore.
  final TextEditingController? siteController;

  /// Dettagli del movimento, di proprieta' della pagina: il pannello li legge
  /// per costruire il piano e non li tocca.
  final TextEditingController? detailsController;

  /// Riapertura di un movimento del ledger: quando arriva, il pannello si
  /// riempie con i prodotti di quel movimento e il suo motivo.
  final InventoryPanelSeed? seed;

  @override
  State<InventoryRettificaPanel> createState() =>
      _InventoryRettificaPanelState();
}

/// Cosa sapeva il ledger di un prodotto del movimento riaperto.
///
/// Resta in lista anche quando l'operatore toglie la riga: il movimento
/// originale ha gia' cambiato lo stock di quel prodotto, quindi toglierlo dalla
/// lista non puo' valere come "lascia stare", altrimenti il prodotto resterebbe
/// con la quantita' di quel movimento. Da qui il piano lo rimette a posto.
class _SeedProduct {
  _SeedProduct(this.movement);

  final MgwsMovement movement;

  /// Stock letto adesso: serve al controllo che il prodotto non sia stato
  /// toccato da altri dopo il movimento.
  InventoryStockSnapshot? snapshot;

  String get key => '${movement.productId}:${movement.variationId}';
}

/// Stato di correzione di un singolo prodotto.
///
/// Ogni prodotto ha il suo: la rettifica e' una correzione per prodotto, non
/// una correzione unica da ripetere.
class _RettificaRow {
  _RettificaRow({
    required this.productId,
    required this.variationId,
    required this.label,
    this.imageUrl,
    this.barcodeInterno,
    this.direction = InventoryRettificaDirection.increase,
  });

  final int productId;
  final int variationId;
  final String label;
  final String? imageUrl;
  final String? barcodeInterno;
  final countedController = TextEditingController();

  InventoryStockSnapshot? snapshot;

  /// Verso scelto dal pannello quando la riga e' stata creata: il verso e' una
  /// scelta della sezione, la riga lo eredita e basta.
  InventoryRettificaDirection direction;

  /// Pezzi di scarto, senza segno: il verso e' [direction].
  int delta = 0;

  /// Conteggio reale scritto dall'operatore. Se valorizzato vince sul delta.
  String counted = '';
  bool useCounted = false;
  bool loading = false;
  String? loadError;

  String get key => '$productId:$variationId';

  int get countedValue => int.tryParse(counted.trim()) ?? 0;

  void dispose() {
    countedController.dispose();
  }

  /// Riga per la sezione condivisa: solo identita' e quantita' di default.
  InventoryQuickLoadLineDraft toLine() {
    return InventoryQuickLoadLineDraft(
      productId: productId,
      variationId: variationId,
      label: label,
      imageUrl: imageUrl,
      barcodeInterno: barcodeInterno,
      quantity: delta > 0 ? delta : 1,
      idempotencyKey: key,
    );
  }

  /// Riga di piano per [siteId].
  ///
  /// La sede arriva dal pannello e non si deduce: il totale che l'operatore
  /// corregge e' quello di una sede, quindi il confronto con lo stock corrente
  /// deve essere fatto sullo stesso numero che il backend riscrive.
  InventoryRettificaLine toPlanLine({int siteId = 0}) {
    return InventoryRettificaLine(
      productId: productId,
      variationId: variationId,
      label: label,
      direction: direction,
      snapshot: snapshot,
      delta: delta,
      correctStock: useCounted ? countedValue : null,
      siteId: siteId,
    );
  }
}

class _InventoryRettificaPanelState extends State<InventoryRettificaPanel> {
  late final InventoryRettificaController _controller;
  late final InventoryQuickLoadCatalogController? _catalogController;

  final _rows = <_RettificaRow>[];

  /// Prodotti del movimento riaperto, anche se non sono (piu') in lista.
  final _seedProducts = <_SeedProduct>[];

  bool _autoAdd = true;
  InventoryActionFeedback? _feedback;

  /// Verso della correzione, scelto una volta per la sezione.
  ///
  /// Parte da "Incremento" con zero pezzi: cosi' l'operatore vede la scelta
  /// gia' in testa e vede che non sta succedendo niente finche non la conferma.
  InventoryRettificaDirection _direction = InventoryRettificaDirection.increase;

  /// `true` dopo [initState]: in quel momento non si puo' chiamare `setState`,
  /// e il seme va comunque applicato perche' il primo build deve vedere gia'
  /// i prodotti del movimento riaperto.
  bool _ready = false;

  /// Impronta dell'ultimo seme applicato: il seme si consuma una volta sola.
  int? _appliedSeedStamp;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InventoryRettificaController();
    _catalogController = widget.catalogController;
    final seeded = _controller.lastSnapshot;
    if (seeded != null && seeded.productId > 0) {
      _rows.add(
        _RettificaRow(
          productId: seeded.productId,
          variationId: seeded.variationId,
          label: seeded.label,
          direction: _direction,
        )..snapshot = seeded,
      );
    }
    _ready = true;
    _applySeed(widget.seed);
  }

  @override
  void didUpdateWidget(InventoryRettificaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySeed(widget.seed);
  }

  /// Riapre un movimento del ledger in questo pannello.
  ///
  /// Le righe esistenti vengono sostituite, non accodate: se l'operatore sta
  /// correggendo qualcosa e ne riapre un'altra, tenere le due insieme
  /// produrrebbe un invio che non corrisponde a nessuna delle due operazioni.
  ///
  /// Ogni prodotto riparte dal valore assoluto che il movimento gli aveva
  /// lasciato, non dal suo delta. Il delta si applicherebbe a uno stock che
  /// quel movimento ha gia' modificato e finirebbe per raddoppiarlo: quello che
  /// l'operatore deve poter dire qui e' "il magazzino ne ha N", non "togli
  /// ancora N pezzi".
  ///
  /// Il seme si applica una volta sola, riconosciuto dall'impronta: riaprire
  /// due volte lo stesso movimento non deve raddoppiare i prodotti, e tornare
  /// su questo modulo dopo un altro non deve ricaricare il vecchio.
  void _applySeed(InventoryPanelSeed? seed) {
    if (seed == null || seed.module != InventoryModule.fix) return;
    if (_appliedSeedStamp == seed.stamp) return;
    _appliedSeedStamp = seed.stamp;

    final previous = List<_RettificaRow>.of(_rows);
    _seedProducts.clear();
    final seeded = <_RettificaRow>[];
    for (final movement in seed.movements) {
      final after = movement.stockAfter;
      if (after == null) continue;
      final row = _RettificaRow(
        productId: movement.productId,
        variationId: movement.variationId,
        label: context.l10n.inventoryProdottoNumero(
          movement.productId.toString(),
        ),
        // Il verso non conta finche' la spunta e' spenta e si usa il conteggio
        // assoluto, ma se l'operatore la riaccende la riga deve comunque
        // obbedire al verso scelto in testa, non a un default rimasto indietro.
        direction: _direction,
      );
      row.counted = '$after';
      row.useCounted = true;
      row.countedController.text = '$after';
      seeded.add(row);
      _seedProducts.add(_SeedProduct(movement));
    }

    _rows
      ..clear()
      ..addAll(seeded);
    widget.detailsController?.text = seed.reason;
    _feedback = null;
    // Il valore da correggere e' assoluto, quindi il pannello parte dal campo
    // del conteggio: con la correzione rapida attiva l'operatore sceglierebbe
    // un verso e un numero da sommare a uno stock che il movimento ha gia'
    // cambiato.
    _autoAdd = false;
    if (_ready) setState(() {});
    for (final row in previous) {
      row.dispose();
    }
    for (final row in seeded) {
      unawaited(_loadSnapshot(row));
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Scelta dei prodotti ───────────────────────────────────────────

  /// Risoluzione barcode condivisa con gli altri moduli: MGWS ragiona per id,
  /// quindi un barcode puo' arrivare come id o come codice del catalogo.
  Future<_RettificaRow?> _resolve(String code) async {
    final catalog = _catalogController;
    final match = catalog?.findByBarcode(code);
    final productId = match?.productId ?? int.tryParse(code.trim());
    if (productId == null || productId <= 0) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryBarcodeNonRiconosciuto,
        ),
      );
      return null;
    }
    final existing = _rows.where((row) => row.productId == productId);
    if (existing.isNotEmpty) {
      _showFeedback(
        InventoryActionFeedback(
          success: false,
          message: (l10n) => l10n.inventoryProdottoGiaInLista(
            match?.label ??
                context.l10n.inventoryProdottoNumero(productId.toString()),
          ),
        ),
      );
      return null;
    }
    final row = _RettificaRow(
      productId: productId,
      variationId: match?.variationId ?? 0,
      label:
          match?.label ??
          context.l10n.inventoryProdottoNumero(productId.toString()),
      imageUrl: match?.imageUrl,
      barcodeInterno: match?.barcodeInterno.isEmpty == true
          ? null
          : match?.barcodeInterno,
      // Il prodotto entra con il verso che l'operatore ha scelto in testa: se
      // la scelta cambiasse a meta' operazione, i prodotti gia' corretti
      // resterebbero col verso vecchio e il piano non sarebbe piu' quello che
      // l'operatore crede di aver scritto.
      direction: _direction,
    );
    setState(() {
      _rows.add(row);
      _feedback = null;
    });
    await _loadSnapshot(row);
    return row;
  }

  /// Legge lo stock MGWS del prodotto: senza quello non si puo' correggere,
  /// perche' la correzione parte da quanto MGWS ha registrato.
  Future<void> _loadSnapshot(_RettificaRow row) async {
    row.loading = true;
    // Anche questa puo' partire da initState, quando il seme ha gia' riempito
    // le righe: in quel momento non c'e' ancora un frame da ridisegnare.
    if (_ready) setState(() {});
    final feedback = await _controller.loadStock('${row.productId}');
    if (!mounted) return;
    setState(() {
      row.loading = false;
      if (feedback.success) {
        row.snapshot = _controller.lastSnapshot;
        row.loadError = null;
        // Lo stesso prodotto puo' essere anche uno di quelli che il movimento
        // riaperto aveva toccato: lo stock appena letto serve anche al
        // controllo del ripristino, quindi va aggiornato anche lì.
        for (final seed in _seedProducts) {
          if (seed.key == row.key) seed.snapshot = _controller.lastSnapshot;
        }
      } else {
        row.loadError = feedback.message(context.l10n);
      }
      _feedback = feedback.success ? null : feedback;
    });
  }

  Future<void> _openExistingProducts() async {
    final selected = await openProdottoPicker(context);
    if (!mounted || selected == null || selected.isEmpty) return;
    for (final unita in expandSelectedProducts(selected)) {
      if (!unita.isValid) continue;
      if (_rows.any(
        (row) =>
            row.productId == unita.productId &&
            row.variationId == unita.variationId,
      )) {
        continue;
      }
      final row = _RettificaRow(
        productId: unita.productId,
        variationId: unita.variationId,
        label: unita.label,
        imageUrl: unita.imageUrl,
        barcodeInterno: unita.barcodeInterno.isEmpty
            ? null
            : unita.barcodeInterno,
        direction: _direction,
      );
      setState(() {
        _rows.add(row);
        _feedback = null;
      });
      await _loadSnapshot(row);
      if (!mounted) return;
    }
  }

  void _removeRow(String key) {
    setState(() {
      final index = _rows.indexWhere((row) => row.key == key);
      if (index < 0) return;
      _rows.removeAt(index).dispose();
      _feedback = null;
    });
  }

  // ── Correzione ────────────────────────────────────────────────────

  /// Sceglie il verso della correzione, per tutta la sezione.
  ///
  /// Il verso non e' una proprieta' del prodotto ma della correzione: e' la
  /// risposta alla domanda "quando scanno un barcode, aumento o diminuisco?",
  /// quindi sta una volta sola accanto alla spunta, dove si vede prima ancora
  /// di aver scansionato qualcosa.
  ///
  /// Cambiare verso riparte da un pezzo invece di sommare: dopo tre incrementi
  /// scegliere la diminuzione vuol dire un pezzo sotto, non quattro sotto.
  /// L'operatore ha deciso "ora correggo verso il basso", non "ora aggiungo
  /// altri tre pezzi sotto".
  ///
  /// Le righe gia' in lista cambiano verso insieme: una rettifica e' una
  /// correzione sola, e due versi opposti nella stessa operazione significherebbero
  /// che il magazzino e' sbagliato in due direzioni diverse, che e' una cosa da
  /// sapere prima di mandare, non dopo.
  void _setDirection(InventoryRettificaDirection direction) {
    if (_direction == direction) return;
    setState(() {
      _direction = direction;
      for (final row in _rows) {
        if (row.direction == direction) continue;
        row.direction = direction;
        row.delta = 1;
      }
      _feedback = null;
    });
  }

  /// Quanti pezzi la correzione muove, senza segno: il verso e' [row.direction].
  void _setAmount(_RettificaRow row, int amount) {
    if (amount < 1) return;
    setState(() {
      row.delta = amount;
      // Il conteggio scritto a mano e la correzione rapida si escludono a
      // vicenda: non possono governare lo stesso numero insieme, altrimenti
      // l'anteprima dipenderebbe da quale dei due e' stato toccato per primo.
      if (row.useCounted) {
        row.useCounted = false;
        row.counted = '';
        row.countedController.clear();
      }
      _feedback = null;
    });
  }

  /// Torna a zero: la riga resta in lista ma senza correzione, quindi il piano
  /// non e' inviable finche l'operatore non sceglie un verso.
  void _resetRow(_RettificaRow row) {
    setState(() {
      row.delta = 0;
      row.useCounted = false;
      row.counted = '';
      row.countedController.clear();
      _feedback = null;
    });
  }

  void _setCounted(_RettificaRow row, String value) {
    setState(() {
      row.counted = value;
      row.useCounted = value.trim().isNotEmpty;
      _feedback = null;
    });
  }

  void _setAutoAdd(bool value) {
    setState(() {
      _autoAdd = value;
      _feedback = null;
      if (value) {
        for (final row in _rows) {
          row.useCounted = false;
          row.counted = '';
          row.countedController.clear();
        }
      }
    });
  }

  // ── Piano e invio ────────────────────────────────────────────────

  InventoryRettificaPlan _plan() {
    return InventoryRettificaPlan(
      // La sede va su ogni riga e non solo sul piano: `previousStock` di una riga
      // e' confrontato con il totale che il backend riscrive, e se i due numeri
      // fossero di ambiti diversi la differenza risulterebbe non nulla anche senza
      // errori. Passandola qui il confronto usa lo stesso perimetro della scrittura.
      lines: [for (final row in _rows) row.toPlanLine(siteId: _planSiteId)],
      restores: _restoreLines(),
      details: widget.detailsController?.text ?? '',
      siteIdText: widget.siteController?.text ?? '',
    );
  }

  /// Sede letta dal campo della pagina, o zero se non e' ancora una sede
  /// valida.
  int get _planSiteId {
    final text = widget.siteController?.text ?? '';
    return InventoryInputParser.parseOptionalPositiveInt(text) ?? 0;
  }

  /// Prodotti del movimento riaperto che non sono (piu') in lista.
  ///
  /// Derivato dalla lista di prodotti del seme, non tenuto in parallelo: se
  /// l'operatore toglie una riga e poi la riapre, la riga smette da sola di
  /// essere un ripristino. Una seconda lista da tenere allineata a mano
  /// finirebbe per contare due volte lo stesso prodotto o per dimenticarne uno.
  List<InventoryRettificaRestoreLine> _restoreLines() {
    return [
      for (final seed in _seedProducts)
        if (!_rows.any((row) => row.key == seed.key))
          InventoryRettificaRestoreLine(
            productId: seed.movement.productId,
            variationId: seed.movement.variationId,
            label: context.l10n.inventoryProdottoNumero(
              seed.movement.productId.toString(),
            ),
            movementId: seed.movement.id,
            stockBefore: seed.movement.stockBefore,
            stockAfter: seed.movement.stockAfter,
            snapshot: seed.snapshot,
          ),
    ];
  }

  Future<void> _submit() async {
    final plan = _plan();
    final parsed = plan.parse(l10n: context.l10n);
    if (parsed case InventoryFormInvalid(:final message)) {
      _showFeedback(InventoryActionFeedback(success: false, message: message));
      return;
    }
    final confirmed = await showInventoryRettificaConfirmDialog(
      context: context,
      plan: plan,
    );
    if (confirmed != true || !mounted) return;
    final feedback = await _controller.submit(context.l10n, plan);
    if (!mounted) return;
    if (feedback.success) {
      setState(() {
        _feedback = feedback;
        for (final row in _rows) {
          row.dispose();
        }
        _rows.clear();
      });
      return;
    }
    setState(() => _feedback = feedback);
    // Ricarica lo stock di chi e' rimasto: MGWS puo' aver mosso pezzi anche
    // sulle righe andate a buon fine, e correggere sul numero di prima
    // finirebbe per spostare merce due volte.
    for (final row in _rows) {
      if (row.snapshot != null) await _loadSnapshot(row);
      if (!mounted) return;
    }
  }

  void _showFeedback(InventoryActionFeedback feedback) {
    setState(() => _feedback = feedback);
  }

  // ── Interfaccia ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return Card(
      key: const ValueKey('inventory-rettifica-panel'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.tune, color: theme.colorScheme.primary),
              title: Text(
                context.l10n.inventoryRettificaTitolo,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                context.l10n.inventoryRettificaSottotitolo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.subtitleColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            InventoryProductSection(
              title: context.l10n.inventorySezioneProdottiDaRettificare,
              keyPrefix: 'inventory-rettifica',
              lines: [for (final row in _rows) row.toLine()],
              autoAdd: _autoAdd,
              onAutoAddChanged: _setAutoAdd,
              autoAddLabel: context.l10n.inventoryRettificaScegliQuanti,
              askQuantityLabel:
                  context.l10n.inventoryRettificaConfermaConteggio,
              onBarcodeEntered: (code) async => await _resolve(code) != null,
              onPickExisting: _openExistingProducts,
              onRemoveLine: _removeRow,
              busy: _controller.isSubmitting,
              barcodeLauncher: widget.barcodeLauncher,
              // Col conteggio scritto a mano il verso non serve: mostrarlo li'
              // farebbe scegliere una correzione che nessuno usa.
              autoAddTrailing: _autoAdd ? _buildDirectionChooser() : null,
              emptyHint: context.l10n.inventoryRettificaVuotoProdotti,
              trailingBuilder: (context, line) {
                final row = _rowFor(line.key);
                return row == null ? const SizedBox.shrink() : _buildRow(row);
              },
            ),
            const SizedBox(height: 10),
            if (_restoreLines().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildRestoreCard(),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 10),
              _buildFeedback(colors),
            ],
            const SizedBox(height: 12),
            _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  _RettificaRow? _rowFor(String key) {
    for (final row in _rows) {
      if (row.key == key) return row;
    }
    return null;
  }

  /// "Conferma 3 prodotti e 1 ripristini in sede 2": i tre pezzi si accodano
  /// solo quando ci sono, quindi la frase resta leggibile anche senza ripristini
  /// o senza sede.
  String _riepilogoInvio(
    InventoryRettificaPlan plan,
    List<InventoryRettificaRestoreLine> restores,
  ) {
    final l10n = context.l10n;
    return '${l10n.inventoryRettificaConfermaProdotti(plan.lineCount.toString())}'
        '${restores.isEmpty ? '' : ' ${l10n.inventoryRettificaERipristini(restores.length.toString())}'}'
        '${plan.siteId > 0 ? ' ${l10n.inventoryRettificaInSede(plan.siteId.toString())}' : ''}';
  }

  /// Le due radio del verso, accanto alla spunta.
  ///
  /// Vivono in testa alla sezione e non dentro le righe perche' rispondono alla
  /// domanda che l'operatore si fa mentre scansiona, non a una domanda sul
  /// singolo prodotto: dentro la riga comparivano solo dopo la scansione, cioe'
  /// quando la domanda e' gia' stata posta. E senza spunta non compaiono
  /// affatto, perche' con il conteggio scritto a mano il verso non serve.
  Widget _buildDirectionChooser() {
    final theme = Theme.of(context);
    return RadioGroup<InventoryRettificaDirection>(
      key: const ValueKey('inventory-rettifica-direction-group'),
      groupValue: _direction,
      // Il gruppo non accetta un onChanged nullo, quindi durante l'invio il
      // blocco sta qui dentro: le radio restano visibili e coerenti, solo non
      // piu' tocabili.
      onChanged: (InventoryRettificaDirection? value) {
        if (_controller.isSubmitting) return;
        if (value != null) _setDirection(value);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.inventoryEtichettaVerso,
            key: const ValueKey('inventory-rettifica-direction-label'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          // Flexible, non il semplice figlio in fila: la riga ha larghezza
          // limitata e una riga figlia senza vincolo la chiederebbe infinita,
          // che la riga-titolo del radio non sa cosa farsene.
          Flexible(
            child: RadioListTile<InventoryRettificaDirection>(
              key: const ValueKey('inventory-rettifica-direction-increase'),
              value: InventoryRettificaDirection.increase,
              title: Text(context.l10n.inventoryVersoIncremento),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          Flexible(
            child: RadioListTile<InventoryRettificaDirection>(
              key: const ValueKey('inventory-rettifica-direction-decrease'),
              value: InventoryRettificaDirection.decrease,
              title: Text(context.l10n.inventoryVersoDiminuzione),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Controlli di correzione del singolo prodotto.
  ///
  /// Con la spunta attiva la correzione si sceglie in due gesti: il verso con
  /// le due radio, poi quanti pezzi con il contatore. Senza spunta
  /// l'operatore scrive il conteggio reale, che vince su qualsiasi somma.
  Widget _buildRow(_RettificaRow row) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final line = row.toPlanLine();
    final tone = line.effectiveDelta > 0
        ? colors.successColor
        : line.effectiveDelta < 0
        ? colors.errorColorStatus
        : colors.subtitleColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (row.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(),
          )
        else if (row.loadError != null)
          Text(
            context.l10n.inventorySpostaStockNonCaricato(row.loadError!),
            key: ValueKey('inventory-rettifica-load-error-${row.key}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.errorColorStatus,
            ),
          )
        else if (row.snapshot == null)
          Text(
            context.l10n.inventoryRettificaStockNonDisponibile,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.warningColor,
            ),
          ),
        if (_autoAdd) ...[
          Row(
            children: [
              Text(
                context.l10n.inventoryRettificaQuantiPezzi,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              InventoryInlineQuantity(
                quantity: row.delta,
                min: 0,
                onChanged: (value) => _setAmount(row, value),
                decreaseKey: ValueKey(
                  'inventory-rettifica-amount-minus-${row.key}',
                ),
                increaseKey: ValueKey(
                  'inventory-rettifica-amount-plus-${row.key}',
                ),
              ),
              if (row.delta > 0)
                TextButton(
                  key: ValueKey('inventory-rettifica-reset-${row.key}'),
                  onPressed: _controller.isSubmitting
                      ? null
                      : () => _resetRow(row),
                  child: Text(context.l10n.inventoryAzzera),
                ),
            ],
          ),
        ] else
          TextField(
            key: ValueKey('inventory-rettifica-counted-${row.key}'),
            controller: row.countedController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.inventoryRettificaQuantitaContata,
              isDense: true,
              helperText: context.l10n.inventoryRettificaStockMgws(
                line.previousStock.toString(),
              ),
            ),
            onChanged: (value) => _setCounted(row, value),
          ),
        const SizedBox(height: 8),
        Container(
          key: ValueKey('inventory-rettifica-preview-${row.key}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.withValues(alpha: 0.30)),
          ),
          child: Text(
            line.effectiveDelta == 0
                ? context.l10n.inventoryRettificaNessunaVariazione
                : '${line.previousStock} -> ${line.targetStock} '
                      '(${context.l10n.inventoryRettificaDelta} '
                      '${line.effectiveDelta > 0 ? '+' : ''}'
                      '${line.effectiveDelta})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Prodotti del movimento riaperto che l'operatore ha tolto dalla lista.
  ///
  /// La card serve a una cosa sola: far vedere che togliere una riga non
  /// significa "lascia stare", ma "rimettila com'era prima". Se l'operatore non
  /// lo sa crede di aver solo tolto una riga, e invece al submit gli torna
  /// indietro uno stock che non voleva toccare.
  Widget _buildRestoreCard() {
    final restores = _restoreLines();
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    return InventorySectionCard(
      key: const ValueKey('inventory-rettifica-restore-card'),
      icon: Icons.undo,
      title: context.l10n.inventoryRettificaRipristinoTitolo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.inventoryRettificaRipristinoDescrizione,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final line in restores) ...[
            Text(
              '${line.label}: ${line.stockAfter} -> ${line.stockBefore}',
              key: ValueKey('inventory-rettifica-restore-${line.key}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: line.canRestore
                    ? colors.subtitleColor
                    : colors.errorColorStatus,
              ),
            ),
            if (!line.canRestore)
              Text(
                context.l10n.inventoryRettificaBloccato(
                  line.blockReason(context.l10n) ?? '',
                ),
                key: ValueKey(
                  'inventory-rettifica-restore-blocked-${line.key}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.errorColorStatus,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedback(AppColorExtension colors) {
    final feedback = _feedback!;
    final tone = feedback.success
        ? colors.successColor
        : colors.errorColorStatus;
    return Container(
      key: const ValueKey('inventory-rettifica-feedback'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.message(context.l10n),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final detail in feedback.details)
            Text(
              detail(context.l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final plan = _plan();
    final restores = plan.restores;
    final busy = _rows.any((row) => row.loading);
    final ready = !busy && plan.canSubmit && !_controller.isSubmitting;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        if (plan.lineCount > 0 || restores.isNotEmpty)
          Text(
            ready
                ? _riepilogoInvio(plan, restores)
                // L'ordine delle spiegazioni segue quello in cui i dati si
                // perdono: prima la sede, perche' senza di lei il confronto con
                // lo stock non ha senso, poi i prodotti, poi il ripristino.
                : plan.siteId <= 0
                ? context.l10n.inventoryRettificaIndicaSede
                : restores.any((line) => !line.canRestore)
                ? context.l10n.inventoryRettificaProdottoToltoBloccato
                : context.l10n.inventoryRettificaServeCorrezione,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ElevatedButton.icon(
          key: const ValueKey('inventory-rettifica-submit'),
          onPressed: ready ? _submit : null,
          icon: _controller.isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(
            _controller.isSubmitting
                ? context.l10n.inventoryAdjustmentRunning
                : context.l10n.inventoryApplyAdjustment,
          ),
        ),
      ],
    );
  }
}

/// Riepilogo delle correzioni prima dell'invio, una riga per prodotto.
///
/// Con piu' prodotti e' l'unico posto dove si vede se il conto torna: il
/// piano porta su N righe e serve a fermarsi se una e' sbagliata.
Future<bool?> showInventoryRettificaConfirmDialog({
  required BuildContext context,
  required InventoryRettificaPlan plan,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '${context.l10n.inventoryConfermaRettifica} — '
        '${context.l10n.inventoryConfermaRettificaSede(plan.siteId.toString())} '
        '(${context.l10n.inventoryParolaProdotti})',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in plan.lines) ...[
                Text(
                  '${line.label}: ${line.previousStock} -> ${line.targetStock} '
                  '(${context.l10n.inventoryRettificaDelta} '
                  '${line.effectiveDelta > 0 ? '+' : ''}'
                  '${line.effectiveDelta})',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  plan.reasonTextFor(line, context.l10n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              for (final line in plan.restores) ...[
                Text(
                  '${line.label}: '
                  '${context.l10n.inventoryRettificaRipristinoTra} '
                  '${line.stockAfter} -> ${line.stockBefore}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  plan.restoreReasonTextFor(line, context.l10n),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              // La sede sta in cima perche' e' il perimetro di tutti i numeri
              // qui sotto: leggere "3 -> 5" senza sapere di quale sede si parla
              // mostrerebbe un conto che non torna da nessuna parte.
              Text(
                '${context.l10n.inventoryEtichettaSede}: ${plan.siteId}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (plan.details.trim().isNotEmpty)
                Text(
                  '${context.l10n.inventoryEtichettaDettaglio}: ${plan.details.trim()}',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          key: const ValueKey('inventory-rettifica-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.l10n.inventoryConfermaRettifica),
        ),
      ],
    ),
  );
}
