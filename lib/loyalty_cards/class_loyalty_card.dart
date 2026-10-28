/// Cliente con la sua carta fedelta', se ne ha una. Unisce il cliente del
/// negozio (WooCommerce) e la carta (MGWS) in un modello solo, quello che la
/// lista Carte fedelta' mostra.
library;

import '../customers/class_customer.dart';
import '../l10n/generated/app_localizations.dart';
import '../reuse_class/datagridview/datagridview.code.dart';

class CartaFedeltaGlobal {
  final int customerId;
  final String nome;
  final String cognome;
  final String email;
  final String? numeroCarta;

  /// Livello della carta: `bronze`, `silver`, `gold` o `platinum`.
  final String livello;
  final int punti;
  final int cardId;
  final bool attiva;

  const CartaFedeltaGlobal({
    required this.customerId,
    this.nome = '',
    this.cognome = '',
    this.email = '',
    this.numeroCarta,
    this.livello = 'bronze',
    this.punti = 0,
    this.cardId = 0,
    this.attiva = false,
  });

  /// Il cliente ha un numero di carta assegnato.
  bool get haCarta => (numeroCarta ?? '').isNotEmpty;

  String get nomeCompleto => '$nome $cognome'.trim();

  /// Cliente [cliente] con la carta [carta] (riga MGWS) o senza.
  factory CartaFedeltaGlobal.daCliente(
    ClienteGlobal cliente,
    Map<String, dynamic>? carta,
  ) {
    return CartaFedeltaGlobal(
      customerId: cliente.id ?? 0,
      nome: cliente.nome ?? '',
      cognome: cliente.cognome ?? '',
      email: cliente.email ?? '',
      numeroCarta: carta?['card_number']?.toString(),
      livello: carta?['tier']?.toString() ?? 'bronze',
      punti: (carta?['points'] as num?)?.toInt() ?? 0,
      cardId: (carta?['id'] as num?)?.toInt() ?? 0,
      attiva: carta?['enabled'] == true,
    );
  }

  /// Riga di carta letta da MGWS (ricerca per numero carta).
  factory CartaFedeltaGlobal.daMappa(Map<String, dynamic> map) {
    return CartaFedeltaGlobal(
      customerId: (map['customer_id'] as num?)?.toInt() ?? 0,
      nome: map['first_name']?.toString() ?? '',
      cognome: map['last_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      numeroCarta: map['card_number']?.toString(),
      livello: map['tier']?.toString() ?? 'bronze',
      punti: int.tryParse(map['points']?.toString() ?? '') ?? 0,
      cardId: (map['card_id'] as num?)?.toInt() ?? 0,
      attiva: map['card_enabled'] == true || map['enabled'] == true,
    );
  }

  /// Forma a mappa con le chiavi usate dal dettaglio e dai dialoghi della
  /// carta.
  Map<String, dynamic> toMap() => {
    'id': customerId,
    'customer_id': customerId,
    'first_name': nome,
    'last_name': cognome,
    'email': email,
    'has_card': haCarta,
    if (haCarta) ...{
      'card_number': numeroCarta,
      'tier': livello,
      'points': punti,
      'card_id': cardId,
      'card_enabled': attiva,
    },
  };

  static const List<String> livelli = <String>[
    'bronze',
    'silver',
    'gold',
    'platinum',
  ];

  static String livelloLabel(AppLocalizations l10n, String livello) =>
      switch (livello.toLowerCase()) {
        'platinum' => l10n.loyaltyTierPlatinum,
        'gold' => l10n.loyaltyTierGold,
        'silver' => l10n.loyaltyTierSilver,
        _ => l10n.loyaltyTierBronze,
      };

  /// Campi della lista Carte fedelta'. Nome ed email esatta vanno al server
  /// dei clienti; numero carta, livello e punti vivono su MGWS e si filtrano
  /// sull'elenco completo, come la ricerca rapida, che deve trovare anche i
  /// numeri di carta.
  static final List<DataGridField<CartaFedeltaGlobal>> gridFields =
      <DataGridField<CartaFedeltaGlobal>>[
        DataGridField<CartaFedeltaGlobal>(
          name: 'nome',
          label: (l10n) => l10n.customersFieldName,
          aliases: const <String>['nome', 'cliente', 'cognome', 'name'],
          read: (c) => <Object?>[c.nomeCompleto],
          sortable: true,
          serverSortParam: 'name',
          width: 200,
          flexible: true,
        ),
        DataGridField<CartaFedeltaGlobal>(
          name: 'email',
          label: (l10n) => l10n.customersFieldEmail,
          aliases: const <String>['email', 'mail'],
          read: (c) => <Object?>[c.email],
          serverParam: 'email',
          width: 220,
        ),
        DataGridField<CartaFedeltaGlobal>(
          name: 'numeroCarta',
          label: (l10n) => l10n.loyaltyCardNumberLabel,
          aliases: const <String>['carta', 'numero', 'card'],
          read: (c) => <Object?>[c.numeroCarta],
          sortable: true,
          width: 170,
        ),
        DataGridField<CartaFedeltaGlobal>(
          name: 'livello',
          label: (l10n) => l10n.loyaltyTierSection,
          aliases: const <String>['livello', 'tier'],
          type: DataGridFieldType.elenco,
          read: (c) => <Object?>[if (c.haCarta) c.livello],
          options: [
            for (final livello in livelli)
              DataGridFieldOption(
                livello,
                (l10n) => livelloLabel(l10n, livello),
              ),
          ],
          width: 120,
        ),
        DataGridField<CartaFedeltaGlobal>(
          name: 'punti',
          label: (l10n) => l10n.loyaltyPointsField,
          aliases: const <String>['punti', 'points'],
          type: DataGridFieldType.numero,
          read: (c) => <Object?>[c.punti],
          sortable: true,
          searchable: false,
          width: 100,
          numeric: true,
        ),
        DataGridField<CartaFedeltaGlobal>(
          name: 'haCarta',
          label: (l10n) => l10n.loyaltyCardsTitle,
          aliases: const <String>['ha carta', 'con carta'],
          type: DataGridFieldType.booleano,
          read: (c) => <Object?>[c.haCarta],
          searchable: false,
          column: false,
        ),
      ];
}
