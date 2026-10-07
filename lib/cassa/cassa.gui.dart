import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'class_scontrino.dart';
import 'cassa.code.dart';
import 'storico_cassa.gui.dart';
import '../prodotti/class_prodotti.dart';
import '../prodotti/prodotti_gestisci/product_picker.dart';
import '../notification/notification_service.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import '../reuse_class/barcode/barcode_scanner.dart';
import '../reuse_class/image_url_resolver.dart';
import '../login/jwt_api/adapter/platform_manager.dart';
import '../settings/cassa_settings.dart';

class CassaPage extends StatefulWidget {
  const CassaPage({super.key});

  @override
  CassaPageState createState() => CassaPageState();
}

class CassaPageState extends State<CassaPage>
    with AutomaticKeepAliveClientMixin {
  final CassaController _controller = CassaController();
  final TextEditingController _searchController = TextEditingController();
  bool _mostraStorico = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initContestoCassa();
  }

  Future<void> _initContestoCassa() async {
    await cassaSettings.init();
    await _controller.storicoStore.init();
    await _controller.risolviOperatoreDaLogin();
    if (mounted) setState(() {});
  }

  double _parseEuro(String value) =>
      double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;

  Future<void> _dialogApriTurno() async {
    final fondoController = TextEditingController();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaApriTurnoCassa),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.cassaEtichettaOperatore(
                  '${_controller.operatoreLabel}',
                ),
              ),
              Text(
                context.l10n.cassaEtichettaCassa(
                  '${_controller.cassaCorrenteLabel}',
                ),
              ),
              if (_controller.sedeCorrenteLabel.isNotEmpty)
                Text(
                  context.l10n.cassaEtichettaSede(
                    '${_controller.sedeCorrenteLabel}',
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: fondoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.cassaFondoIniziale,
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Il fondo viene fissato all\'apertura e usato nella chiusura del turno.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_open),
            label: Text(context.l10n.cassaApriTurno),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    final esito = await _controller.apriTurno(
      fondoIniziale: _parseEuro(fondoController.text),
    );
    if (!mounted) return;
    NotificationService.instance.messageBar(
      esito.ok ? 'successo' : 'errore',
      'cassa',
      esito.ok ? 'Turno cassa aperto.' : (esito.errore ?? 'Turno non aperto.'),
    );
    setState(() {});
  }

  Future<void> _dialogChiudiTurno() async {
    final turno = _controller.turnoCorrente;
    if (turno == null) {
      NotificationService.instance.messageBar(
        'warning',
        'cassa',
        'Nessun turno aperto da chiudere.',
      );
      return;
    }
    final totali = _controller.totaliTurnoCorrente();
    final contantiController = TextEditingController();
    final cartaController = TextEditingController();
    final causaleController = TextEditingController();
    final noteController = TextEditingController();
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaChiudiTurnoCassa),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.cassaEtichettaTurno('${turno.id}')),
                Text(
                  context.l10n.cassaEtichettaOperatore(
                    '${turno.operatoreLabel}',
                  ),
                ),
                Text(
                  'Fondo iniziale: €${turno.fondoIniziale.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Incassi turno - contanti €${(totali['contanti'] ?? 0).toStringAsFixed(2)} · '
                  'carta €${(totali['carta'] ?? 0).toStringAsFixed(2)} · '
                  'altri €${(totali['altri'] ?? 0).toStringAsFixed(2)} · '
                  'rimborsi €${(totali['rimborsi'] ?? 0).toStringAsFixed(2)}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contantiController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaContantiContati,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cartaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaCartaPosContato,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: causaleController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaCausaleDifferenza,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaNote,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock),
            label: Text(context.l10n.cassaChiudiTurno),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    final esito = await _controller.chiudiTurno(
      contanteContato: _parseEuro(contantiController.text),
      cartaContato: _parseEuro(cartaController.text),
      causaleDifferenza: causaleController.text,
      note: noteController.text,
    );
    if (!mounted) return;
    NotificationService.instance.messageBar(
      esito.ok ? 'successo' : 'errore',
      'cassa',
      esito.ok ? 'Turno cassa chiuso.' : (esito.errore ?? 'Turno non chiuso.'),
    );
    setState(() {});
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessario per AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Material(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final selector = SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.point_of_sale),
                        label: Text(context.l10n.cassaVendita),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.history),
                        label: Text(context.l10n.cassaStorico),
                      ),
                    ],
                    selected: {_mostraStorico},
                    onSelectionChanged: (s) =>
                        setState(() => _mostraStorico = s.first),
                  );
                  final actions = _buildCashierHeaderActions();
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [selector, const SizedBox(height: 8), actions],
                    );
                  }
                  return Row(
                    children: [
                      selector,
                      const SizedBox(width: 12),
                      Expanded(child: actions),
                    ],
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _mostraStorico
                ? StoricoCassaPage(
                    controller: _controller,
                    onVaiAllaVendita: () =>
                        setState(() => _mostraStorico = false),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isSmallScreen = constraints.maxWidth < 800;
                      if (isSmallScreen) {
                        return _buildMobileLayout();
                      } else {
                        return _buildDesktopLayout();
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Layout per desktop (split view)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // LATO SINISTRO - Ricerca Prodotti (60%)
        Expanded(
          flex: 6,
          child: _LatoSinistroWidget(
            controller: _controller,
            searchController: _searchController,
            onStateChanged: _updateState,
          ),
        ),

        // Divider verticale
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor,
        ),

        // LATO DESTRO - Scontrino (40%)
        Expanded(
          flex: 4,
          child: _LatoDestroWidget(
            controller: _controller,
            onStateChanged: _updateState,
          ),
        ),
      ],
    );
  }

  /// Layout per mobile (stacked view)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(
          child: _LatoSinistroWidget(
            controller: _controller,
            searchController: _searchController,
            onStateChanged: _updateState,
          ),
        ),
        _MobileCheckoutBar(
          controller: _controller,
          onStateChanged: _updateState,
          onOpenOptions: _showMobileCheckoutOptions,
        ),
      ],
    );
  }

  Widget _buildCashierHeaderActions() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            'Operatore: ${_controller.operatoreLabel}'
            '${cassaSettings.hasCassa ? ' · ${cassaSettings.nomeCassa}' : ''}'
            '${cassaSettings.hasSede ? ' · ${cassaSettings.sede}' : ''}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        if (cassaSettings.turnoObbligatorio) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Tooltip(
              message: _controller.turnoLabel,
              child: Chip(
                avatar: Icon(
                  _controller.hasTurnoAperto
                      ? Icons.lock_open
                      : Icons.lock_outline,
                  size: 16,
                ),
                label: Text(
                  _controller.turnoBreve,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _controller.hasTurnoAperto
                ? _dialogChiudiTurno
                : _dialogApriTurno,
            icon: Icon(
              _controller.hasTurnoAperto ? Icons.lock : Icons.lock_open,
            ),
            label: Text(
              _controller.hasTurnoAperto ? 'Chiudi turno' : 'Apri turno',
            ),
          ),
        ],
        IconButton(
          tooltip: context.l10n.cassaRileggiOperatore,
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: () async {
            await _controller.risolviOperatoreDaLogin(force: true);
            setState(() {});
          },
        ),
      ],
    );
  }

  void _showMobileCheckoutOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
              ),
              child: _LatoDestroWidget(
                controller: _controller,
                onStateChanged: () {
                  _updateState();
                  setSheetState(() {});
                },
                showHeader: false,
                showTotals: false,
                fillAvailableSpace: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget lato sinistro - Ricerca e selezione prodotti
class _LatoSinistroWidget extends StatelessWidget {
  final CassaController controller;
  final TextEditingController searchController;
  final VoidCallback onStateChanged;

  const _LatoSinistroWidget({
    required this.controller,
    required this.searchController,
    required this.onStateChanged,
  });

  Future<TipoRigaCassa?> _scegliTipoCambio(BuildContext context) {
    return showModalBottomSheet<TipoRigaCassa>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: Text(context.l10n.cassaClientePrendeProdotto),
              subtitle: Text(context.l10n.cassaVoceVendita),
              onTap: () =>
                  Navigator.of(sheetContext).pop(TipoRigaCassa.vendita),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: Text(context.l10n.cassaClienteRestituisceProdotto),
              subtitle: Text(context.l10n.cassaVoceReso),
              onTap: () => Navigator.of(sheetContext).pop(TipoRigaCassa.reso),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _aggiungiElementoContestuale(
    BuildContext context,
    ElementoCassa elemento,
  ) async {
    TipoRigaCassa tipoMovimento;
    if (controller.isOperazioneCambio) {
      final scelta = await _scegliTipoCambio(context);
      if (scelta == null) return false;
      tipoMovimento = scelta;
    } else {
      tipoMovimento = controller.isOperazioneReso
          ? TipoRigaCassa.reso
          : TipoRigaCassa.vendita;
    }

    final errore = controller.aggiungiElementoConControlloStock(
      elemento,
      tipoMovimento: tipoMovimento,
    );
    if (errore == null) {
      onStateChanged();
      NotificationService.instance.messageBar(
        'successo',
        'cassa',
        tipoMovimento == TipoRigaCassa.reso
            ? '${elemento.nome} aggiunto come reso'
            : '${elemento.nome} aggiunto al carrello',
      );
      return true;
    } else {
      NotificationService.instance.messageBar('errore', 'cassa', errore);
      return false;
    }
  }

  Future<void> _aggiungiBarcodeDiretto(BuildContext context) async {
    final barcode = searchController.text.trim();
    if (barcode.isEmpty) return;

    final elemento = await controller.ricercaPerBarcode(barcode);
    if (!context.mounted) return;

    if (elemento == null) {
      NotificationService.instance.messageBar(
        'errore',
        'cassa',
        'Il barcode non esiste',
      );
      return;
    }

    if (elemento.quantitaStock <= 0 || !elemento.isDisponibile) {
      NotificationService.instance.messageBar(
        'errore',
        'cassa',
        'Il prodotto non è più disponibile',
      );
      return;
    }

    final aggiunto = await _aggiungiElementoContestuale(context, elemento);
    if (!context.mounted) return;
    if (aggiunto) searchController.clear();
  }

  Future<void> _aggiungiProdottiManualmente(
    BuildContext context,
    CassaController controller,
    List<ProdottoGlobal> prodotti,
    VoidCallback onStateChanged,
  ) async {
    TipoRigaCassa tipoMovimento;
    if (controller.isOperazioneCambio) {
      final scelta = await _scegliTipoCambio(context);
      if (scelta == null) return;
      tipoMovimento = scelta;
    } else {
      tipoMovimento = controller.isOperazioneReso
          ? TipoRigaCassa.reso
          : TipoRigaCassa.vendita;
    }

    final elementi = await controller.elementiPerProdotti(prodotti);
    if (elementi.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'cassa',
        'Nessun prodotto selezionato da aggiungere.',
      );
      return;
    }

    var aggiunti = 0;
    final errori = <String>[];
    for (final elemento in elementi) {
      final errore = controller.aggiungiElementoConControlloStock(
        elemento,
        tipoMovimento: tipoMovimento,
      );
      if (errore == null) {
        aggiunti++;
      } else {
        errori.add('${elemento.nome}: $errore');
      }
    }

    if (aggiunti > 0) onStateChanged();
    if (errori.isEmpty) {
      NotificationService.instance.messageBar(
        'successo',
        'cassa',
        '$aggiunti prodotti aggiunti alla cassa',
      );
    } else {
      NotificationService.instance.messageBar(
        aggiunti > 0 ? 'warning' : 'errore',
        'cassa',
        aggiunti > 0
            ? '$aggiunti prodotti aggiunti. ${errori.length} non aggiunti per stock insufficiente.'
            : 'Nessun prodotto aggiunto: ${errori.first}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;

    return Column(
      children: [
        // Header con ricerca
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                customColors.headerGradientStart,
                customColors.headerGradientEnd,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ricerca Prodotti',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final barcodeField = TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText:
                          context.l10n.inventoryHintInserisciOscansionaBarcode,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      prefixIcon: const Icon(
                        Icons.qr_code,
                        color: Colors.white,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.l10n.cassaAggiungiBarcode,
                            icon: const Icon(
                              Icons.add_shopping_cart,
                              color: Colors.white,
                            ),
                            onPressed: () => _aggiungiBarcodeDiretto(context),
                          ),
                          IconButton(
                            tooltip: context.l10n.cassaCancellaBarcode,
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () => searchController.clear(),
                          ),
                          IconButton(
                            tooltip: context.l10n.cassaScansiona,
                            icon: const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              final scannedCode = await showBarcodeScanner(
                                context,
                              );
                              if (scannedCode != null &&
                                  scannedCode.isNotEmpty) {
                                searchController.text = scannedCode;
                                await _aggiungiBarcodeDiretto(context);
                              }
                            },
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _aggiungiBarcodeDiretto(context),
                  );
                  final manualButton = FilledButton.tonalIcon(
                    onPressed: () async {
                      final prodotti = await openProdottoPicker(context);
                      if (prodotti == null || prodotti.isEmpty) return;
                      if (!context.mounted) return;
                      _aggiungiProdottiManualmente(
                        context,
                        controller,
                        prodotti,
                        onStateChanged,
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(context.l10n.cassaAggiungiManualmente),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        barcodeField,
                        const SizedBox(height: 8),
                        manualButton,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: barcodeField),
                      const SizedBox(width: 8),
                      manualButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Carrello corrente
        Expanded(
          child: _CarrelloScontrinoWidget(
            controller: controller,
            onStateChanged: onStateChanged,
          ),
        ),
      ],
    );
  }
}

/// Lista carrello mostrata nel lato sinistro della cassa.
///
/// Riusa le righe scontrino esistenti senza cambiarne le funzioni: modifica
/// quantità, rimozione riga e sconti riga restano gestiti da
/// [_RigaScontrinoWidget].
class _CarrelloScontrinoWidget extends StatelessWidget {
  final CassaController controller;
  final VoidCallback onStateChanged;

  const _CarrelloScontrinoWidget({
    required this.controller,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scontrino = controller.scontrinoCorrente;

    if (scontrino.isVuoto) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxHeight < 150;
          final iconSize = isTight ? 36.0 : 64.0;
          final titleStyle =
              (isTight
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.titleMedium)
                  ?.copyWith(color: context.colors.subtitleColor);

          if (isTight) {
            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: iconSize,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text('Carrello vuoto', style: titleStyle)),
                ],
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: iconSize,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text('Carrello vuoto', style: titleStyle),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Aggiungi prodotti con barcode, QR o selezione manuale',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: scontrino.righe.length,
      itemBuilder: (context, index) {
        final riga = scontrino.righe[index];
        return _RigaScontrinoWidget(
          riga: riga,
          index: index,
          controller: controller,
          onStateChanged: onStateChanged,
        );
      },
    );
  }
}

class _MobileCheckoutBar extends StatelessWidget {
  final CassaController controller;
  final VoidCallback onStateChanged;
  final VoidCallback onOpenOptions;

  const _MobileCheckoutBar({
    required this.controller,
    required this.onStateChanged,
    required this.onOpenOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final receipt = controller.scontrinoCorrente;
    final actions = _LatoDestroWidget(
      controller: controller,
      onStateChanged: onStateChanged,
    );

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.cassaTotaleMobile,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: context.colors.subtitleColor,
                          ),
                        ),
                        Text(
                          '€${receipt.totale.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: receipt.totale < 0
                                ? customColors.errorColorStatus
                                : customColors.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.shopping_cart_outlined, size: 16),
                    label: Text('${receipt.numeroArticoli}'),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: context.l10n.cassaOpzioniMobile,
                    onPressed: onOpenOptions,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: context.l10n.cassaSvuotaCarrello,
                    onPressed: receipt.isVuoto
                        ? null
                        : () => actions._confermaVuotaCarrello(
                            context,
                            controller,
                            onStateChanged,
                          ),
                    color: customColors.errorColorStatus,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: receipt.isVuoto
                          ? null
                          : () => actions._confermaPagamento(
                              context,
                              controller,
                              onStateChanged,
                            ),
                      icon: const Icon(Icons.payment),
                      label: Text(
                        context.l10n.cassaPaga,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors.successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget lato destro - Scontrino
class _LatoDestroWidget extends StatelessWidget {
  final CassaController controller;
  final VoidCallback onStateChanged;
  final bool showHeader;
  final bool showTotals;
  final bool fillAvailableSpace;

  const _LatoDestroWidget({
    required this.controller,
    required this.onStateChanged,
    this.showHeader = true,
    this.showTotals = true,
    this.fillAvailableSpace = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final scontrino = controller.scontrinoCorrente;

    return Column(
      mainAxisSize: fillAvailableSpace ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Header scontrino
        if (showHeader)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  customColors.headerGradientStart,
                  customColors.headerGradientEnd,
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCONTRINO',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '#${scontrino.id.substring(scontrino.id.length - 6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge numero articoli
                if (!scontrino.isVuoto)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${scontrino.numeroArticoli}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TipoOperazioneCassa>(
                  segments: [
                    ButtonSegment<TipoOperazioneCassa>(
                      value: TipoOperazioneCassa.vendita,
                      icon: Icon(Icons.point_of_sale),
                      label: Text(context.l10n.cassaVendita),
                    ),
                    ButtonSegment<TipoOperazioneCassa>(
                      value: TipoOperazioneCassa.reso,
                      icon: Icon(Icons.assignment_return),
                      label: Text(context.l10n.cassaReso),
                    ),
                    ButtonSegment<TipoOperazioneCassa>(
                      value: TipoOperazioneCassa.cambio,
                      icon: Icon(Icons.swap_horiz),
                      label: Text(context.l10n.cassaCambio),
                    ),
                  ],
                  selected: {controller.tipoOperazioneCorrente},
                  onSelectionChanged: (selection) {
                    controller.setTipoOperazione(selection.first);
                    onStateChanged();
                  },
                ),
              ),
              const SizedBox(height: 12),
              _MetricheCassaCard(controller: controller),
            ],
          ),
        ),

        // Spazio riepilogo: la lista carrello è mostrata nel lato sinistro.
        if (fillAvailableSpace) const Expanded(child: SizedBox.shrink()),

        // Sezione cliente (TODO: solo UI)
        if (!scontrino.isVuoto) ...[
          Divider(height: 1, color: theme.dividerColor),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.hasCliente
                        ? controller.clienteNome!
                        : 'Cliente non associato',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _dialogSelezionaCliente(
                      context,
                      controller,
                      onStateChanged,
                    );
                  },
                  icon: Icon(controller.hasCliente ? Icons.edit : Icons.add),
                  label: Text(controller.hasCliente ? 'Modifica' : 'Aggiungi'),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // Sezione Carta Fedeltà
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.card_membership,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Carta Fedeltà',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _dialogCartaFedelta(
                      context,
                      controller,
                      onStateChanged,
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(context.l10n.cassaScansiona),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // Sezione Coupon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.local_offer, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scontrino.couponCode != null
                        ? 'Coupon: ${scontrino.couponCode}'
                        : 'Nessun coupon',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (scontrino.couponCode != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: customColors.errorColorStatus,
                      size: 20,
                    ),
                    onPressed: () {
                      controller.rimuoviCoupon();
                      onStateChanged();
                    },
                  )
                else
                  TextButton.icon(
                    onPressed: () => _dialogApplicaCoupon(
                      context,
                      controller,
                      onStateChanged,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.cassaApplica),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),

          // Sezione Sospendi/Riprendi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  color: theme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.hasScontriniSospesi
                        ? '${controller.numeroScontriniSospesi} sospesi'
                        : 'Nessuno sospeso',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (controller.hasScontriniSospesi)
                  TextButton.icon(
                    onPressed: () => _dialogScontriniSospesi(
                      context,
                      controller,
                      onStateChanged,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(context.l10n.cassaRiprendi),
                  ),
                if (!scontrino.isVuoto)
                  TextButton.icon(
                    onPressed: () {
                      controller.sospendiScontrino();
                      onStateChanged();
                      NotificationService.instance.messageBar(
                        'successo',
                        'cassa',
                        'Scontrino sospeso',
                      );
                    },
                    icon: const Icon(Icons.pause),
                    label: Text(context.l10n.cassaSospendi),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: theme.dividerColor),
        ],

        // Totali e azioni
        if (showTotals)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Subtotale
                _RigaTotale(
                  label: 'Vendite:',
                  valore: '€${scontrino.totaleVendite.toStringAsFixed(2)}',
                ),

                if (scontrino.totaleResi > 0)
                  _RigaTotale(
                    label: 'Resi:',
                    valore: '-€${scontrino.totaleResi.toStringAsFixed(2)}',
                    colore: customColors.errorColorStatus,
                  ),

                _RigaTotale(
                  label: 'Subtotale netto:',
                  valore: '€${scontrino.subtotale.toStringAsFixed(2)}',
                ),

                // Sconto fisso (se presente)
                if (scontrino.sconto > 0)
                  _RigaTotale(
                    label: 'Sconto:',
                    valore: '-€${scontrino.sconto.toStringAsFixed(2)}',
                    colore: customColors.errorColorStatus,
                  ),

                // Sconto percentuale (se presente)
                if (scontrino.scontoPercentuale > 0)
                  _RigaTotale(
                    label:
                        'Sconto ${scontrino.scontoPercentuale.toStringAsFixed(0)}%:',
                    valore:
                        '-€${(scontrino.subtotale * scontrino.scontoPercentuale / 100).toStringAsFixed(2)}',
                    colore: customColors.errorColorStatus,
                  ),

                // Coupon (se presente)
                if (scontrino.couponSconto > 0)
                  _RigaTotale(
                    label: 'Coupon (${scontrino.couponCode}):',
                    valore: '-€${scontrino.couponSconto.toStringAsFixed(2)}',
                    colore: customColors.errorColorStatus,
                  ),

                // IVA (scorporata)
                if (scontrino.iva > 0)
                  _RigaTotale(
                    label:
                        'IVA (${scontrino.aliquotaIva.toStringAsFixed(0)}%):',
                    valore: '€${scontrino.iva.toStringAsFixed(2)}',
                  ),

                const Divider(height: 24, thickness: 2),

                // TOTALE
                _RigaTotale(
                  label: scontrino.totale < 0 ? 'RIMBORSO:' : 'TOTALE:',
                  valore: '€${scontrino.totale.toStringAsFixed(2)}',
                  isGrande: true,
                  colore: scontrino.totale < 0
                      ? (customColors.errorColorStatus)
                      : (customColors.successColor),
                ),

                const SizedBox(height: 16),

                // Bottoni azione
                Row(
                  children: [
                    // Bottone Svuota
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: scontrino.isVuoto
                            ? null
                            : () {
                                _confermaVuotaCarrello(
                                  context,
                                  controller,
                                  onStateChanged,
                                );
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.l10n.reportSvuota),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: customColors.errorColorStatus,
                          side: BorderSide(
                            color: customColors.errorColorStatus,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Bottone Paga
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: scontrino.isVuoto
                            ? null
                            : () {
                                _confermaPagamento(
                                  context,
                                  controller,
                                  onStateChanged,
                                );
                              },
                        icon: const Icon(Icons.payment, size: 24),
                        label: const Text(
                          'PAGA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customColors.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _confermaVuotaCarrello(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaSvuotaCarrello),
        content: Text(context.l10n.cassaConfermaSvuotaCarrello),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () {
              controller.svuotaCarrello();
              Navigator.pop(context);
              onStateChanged();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.errorColorStatus,
            ),
            child: Text(context.l10n.reportSvuota),
          ),
        ],
      ),
    );
  }

  Future<void> _dialogSelezionaCliente(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) async {
    final nomeController = TextEditingController(
      text: controller.clienteNome ?? '',
    );
    final emailController = TextEditingController(
      text: controller.clienteEmail ?? '',
    );
    final telefonoController = TextEditingController(
      text: controller.clienteTelefono ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaDatiCliente),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: InputDecoration(
                  labelText: context.l10n.commonName,
                  hintText: context.l10n.cassaInserisciNomeCliente,
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: context.l10n.cassaEmailOpzionale,
                  hintText: 'cliente@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                decoration: InputDecoration(
                  labelText: context.l10n.cassaTelefonoOpzionale,
                  hintText: '+39 123 456 7890',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          if (controller.hasCliente)
            TextButton.icon(
              onPressed: () {
                controller.cancellaCliente();
                Navigator.pop(context);
                onStateChanged();
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.prodottiRimuovi),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.errorColorStatus,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeController.text.trim();
              if (nome.isNotEmpty) {
                final carta = await controller.setCliente(
                  nome: nome,
                  email: emailController.text.trim().isNotEmpty
                      ? emailController.text.trim()
                      : null,
                  telefono: telefonoController.text.trim().isNotEmpty
                      ? telefonoController.text.trim()
                      : null,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  onStateChanged();

                  // Mostra messaggio se carta fedeltà trovata
                  if (carta != null) {
                    NotificationService.instance.messageBar(
                      'successo',
                      'cassa',
                      'Carta fedeltà trovata! ${carta['points']} punti disponibili',
                    );
                  }
                }
              } else {
                NotificationService.instance.messageBar(
                  'errore',
                  'cassa',
                  'Il nome è obbligatorio',
                );
              }
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    nomeController.dispose();
    emailController.dispose();
    telefonoController.dispose();
  }

  void _confermaPagamento(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) {
    String metodoPagamento = controller.scontrinoCorrente.metodoPagamento;
    final importoController = TextEditingController();
    double importoRicevuto = 0;
    double resto = 0;
    final totale = controller.scontrinoCorrente.totale;
    final absTotale = totale.abs();
    final tipoOperazione = controller.tipoOperazioneEffettivaCorrente;
    final isRimborso = totale < 0;
    final isCambio = tipoOperazione == TipoOperazioneCassa.cambio;
    final isCambioPari = isCambio && absTotale < 0.009;
    final dialogTitle = isCambioPari
        ? 'Conferma Cambio'
        : isRimborso
        ? 'Conferma Rimborso'
        : 'Conferma Pagamento';
    final actionLabel = isCambioPari
        ? 'Conferma cambio'
        : isRimborso
        ? 'Conferma rimborso'
        : 'Conferma';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final customColors = Theme.of(
            context,
          ).extension<AppColorExtension>()!;

          return AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Totale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (customColors.successColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isCambioPari
                              ? 'CAMBIO A PARI VALORE'
                              : isRimborso
                              ? 'IMPORTO DA RIMBORSARE'
                              : 'TOTALE DA PAGARE',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '€${absTotale.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isRimborso
                                ? (customColors.errorColorStatus)
                                : (customColors.successColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isCambioPari) ...[
                    const SizedBox(height: 20),
                    Text(
                      isRimborso
                          ? 'Metodo di rimborso:'
                          : 'Metodo di pagamento:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: metodoPagamento,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => metodoPagamento = value);
                      },
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  color: customColors.successColor,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.cassaContanti),
                              ],
                            ),
                            value: 'contanti',
                          ),
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  color: customColors.infoColor,
                                ),
                                SizedBox(width: 8),
                                Text(context.l10n.cassaCartaDiCredito),
                              ],
                            ),
                            value: 'carta',
                          ),
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  color: customColors.cardIconColor,
                                ),
                                SizedBox(width: 8),
                                Text(context.l10n.cassaBancomat),
                              ],
                            ),
                            value: 'bancomat',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Calcolo resto per contanti
                  if (!isRimborso &&
                      !isCambioPari &&
                      metodoPagamento == 'contanti') ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: importoController,
                      decoration: InputDecoration(
                        labelText: context.l10n.cassaImportoRicevuto,
                        hintText: context.l10n.cassaEsCinquanta,
                        prefixIcon: Icon(Icons.euro),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          importoRicevuto = double.tryParse(value) ?? 0;
                          resto = importoRicevuto > totale
                              ? importoRicevuto - totale
                              : 0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Pulsanti rapidi per importi comuni
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Pulsante importo esatto
                        ActionChip(
                          label: Text('€${totale.toStringAsFixed(2)}'),
                          avatar: const Icon(Icons.check, size: 16),
                          backgroundColor: customColors.successColor.withValues(
                            alpha: 0.2,
                          ),
                          onPressed: () {
                            setState(() {
                              importoRicevuto = totale;
                              importoController.text = totale.toStringAsFixed(
                                2,
                              );
                              resto = 0;
                            });
                          },
                        ),
                        // Tagli comuni
                        for (final taglio in [5.0, 10.0, 20.0, 50.0, 100.0])
                          if (taglio >= totale)
                            ActionChip(
                              label: Text('€${taglio.toStringAsFixed(0)}'),
                              onPressed: () {
                                setState(() {
                                  importoRicevuto = taglio;
                                  importoController.text = taglio
                                      .toStringAsFixed(2);
                                  resto = taglio - totale;
                                });
                              },
                            ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (importoRicevuto > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: resto > 0
                              ? customColors.infoColor.withValues(alpha: 0.1)
                              : customColors.errorColorStatus.withValues(
                                  alpha: 0.1,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              resto > 0
                                  ? 'RESTO DA DARE'
                                  : 'IMPORTO INSUFFICIENTE',
                              style: TextStyle(
                                fontSize: 11,
                                color: resto > 0
                                    ? customColors.infoColor
                                    : customColors.errorColorStatus,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              resto > 0
                                  ? '€${resto.toStringAsFixed(2)}'
                                  : 'Mancano €${(totale - importoRicevuto).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: resto > 0
                                    ? customColors.infoColor
                                    : customColors.errorColorStatus,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonAnnulla),
              ),
              ElevatedButton(
                onPressed:
                    (!isRimborso &&
                        !isCambioPari &&
                        metodoPagamento == 'contanti' &&
                        importoRicevuto > 0 &&
                        importoRicevuto < totale)
                    ? null
                    : () async {
                        // Imposta il metodo di pagamento e l'importo ricevuto
                        controller.setMetodoPagamento(metodoPagamento);
                        if (!isRimborso &&
                            !isCambioPari &&
                            metodoPagamento == 'contanti') {
                          controller.setImportoRicevuto(
                            importoRicevuto > 0 ? importoRicevuto : totale,
                          );
                        }

                        final success = await controller.completaOperazione();
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (success) {
                            String message = isCambioPari
                                ? 'Cambio registrato con successo!'
                                : isCambio
                                ? isRimborso
                                      ? 'Cambio registrato. Credito cliente: €${absTotale.toStringAsFixed(2)}'
                                      : 'Cambio registrato. Conguaglio da incassare: €${absTotale.toStringAsFixed(2)}'
                                : isRimborso
                                ? 'Reso registrato. Rimborso: €${absTotale.toStringAsFixed(2)}'
                                : 'Vendita completata con successo!';
                            if (!isRimborso &&
                                !isCambioPari &&
                                metodoPagamento == 'contanti' &&
                                resto > 0) {
                              message =
                                  'Vendita completata! Resto: €${resto.toStringAsFixed(2)}';
                            }
                            NotificationService.instance.messageBar(
                              'successo',
                              'cassa',
                              message,
                            );
                            onStateChanged();
                          } else {
                            NotificationService.instance.messageBar(
                              'errore',
                              'cassa',
                              'Errore durante il completamento della vendita',
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRimborso
                      ? (customColors.errorColorStatus)
                      : (customColors.successColor),
                ),
                child: Text(actionLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog per carta fedeltà
  Future<void> _dialogCartaFedelta(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) async {
    final numeroCartaController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaCartaFedelta),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numeroCartaController,
              decoration: InputDecoration(
                labelText: context.l10n.cassaNumeroCarta,
                hintText: context.l10n.cassaInserisciOScansiona,
                prefixIcon: const Icon(Icons.card_membership),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final scanned = await showBarcodeScanner(context);
                    if (scanned != null) {
                      numeroCartaController.text = scanned;
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () async {
              final numeroCarta = numeroCartaController.text.trim();
              if (numeroCarta.isEmpty) return;

              Navigator.pop(context);

              // Cerca la carta fedeltà
              try {
                final carta = await PlatformManager.cartaFedelta
                    .findCustomerByCardNumber(numeroCarta);

                if (carta != null && context.mounted) {
                  // Carta trovata - associa il cliente (già abbiamo i dati della carta, non serve await)
                  await controller.setCliente(
                    nome: '${carta['first_name']} ${carta['last_name']}',
                    email: carta['email'],
                  );
                  onStateChanged();

                  if (context.mounted) {
                    NotificationService.instance.messageBar(
                      'successo',
                      'cassa',
                      'Carta trovata! Cliente: ${carta['first_name']} ${carta['last_name']} - ${carta['points']} punti',
                    );
                  }
                } else if (context.mounted) {
                  NotificationService.instance.messageBar(
                    'errore',
                    'cassa',
                    'Carta non trovata: $numeroCarta',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  NotificationService.instance.messageBar(
                    'errore',
                    'cassa',
                    'Errore: $e',
                  );
                }
              }
            },
            child: Text(context.l10n.commonSearch),
          ),
        ],
      ),
    );

    numeroCartaController.dispose();
  }

  /// Dialog per applicare un coupon
  Future<void> _dialogApplicaCoupon(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) async {
    final couponController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaApplicaCoupon),
        content: TextField(
          controller: couponController,
          decoration: InputDecoration(
            labelText: context.l10n.cassaCodiceCoupon,
            hintText: context.l10n.cassaInserisciIlCodice,
            prefixIcon: Icon(Icons.local_offer),
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () async {
              final codice = couponController.text.trim();
              if (codice.isEmpty) return;

              Navigator.pop(context);

              final success = await controller.applicaCoupon(codice);
              if (context.mounted) {
                if (success) {
                  onStateChanged();
                  NotificationService.instance.messageBar(
                    'successo',
                    'cassa',
                    'Coupon "$codice" applicato!',
                  );
                } else {
                  NotificationService.instance.messageBar(
                    'errore',
                    'cassa',
                    'Coupon "$codice" non valido',
                  );
                }
              }
            },
            child: Text(context.l10n.cassaApplica),
          ),
        ],
      ),
    );

    couponController.dispose();
  }

  /// Dialog per mostrare e riprendere scontrini sospesi
  void _dialogScontriniSospesi(
    BuildContext context,
    CassaController controller,
    VoidCallback onStateChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaScontriniSospesi),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.scontriniSospesi.length,
            itemBuilder: (context, index) {
              final scontrino = controller.scontriniSospesi[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text('€${scontrino.totale.toStringAsFixed(2)}'),
                  subtitle: Text(
                    context.l10n.cassaNumeroArticoli(
                      '${scontrino.numeroArticoli}',
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.play_arrow,
                          color: context.colors.successColor,
                        ),
                        onPressed: () {
                          controller.riprendiScontrino(index);
                          Navigator.pop(context);
                          onStateChanged();
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: context.colors.errorColorStatus,
                        ),
                        onPressed: () {
                          controller.eliminaScontrinoSospeso(index);
                          Navigator.pop(context);
                          if (controller.hasScontriniSospesi) {
                            _dialogScontriniSospesi(
                              context,
                              controller,
                              onStateChanged,
                            );
                          }
                          onStateChanged();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cassaChiudi),
          ),
        ],
      ),
    );
  }
}

