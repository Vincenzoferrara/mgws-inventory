// inventory.gui.dart
//
// Pagina "Inventario MGWS" con i moduli del magazzino:
//  1. Aggiungi prodotto: inserimento pezzi, semplice o
//     associato a un ordine, con barcode.
//  2. Rettifica: correzione della quantita reale in
//     aumento o diminuzione.
//  3. Sposta: trasferimento pezzi tra sedi/magazzini
//     fisici.
//  4. Movimenti: le operazioni fatte finora, con i
//     prodotti che hanno toccato, la data e chi le ha
//     fatte.
//
// La pagina e' solo la cornice: possiede il selettore dei
// moduli e il campo "Dettagli", che vale per il modulo
// attivo, e smista i pannelli. I pannelli non si conoscono
// fra loro, quindi il passaggio fra moduli — la riapertura
// di un movimento dal ledger — passa di qui.
//
// Nessun modulo modifica un movimento gia' registrato: il
// ledger non ha una rotta che lo faccia e non deve averla.
// Le azioni che partono da un movimento ne producono uno
// nuovo.

import 'package:flutter/material.dart';

import '../login/gui/login.code.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'inventory.code.dart';
import 'inventory_add_products.gui.dart';
import 'inventory_module.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_move.gui.dart';
import 'inventory_movements.gui.dart';
import 'inventory_rettifica.gui.dart';

