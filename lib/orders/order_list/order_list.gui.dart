import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../login/jwt_api/adapter/platform_manager.dart';
import '../../notification/notification_service.dart';
import '../../products/class_products.dart';
import '../../products/product_list/product_list_view.gui.dart';
import '../../reuse_class/barcode/barcode_scanner.dart';
import '../../reuse_class/image_url_resolver.dart';
import '../../theme/theme.dart';
import 'order_list.code.dart';
import '../order_editor/order_editor.gui.dart';
import '../class_orders.dart';
import '../../l10n/extensions.dart';
import '../../reuse_class/datagridview/datagridview_list.gui.dart';

/// Pagina principale per la gestione degli ordini.
///
/// E' una [DataGridListView] sui campi di [OrdiniGlobal]: ricerca, stato e
/// ordinamento vanno al server, che restituisce solo la pagina visibile.
/// Sopra la griglia i conteggi per stato vengono dal server (`X-WP-Total`)
/// e non dipendono dalla pagina caricata.
class OrdiniGestisciPage extends StatefulWidget {
  const OrdiniGestisciPage({super.key});

  @override
  OrdiniGestisciPageState createState() => OrdiniGestisciPageState();
}

class OrdiniGestisciPageState extends State<OrdiniGestisciPage> {
  final OrdiniGestioneController _controller = OrdiniGestioneController();
  late final DataGridListController<OrdiniGlobal> _listController =
      DataGridListController<OrdiniGlobal>(
        fields: OrdiniGlobal.gridFields,
        idOf: _idOf,
        loadPage: _controller.caricaPagina,
        cacheKey: 'ordini',
      );

  static String _idOf(OrdiniGlobal ordine) => '${ordine.id ?? 0}';

