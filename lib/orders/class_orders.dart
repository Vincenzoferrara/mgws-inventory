/// Classe globale per gestire gli ordini nell'applicazione
/// Questa classe è indipendente da WooCommerce e viene usata in tutta l'app
library;

import '../l10n/extensions.dart';
import '../reuse_class/datagridview/datagridview.code.dart';
import '../reuse_class/datagridview/datagridview_filters.dart';

/// Enum per gli stati degli ordini
enum OrdineStatus {
  pending,
  processing,
  onHold,
  completed,
  cancelled,
  refunded,
  failed,
  trash,
  any;

  /// Ottiene il colore associato allo stato
  String get colore {
    switch (this) {
      case OrdineStatus.pending:
        return 'orange';
      case OrdineStatus.processing:
        return 'blue';
      case OrdineStatus.onHold:
        return 'purple';
      case OrdineStatus.completed:
        return 'green';
      case OrdineStatus.cancelled:
      case OrdineStatus.failed:
        return 'red';
      case OrdineStatus.refunded:
        return 'grey';
      case OrdineStatus.trash:
        return 'darkgrey';
      case OrdineStatus.any:
        return 'grey';
    }
  }
}

/// Etichetta tradotta di uno stato ordine.
///
/// La traduzione non puo' stare nell'enum: un enum non ha accesso alle
/// localizzazioni, e il testo mostrato dipende dalla lingua scelta.
String ordineStatusLabel(AppLocalizations l10n, OrdineStatus status) =>
    switch (status) {
      OrdineStatus.pending => l10n.ordiniStatusInAttesa,
      OrdineStatus.processing => l10n.ordiniStatusInElaborazione,
      OrdineStatus.onHold => l10n.ordiniStatusInSospeso,
      OrdineStatus.completed => l10n.ordiniStatusCompletato,
      OrdineStatus.cancelled => l10n.ordiniStatusAnnullato,
      OrdineStatus.refunded => l10n.ordiniStatusRimborsato,
      OrdineStatus.failed => l10n.ordiniStatusFallito,
      OrdineStatus.trash => l10n.ordiniStatusCestino,
      OrdineStatus.any => l10n.ordiniStatusTutti,
    };

/// Indirizzo di fatturazione
class IndirizzoBilling {
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final String? email;
  final String? phone;

  IndirizzoBilling({
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'company': company,
    'address_1': address1,
    'address_2': address2,
    'city': city,
    'state': state,
    'postcode': postcode,
    'country': country,
    'email': email,
    'phone': phone,
  };
}

/// Indirizzo di spedizione
class IndirizzoShipping {
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;

  IndirizzoShipping({
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'company': company,
    'address_1': address1,
    'address_2': address2,
    'city': city,
    'state': state,
    'postcode': postcode,
    'country': country,
  };
}

/// Prodotto in un ordine
class ProdottoOrdine {
  final int? id;
  final String? name;
  final int? productId;
  final int? variationId;
  final int? quantity;
  final double? subtotal;
  final double? total;
  final String? barcodeInterno;
  final double? price;

  ProdottoOrdine({
    this.id,
    this.name,
    this.productId,
    this.variationId,
    this.quantity,
    this.subtotal,
    this.total,
    this.barcodeInterno,
    this.price,
  });
}

/// Classe principale per gli ordini
class OrdiniGlobal {
  final int? id;
  final String? number;
  final OrdineStatus? status;
  final String? currency;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final DateTime? datePaid;
  final DateTime? dateCompleted;
  final double? total;
  final double? subtotal;
  final double? totalTax;
  final double? shippingTotal;
  final double? shippingTax;
  final double? discountTotal;
  final double? discountTax;
  final String? paymentMethod;
  final String? paymentMethodTitle;
  final IndirizzoBilling? billing;
  final IndirizzoShipping? shipping;
  final List<ProdottoOrdine>? lineItems;
  final String? customerNote;

  /// Stati che un ordine reale puo' avere: `any` e' solo un filtro.
  static const List<OrdineStatus> statiOrdine = <OrdineStatus>[
    OrdineStatus.pending,
    OrdineStatus.processing,
    OrdineStatus.onHold,
    OrdineStatus.completed,
    OrdineStatus.cancelled,
    OrdineStatus.refunded,
    OrdineStatus.failed,
  ];

  /// Nome del cliente dall'indirizzo di fatturazione.
  String get nomeCliente =>
      '${billing?.firstName ?? ''} ${billing?.lastName ?? ''}'.trim();

