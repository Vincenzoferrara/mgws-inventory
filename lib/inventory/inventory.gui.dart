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

import '../theme/theme.dart';
import '../login/mgws/query/query_mgws_site.dart';
import '../l10n/extensions.dart';
import 'inventory_site_panel.gui.dart';
import 'reservations.gui.dart';
import 'count_schedules.gui.dart';
import 'kits.gui.dart';
import 'product_barcodes.gui.dart';
import 'documents.gui.dart';
import '../approvals/approval_rules.gui.dart';
import 'transfers.gui.dart';
import 'stock_reset.gui.dart';
import 'payments.gui.dart';
import 'shipments.gui.dart';
import 'inventory.code.dart';
import 'inventory_add_products.gui.dart';
import 'inventory_module.code.dart';
import 'inventory_movement_groups.code.dart';
import 'inventory_move.gui.dart';
import 'inventory_movements.gui.dart';
import 'inventory_adjustment.gui.dart';

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

  /// Sede in uso, dal server. Finche' e' `null` l'inventario non si usa:
  /// il pannello della sede mostra perche' e, a chi puo', come rimediare.
  MgwsSiteStatus? _site;

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
  }

  /// La sede arriva dal pannello: i pannelli dei moduli la leggono dal
  /// campo condiviso per costruire il piano da inviare.
  void _onSiteStatus(MgwsSiteStatus? status) {
    final previous = _site?.siteId;
    // Cambiata la sede, lo stock letto prima vale per l'altra: uno
    // spostamento ripartirebbe da magazzini che non si possono piu' usare.
    if (previous != null && previous != status?.siteId) _moveController.clear();
    setState(() => _site = status);
    _siteController.text = status == null ? '' : '${status.siteId}';
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
      // Lo Scaffold da' al corpo un'altezza massima, non fissa, e lo scroll
      // dentro si ferma all'altezza del contenuto: senza expand lo sfondo
      // finiva a meta' schermo quando il modulo e' corto.
      body: SizedBox.expand(
        child: DecoratedBox(
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
                          // Solo quando c'e' qualcosa da dire: "MGWS
                          // disponibile" sempre in vista occupava spazio senza
                          // dare informazioni.
                          if (_controller.isMgwsAvailable != true) ...[
                            _BackendStatus(controller: _controller),
                            const SizedBox(height: 10),
                          ],
                          // La sede e' obbligatoria: senza, i moduli non
                          // compaiono e il pannello dice perche'.
                          InventorySitePanel(onStatusChanged: _onSiteStatus),
                          if (_site != null) ...[
                            const SizedBox(height: 10),
                            // I quattro moduli sempre in vista, gli strumenti
                            // meno frequenti in un menu accanto: prima erano
                            // dieci pulsanti sopra il lavoro di tutti i giorni,
                            // e i moduli stavano chiusi in una tendina.
                            _ModuleSelector(
                              activeModule: _activeModule,
                              onModuleChanged: _setModule,
                              tools: const _ToolsMenu(),
                            ),
                            // I dettagli stanno sopra il pannello, non dentro:
                            // valgono per il movimento qualunque modulo sia attivo.
                            // Sul ledger non hanno dove finire, quindi non ci sono:
                            // un campo che raccoglie testo e poi lo perde e' peggio
                            // di non averlo.
                            if (_activeModule?.writesStock == true) ...[
                              const SizedBox(height: 10),
                              _ModuleDetailsCard(
                                controller: _detailsController,
                              ),
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
                                siteName: _site?.siteName,
                                seed: _pendingSeed,
                              ),
                            if (_activeModule == InventoryModule.move)
                              InventoryMovePanel(
                                // Una sede nuova riparte da zero: sedi e
                                // magazzini proposti sono quelli della sede.
                                key: ValueKey(
                                  'inventory-move-site-${_site!.siteId}',
                                ),
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
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra dei moduli: Aggiungi, Rettifica, Sposta e Movimenti sempre visibili,
/// un tocco per passare dall'uno all'altro. Solo il pannello scelto appare
/// sotto: le operazioni non sono mai visibili insieme.
class _ModuleSelector extends StatelessWidget {
  const _ModuleSelector({
    required this.activeModule,
    required this.onModuleChanged,
    required this.tools,
  });

  final InventoryModule? activeModule;
  final ValueChanged<InventoryModule?> onModuleChanged;
  final Widget tools;

  static const _modules = <InventoryModule>[
    InventoryModule.add,
    InventoryModule.fix,
    InventoryModule.move,
    InventoryModule.ledger,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected =
        activeModule == null || activeModule == InventoryModule.choose
        ? const <InventoryModule>{}
        : <InventoryModule>{activeModule!};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Sotto i 600 px le etichette non ci stanno tutte: restano le
              // icone, con il nome nel tooltip.
              final compact = constraints.maxWidth < 600;
              final bar = SegmentedButton<InventoryModule>(
                key: const ValueKey('inventory-module-bar'),
                segments: [
                  for (final module in _modules)
                    ButtonSegment<InventoryModule>(
                      value: module,
                      icon: Icon(_moduleIcons[module], size: 18),
                      label: compact
                          ? null
                          : Text(inventoryModuleLabel(context.l10n, module)),
                      tooltip: inventoryModuleLabel(context.l10n, module),
                    ),
                ],
                selected: selected,
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    onModuleChanged(value.isEmpty ? null : value.first),
              );
              return Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: bar),
                  ),
                  const SizedBox(width: 8),
                  tools,
                ],
              );
            },
          ),
          // Descrizione del modulo selezionato, sotto la barra: resta in
          // piccolo perche' ripete quello che la scelta del modulo ha gia'
          // detto.
          if (selected.isNotEmpty) ...[
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

/// Strumenti MGWS meno frequenti, in un menu solo e divisi per argomento.
/// Il reset dello stock sta in fondo, separato e in colore di avviso: e'
/// l'unico che cambia le quantita' di molti prodotti in un colpo.
class _ToolsMenu extends StatelessWidget {
  const _ToolsMenu();

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).extension<AppColorExtension>()!;
    MenuItemButton item(String label, IconData icon, Widget screen) =>
        MenuItemButton(
          leadingIcon: Icon(icon, size: 18),
          onPressed: () => _open(context, screen),
          child: Text(label),
        );
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.subtitleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return MenuAnchor(
      menuChildren: [
        header(l10n.inventoryToolsGroupDocuments),
        item(
          l10n.mgwsToolDocuments,
          Icons.description,
          const DocumentsScreen(),
        ),
        item(
          l10n.mgwsToolShipments,
          Icons.local_shipping,
          const ShipmentsScreen(),
        ),
        item(l10n.mgwsToolPayments, Icons.payments, const PaymentsScreen()),
        item(
          l10n.mgwsToolReservations,
          Icons.bookmark,
          const ReservationsScreen(),
        ),
        const Divider(height: 1),
        header(l10n.inventoryToolsGroupCatalog),
        item(l10n.mgwsToolKits, Icons.inventory, const KitsScreen()),
        item(
          l10n.mgwsToolProductBarcodes,
          Icons.qr_code,
          const ProductBarcodesScreen(),
        ),
        const Divider(height: 1),
        header(l10n.inventoryToolsGroupControl),
        item(l10n.mgwsToolTransfers, Icons.swap_horiz, const TransfersScreen()),
        item(
          l10n.mgwsToolCountSchedules,
          Icons.event_repeat,
          const CountSchedulesScreen(),
        ),
        item(
          l10n.mgwsToolApprovalRules,
          Icons.rule,
          const ApprovalRulesScreen(),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.restart_alt,
            size: 18,
            color: colors.warningColor,
          ),
          onPressed: () => _open(context, const StockResetScreen()),
          child: Text(
            l10n.mgwsToolStockReset,
            style: TextStyle(color: colors.warningColor),
          ),
        ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        key: const ValueKey('inventory-tools-menu'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz, size: 18),
        label: Text(l10n.inventoryToolsMenu),
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
        minLines: 1,
        maxLines: 3,
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
            // Testi nei colori del tema per il testo, non nel primario
            // trasparente: rosso scuro su fondo scuro non si leggeva.
            Text(
              context.l10n.inventoryEmptyStateTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.inventoryEmptyStateDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
