import 'package:shared_preferences/shared_preferences.dart';

import 'class_receipt.dart';

class CassaMetricheSnapshot {
  final int numeroVendite;
  final int numeroResi;
  final int numeroCambi;
  final double valoreVendite;
  final double valoreResi;
  final double saldoNetto;
  final double conguagliPositivi;
  final double conguagliNegativi;

  const CassaMetricheSnapshot({
    this.numeroVendite = 0,
    this.numeroResi = 0,
    this.numeroCambi = 0,
    this.valoreVendite = 0,
    this.valoreResi = 0,
    this.saldoNetto = 0,
    this.conguagliPositivi = 0,
    this.conguagliNegativi = 0,
  });

  CassaMetricheSnapshot copyWith({
    int? numeroVendite,
    int? numeroResi,
    int? numeroCambi,
    double? valoreVendite,
    double? valoreResi,
    double? saldoNetto,
    double? conguagliPositivi,
    double? conguagliNegativi,
  }) {
    return CassaMetricheSnapshot(
      numeroVendite: numeroVendite ?? this.numeroVendite,
      numeroResi: numeroResi ?? this.numeroResi,
      numeroCambi: numeroCambi ?? this.numeroCambi,
      valoreVendite: valoreVendite ?? this.valoreVendite,
      valoreResi: valoreResi ?? this.valoreResi,
      saldoNetto: saldoNetto ?? this.saldoNetto,
      conguagliPositivi: conguagliPositivi ?? this.conguagliPositivi,
      conguagliNegativi: conguagliNegativi ?? this.conguagliNegativi,
    );
  }
}

class CassaMetricheStore {
  static const String _numeroVenditeKey = 'cassa_metriche_numero_vendite';
  static const String _numeroResiKey = 'cassa_metriche_numero_resi';
  static const String _numeroCambiKey = 'cassa_metriche_numero_cambi';
  static const String _valoreVenditeKey = 'cassa_metriche_valore_vendite';
  static const String _valoreResiKey = 'cassa_metriche_valore_resi';
  static const String _saldoNettoKey = 'cassa_metriche_saldo_netto';
  static const String _conguagliPositiviKey =
      'cassa_metriche_conguagli_positivi';
  static const String _conguagliNegativiKey =
      'cassa_metriche_conguagli_negativi';

  CassaMetricheSnapshot _snapshot = const CassaMetricheSnapshot();
  bool _initialized = false;

  CassaMetricheSnapshot get snapshot => _snapshot;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _snapshot = CassaMetricheSnapshot(
      numeroVendite: prefs.getInt(_numeroVenditeKey) ?? 0,
      numeroResi: prefs.getInt(_numeroResiKey) ?? 0,
      numeroCambi: prefs.getInt(_numeroCambiKey) ?? 0,
      valoreVendite: prefs.getDouble(_valoreVenditeKey) ?? 0,
      valoreResi: prefs.getDouble(_valoreResiKey) ?? 0,
      saldoNetto: prefs.getDouble(_saldoNettoKey) ?? 0,
      conguagliPositivi: prefs.getDouble(_conguagliPositiviKey) ?? 0,
      conguagliNegativi: prefs.getDouble(_conguagliNegativiKey) ?? 0,
    );
    _initialized = true;
  }

  Future<void> registraOperazione(Scontrino scontrino) async {
    await init();

    final tipo = scontrino.tipoOperazioneEffettiva;
    final totaleVendite = scontrino.totaleVendite;
    final totaleResi = scontrino.totaleResi;
    final saldo = scontrino.saldoOperazione;

    _snapshot = _snapshot.copyWith(
      numeroVendite:
          _snapshot.numeroVendite +
          (tipo == TipoOperazioneCassa.vendita ? 1 : 0),
      numeroResi:
          _snapshot.numeroResi + (tipo == TipoOperazioneCassa.reso ? 1 : 0),
      numeroCambi:
          _snapshot.numeroCambi + (tipo == TipoOperazioneCassa.cambio ? 1 : 0),
      valoreVendite: _snapshot.valoreVendite + totaleVendite,
      valoreResi: _snapshot.valoreResi + totaleResi,
      saldoNetto: _snapshot.saldoNetto + saldo,
      conguagliPositivi:
          _snapshot.conguagliPositivi +
          (tipo == TipoOperazioneCassa.cambio && saldo > 0 ? saldo : 0),
      conguagliNegativi:
          _snapshot.conguagliNegativi +
          (tipo == TipoOperazioneCassa.cambio && saldo < 0 ? saldo.abs() : 0),
    );

    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_numeroVenditeKey, _snapshot.numeroVendite);
    await prefs.setInt(_numeroResiKey, _snapshot.numeroResi);
    await prefs.setInt(_numeroCambiKey, _snapshot.numeroCambi);
    await prefs.setDouble(_valoreVenditeKey, _snapshot.valoreVendite);
    await prefs.setDouble(_valoreResiKey, _snapshot.valoreResi);
    await prefs.setDouble(_saldoNettoKey, _snapshot.saldoNetto);
    await prefs.setDouble(_conguagliPositiviKey, _snapshot.conguagliPositivi);
    await prefs.setDouble(_conguagliNegativiKey, _snapshot.conguagliNegativi);
  }
}
