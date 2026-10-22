import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../notification/notification_service.dart';
import '../../theme/theme.dart';
import '../class_orders.dart';
import 'incoming_orders.code.dart';
import '../../reuse_class/barcode/barcode_scanner.dart';
import '../../l10n/extensions.dart';

/// Pagina principale per la gestione degli ordini in arrivo
class OrdiniInArrivoPage extends StatefulWidget {
  const OrdiniInArrivoPage({super.key});

  @override
  OrdiniInArrivoPageState createState() => OrdiniInArrivoPageState();
}

class OrdiniInArrivoPageState extends State<OrdiniInArrivoPage> {
  final OrdiniInArrivoController _controller = OrdiniInArrivoController();

  @override
  void initState() {
    super.initState();
    _caricaOrdini();
  }

  Future<void> _caricaOrdini() async {
    await _controller.caricaOrdini();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSmallScreen = constraints.maxWidth < 800;
          if (isSmallScreen) {
            return _buildMobileLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _HeaderInArrivoWidget(controller: _controller),
        _FiltriInArrivoWidget(
          controller: _controller,
          onStateChanged: _updateState,
          onRefresh: _caricaOrdini,
        ),
        Expanded(child: _buildListaOrdini(apriDettaglioInPagina: true)),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _HeaderInArrivoWidget(controller: _controller),
              _FiltriInArrivoWidget(
                controller: _controller,
                onStateChanged: _updateState,
                onRefresh: _caricaOrdini,
              ),
              Expanded(child: _buildListaOrdini(apriDettaglioInPagina: false)),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          flex: 2,
          child: _controller.hasOrdineSelezionato
              ? _OrdineInArrivoDetailView(
                  controller: _controller,
                  ordine: _controller.ordineSelezionato!,
                  onStateChanged: _updateState,
                )
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildListaOrdini({required bool apriDettaglioInPagina}) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colors.errorColorStatus,
            ),
            SizedBox(height: context.spacing.l),
            Text(_controller.errorMessage!, textAlign: TextAlign.center),
            SizedBox(height: context.spacing.l),
            ElevatedButton.icon(
              onPressed: _caricaOrdini,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_controller.ordini.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4),
            ),
            SizedBox(height: context.spacing.l),
            Text(
              'Nessun ordine in arrivo trovato',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: context.spacing.iS,
      itemCount: _controller.ordini.length,
      itemBuilder: (context, index) => _OrdineInArrivoListItem(
        ordine: _controller.ordini[index],
        isSelected: _controller.isOrdineSelezionato(_controller.ordini[index]),
        onTap: () =>
            _selezionaOrdine(_controller.ordini[index], apriDettaglioInPagina),
      ),
    );
  }

  void _selezionaOrdine(OrdiniGlobal ordine, bool apriDettaglioInPagina) {
    _controller.selezionaOrdine(ordine);
    _updateState();
    if (!apriDettaglioInPagina) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${context.l10n.ordiniOrdineNumero}${ordine.number}'),
          ),
          body: _OrdineInArrivoDetailView(
            controller: _controller,
            ordine: ordine,
            onStateChanged: _updateState,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: theme.iconTheme.color?.withValues(alpha: 0.4),
          ),
          SizedBox(height: context.spacing.l),
          Text(
            'Seleziona un ordine in arrivo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInArrivoWidget extends StatelessWidget {
  final OrdiniInArrivoController controller;

  const _HeaderInArrivoWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return Container(
      width: double.infinity,
      padding: context.spacing.iL,
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
          const Icon(Icons.local_shipping, color: Colors.white, size: 28),
          SizedBox(width: context.spacing.m),
          Expanded(
            child: Text(
              'Ordini in arrivo',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Chip(
            label: Text(
              context.l10n.ordiniConteggio('${controller.ordini.length}'),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

class _FiltriInArrivoWidget extends StatefulWidget {
  final OrdiniInArrivoController controller;
  final VoidCallback onStateChanged;
  final VoidCallback onRefresh;

  const _FiltriInArrivoWidget({
    required this.controller,
    required this.onStateChanged,
    required this.onRefresh,
  });

  @override
  State<_FiltriInArrivoWidget> createState() => _FiltriInArrivoWidgetState();
}

class _FiltriInArrivoWidgetState extends State<_FiltriInArrivoWidget> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.spacing.iM,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.ordiniCercaHintTesto,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              widget.controller.setSearchQuery('');
                              widget.onStateChanged();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    widget.controller.setSearchQuery(value);
                    widget.onStateChanged();
                  },
                ),
              ),
              SizedBox(width: context.spacing.s),
              IconButton(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: context.l10n.commonRefresh,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1),
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.s),
          Container(
            padding: context.spacing.hM,
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: context.shapes.s,
              border: Border.all(
                color: Theme.of(
                  context,
                ).inputDecorationTheme.enabledBorder!.borderSide.color,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OrdineStatus?>(
                value: widget.controller.filtroStatus,
                isExpanded: true,
                icon: Icon(
                  Icons.filter_list,
                  color: Theme.of(context).primaryColor,
                ),
                onChanged: (OrdineStatus? newValue) {
                  widget.controller.setFiltroStatus(newValue);
                  widget.onRefresh();
                },
                items: [
                  DropdownMenuItem<OrdineStatus?>(
                    value: null,
                    child: Text(context.l10n.ordiniTuttiGliStati),
                  ),
                  ...OrdineStatus.values.map((status) {
                    return DropdownMenuItem<OrdineStatus?>(
                      value: status,
                      child: Text(ordineStatusLabel(context.l10n, status)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdineInArrivoListItem extends StatelessWidget {
  final OrdiniGlobal ordine;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrdineInArrivoListItem({
    required this.ordine,
    required this.isSelected,
    required this.onTap,
  });

  Color _getStatusColor(BuildContext context, OrdineStatus? status) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    switch (status) {
      case OrdineStatus.completed:
        return customColors.successColor;
      case OrdineStatus.processing:
        return theme.primaryColor;
      case OrdineStatus.pending:
      case OrdineStatus.onHold:
        return customColors.warningColor;
      case OrdineStatus.cancelled:
      case OrdineStatus.failed:
        return customColors.errorColorStatus;
      case OrdineStatus.refunded:
      case OrdineStatus.trash:
      case OrdineStatus.any:
      case null:
        return theme.disabledColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dataOrdine = ordine.dateCreated != null
        ? dateFormat.format(ordine.dateCreated!)
        : 'N/D';

    return Card(
      margin: EdgeInsets.symmetric(
        vertical: context.spacing.xs,
        horizontal: context.spacing.s,
      ),
      elevation: isSelected ? 8 : 2,
      shadowColor: isSelected
          ? theme.primaryColor.withValues(alpha: 0.3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: context.shapes.m,
        side: isSelected
            ? BorderSide(color: theme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? customColors.selectedCardBackground : theme.cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: context.shapes.m,
        child: Padding(
          padding: context.spacing.iM,
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
                          'Ordine #${ordine.number}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.primaryColor : null,
                          ),
                        ),
                        Text(
                          '${ordine.billing?.firstName ?? ''} ${ordine.billing?.lastName ?? ''}'
                              .trim(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${ordine.total?.toStringAsFixed(2) ?? '0.00'} ${ordine.currency ?? 'EUR'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: customColors.successColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.s),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.disabledColor,
                  ),
                  SizedBox(width: context.spacing.xs),
                  Text(dataOrdine, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  _StatusChipInArrivo(
                    label: ordine.status == null
                        ? context.l10n.ordiniStatusSconosciuto
                        : ordineStatusLabel(context.l10n, ordine.status!),
                    color: _getStatusColor(context, ordine.status),
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

class _OrdineInArrivoDetailView extends StatefulWidget {
  final OrdiniInArrivoController controller;
  final OrdiniGlobal ordine;
  final VoidCallback onStateChanged;

  const _OrdineInArrivoDetailView({
    required this.controller,
    required this.ordine,
    required this.onStateChanged,
  });

  @override
  State<_OrdineInArrivoDetailView> createState() =>
      _OrdineInArrivoDetailViewState();
}

class _OrdineInArrivoDetailViewState extends State<_OrdineInArrivoDetailView> {
  Future<void> _scansionaProdotto() async {
    final codice = await showBarcodeScanner(context);
    if (codice == null) return;

    final risultato = widget.controller.verificaCodiceProdotto(codice);
    if (risultato.trovato) {
      NotificationService.instance.messageBar(
        'successo',
        'ordini_in_arrivo',
        'Prodotto verificato: ${risultato.prodotto?.name ?? risultato.prodotto?.barcodeInterno ?? codice}',
      );
    } else {
      NotificationService.instance.messageBar(
        'errore',
        'ordini_in_arrivo',
        'Prodotto non corrispondente all\'ordine: ${risultato.codiceScansionato ?? codice}',
      );
    }
    setState(() {});
    widget.onStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final cliente =
        '${widget.ordine.billing?.firstName ?? ''} ${widget.ordine.billing?.lastName ?? ''}'
            .trim();
    final prodotti = widget.ordine.lineItems ?? <ProdottoOrdine>[];

    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordine #${widget.ordine.number}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacing.s),
          Text(cliente.isEmpty ? 'Cliente non disponibile' : cliente),
          Text(
            'Creato: ${widget.ordine.dateCreated != null ? dateFormat.format(widget.ordine.dateCreated!) : "N/D"}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          Divider(height: context.spacing.xxl),
          Card(
            child: Padding(
              padding: context.spacing.iL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: theme.primaryColor),
                      SizedBox(width: context.spacing.s),
                      Expanded(
                        child: Text(
                          'Verifica prodotti',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacing.m),
                  Wrap(
                    spacing: context.spacing.s,
                    runSpacing: context.spacing.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        avatar: Icon(
                          widget.controller.verificaCompleta
                              ? Icons.check_circle
                              : Icons.inventory_2,
                          color: widget.controller.verificaCompleta
                              ? customColors.successColor
                              : theme.primaryColor,
                        ),
                        label: Text(
                          'Verificati ${widget.controller.numeroProdottiVerificati}/${widget.controller.numeroProdottiTotali}',
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _scansionaProdotto,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(context.l10n.ordiniScansionaProdotto),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.spacing.l),
          Text(
            'Prodotti ordinati',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacing.s),
          ...prodotti.map(
            (prodotto) => _ProdottoInArrivoRow(
              prodotto: prodotto,
              isVerified: widget.controller.isBarcodeInternoVerificato(
                prodotto.barcodeInterno,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProdottoInArrivoRow extends StatelessWidget {
  final ProdottoOrdine prodotto;
  final bool isVerified;

  const _ProdottoInArrivoRow({
    required this.prodotto,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return Card(
      child: ListTile(
        title: Text(prodotto.name ?? 'Prodotto senza nome'),
        subtitle: Text(
          'Quantità: ${prodotto.quantity ?? 0} - Barcode interno: ${prodotto.barcodeInterno ?? 'N/D'}',
        ),
        trailing: Icon(
          isVerified ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isVerified ? customColors.successColor : theme.disabledColor,
        ),
      ),
    );
  }
}

class _StatusChipInArrivo extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChipInArrivo({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: context.shapes.m,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
