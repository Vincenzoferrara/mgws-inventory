import 'class_scontrino.dart';

Map<String, dynamic> buildMgwsCheckoutPayload({
  required Scontrino scontrino,
  String? customerName,
  String? customerEmail,
  String? customerPhone,
}) {
  final saleItems = scontrino.righe
      .where((riga) => riga.tipoMovimento == TipoRigaCassa.vendita)
      .map(_serializeCheckoutLine)
      .toList();
  final returnItems = scontrino.righe
      .where((riga) => riga.tipoMovimento == TipoRigaCassa.reso)
      .map(_serializeCheckoutLine)
      .toList();
  final metadata = <Map<String, dynamic>>[
    {'key': '_punto_vendita', 'value': 'Cassa POS'},
    {'key': '_canale', 'value': scontrino.canale},
    {'key': '_id_scontrino_locale', 'value': scontrino.id},
    {'key': '_data_operazione', 'value': scontrino.data.toIso8601String()},
    {
      'key': '_tipo_operazione_cassa',
      'value': scontrino.tipoOperazioneEffettiva.value,
    },
    {'key': '_totale_resi', 'value': scontrino.totaleResi.toStringAsFixed(2)},
    {'key': '_saldo_operazione', 'value': scontrino.totale.toStringAsFixed(2)},
    if (scontrino.numeroProgressivo != null)
      {
        'key': '_numero_scontrino_pos',
        'value': scontrino.numeroProgressivo.toString(),
      },
    if (scontrino.operatoreId != null)
      {'key': '_operatore_id', 'value': scontrino.operatoreId.toString()},
    if ((scontrino.operatoreNome ?? '').isNotEmpty)
      {
        'key': '_operatore_nome',
        'value':
            '${scontrino.operatoreNome ?? ''} ${scontrino.operatoreCognome ?? ''}'
                .trim(),
      },
    if ((scontrino.cassaNome ?? '').isNotEmpty)
      {'key': '_cassa_nome', 'value': scontrino.cassaNome},
    if ((scontrino.sede ?? '').isNotEmpty)
      {'key': '_sede', 'value': scontrino.sede},
    if ((scontrino.giornataId ?? '').isNotEmpty)
      {'key': '_giornata_id', 'value': scontrino.giornataId},
    if ((scontrino.turnoId ?? '').isNotEmpty)
      {'key': '_turno_id', 'value': scontrino.turnoId},
  ];

  final payload = <String, dynamic>{
    'operation_type': scontrino.tipoOperazione.value,
    'effective_operation_type': scontrino.tipoOperazioneEffettiva.value,
    // Con registratore telematico il progressivo lo emette il dispositivo e
    // viene inviato gia' valorizzato. In simulazione il campo non viaggia e
    // MGWS assegna il numero. La chiave del documento e' gia' il
    // `_id_scontrino_locale` sopra, che MGWS usa anche come idempotency key.
    // With a fiscal register the number is issued by the device and sent
    // already set. In simulation the field is absent and MGWS allocates it.
    if ((scontrino.numeroProgressivoDispositivo ?? '').isNotEmpty)
      'receipt_number': scontrino.numeroProgressivoDispositivo,
    if ((scontrino.turnoId ?? '').isNotEmpty) 'shift_id': scontrino.turnoId,
    'payment_method': scontrino.metodoPagamento,
    'payment_method_title': _paymentMethodTitle(
      scontrino.metodoPagamento,
      isRefund: scontrino.totale < 0,
    ),
    'set_paid': scontrino.totale >= 0,
    'customer': {
      if (customerName != null && customerName.isNotEmpty)
        'first_name': customerName,
      if (customerEmail != null && customerEmail.isNotEmpty)
        'email': customerEmail,
      if (customerPhone != null && customerPhone.isNotEmpty)
        'phone': customerPhone,
    },
    'sale_items': saleItems,
    'return_items': returnItems,
    'totals': {
      'subtotale': scontrino.subtotale,
      'iva': scontrino.iva,
      'sconto': scontrino.sconto,
      'coupon_sconto': scontrino.couponSconto,
      'totale': scontrino.totale,
      'totale_vendite': scontrino.totaleVendite,
      'totale_resi': scontrino.totaleResi,
      'saldo_operazione': scontrino.saldoOperazione,
      'resto': scontrino.resto,
    },
    'meta_data': metadata,
  };

  if (scontrino.note != null && scontrino.note!.isNotEmpty) {
    payload['note'] = scontrino.note;
  }

  if (saleItems.isNotEmpty && returnItems.isNotEmpty) {
    metadata.add({
      'key': '_righe_reso',
      'value': returnItems
          .map(
            (item) =>
                '${item['sku']} x${item['quantity']} (€${item['subtotal']})',
          )
          .join(' | '),
    });
  }

  return payload;
}

String _paymentMethodTitle(String method, {required bool isRefund}) {
  switch (method) {
    case 'contanti':
      return isRefund ? 'Rimborso in Contanti' : 'Pagamento in Contanti';
    case 'carta':
      return isRefund ? 'Rimborso su Carta' : 'Carta di Credito';
    case 'bancomat':
      return isRefund ? 'Rimborso Bancomat/POS' : 'Bancomat/POS';
    default:
      return isRefund ? 'Rimborso' : 'Altro';
  }
}

Map<String, dynamic> _serializeCheckoutLine(RigaScontrino line) {
  return <String, dynamic>{
    if (line.prodotto.id != null) 'product_id': line.prodotto.id,
    if (line.variante != null) 'variation_id': line.variante!.id,
    'quantity': line.quantita,
    'sku': line.variante?.codiceProdotto ?? line.prodotto.codiceProdotto,
    'barcode': line.variante?.barcodeInterno ?? line.prodotto.barcodeInterno,
    'name': line.nomeCompleto,
    'unit_price': line.prezzoUnitario,
    'subtotal': line.subtotale,
    'movement_type': line.tipoMovimento.value,
    'line_key': line.chiaveRiga,
    if (line.riferimentoScontrinoId != null)
      'source_sale_id': line.riferimentoScontrinoId,
    if (line.riferimentoChiaveRiga != null)
      'source_line_key': line.riferimentoChiaveRiga,
    if (line.motivoReso != null) 'return_reason': line.motivoReso,
    if (line.esitoMerce != null) 'return_outcome': line.esitoMerce,
  };
}
