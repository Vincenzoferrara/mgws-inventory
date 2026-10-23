import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/theme.dart';
import 'customer_list.code.dart';
import '../l10n/extensions.dart';

/// Pagina principale per la gestione dei clienti
class ClientiGestisciPage extends StatefulWidget {
  const ClientiGestisciPage({super.key});

  @override
  ClientiGestisciPageState createState() => ClientiGestisciPageState();
}

class ClientiGestisciPageState extends State<ClientiGestisciPage>
    with AutomaticKeepAliveClientMixin {
  final ClientiGestioneController _controller = ClientiGestioneController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _caricaClienti();
  }

  Future<void> _caricaClienti() async {
    await _controller.caricaClienti();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessario per AutomaticKeepAliveClientMixin
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
        _FiltriWidget(
          controller: _controller,
          onStateChanged: _updateState,
          onRefresh: _caricaClienti,
        ),
        Expanded(child: _buildListaClienti()),
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
              _FiltriWidget(
                controller: _controller,
                onStateChanged: _updateState,
                onRefresh: _caricaClienti,
              ),
              Expanded(child: _buildListaClienti()),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          flex: 2,
          child: _controller.hasClienteSelezionato
              ? _ClienteDettagli(cliente: _controller.clienteSelezionato!)
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: theme.iconTheme.color?.withValues(alpha: 0.4),
          ),
          SizedBox(height: context.spacing.l),
          Text(
            context.l10n.customersSelect,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaClienti() {
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
            Text(
              _controller.errorMessage!(context.l10n),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.l),
            ElevatedButton.icon(
              onPressed: _caricaClienti,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.clientiRiprova),
            ),
          ],
        ),
      );
    }

    if (_controller.clienti.isEmpty) {
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
              context.l10n.customersNoneFound,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: context.spacing.iS,
      itemCount: _controller.clienti.length,
      itemBuilder: (context, index) {
        final cliente = _controller.clienti[index];
        final isSelected = _controller.isClienteSelezionato(cliente);

        return _ClienteListItem(
          cliente: cliente,
          isSelected: isSelected,
          onTap: () {
            _controller.selezionaCliente(cliente);
            _updateState();
          },
        );
      },
    );
  }
}

/// Widget per i filtri e la ricerca
class _FiltriWidget extends StatefulWidget {
  final ClientiGestioneController controller;
  final VoidCallback onStateChanged;
  final VoidCallback onRefresh;

  const _FiltriWidget({
    required this.controller,
    required this.onStateChanged,
    required this.onRefresh,
  });

  @override
  _FiltriWidgetState createState() => _FiltriWidgetState();
}

class _FiltriWidgetState extends State<_FiltriWidget> {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.clientiCercaHint,
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
    );
  }
}

