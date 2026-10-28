/// Cliente del negozio, indipendente dalla piattaforma: la conversione dal
/// formato WooCommerce sta in `woo_query_customers.dart`.
library;

import '../orders/class_orders.dart';
import '../reuse_class/datagridview/datagridview.code.dart';

class ClienteGlobal {
  final int? id;
  final String? username;
  final String? nome;
  final String? cognome;
  final String? email;

  /// Ruolo dell'account sul sito (`customer`, `subscriber`, ...).
  final String? ruolo;

  /// Ha gia' pagato almeno un ordine.
  final bool pagante;
  final DateTime? dataRegistrazione;
  final String? avatarUrl;
  final IndirizzoBilling? billing;
  final IndirizzoShipping? shipping;

  /// Numero di ordini e totale speso. Null quando il server non li fornisce
  /// (statistiche del negozio non disponibili).
  final int? ordini;
  final double? totaleSpeso;

  const ClienteGlobal({
    this.id,
    this.username,
    this.nome,
    this.cognome,
    this.email,
    this.ruolo,
    this.pagante = false,
    this.dataRegistrazione,
    this.avatarUrl,
    this.billing,
    this.shipping,
    this.ordini,
    this.totaleSpeso,
  });

  /// Nome e cognome, o lo username se mancano entrambi.
  String get nomeCompleto {
    final completo = '${nome ?? ''} ${cognome ?? ''}'.trim();
    return completo.isNotEmpty ? completo : (username ?? '');
  }

  String? get telefono => _nonVuoto(billing?.phone);

  String? get citta => _nonVuoto(billing?.city) ?? _nonVuoto(shipping?.city);

  ClienteGlobal copyWith({int? ordini, double? totaleSpeso}) => ClienteGlobal(
    id: id,
    username: username,
    nome: nome,
    cognome: cognome,
    email: email,
    ruolo: ruolo,
    pagante: pagante,
    dataRegistrazione: dataRegistrazione,
    avatarUrl: avatarUrl,
    billing: billing,
    shipping: shipping,
    ordini: ordini ?? this.ordini,
    totaleSpeso: totaleSpeso ?? this.totaleSpeso,
  );

  /// Forma a mappa con le chiavi del sito, per chi unisce il cliente ad
  /// altri dati (carte fedelta').
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': nome,
    'last_name': cognome,
    'email': email,
    'role': ruolo,
    'is_paying_customer': pagante,
    'date_created': dataRegistrazione?.toIso8601String(),
    'avatar_url': avatarUrl,
    'billing': billing?.toJson(),
    'shipping': shipping?.toJson(),
  };

  static String? _nonVuoto(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Campi del cliente per la lista Clienti. La ricerca libera, l'email
  /// esatta e l'ordinamento per nome o data di registrazione li fa il
  /// server; gli altri filtri lavorano sull'elenco completo.
  static final List<DataGridField<ClienteGlobal>> gridFields =
      <DataGridField<ClienteGlobal>>[
        DataGridField<ClienteGlobal>(
          name: 'id',
          label: (l10n) => l10n.prodottiFiltroCampo_id,
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.id],
          sortable: true,
          serverSortParam: 'id',
          width: 80,
          numeric: true,
        ),
        DataGridField<ClienteGlobal>(
          name: 'nome',
          label: (l10n) => l10n.customersFieldName,
          aliases: const <String>['nome', 'cliente', 'cognome', 'name'],
          read: (c) => <Object?>[c.nomeCompleto, c.username],
          format: (l10n, c) => c.nomeCompleto.isEmpty ? '-' : c.nomeCompleto,
          sortable: true,
          serverSortParam: 'name',
          width: 200,
          flexible: true,
        ),
        DataGridField<ClienteGlobal>(
          name: 'email',
          label: (l10n) => l10n.customersFieldEmail,
          aliases: const <String>['email', 'mail'],
          read: (c) => <Object?>[c.email],
          serverParam: 'email',
          width: 220,
        ),
        DataGridField<ClienteGlobal>(
          name: 'telefono',
          label: (l10n) => l10n.customersFieldPhone,
          aliases: const <String>['telefono', 'phone', 'cellulare'],
          read: (c) => <Object?>[c.telefono],
          width: 140,
        ),
        DataGridField<ClienteGlobal>(
          name: 'citta',
          label: (l10n) => l10n.customersFieldCity,
          aliases: const <String>['citta', 'city', 'comune'],
          read: (c) => <Object?>[c.citta],
          width: 140,
        ),
        DataGridField<ClienteGlobal>(
          name: 'dataRegistrazione',
          label: (l10n) => l10n.customersFieldRegistered,
          aliases: const <String>['registrato', 'registrazione', 'data'],
          type: DataGridFieldType.data,
          read: (c) => <Object?>[c.dataRegistrazione],
          sortable: true,
          serverSortParam: 'registered_date',
          searchable: false,
          width: 140,
        ),
        DataGridField<ClienteGlobal>(
          name: 'ordini',
          label: (l10n) => l10n.customersFieldOrders,
          aliases: const <String>['ordini', 'orders'],
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.ordini],
          sortable: true,
          searchable: false,
          width: 100,
          numeric: true,
        ),
        DataGridField<ClienteGlobal>(
          name: 'totaleSpeso',
          label: (l10n) => l10n.customersFieldTotalSpent,
          aliases: const <String>['speso', 'totale', 'spesa'],
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.totaleSpeso],
          format: (l10n, c) => c.totaleSpeso == null
              ? '-'
              : '€ ${c.totaleSpeso!.toStringAsFixed(2)}',
          sortable: true,
          searchable: false,
          width: 130,
          numeric: true,
        ),
      ];
}