/// Widget per una singola riga dello scontrino
class _RigaScontrinoWidget extends StatefulWidget {
  final RigaScontrino riga;
  final int index;
  final CassaController controller;
  final VoidCallback onStateChanged;

  const _RigaScontrinoWidget({
    required this.riga,
    required this.index,
    required this.controller,
    required this.onStateChanged,
  });

  @override
  State<_RigaScontrinoWidget> createState() => _RigaScontrinoWidgetState();
}

class _RigaScontrinoWidgetState extends State<_RigaScontrinoWidget> {
  late final TextEditingController _quantitaController;
  late final FocusNode _quantitaFocusNode;
  late int _lastValidQuantita;
  bool _isInternalUpdate = false;

  RigaScontrino get riga => widget.riga;
  int get index => widget.index;
  CassaController get controller => widget.controller;
  VoidCallback get onStateChanged => widget.onStateChanged;

  @override
  void initState() {
    super.initState();
    _lastValidQuantita = riga.quantita;
    _quantitaController = TextEditingController(text: '$_lastValidQuantita');
    _quantitaFocusNode = FocusNode();
    _quantitaFocusNode.addListener(() {
      if (!_quantitaFocusNode.hasFocus) {
        _ripristinaSeVuoto();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _RigaScontrinoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_quantitaFocusNode.hasFocus && riga.quantita != _lastValidQuantita) {
      _lastValidQuantita = riga.quantita;
      _setControllerText('$_lastValidQuantita');
    }
  }

  @override
  void dispose() {
    _quantitaController.dispose();
    _quantitaFocusNode.dispose();
    super.dispose();
  }

  void _setControllerText(String value) {
    _isInternalUpdate = true;
    _quantitaController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _isInternalUpdate = false;
  }

  void _ripristinaValorePrecedente({String? messaggioErrore}) {
    _setControllerText('$_lastValidQuantita');
    if (messaggioErrore != null && mounted) {
      NotificationService.instance.messageBar(
        'errore',
        'cassa',
        messaggioErrore,
      );
    }
  }

  void _ripristinaSeVuoto() {
    if (_quantitaController.text.trim().isEmpty) {
      _ripristinaValorePrecedente();
    }
  }

  void _applicaQuantitaManuale(String rawValue) {
    if (_isInternalUpdate) return;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final nuovaQuantita = int.tryParse(trimmed);
    if (nuovaQuantita == null) {
      _ripristinaValorePrecedente(
        messaggioErrore: 'Inserisci solo numeri interi.',
      );
      return;
    }
    if (nuovaQuantita <= 0) {
      _ripristinaValorePrecedente(
        messaggioErrore: 'La quantità deve essere maggiore di zero.',
      );
      return;
    }

    final errore = controller.aggiornaQuantitaRiga(index, nuovaQuantita);
    if (errore == null) {
      _lastValidQuantita = nuovaQuantita;
      onStateChanged();
    } else {
      _ripristinaValorePrecedente(messaggioErrore: errore);
      onStateChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final immagineUrl = resolveImageUrl(riga.immagineUrl);

    return GestureDetector(
      onLongPress: () => _showScontoRigaDialog(context),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: immagineUrl != null && immagineUrl.isNotEmpty
                        ? Image.network(
                            immagineUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.shopping_bag, size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          riga.nomeCompleto,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (riga.isReso) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (customColors.errorColorStatus).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'RESO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: customColors.errorColorStatus,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      controller.decrementaQuantitaRiga(index);
                                      onStateChanged();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 52,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: TextFormField(
                                      controller: _quantitaController,
                                      focusNode: _quantitaFocusNode,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 8,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onChanged: _applicaQuantitaManuale,
                                      onFieldSubmitted: _applicaQuantitaManuale,
                                      onTapOutside: (_) {
                                        _ripristinaSeVuoto();
                                        _quantitaFocusNode.unfocus();
                                      },
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      final errore = controller
                                          .incrementaQuantitaRiga(index);
                                      if (errore == null) {
                                        onStateChanged();
                                      } else {
                                        NotificationService.instance.messageBar(
                                          'errore',
                                          'cassa',
                                          errore,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '× €${riga.prezzoUnitario.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: customColors.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Builder(
                        builder: (context) {
                          final customColors = theme
                              .extension<AppColorExtension>()!;
                          return Text(
                            '${riga.isReso ? '-' : ''}€${riga.subtotale.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: riga.isReso
                                  ? customColors.errorColorStatus
                                  : customColors.successColor,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final customColors = theme
                              .extension<AppColorExtension>()!;
                          return InkWell(
                            onTap: () {
                              controller.rimuoviRiga(index);
                              onStateChanged();
                            },
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: customColors.errorColorStatus,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (riga.totaleSconto > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.discount,
                        size: 14,
                        color: customColors.errorColorStatus,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sconto: -€${riga.totaleSconto.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: customColors.errorColorStatus,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScontoRigaDialog(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final percentualeController = TextEditingController(
      text: riga.scontoPercentuale > 0 ? riga.scontoPercentuale.toString() : '',
    );
    final fissoController = TextEditingController(
      text: riga.scontoRiga > 0 ? riga.scontoRiga.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaScontoSullaRiga),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              riga.nomeCompleto,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: percentualeController,
              decoration: InputDecoration(
                labelText: context.l10n.cassaScontoPercentuale,
                hintText: context.l10n.cassaEsDieci,
                prefixIcon: Icon(Icons.percent),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fissoController,
              decoration: InputDecoration(
                labelText: context.l10n.cassaScontoFisso,
                hintText: context.l10n.cassaEsCinque,
                prefixIcon: Icon(Icons.euro),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          if (riga.totaleSconto > 0)
            TextButton.icon(
              onPressed: () {
                controller.rimuoviScontiRiga(index);
                Navigator.pop(context);
                onStateChanged();
              },
              icon: const Icon(Icons.clear),
              label: Text(context.l10n.cassaRimuoviSconti),
              style: TextButton.styleFrom(
                foregroundColor: customColors.errorColorStatus,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () {
              final percentuale =
                  double.tryParse(percentualeController.text) ?? 0;
              final fisso = double.tryParse(fissoController.text) ?? 0;

              if (percentuale > 0) {
                controller.applicaScontoRigaPercentuale(index, percentuale);
              }
              if (fisso > 0) {
                controller.applicaScontoRigaFisso(index, fisso);
              }

              Navigator.pop(context);
              onStateChanged();
            },
            child: Text(context.l10n.cassaApplica),
          ),
        ],
      ),
    );
  }
}

class _MetricheCassaCard extends StatelessWidget {
  final CassaController controller;

  const _MetricheCassaCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final metriche = controller.metricheSnapshot;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricChip(
            label: 'Vendite',
            value: metriche.numeroVendite.toString(),
            icon: Icons.point_of_sale,
          ),
          _MetricChip(
            label: 'Resi',
            value: metriche.numeroResi.toString(),
            icon: Icons.assignment_return,
          ),
          _MetricChip(
            label: 'Cambi',
            value: metriche.numeroCambi.toString(),
            icon: Icons.swap_horiz,
          ),
          _MetricChip(
            label: 'Valore vendite',
            value: '€${metriche.valoreVendite.toStringAsFixed(2)}',
            icon: Icons.trending_up,
          ),
          _MetricChip(
            label: 'Valore resi',
            value: '€${metriche.valoreResi.toStringAsFixed(2)}',
            icon: Icons.undo,
          ),
          _MetricChip(
            label: 'Saldo netto',
            value: '€${metriche.saldoNetto.toStringAsFixed(2)}',
            icon: Icons.analytics_outlined,
          ),
          _MetricChip(
            label: 'Conguagli incassati',
            value: '€${metriche.conguagliPositivi.toStringAsFixed(2)}',
            icon: Icons.arrow_circle_up,
          ),
          _MetricChip(
            label: 'Conguagli rimborsati',
            value: '€${metriche.conguagliNegativi.toStringAsFixed(2)}',
            icon: Icons.arrow_circle_down,
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.primaryColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget helper per le righe dei totali
class _RigaTotale extends StatelessWidget {
  final String label;
  final String valore;
  final bool isGrande;
  final Color? colore;

  const _RigaTotale({
    required this.label,
    required this.valore,
    this.isGrande = false,
    this.colore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isGrande
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodyLarge,
          ),
          Text(
            valore,
            style: isGrande
                ? theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colore ?? theme.textTheme.bodyLarge?.color,
                  )
                : theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colore ?? theme.textTheme.bodyLarge?.color,
                  ),
          ),
        ],
      ),
    );
  }
}