/// Widget per ogni elemento della lista clienti
class _ClienteListItem extends StatelessWidget {
  final dynamic cliente;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClienteListItem({
    required this.cliente,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final dataRegistrazione = cliente.dateCreated != null
        ? dateFormat.format(cliente.dateCreated!)
        : 'N/D';

    final nomeCompleto = '${cliente.firstName ?? ''} ${cliente.lastName ?? ''}'
        .trim();
    final displayName = nomeCompleto.isNotEmpty
        ? nomeCompleto
        : cliente.username ?? 'N/D';

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
                  CircleAvatar(
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                    child: Icon(Icons.person, color: theme.primaryColor),
                  ),
                  SizedBox(width: context.spacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? theme.primaryColor : null,
                          ),
                        ),
                        Text(
                          cliente.email ?? 'N/D',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: customColors.subtitleColor,
                          ),
                        ),
                      ],
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
                    color: customColors.subtitleColor,
                  ),
                  SizedBox(width: context.spacing.xs),
                  Text(
                    context.l10n.customersRegisteredOn(dataRegistrazione),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (cliente.isPayingCustomer == true)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.s,
                        vertical: context.spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: customColors.successColor.withValues(alpha: 0.2),
                        borderRadius: context.shapes.m,
                      ),
                      child: Text(
                        context.l10n.customersPaying,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: customColors.successColor,
                          fontWeight: FontWeight.bold,
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

/// Widget per visualizzare i dettagli di un cliente
class _ClienteDettagli extends StatelessWidget {
  final dynamic cliente;

  const _ClienteDettagli({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final nomeCompleto = '${cliente.firstName ?? ''} ${cliente.lastName ?? ''}'
        .trim();

    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 40, color: theme.primaryColor),
            ),
          ),
          SizedBox(height: context.spacing.l),
          Center(
            child: Text(
              nomeCompleto.isNotEmpty
                  ? nomeCompleto
                  : cliente.username ?? 'N/D',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              cliente.email ?? 'N/D',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ),
          Divider(height: context.spacing.xxl),

          // Informazioni personali
          _buildSezione(
            context,
            context.l10n.customersPersonalInfo,
            Icons.person,
            [
              _buildInfoRow(context, 'Username', cliente.username ?? 'N/D'),
              _buildInfoRow(
                context,
                context.l10n.commonName,
                cliente.firstName ?? 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersLastName,
                cliente.lastName ?? 'N/D',
              ),
              _buildInfoRow(context, 'Email', cliente.email ?? 'N/D'),
              _buildInfoRow(
                context,
                context.l10n.customersRole,
                cliente.role?.value ?? 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersPaying,
                cliente.isPayingCustomer == true
                    ? context.l10n.commonYes
                    : context.l10n.commonNo,
              ),
              _buildInfoRow(
                context,
                context.l10n.customersRegistered,
                cliente.dateCreated != null
                    ? dateFormat.format(cliente.dateCreated!)
                    : 'N/D',
              ),
            ],
          ),
          SizedBox(height: context.spacing.l),

          // Indirizzo di fatturazione
          if (cliente.billing != null)
            _buildSezione(
              context,
              context.l10n.ordersBillingAddress,
              Icons.receipt,
              [
                _buildInfoRow(
                  context,
                  context.l10n.commonName,
                  '${cliente.billing?.firstName ?? ''} ${cliente.billing?.lastName ?? ''}'
                      .trim(),
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersCompany,
                  cliente.billing?.company ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersAddress,
                  cliente.billing?.address1 ?? 'N/D',
                ),
                if (cliente.billing?.address2?.isNotEmpty ?? false)
                  _buildInfoRow(
                    context,
                    context.l10n.customersAddress2,
                    cliente.billing?.address2 ?? '',
                  ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersCity,
                  cliente.billing?.city ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersPostcode,
                  cliente.billing?.postcode ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersProvince,
                  cliente.billing?.state ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersCountry,
                  cliente.billing?.country ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersPhone,
                  cliente.billing?.phone ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  'Email',
                  cliente.billing?.email ?? 'N/D',
                ),
              ],
            ),
          SizedBox(height: context.spacing.l),

          // Indirizzo di spedizione
          if (cliente.shipping != null)
            _buildSezione(
              context,
              context.l10n.customersShippingAddress,
              Icons.local_shipping,
              [
                _buildInfoRow(
                  context,
                  context.l10n.commonName,
                  '${cliente.shipping?.firstName ?? ''} ${cliente.shipping?.lastName ?? ''}'
                      .trim(),
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersCompany,
                  cliente.shipping?.company ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersAddress,
                  cliente.shipping?.address1 ?? 'N/D',
                ),
                if (cliente.shipping?.address2?.isNotEmpty ?? false)
                  _buildInfoRow(
                    context,
                    context.l10n.customersAddress2,
                    cliente.shipping?.address2 ?? '',
                  ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersCity,
                  cliente.shipping?.city ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.ordersPostcode,
                  cliente.shipping?.postcode ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersProvince,
                  cliente.shipping?.state ?? 'N/D',
                ),
                _buildInfoRow(
                  context,
                  context.l10n.customersCountry,
                  cliente.shipping?.country ?? 'N/D',
                ),
              ],
            ),
        ],
      ),
    );
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
            width: 120,
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
}