/// Icona del modulo nel dropdown.
///
/// Sta qui e non accanto all'enum: `inventory_module.code.dart` e' logica pura e
/// non deve sapere nulla delle icone, che sono una scelta di schermata.
const _moduleIcons = {
  InventoryModule.choose: Icons.category_outlined,
  InventoryModule.add: Icons.playlist_add_check,
  InventoryModule.fix: Icons.tune,
  InventoryModule.move: Icons.swap_horiz,
  InventoryModule.ledger: Icons.timeline,
};

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    this.controller,
    this.addProductsController,
    this.supplierController,
    this.rettificaController,
    this.moveController,
    this.movementController,
    this.catalogController,
  });

  final InventoryController? controller;
  final InventoryAddProductsController? addProductsController;
  final InventorySupplierController? supplierController;
  final InventoryRettificaController? rettificaController;
  final InventoryMoveController? moveController;

  /// Ledger: un controller per pagina, cosi' il ricaricamento non riparte da
  /// zero a ogni filtro.
  final InventoryMovementController? movementController;

  /// mgws_inventory condiviso: serve a risolvere il barcode in un product
  /// id nei pannelli che non hanno un proprio selettore.
  final InventoryQuickLoadCatalogController? catalogController;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryController _controller;
  late final InventoryAddProductsController _addProductsController;
  late final InventorySupplierController _supplierController;
  late final InventoryRettificaController _rettificaController;
  late final InventoryMoveController _moveController;
  late final InventoryMovementController _movementController;
  late final InventoryQuickLoadCatalogController _catalogController;
  late final bool _ownsCatalog;

  /// Il modulo attivo scelto dall'operatore: null significa
  /// "scegli" e non mostra nessun pannello.
  InventoryModule? _activeModule;

  /// Dettagli del movimento: un campo solo per tutti e tre i moduli, perche'
  /// e' una sola operazione di magazzino. I pannelli lo leggono e non lo
  /// scrivono: resta di proprieta' della pagina.
  final _detailsController = TextEditingController();

  /// Sede su cui vale il movimento, un campo solo per i moduli che la usano
  /// (Aggiungi e Rettifica).
  ///
  /// Sta qui e non dentro i pannelli per lo stesso motivo dei dettagli: e'
  /// una sola operazione di magazzino e la sede e' una sola. I pannelli la
  /// leggono per costruire il piano e non la scrivono: se un pannello la
  /// cambiasse, l'altro non lo vedrebbe e i due finirebbero per dichiarare
  /// sedi diverse per lo stesso movimento.
  final _siteController = TextEditingController();

  /// Sede di riferimento dell'operatore, se ne ha una.
  ///
  /// Va letta dal profilo e non dedotta dal prodotto: chi ha una sede di
  /// riferimento lavora su quella e il backend rifiuta ogni altra, quindi
  /// lasciargliela scegliere sarebbe proporre una scelta che non puo' fare. Il
  /// valore arriva presto e in modo asincrono, per cui i pannelli devono poter
  /// lavorare anche senza: per quello il campo resta semplicemente vuoto e
  /// obbligatorio, che e' la condizione in cui nessuna sede e' stata dichiarata
  /// e quindi va detta.
  int _operatorSiteId = 0;

  /// Riapertura di un movimento dal ledger, in attesa che il pannello di
  /// destinazione la consumi.
  ///
  /// Vive qui perche' il passaggio e' fra moduli: il pannello del ledger non
  /// conosce i pannelli operativi, e la pagina conosce entrambi. Dura un solo
  /// frame: se restasse, tornare su un modulo dopo un altro ricaricherebbe il
  /// vecchio movimento senza che nessuno lo abbia chiesto.
  InventoryPanelSeed? _pendingSeed;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? InventoryController();
    _addProductsController =
        widget.addProductsController ?? InventoryAddProductsController();
    _supplierController =
        widget.supplierController ?? InventorySupplierController();
    _rettificaController =
        widget.rettificaController ??
        InventoryRettificaController(inventory: _controller);
    _moveController = widget.moveController ?? InventoryMoveController();
    _movementController =
        widget.movementController ?? InventoryMovementController();
    _ownsCatalog = widget.catalogController == null;
    _catalogController =
        widget.catalogController ?? InventoryQuickLoadCatalogController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReadiness());
    _loadOperatorSite();
  }

  /// Legge la sede di riferimento dal profilo WordPress.
  ///
  /// Va letta qui e non passata dalla Home perche' la pagina e' costruita anche
  /// da solo, e un valore che arriva da fuori sarebbe nullo in quel caso: la
  /// sede di un operatore che non e' quella non e' una sede, e' una sede
  /// sbagliata. Costa una richiesta per apertura di pagina; il pannello resta
  /// utilizzabile mentre arriva, perche' il campo sede obbligatorio e' gia' la
  /// condizione giusta quando la sede non e' ancora nota.
  Future<void> _loadOperatorSite() async {
    final profile = await loginCode.currentUserProfile();
    if (!mounted) return;
    final siteId = profile?.defaultSiteId ?? 0;
    if (siteId == 0 || siteId == _operatorSiteId) return;
    setState(() => _operatorSiteId = siteId);
    // Il campo della pagina lo scrive come farebbe l'operatore: i pannelli
    // che lo leggono (magazzini da caricare, piano da inviare) reagiscono da
    // soli al cambiamento.
    _siteController.text = '$siteId';
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _siteController.dispose();
    if (_ownsCatalog) _catalogController.dispose();
    super.dispose();
  }

  void _setModule(InventoryModule? module) {
    setState(() {
      _activeModule = module;
      // I dettagli sono del movimento che si sta per fare: lasciarli scritti
      // mentre si cambia idea sul modulo li allegherebbe a un'operazione
      // diversa da quella a cui l'operatore pensava.
      if (module?.writesStock != true) _detailsController.clear();
    });
  }

  /// Salta al pannello che ha prodotto il movimento, con i suoi prodotti gia'
  /// in lista e la sua nota.
  void _resumeMovement(InventoryPanelSeed seed) {
    setState(() {
      _activeModule = seed.module;
      _pendingSeed = seed;
      // I dettagli sono di proprieta' della pagina e il pannello non li tocca:
      // se non li ripristina qui, il movimento riaperto viaggerebbe senza la
      // sua nota.
      _detailsController.text = seed.details;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _pendingSeed = null);
    });
  }

  Future<void> _checkReadiness() async {
    final pending = _controller.checkMgwsReadiness();
    setState(() {});
    await pending;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.gradientStart, colors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 760;
              return SingleChildScrollView(
                key: const ValueKey('inventory-shell'),
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      key: ValueKey(
                        isSmall
                            ? 'inventory-small-layout'
                            : 'inventory-desktop-layout',
                      ),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BackendStatus(controller: _controller),
                        const SizedBox(height: 10),
                        // Selettore modulo: mostra solo il pannello
                        // selezionato, le operazioni non sono mai visibili
                        // insieme.
                        _ModuleSelector(
                          activeModule: _activeModule,
                          onModuleChanged: _setModule,
                        ),
                        // La sede sta sopra i dettagli e vale per i moduli
                        // che la usano (Aggiungi e Rettifica): Sposta sceglie
                        // sede d'arrivo riga per riga e non ne ha una sola.
                        // Sul ledger non ha dove finire, quindi non c'e'.
                        if (_activeModule == InventoryModule.add ||
                            _activeModule == InventoryModule.fix) ...[
                          const SizedBox(height: 10),
                          _ModuleSiteField(
                            controller: _siteController,
                            operatorSiteId: _operatorSiteId,
                          ),
                        ],
                        // I dettagli stanno sopra il pannello, non dentro:
                        // valgono per il movimento qualunque modulo sia attivo.
                        // Sul ledger non hanno dove finire, quindi non ci sono:
                        // un campo che raccoglie testo e poi lo perde e' peggio
                        // di non averlo.
                        if (_activeModule?.writesStock == true) ...[
                          const SizedBox(height: 10),
                          _ModuleDetailsCard(controller: _detailsController),
                        ],
                        const SizedBox(height: 10),
                        if (_activeModule == InventoryModule.add)
                          InventoryAddProductsPanel(
                            controller: _addProductsController,
                            supplierController: _supplierController,
                            detailsController: _detailsController,
                            siteController: _siteController,
                          ),
                        if (_activeModule == InventoryModule.fix)
                          InventoryRettificaPanel(
                            controller: _rettificaController,
                            catalogController: _catalogController,
                            detailsController: _detailsController,
                            siteController: _siteController,
                            seed: _pendingSeed,
                          ),
                        if (_activeModule == InventoryModule.move)
                          InventoryMovePanel(
                            controller: _moveController,
                            catalogController: _catalogController,
                            detailsController: _detailsController,
                            seed: _pendingSeed,
                          ),
                        if (_activeModule == InventoryModule.ledger)
                          InventoryMovementLedgerPanel(
                            controller: _movementController,
                            onReopen: _resumeMovement,
                          ),
                        if (_activeModule == null) _EmptyModulePrompt(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Selettore a barra piatta del modulo attivo.
/// Quando l'operatore sceglie, solo quel pannello appare
/// sotto — le due operazioni non sono mai visibili insieme.
class _ModuleSelector extends StatelessWidget {
  const _ModuleSelector({
    required this.activeModule,
    required this.onModuleChanged,
  });

  final InventoryModule? activeModule;
  final ValueChanged<InventoryModule?> onModuleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Etichetta
              Text(
                context.l10n.inventoryModuleModulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Dropdown
              Expanded(
                child: DropdownButtonFormField<InventoryModule>(
                  initialValue: activeModule,
                  isExpanded: true,
                  hint: Text(context.l10n.inventoryHintChooseModule),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: [
                    for (final module in InventoryModule.values)
                      DropdownMenuItem<InventoryModule>(
                        value: module,
                        child: Row(
                          children: [
                            Icon(_moduleIcons[module], size: 18),
                            const SizedBox(width: 10),
                            Text(inventoryModuleLabel(context.l10n, module)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null && value != InventoryModule.choose) {
                      onModuleChanged(value);
                    } else if (value == InventoryModule.choose) {
                      onModuleChanged(null);
                    }
                  },
                ),
              ),
            ],
          ),
          // Descrizione del modulo selezionato, sotto la barra: resta in
          // piccolo perche' ripete quello che la scelta del modulo ha gia'
          // detto.
          if (activeModule != null && activeModule != InventoryModule.choose) ...[
            const SizedBox(height: 6),
            Text(
              inventoryModuleDescription(context.l10n, activeModule!) ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.extension<AppColorExtension>()!.subtitleColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo "Sede *" unico per la pagina.
///
/// Sta sopra i dettagli e vale per il modulo attivo quando questo la usa
/// (Aggiungi e Rettifica): e' la stessa operazione di magazzino, quindi la si
/// dichiara una volta e non in due pannelli. Chi ha una sede di riferimento la
/// trova gia' scritta e non puo' cambiarla: il backend accetta solo quella per
/// quell'operatore, quindi offrire la scelta proporrebbe una scelta che non
/// puo' fare. Quando la sede non e' assegnata, il campo e' suo e la sede va
/// dichiarata: senza, il backend rifiuta il totale.
class _ModuleSiteField extends StatelessWidget {
  const _ModuleSiteField({
    required this.controller,
    required this.operatorSiteId,
  });

  final TextEditingController controller;
  final int operatorSiteId;

  @override
  Widget build(BuildContext context) {
    final locked = operatorSiteId > 0;
    return Container(
      key: const ValueKey('inventory-site-card'),
      child: TextField(
        key: const ValueKey('inventory-site-field'),
        controller: controller,
        readOnly: locked,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: context.l10n.inventoryLabelSede,
          hintText: locked
              ? context.l10n.inventoryHintSedeRiferimento
              : context.l10n.inventoryHintNumeroSede,
          prefixIcon: Icon(
            locked ? Icons.lock_outline : Icons.public,
            size: 18,
          ),
          helperText: locked
              ? context.l10n.inventoryHelperSedeBloccata
              : context.l10n.inventoryHelperSedeObbligatoria,
          helperMaxLines: 2,
        ),
      ),
    );
  }
}

/// Campo "Dettagli" unico per la pagina.
///
/// Sta sotto il selettore e vale per il modulo attivo: e' la stessa operazione
/// di magazzino, quindi la si scrive una volta e non in tre posti. Facoltativa,
/// ma quando c'e' viaggia con il movimento. Senza card intorno: il campo e'
/// gia' un campo, non serve un riquadro che lo contenga.
class _ModuleDetailsCard extends StatelessWidget {
  const _ModuleDetailsCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('inventory-details-card'),
      child: TextField(
        key: const ValueKey('inventory-details-field'),
        controller: controller,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: context.l10n.inventoryLabelDettagli,
          hintText: context.l10n.inventoryHintNotaMovimento,
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
    );
  }
}

/// Prompt mostrato quando l'operatore non ha ancora scelto un
/// modulo.
class _EmptyModulePrompt extends StatelessWidget {
  const _EmptyModulePrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.inventoryEmptyStateTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.inventoryEmptyStateDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stato del backend, compattto: dice solo se MGWS risponde.
class _BackendStatus extends StatelessWidget {
  const _BackendStatus({required this.controller});

  final InventoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorExtension>()!;
    final scheme = theme.colorScheme;
    final available = controller.isMgwsAvailable == true;
    final checking = controller.isCheckingAvailability;
    final statusColor = checking
        ? colors.warningColor
        : available
        ? colors.successColor
        : colors.errorColorStatus;

    return Container(
      key: const ValueKey('inventory-backend-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.admin_panel_settings,
            color: statusColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            checking
                ? context.l10n.inventoryStatoVerificaBackend
                : available
                ? context.l10n.inventoryStatoMgwsDisponibile
                : context.l10n.inventoryStatoMgwsRichiesto,
            style: theme.textTheme.labelMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