  @override
  void initState() {
    super.initState();
    _caricaConteggi();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _caricaConteggi() async {
    try {
      await _controller.caricaConteggiStati();
    } catch (_) {
      // I conteggi sono un aiuto: se il server non risponde la lista resta.
    }
    if (mounted) setState(() {});
  }

  /// Dopo una modifica: la lista si ricarica dal server, i conteggi pure, e
  /// il dettaglio mostra l'ordine aggiornato (o niente, se e' stato
  /// eliminato).
  Future<void> _aggiorna({OrdiniGlobal? aggiornato}) async {
    _listController.select(aggiornato);
    await Future.wait([_listController.reload(force: true), _caricaConteggi()]);
  }

  void _filtraStato(OrdineStatus stato) {
    _listController.setFilters([
      DataGridFilter(
        fieldName: 'stato',
        operatore: DataGridFilterOperator.uguale,
        valori: [stato.name],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DataGridListView<OrdiniGlobal>(
        controller: _listController,
        fields: OrdiniGlobal.gridFields,
        idOf: _idOf,
        loadPage: _controller.caricaPagina,
        cacheKey: 'ordini',
        defaultColumns: const [
          'numero',
          'data',
          'cliente',
          'stato',
          'totale',
          'pagamento',
        ],
        defaultMobileColumns: const ['numero', 'cliente', 'stato'],
        onRefresh: _aggiorna,
        onRowSelected: _controller.selezionaOrdine,
        cellsOf: _buildCells,
        extraFilters: [
          for (final stato in OrdiniGlobal.statiOrdine)
            if ((_controller.conteggiStati[stato] ?? 0) > 0)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: _statusColor(context, stato),
                  radius: 5,
                ),
                label: Text(
                  l10n.ordersStatusCount(
                    ordineStatusLabel(l10n, stato),
                    _controller.conteggiStati[stato] ?? 0,
                  ),
                ),
                onPressed: () => _filtraStato(stato),
              ),
        ],
        emptyDetailsIcon: Icons.receipt_long,
        emptyDetailsTitle: (context) => context.l10n.ordersSelectOrder,
        detailsOf: (context, ordine, inPage) => inPage
            ? _OrdineDettagliPage(
                ordine: ordine,
                controller: _controller,
                onChanged: _aggiorna,
              )
            : _OrdineDettagli(
                ordine: ordine,
                controller: _controller,
                onChanged: _aggiorna,
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostraDialogCreaOrdine(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.ordiniNuovoOrdine),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Map<String, Widget> _buildCells(BuildContext context, OrdiniGlobal ordine) {
    final theme = Theme.of(context);
    final stato = ordine.status;
    return <String, Widget>{
      'numero': Text(
        '#${ordine.number ?? ordine.id ?? ''}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      'data': Text(
        ordine.dateCreated == null
            ? context.l10n.ordersNotAvailable
            : DateFormat('dd/MM/yyyy HH:mm').format(ordine.dateCreated!),
      ),
      'stato': DataGridStatusChip(
        label: stato == null
            ? context.l10n.ordiniStatusSconosciuto
            : ordineStatusLabel(context.l10n, stato),
        color: _statusColor(context, stato),
      ),
    };
  }

  Future<void> _mostraDialogCreaOrdine(BuildContext context) async {
    final ordine = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdiniCreaPage(controller: _controller),
      ),
    );

    // Ricarica la lista se un ordine è stato creato
    if (ordine != null && mounted) {
      await _aggiorna();
    }
  }
}

Color _statusColor(BuildContext context, OrdineStatus? status) {
  final customColors = Theme.of(context).extension<AppColorExtension>()!;
  switch (status) {
    case OrdineStatus.completed:
      return customColors.successColor;
    case OrdineStatus.processing:
      return customColors.infoColor;
    case OrdineStatus.pending:
    case OrdineStatus.refunded:
      return customColors.warningColor;
    case OrdineStatus.cancelled:
    case OrdineStatus.failed:
      return customColors.errorColorStatus;
    default:
      return customColors.subtitleColor;
  }
}

/// Dettaglio ordine a pagina intera, usato su telefono.
class _OrdineDettagliPage extends StatelessWidget {
  final OrdiniGlobal ordine;
  final OrdiniGestioneController controller;
  final Future<void> Function({OrdiniGlobal? aggiornato}) onChanged;

  const _OrdineDettagliPage({
    required this.ordine,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ordersOrderNumber('${ordine.number}')),
      ),
      body: _OrdineDettagli(
        ordine: ordine,
        controller: controller,
        onChanged: onChanged,
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Widget per visualizzare i dettagli di un ordine
class _OrdineDettagli extends StatefulWidget {
  final OrdiniGlobal ordine;
  final OrdiniGestioneController controller;

  /// Dopo cambio stato o eliminazione: la pagina ricarica lista e conteggi.
  final Future<void> Function({OrdiniGlobal? aggiornato}) onChanged;

  /// Dopo l'eliminazione, per chiudere la pagina di dettaglio su telefono.
  final VoidCallback? onDeleted;

  const _OrdineDettagli({
    required this.ordine,
    required this.controller,
    required this.onChanged,
    this.onDeleted,
  });

  @override
  State<_OrdineDettagli> createState() => _OrdineDettagliState();
}

class _OrdineDettagliState extends State<_OrdineDettagli> {
  final Map<int, ProdottoGlobal> _prodottiOrdine = {};
  final Set<int> _productIdsRichiesti = {};

  /// L'ordine della lista arriva senza il barcode dei prodotti, che serve
  /// alla verifica con lo scanner: il dettaglio rilegge l'ordine completo.
  late OrdiniGlobal _ordine = widget.ordine;

  @override
  void initState() {
    super.initState();
    _caricaOrdineCompleto();
    _caricaProdottiOrdine();
  }

  @override
  void didUpdateWidget(covariant _OrdineDettagli oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ordine.id != widget.ordine.id ||
        oldWidget.ordine.status != widget.ordine.status) {
      _ordine = widget.ordine;
      _caricaOrdineCompleto();
      _caricaProdottiOrdine();
    }
  }

  Future<void> _caricaOrdineCompleto() async {
    final id = widget.ordine.id;
    if (id == null) return;
    final completo = await widget.controller.getDettagliOrdine(id);
    if (!mounted || completo == null || widget.ordine.id != id) return;
    setState(() => _ordine = completo);
  }

  Future<void> _caricaProdottiOrdine() async {
    final List<int> productIds =
        _ordine.lineItems
            ?.map((item) => item.productId)
            .whereType<int>()
            .where(_productIdsRichiesti.add)
            .toList() ??
        [];
    if (productIds.isEmpty) return;

    final prodottiCaricati = await Future.wait(
      productIds.map((productId) async {
        try {
          return MapEntry<int, ProdottoGlobal>(
            productId,
            await PlatformManager.prodotti.getProductById(productId),
          );
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;

    setState(() {
      _prodottiOrdine.addEntries(
        prodottiCaricati.whereType<MapEntry<int, ProdottoGlobal>>(),
      );
    });
  }

  String? _immagineProdotto(ProdottoOrdine item) {
    final productId = item.productId;
    if (productId == null) return null;

    final prodotto = _prodottiOrdine[productId];
    if (prodotto == null) return null;

    final variationId = item.variationId;
    if (variationId != null) {
      for (final variante in prodotto.varianti ?? <VarianteProductGlobal>[]) {
        if (variante.id == variationId) {
          return resolveImageUrl(variante.immagineUrl ?? prodotto.immagineUrl);
        }
      }
    }

    return resolveImageUrl(prodotto.immagineUrl);
  }

  String _nomeProdotto(ProdottoOrdine item) {
    final nome = (item.name ?? '').trim();
    return nome.isNotEmpty ? nome : context.l10n.productsUnnamed;
  }

  String _formatImporto(double? value) {
    return NumberFormat('#,##0.00').format(value ?? 0);
  }

  ProdottoGlobal? _prodottoDaItem(ProdottoOrdine item) {
    final productId = item.productId;
    if (productId == null) return null;
    return _prodottiOrdine[productId];
  }

  void _mostraErroreProdotto(String message) {
    NotificationService.instance.messageBar('errore', 'ordini', message);
  }

  Future<void> _apriFotoProdotto(
    BuildContext context,
    ProdottoOrdine item,
  ) async {
    final safeUrl = (_immagineProdotto(item) ?? '').trim();
    if (safeUrl.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: context.spacing.iXL,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.xl,
                    context.spacing.l,
                    context.spacing.m,
                    context.spacing.s,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _nomeProdotto(item),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 5,
                    child: Container(
                      color: theme.colorScheme.surface,
                      alignment: Alignment.center,
                      child: Image.network(
                        safeUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.cardColor,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _apriProdottoInNegozio(ProdottoOrdine item) async {
    final prodotto = _prodottoDaItem(item);
    if (prodotto == null) {
      _mostraErroreProdotto(
        context.l10n.ordersProductNotLoaded(_nomeProdotto(item)),
      );
      return;
    }

    final permalink = (prodotto.permalink ?? '').trim();
    if (permalink.isEmpty) {
      _mostraErroreProdotto(
        context.l10n.ordersShopLinkUnavailable(_nomeProdotto(item)),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(permalink),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _mostraErroreProdotto(context.l10n.ordersCannotOpenInShop);
      }
    } catch (_) {
      _mostraErroreProdotto(context.l10n.ordersCannotOpenInShop);
    }
  }

  void _apriDettaglioProdotto(BuildContext context, ProdottoOrdine item) {
    final prodotto = _prodottoDaItem(item);
    if (prodotto == null) {
      _mostraErroreProdotto(
        context.l10n.ordersProductNotLoaded(_nomeProdotto(item)),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProdottoDettagliView(prodotto: prodotto, showCloseButton: true),
      ),
    );
  }

  Widget _buildAnteprimaProdotto(BuildContext context, ProdottoOrdine item) {
    final imageUrl = _immagineProdotto(item);
    final hasImage = imageUrl?.isNotEmpty ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasImage ? () => _apriFotoProdotto(context, item) : null,
        borderRadius: context.shapes.s,
        child: ClipRRect(
          borderRadius: context.shapes.s,
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 56,
                      height: 56,
                      color: context.colors.surfaceVariantColor,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: context.colors.surfaceVariantColor,
                  child: const Icon(Icons.image_not_supported),
                ),
        ),
      ),
    );
  }

  Widget _buildProdottoRow(BuildContext context, ProdottoOrdine item) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final currency = _ordine.currency ?? 'EUR';
    final barcodeInterno = (item.barcodeInterno ?? '').trim();
    final quantita = item.quantity ?? 0;
    final prezzoUnitario = _formatImporto(item.price);
    final totaleRiga = _formatImporto(item.total);

    return Container(
      margin: EdgeInsets.symmetric(vertical: context.spacing.s),
      padding: context.spacing.iM,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: context.shapes.m,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnteprimaProdotto(context, item),
          SizedBox(width: context.spacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _nomeProdotto(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      color: theme.primaryColor,
                      tooltip: context.l10n.ordiniVerificaBarcode,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _verificaBarcodeProdotto(context, item),
                    ),
                    PopupMenuButton<String>(
                      tooltip: context.l10n.prodottiAzioniProdotto,
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        switch (value) {
                          case 'negozio':
                            _apriProdottoInNegozio(item);
                            break;
                          case 'dettaglio':
                            _apriDettaglioProdotto(context, item);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'negozio',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_browser, size: 20),
                              SizedBox(width: context.spacing.s),
                              Text(context.l10n.ordiniVediInNegozio),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'dettaglio',
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 20),
                              SizedBox(width: context.spacing.s),
                              Text(context.l10n.ordiniVediProdotto),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.s),
                Wrap(
                  spacing: context.spacing.s,
                  runSpacing: context.spacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.s,
                        vertical: context.spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: context.shapes.full,
                      ),
                      child: Text(
                        context.l10n.ordersQuantityValue('$quantita'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (barcodeInterno.isNotEmpty)
                      Text(
                        context.l10n.ordersInternalBarcodeValue(
                          '$barcodeInterno',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.spacing.s),
                Wrap(
                  spacing: context.spacing.m,
                  runSpacing: context.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.ordersUnitPrice('$prezzoUnitario', currency),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      context.l10n.ordersLineTotal('$totaleRiga', currency),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: customColors.successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ordersOrderNumber('${_ordine.number}'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.spacing.s),
                    Text(
                      context.l10n.ordersCreatedAt(
                        _ordine.dateCreated != null
                            ? dateFormat.format(_ordine.dateCreated!)
                            : context.l10n.ordersNotAvailable,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.primaryColor),
                onSelected: (value) => _handleMenuAction(value, context),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'cambiaStato',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: context.spacing.s),
                        Text(context.l10n.ordiniCambiaStato),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'aggiungiNota',
                    child: Row(
                      children: [
                        Icon(Icons.note_add, size: 20),
                        SizedBox(width: context.spacing.s),
                        Text(context.l10n.ordiniAggiungiNota),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'elimina',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: context.colors.errorColorStatus,
                          size: 20,
                        ),
                        SizedBox(width: context.spacing.s),
                        Text(
                          context.l10n.commonDelete,
                          style: context.text.bodyLarge?.copyWith(
                            color: context.colors.errorColorStatus,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: context.spacing.xxl),
          _buildSezione(context, context.l10n.ordersCustomer, Icons.person, [
            _buildInfoRow(
              context,
              context.l10n.commonName,
              '${_ordine.billing?.firstName ?? ''} ${_ordine.billing?.lastName ?? ''}'
                  .trim(),
            ),
            _buildInfoRow(
              context,
              'Email',
              _ordine.billing?.email ?? context.l10n.ordersNotAvailable,
            ),
            _buildInfoRow(
              context,
              context.l10n.ordersPhone,
              _ordine.billing?.phone ?? context.l10n.ordersNotAvailable,
            ),
          ]),
          SizedBox(height: context.spacing.l),
          _buildSezione(
            context,
            context.l10n.ordersAddress,
            Icons.location_on,
            [
              _buildInfoRow(
                context,
                context.l10n.ordersAddress,
                _ordine.billing?.address1 ??
                    context.l10n.ordersNotAvailable,
              ),
              _buildInfoRow(
                context,
                context.l10n.ordersCity,
                _ordine.billing?.city ?? context.l10n.ordersNotAvailable,
              ),
              _buildInfoRow(
                context,
                context.l10n.ordersPostcode,
                _ordine.billing?.postcode ??
                    context.l10n.ordersNotAvailable,
              ),
            ],
          ),
          SizedBox(height: context.spacing.l),
          _buildSezione(
            context,
            context.l10n.ordersProducts,
            Icons.shopping_bag,
            _ordine.lineItems
                    ?.map((item) => _buildProdottoRow(context, item))
                    .toList() ??
                [],
          ),
          SizedBox(height: context.spacing.l),
          Card(
            child: Padding(
              padding: context.spacing.iL,
              child: Column(
                children: [
                  _buildTotaleRow(
                    context,
                    context.l10n.ordersSubtotal,
                    (_ordine.total ??
                            0 -
                                (_ordine.shippingTotal ?? 0) -
                                (_ordine.totalTax ?? 0))
                        .toString(),
                    _ordine.currency,
                  ),
                  _buildTotaleRow(
                    context,
                    context.l10n.ordersShipping,
                    _ordine.shippingTotal?.toString() ?? '0',
                    _ordine.currency,
                  ),
                  _buildTotaleRow(
                    context,
                    context.l10n.ordersTaxes,
                    _ordine.totalTax?.toString() ?? '0',
                    _ordine.currency,
                  ),
                  const Divider(),
                  _buildTotaleRow(
                    context,
                    context.l10n.commonTotal,
                    _ordine.total?.toString() ?? '0',
                    _ordine.currency,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, BuildContext context) {
    switch (action) {
      case 'cambiaStato':
        _mostraDialogCambiaStato(context);
        break;
      case 'aggiungiNota':
        _mostraDialogAggiungiNota(context);
        break;
      case 'elimina':
        _mostraDialogElimina(context);
        break;
    }
  }

  /// Apre lo scanner, scansiona il codice a barre e lo confronta con il barcode
  /// interno del prodotto selezionato nell'ordine.
  Future<void> _verificaBarcodeProdotto(
    BuildContext context,
    ProdottoOrdine item,
  ) async {
    final String? scannedCode = await showBarcodeScanner(context);

    if (scannedCode == null || scannedCode.isEmpty || !mounted) {
      return;
    }

    final String? barcodeInternoProdotto = item.barcodeInterno;
    if (barcodeInternoProdotto == null || barcodeInternoProdotto.isEmpty) {
      NotificationService.instance.messageBar(
        'errore',
        'ordini',
        context.l10n.ordersProductWithoutBarcode('${item.name}'),
      );
      return;
    }

    // Normalizza entrambi i codici: maiuscolo, solo alfanumerici, senza spazi
    String normalizza(String code) =>
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final bool corrisponde =
        normalizza(scannedCode) == normalizza(barcodeInternoProdotto);

    NotificationService.instance.messageBar(
      corrisponde ? 'successo' : 'errore',
      'ordini',
      corrisponde
          ? context.l10n.ordersProductMatches('${item.name}')
          : context.l10n.ordersProductMismatch(
              '${item.barcodeInterno}',
              scannedCode,
            ),
    );
  }

  Future<void> _mostraDialogCambiaStato(BuildContext context) async {
    final controller = widget.controller;
    final nuovoStato = await showDialog<OrdineStatus>(
      context: context,
      builder: (context) => _CambiaStatoDialog(
        statoCorrente: _ordine.status,
        controller: controller,
      ),
    );

    if (nuovoStato != null && mounted) {
      final success = await controller.aggiornaStatoOrdine(
        _ordine.id!,
        nuovoStato,
      );
      if (success && mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'ordini_gestisci',
          context.l10n.ordersStatusUpdated,
        );
        await widget.onChanged(aggiornato: controller.ordineSelezionato);
      }
    }
  }

  Future<void> _mostraDialogAggiungiNota(BuildContext context) async {
    final controller = widget.controller;
    final nota = await showDialog<String>(
      context: context,
      builder: (context) => const _AggiungiNotaDialog(),
    );

    if (nota != null && nota.isNotEmpty && mounted) {
      final success = await controller.aggiungiNota(_ordine.id!, nota);
      if (success && mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'ordini_gestisci',
          context.l10n.ordersNoteAdded,
        );
      }
    }
  }

  Future<void> _mostraDialogElimina(BuildContext context) async {
    final controller = widget.controller;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.ordiniConfermaEliminazione),
        content: Text(
          context.l10n.ordersDeleteConfirm('${_ordine.number}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.errorColorStatus,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (conferma == true && mounted) {
      final success = await controller.eliminaOrdine(
        _ordine.id!,
        force: true,
      );
      if (success && mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'ordini_gestisci',
          context.l10n.ordersDeleted,
        );
        controller.deselezionaOrdine();
        await widget.onChanged();
        widget.onDeleted?.call();
      }
    }
  }

  Widget _buildSezione(
    BuildContext context,
    String titolo,
    IconData icona,
    List<Widget> contenuto,
  ) {
    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, size: 20, color: Theme.of(context).primaryColor),
                SizedBox(width: context.spacing.s),
                Text(
                  titolo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.m),
            ...contenuto,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.colors.subtitleColor,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTotaleRow(
    BuildContext context,
    String label,
    String value,
    String? currency, {
    bool isBold = false,
  }) {
    final style = (isBold ? context.text.titleSmall : context.text.bodyMedium)
        ?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$value ${currency ?? '€'}', style: style),
        ],
      ),
    );
  }
}

/// Dialog per cambiare lo stato di un ordine
class _CambiaStatoDialog extends StatefulWidget {
  final OrdineStatus? statoCorrente;
  final OrdiniGestioneController controller;

  const _CambiaStatoDialog({
    required this.statoCorrente,
    required this.controller,
  });

  @override
  State<_CambiaStatoDialog> createState() => _CambiaStatoDialogState();
}

class _CambiaStatoDialogState extends State<_CambiaStatoDialog> {
  late OrdineStatus? _statoSelezionato;

  @override
  void initState() {
    super.initState();
    _statoSelezionato = widget.statoCorrente;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.ordiniCambiaStatoOrdine),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.ordiniSelezionaNuovoStatoTesto),
          SizedBox(height: context.spacing.l),
          DropdownButtonFormField<OrdineStatus>(
            initialValue: _statoSelezionato,
            decoration: InputDecoration(
              labelText: context.l10n.ordiniStato,
              border: OutlineInputBorder(),
            ),
            items: widget.controller.getStatiDisponibili().map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(
                  widget.controller.getTestoStato(context.l10n, status),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _statoSelezionato = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          onPressed: _statoSelezionato != null
              ? () => Navigator.pop(context, _statoSelezionato)
              : null,
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    );
  }
}

/// Dialog per aggiungere una nota a un ordine
class _AggiungiNotaDialog extends StatefulWidget {
  const _AggiungiNotaDialog();

  @override
  State<_AggiungiNotaDialog> createState() => _AggiungiNotaDialogState();
}

class _AggiungiNotaDialogState extends State<_AggiungiNotaDialog> {
  final _controller = TextEditingController();
  bool _notaCliente = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.ordiniAggiungiNota),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: context.l10n.inventoryEtichettaNota,
              hintText: context.l10n.ordiniHintNota,
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: context.spacing.l),
          CheckboxListTile(
            title: Text(context.l10n.ordiniNotaVisibileAlCliente),
            value: _notaCliente,
            onChanged: (value) {
              setState(() {
                _notaCliente = value ?? false;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(context.l10n.inventoryAzioneAggiungi),
        ),
      ],
    );
  }
}
