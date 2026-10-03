import '../../../../log_viewer/app_logger.dart';
import '../connection/mgws_connection.dart';
import 'query_mgws_base.dart';

class QueryMgwsPos {
  QueryMgwsPos();

  final QueryMgwsBase _base = QueryMgwsBase();
  final AppLogger _log = AppLogger();

  Object? checkoutOrderId(Map<String, dynamic> response) {
    return response['order_id'] ?? response['woo_order_id'];
  }

  /// Elenco scontrini con sintesi, per lo storico e i report.
  ///
  /// La sintesi arriva gia' dal server, cosi' il riepilogo di giornata non
  /// richiede di scaricare ogni documento.
  /// Receipt list with aggregates, for the history and the reports.
  /// Dettaglio documento con righe e residuo rendibile.
  ///
  /// Il residuo e' calcolato dal server su tutti i resi registrati: e' la
  /// fonte che vale, perche' conosce anche i resi fatti da altri dispositivi.
  /// Document detail with lines and the returnable remainder, computed by the
  /// server from every recorded return.
  Future<Map<String, dynamic>> listReceipts({
    String? businessDayId,
    String? registerName,
    String? operationType,
    String? paymentMethod,
    String? status,
    int? customerId,
    String? query,
    int? limit,
    int? offset,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.get(
      '/wp-json/mgws/v1/pos/receipts',
      queryParameters: <String, dynamic>{
        if (businessDayId != null && businessDayId.isNotEmpty)
          'business_day_id': businessDayId,
        if (registerName != null && registerName.isNotEmpty)
          'register_name': registerName,
        if (operationType != null && operationType.isNotEmpty)
          'operation_type': operationType,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
        if (status != null && status.isNotEmpty) 'status': status,
        if (customerId != null && customerId > 0) 'customer_id': customerId,
        if (query != null && query.isNotEmpty) 'query': query,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS listReceipts ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Elenco scontrini non strutturato',
    };
  }

  /// Annulla un documento o gli appende una rettifica.
  ///
  /// Le rettifiche sono tracciate sul server: l'annullamento non cancella la
  /// riga, perche' lo storico contabile non si cancella.
  /// Cancels a document or appends a correction to it. Corrections are tracked
  /// server-side and cancelling never deletes the row.
  Future<Map<String, dynamic>> updateReceiptStatus({
    required String receiptKey,
    required String status,
    String? note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/receipts/'
      '${Uri.encodeComponent(receiptKey)}/status',
      data: <String, dynamic>{'status': status, if (note != null) 'note': note},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS updateReceiptStatus ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Aggiornamento documento non strutturato',
    };
  }

  /// Storico chiusure di turno.
  /// Shift closing history.
  Future<Map<String, dynamic>> listClosings({
    String? businessDayId,
    String? registerName,
    int? limit,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.get(
      '/wp-json/mgws/v1/pos/closings',
      queryParameters: <String, dynamic>{
        if (businessDayId != null && businessDayId.isNotEmpty)
          'business_day_id': businessDayId,
        if (registerName != null && registerName.isNotEmpty)
          'register_name': registerName,
        if (limit != null) 'limit': limit,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS listClosings ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Elenco chiusure non strutturato',
    };
  }

  /// Registra una chiusura di turno. La chiave rende l'invio idempotente.
  /// Records a shift closing. The key makes the submit idempotent.
  Future<Map<String, dynamic>> createClosing(
    Map<String, dynamic> payload,
  ) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/closings',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS createClosing ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Chiusura non strutturata',
    };
  }

  /// Aggiunge una rettifica a una chiusura esistente.
  /// Appends a correction to an existing shift closing.
  Future<Map<String, dynamic>> addClosingCorrection({
    required String closingKey,
    required String note,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/closings/'
      '${Uri.encodeComponent(closingKey)}/corrections',
      data: <String, dynamic>{'note': note},
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS addClosingCorrection ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Rettifica chiusura non strutturata',
    };
  }

  Future<Map<String, dynamic>> getReceipt(String receiptKey) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.get(
      '/wp-json/mgws/v1/pos/receipts/${Uri.encodeComponent(receiptKey)}',
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS getReceipt ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success': false,
      'status_code': response.statusCode,
      'message': 'Dettaglio scontrino non strutturato',
    };
  }

  Future<Map<String, dynamic>> getSettings() async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.get('/wp-json/mgws/v1/pos/settings');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS settings ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success':
          (response.statusCode ?? 500) >= 200 &&
          (response.statusCode ?? 500) < 300,
      'status_code': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> updateSettings({
    required bool turnoObbligatorio,
  }) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.put(
      '/wp-json/mgws/v1/pos/settings',
      data: <String, dynamic>{'turno_obbligatorio': turnoObbligatorio},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w(
      'MGWS POS updateSettings ha restituito una risposta non strutturata',
    );
    return <String, dynamic>{
      'success':
          (response.statusCode ?? 500) >= 200 &&
          (response.statusCode ?? 500) < 300,
      'status_code': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/checkout',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS checkout ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success':
          (response.statusCode ?? 500) >= 200 &&
          (response.statusCode ?? 500) < 300,
      'status_code': response.statusCode,
    };
  }

  /// Apre uno shift (turno cassa) lato server MGWS. Il server è autorevole:
  /// se non conferma l'apertura (es. 409 già aperto, backend giù) l'app nega
  /// il turno locale. La shift_key coincide con `turno.id` e viene riferita
  /// come `shift_id` (root) in ogni checkout per l'enforcement di apertura.
  Future<Map<String, dynamic>> openShift(Map<String, dynamic> payload) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/shifts',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS openShift ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success':
          (response.statusCode ?? 500) >= 200 &&
          (response.statusCode ?? 500) < 300,
      'status_code': response.statusCode,
    };
  }

  /// Chiude uno shift lato server: l'app manda SOLO i conteggi «contato»;
  /// il plugin calcola expected_totals dagli ordini (`_mgws_shift_id`,
  /// HPOS-safe) e restituisce le differenze. Errore server → niente chiusura
  /// locale.
  Future<Map<String, dynamic>> closeShift(
    String shiftIdent,
    Map<String, dynamic> payload,
  ) async {
    if (!await MgwsConnection.instance.ensureConnected()) {
      return const <String, dynamic>{
        'success': false,
        'message': 'Backend MGWS non disponibile',
      };
    }

    final response = await _base.post(
      '/wp-json/mgws/v1/pos/shifts/$shiftIdent/close',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    _log.w('MGWS POS closeShift ha restituito una risposta non strutturata');
    return <String, dynamic>{
      'success':
          (response.statusCode ?? 500) >= 200 &&
          (response.statusCode ?? 500) < 300,
      'status_code': response.statusCode,
    };
  }
}
