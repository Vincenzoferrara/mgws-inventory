import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/theme.dart';
import '../reuse_class/datagridview/datagridview_list.gui.dart';
import 'class_customer.dart';
import 'customer_list.code.dart';
import '../l10n/extensions.dart';

/// Pagina principale per la gestione dei clienti.
///
/// E' una [DataGridListView] sui campi di [ClienteGlobal]: ricerca libera,
/// email e ordinamento vanno al server, che restituisce solo la pagina
/// visibile; con un filtro su un altro campo la lista carica tutti i clienti
/// e filtra in memoria.
class ClientiGestisciPage extends StatefulWidget {
  const ClientiGestisciPage({super.key});

  @override
  ClientiGestisciPageState createState() => ClientiGestisciPageState();
}

class ClientiGestisciPageState extends State<ClientiGestisciPage> {
  final ClientiGestioneController _controller = ClientiGestioneController();

  @override
  Widget build(BuildContext context) {
    return DataGridListView<ClienteGlobal>(
      fields: ClienteGlobal.gridFields,
      idOf: (cliente) => '${cliente.id ?? 0}',
      loadPage: _controller.caricaPagina,
      cacheKey: 'clienti',
      defaultColumns: const [
        'nome',
        'email',
        'telefono',
        'citta',
        'dataRegistrazione',
        'ordini',
        'totaleSpeso',
      ],
      defaultMobileColumns: const ['nome', 'email'],
      onRowSelected: _controller.selezionaCliente,
      cellsOf: (context, cliente) => <String, Widget>{
        'nome': Text(
          cliente.nomeCompleto.isEmpty ? '-' : cliente.nomeCompleto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        'dataRegistrazione': Text(
          cliente.dataRegistrazione == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(cliente.dataRegistrazione!),
        ),
      },
      emptyDetailsIcon: Icons.person_outline,
      emptyDetailsTitle: (context) => context.l10n.customersSelect,
      detailsOf: (context, cliente, inPage) => inPage
          ? Scaffold(
              appBar: AppBar(title: Text(cliente.nomeCompleto)),
              body: _ClienteDettagli(cliente: cliente),
            )
          : _ClienteDettagli(cliente: cliente),
    );
  }
}

class _ClienteDettagli extends StatelessWidget {
  final ClienteGlobal cliente;

  const _ClienteDettagli({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final nomeCompleto = '${cliente.nome ?? ''} ${cliente.cognome ?? ''}'
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
                cliente.nome ?? 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersLastName,
                cliente.cognome ?? 'N/D',
              ),
              _buildInfoRow(context, 'Email', cliente.email ?? 'N/D'),
              _buildInfoRow(
                context,
                context.l10n.customersRole,
                cliente.ruolo ?? 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersPaying,
                cliente.pagante
                    ? context.l10n.commonYes
                    : context.l10n.commonNo,
              ),
              _buildInfoRow(
                context,
                context.l10n.customersRegistered,
                cliente.dataRegistrazione != null
                    ? dateFormat.format(cliente.dataRegistrazione!)
                    : 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersFieldOrders,
                cliente.ordini?.toString() ?? 'N/D',
              ),
              _buildInfoRow(
                context,
                context.l10n.customersFieldTotalSpent,
                cliente.totaleSpeso == null
                    ? 'N/D'
                    : '€ ${cliente.totaleSpeso!.toStringAsFixed(2)}',
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