  /// Campi dell'ordine per la lista Ordini. Ricerca libera, stato e
  /// ordinamento per numero o data li fa il server; gli altri filtri
  /// lavorano sull'elenco completo.
  static final List<DataGridField<OrdiniGlobal>> gridFields =
      <DataGridField<OrdiniGlobal>>[
        DataGridField<OrdiniGlobal>(
          name: 'numero',
          label: (l10n) => l10n.ordersFieldNumber,
          aliases: const <String>['numero', 'ordine', 'id', 'number'],
          read: (o) => <Object?>[o.number ?? o.id?.toString()],
          format: (l10n, o) => '#${o.number ?? o.id ?? ''}',
          sortable: true,
          serverSortParam: 'id',
          width: 100,
        ),
        DataGridField<OrdiniGlobal>(
          name: 'data',
          label: (l10n) => l10n.ordersFieldDate,
          aliases: const <String>['data', 'date', 'creato'],
          type: DataGridFieldType.data,
          read: (o) => <Object?>[o.dateCreated],
          sortable: true,
          serverSortParam: 'date',
          searchable: false,
          width: 120,
        ),
        DataGridField<OrdiniGlobal>(
          name: 'cliente',
          label: (l10n) => l10n.ordersFieldCustomer,
          aliases: const <String>['cliente', 'customer', 'nome', 'email'],
          read: (o) => <Object?>[o.nomeCliente, o.billing?.email],
          format: (l10n, o) =>
              o.nomeCliente.isNotEmpty ? o.nomeCliente : (o.billing?.email ?? '-'),
          width: 200,
          flexible: true,
        ),
        DataGridField<OrdiniGlobal>(
          name: 'stato',
          label: (l10n) => l10n.ordersFieldStatus,
          aliases: const <String>['stato', 'status'],
          type: DataGridFieldType.elenco,
          read: (o) => <Object?>[o.status?.name],
          options: [
            for (final stato in statiOrdine)
              DataGridFieldOption(
                stato.name,
                (l10n) => ordineStatusLabel(l10n, stato),
              ),
          ],
          serverParam: 'status',
          serverOperators: const <DataGridFilterOperator>{
            DataGridFilterOperator.uguale,
            DataGridFilterOperator.inElenco,
          },
          width: 150,
        ),
        DataGridField<OrdiniGlobal>(
          name: 'totale',
          label: (l10n) => l10n.ordersFieldTotal,
          aliases: const <String>['totale', 'total', 'importo'],
          type: DataGridFieldType.numero,
          read: (o) => <Object?>[o.total],
          format: (l10n, o) =>
              '${(o.total ?? 0).toStringAsFixed(2)} ${o.currency ?? '€'}',
          sortable: true,
          width: 120,
          numeric: true,
        ),
        DataGridField<OrdiniGlobal>(
          name: 'pagamento',
          label: (l10n) => l10n.ordersFieldPayment,
          aliases: const <String>['pagamento', 'payment', 'metodo'],
          read: (o) => <Object?>[o.paymentMethodTitle ?? o.paymentMethod],
          width: 170,
        ),
      ];

  OrdiniGlobal({
    this.id,
    this.number,
    this.status,
    this.currency,
    this.dateCreated,
    this.dateModified,
    this.datePaid,
    this.dateCompleted,
    this.total,
    this.subtotal,
    this.totalTax,
    this.shippingTotal,
    this.shippingTax,
    this.discountTotal,
    this.discountTax,
    this.paymentMethod,
    this.paymentMethodTitle,
    this.billing,
    this.shipping,
    this.lineItems,
    this.customerNote,
  });

  /// Crea una copia dell'ordine con alcuni campi modificati
  OrdiniGlobal copyWith({
    int? id,
    String? number,
    OrdineStatus? status,
    String? currency,
    DateTime? dateCreated,
    DateTime? dateModified,
    DateTime? datePaid,
    DateTime? dateCompleted,
    double? total,
    double? subtotal,
    double? totalTax,
    double? shippingTotal,
    double? shippingTax,
    double? discountTotal,
    double? discountTax,
    String? paymentMethod,
    String? paymentMethodTitle,
    IndirizzoBilling? billing,
    IndirizzoShipping? shipping,
    List<ProdottoOrdine>? lineItems,
    String? customerNote,
  }) {
    return OrdiniGlobal(
      id: id ?? this.id,
      number: number ?? this.number,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      datePaid: datePaid ?? this.datePaid,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      total: total ?? this.total,
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      shippingTotal: shippingTotal ?? this.shippingTotal,
      shippingTax: shippingTax ?? this.shippingTax,
      discountTotal: discountTotal ?? this.discountTotal,
      discountTax: discountTax ?? this.discountTax,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodTitle: paymentMethodTitle ?? this.paymentMethodTitle,
      billing: billing ?? this.billing,
      shipping: shipping ?? this.shipping,
      lineItems: lineItems ?? this.lineItems,
      customerNote: customerNote ?? this.customerNote,
    );
  }
}
