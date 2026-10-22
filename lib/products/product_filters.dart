import 'class_products.dart';
import '../l10n/extensions.dart';

enum CampoFiltroProdotto {
  ricercaRapida,
  id,
  nome,
  codiceArticolo,
  barcode,
  categoria,
  tag,
  marchio,
  prezzo,
  giacenza,
  disponibilita,
  descrizioneBreve,
  descrizioneCompleta,
  stanza,
  scaffale,
  mensola,
  status,
}

enum OperatoreFiltroProdotto {
  contiene,
  nonContiene,
  contieneSensibile,
  nonContieneSensibile,
  ugualeEsatto,
  diversoEsatto,
  iniziaCon,
  finisceCon,
  inElenco,
  nonInElenco,
  uguale,
  diverso,
  maggioreUguale,
  maggiore,
  minoreUguale,
  minore,
  tra,
}

class FiltroProdotto {
  final CampoFiltroProdotto campo;
  final OperatoreFiltroProdotto operatore;
  final List<String> valori;

  const FiltroProdotto({
    required this.campo,
    required this.operatore,
    required this.valori,
  });

  String campoLabel(AppLocalizations l10n) =>
      ProdottoFilterEngine.campoLabel(l10n, campo);
  String operatoreLabel(AppLocalizations l10n) =>
      ProdottoFilterEngine.operatoreLabel(l10n, operatore);

  /// Etichetta del chip mostrata nell'elenco dei filtri attivi.
  String chipLabel(AppLocalizations l10n) =>
      '${campoLabel(l10n)} ${operatoreLabel(l10n)} '
      '${valori.join(', ')}';
}

class ProdottoFilterEngine {
  static const Map<CampoFiltroProdotto, List<String>>
  campoAliases = <CampoFiltroProdotto, List<String>>{
    CampoFiltroProdotto.ricercaRapida: <String>[
      'ricerca rapida',
      'ricerca',
      'search',
    ],
    CampoFiltroProdotto.id: <String>['id', 'identificativo id'],
    CampoFiltroProdotto.nome: <String>['nome', 'prodotto', 'product', 'titolo'],
    CampoFiltroProdotto.codiceArticolo: <String>[
      'sku',
      'codice',
      'codice prodotto',
      'articolo',
    ],
    CampoFiltroProdotto.barcode: <String>[
      'barcode',
      'barcode interno',
      'barcode esterno',
      'barcode produttore',
      'ean',
      'upc',
      'gtin',
      'global_unique_id',
      'global unique id',
    ],
    CampoFiltroProdotto.categoria: <String>['categoria', 'categorie', 'cat'],
    CampoFiltroProdotto.tag: <String>['tag', 'etichette'],
    CampoFiltroProdotto.marchio: <String>['marchio', 'marca', 'brand'],
    CampoFiltroProdotto.prezzo: <String>['prezzo', 'price', 'costo'],
    CampoFiltroProdotto.giacenza: <String>['giacenza', 'stock', 'quantita'],
    CampoFiltroProdotto.disponibilita: <String>['disponibilita', 'instock'],
    CampoFiltroProdotto.descrizioneBreve: <String>[
      'descrizione breve',
      'breve',
      'excerpt',
    ],
    CampoFiltroProdotto.descrizioneCompleta: <String>[
      'descrizione',
      'descrizione completa',
      'contenuto',
    ],
    CampoFiltroProdotto.stanza: <String>['stanza', 'room'],
    CampoFiltroProdotto.scaffale: <String>['scaffale', 'rack'],
    CampoFiltroProdotto.mensola: <String>['mensola', 'shelf'],
    CampoFiltroProdotto.status: <String>['stato', 'status'],
  };

  static const List<CampoFiltroProdotto> searchableFields =
      <CampoFiltroProdotto>[
        CampoFiltroProdotto.nome,
        CampoFiltroProdotto.codiceArticolo,
        CampoFiltroProdotto.barcode,
        CampoFiltroProdotto.id,
        CampoFiltroProdotto.categoria,
        CampoFiltroProdotto.tag,
        CampoFiltroProdotto.marchio,
        CampoFiltroProdotto.prezzo,
        CampoFiltroProdotto.giacenza,
        CampoFiltroProdotto.descrizioneBreve,
        CampoFiltroProdotto.descrizioneCompleta,
        CampoFiltroProdotto.stanza,
        CampoFiltroProdotto.scaffale,
        CampoFiltroProdotto.mensola,
        CampoFiltroProdotto.status,
      ];

  /// Etichetta tradotta del campo di filtro.
  ///
  static String campoLabel(
    AppLocalizations l10n,
    CampoFiltroProdotto campo,
  ) => switch (campo) {
    CampoFiltroProdotto.ricercaRapida => l10n.prodottiFiltroCampo_ricercaRapida,
    CampoFiltroProdotto.id => l10n.prodottiFiltroCampo_id,
    CampoFiltroProdotto.nome => l10n.prodottiFiltroCampo_nome,
    CampoFiltroProdotto.codiceArticolo =>
      l10n.prodottiFiltroCampo_codiceArticolo,
    CampoFiltroProdotto.barcode => l10n.prodottiFiltroCampo_barcode,
    CampoFiltroProdotto.categoria => l10n.prodottiFiltroCampo_categoria,
    CampoFiltroProdotto.tag => l10n.prodottiFiltroCampo_tag,
    CampoFiltroProdotto.marchio => l10n.prodottiFiltroCampo_marchio,
    CampoFiltroProdotto.prezzo => l10n.prodottiFiltroCampo_prezzo,
    CampoFiltroProdotto.giacenza => l10n.prodottiFiltroCampo_giacenza,
    CampoFiltroProdotto.disponibilita => l10n.prodottiFiltroCampo_disponibilita,
    CampoFiltroProdotto.descrizioneBreve =>
      l10n.prodottiFiltroCampo_descrizioneBreve,
    CampoFiltroProdotto.descrizioneCompleta =>
      l10n.prodottiFiltroCampo_descrizioneCompleta,
    CampoFiltroProdotto.stanza => l10n.prodottiFiltroCampo_stanza,
    CampoFiltroProdotto.scaffale => l10n.prodottiFiltroCampo_scaffale,
    CampoFiltroProdotto.mensola => l10n.prodottiFiltroCampo_mensola,
    CampoFiltroProdotto.status => l10n.prodottiFiltroCampo_status,
  };

  /// Etichetta tradotta dell'operatore di filtro.
  static String operatoreLabel(
    AppLocalizations l10n,
    OperatoreFiltroProdotto operatore,
  ) => switch (operatore) {
    OperatoreFiltroProdotto.contiene => l10n.prodottiFiltroOperatore_contiene,
    OperatoreFiltroProdotto.nonContiene =>
      l10n.prodottiFiltroOperatore_nonContiene,
    OperatoreFiltroProdotto.contieneSensibile =>
      l10n.prodottiFiltroOperatore_contieneSensibile,
    OperatoreFiltroProdotto.nonContieneSensibile =>
      l10n.prodottiFiltroOperatore_nonContieneSensibile,
    OperatoreFiltroProdotto.ugualeEsatto =>
      l10n.prodottiFiltroOperatore_ugualeEsatto,
    OperatoreFiltroProdotto.diversoEsatto =>
      l10n.prodottiFiltroOperatore_diversoEsatto,
    OperatoreFiltroProdotto.iniziaCon => l10n.prodottiFiltroOperatore_iniziaCon,
    OperatoreFiltroProdotto.finisceCon =>
      l10n.prodottiFiltroOperatore_finisceCon,
    OperatoreFiltroProdotto.inElenco => l10n.prodottiFiltroOperatore_inElenco,
    OperatoreFiltroProdotto.nonInElenco =>
      l10n.prodottiFiltroOperatore_nonInElenco,
    OperatoreFiltroProdotto.uguale => l10n.prodottiFiltroOperatore_uguale,
    OperatoreFiltroProdotto.diverso => l10n.prodottiFiltroOperatore_diverso,
    OperatoreFiltroProdotto.maggioreUguale =>
      l10n.prodottiFiltroOperatore_maggioreUguale,
    OperatoreFiltroProdotto.maggiore => l10n.prodottiFiltroOperatore_maggiore,
    OperatoreFiltroProdotto.minoreUguale =>
      l10n.prodottiFiltroOperatore_minoreUguale,
    OperatoreFiltroProdotto.minore => l10n.prodottiFiltroOperatore_minore,
    OperatoreFiltroProdotto.tra => l10n.prodottiFiltroOperatore_tra,
  };

  /// Spiegazione tradotta dell'operatore di filtro.
  static String operatoreTooltip(
    AppLocalizations l10n,
    OperatoreFiltroProdotto operatore,
  ) => switch (operatore) {
    OperatoreFiltroProdotto.uguale => l10n.prodottiFiltroTooltip_uguale,
    OperatoreFiltroProdotto.diverso => l10n.prodottiFiltroTooltip_diverso,
    OperatoreFiltroProdotto.contiene => l10n.prodottiFiltroTooltip_contiene,
    OperatoreFiltroProdotto.nonContiene =>
      l10n.prodottiFiltroTooltip_nonContiene,
    OperatoreFiltroProdotto.contieneSensibile =>
      l10n.prodottiFiltroTooltip_contieneSensibile,
    OperatoreFiltroProdotto.nonContieneSensibile =>
      l10n.prodottiFiltroTooltip_nonContieneSensibile,
    OperatoreFiltroProdotto.ugualeEsatto =>
      l10n.prodottiFiltroTooltip_ugualeEsatto,
    OperatoreFiltroProdotto.diversoEsatto =>
      l10n.prodottiFiltroTooltip_diversoEsatto,
    OperatoreFiltroProdotto.iniziaCon => l10n.prodottiFiltroTooltip_iniziaCon,
    OperatoreFiltroProdotto.finisceCon => l10n.prodottiFiltroTooltip_finisceCon,
    OperatoreFiltroProdotto.inElenco => l10n.prodottiFiltroTooltip_inElenco,
    OperatoreFiltroProdotto.nonInElenco =>
      l10n.prodottiFiltroTooltip_nonInElenco,
    OperatoreFiltroProdotto.maggioreUguale =>
      l10n.prodottiFiltroTooltip_maggioreUguale,
    OperatoreFiltroProdotto.maggiore => l10n.prodottiFiltroTooltip_maggiore,
    OperatoreFiltroProdotto.minoreUguale =>
      l10n.prodottiFiltroTooltip_minoreUguale,
    OperatoreFiltroProdotto.minore => l10n.prodottiFiltroTooltip_minore,
    OperatoreFiltroProdotto.tra => l10n.prodottiFiltroTooltip_tra,
  };

  static List<OperatoreFiltroProdotto> orderedOperators() {
    return <OperatoreFiltroProdotto>[
      OperatoreFiltroProdotto.contiene,
      OperatoreFiltroProdotto.nonContiene,
      OperatoreFiltroProdotto.ugualeEsatto,
      OperatoreFiltroProdotto.diversoEsatto,
      OperatoreFiltroProdotto.inElenco,
      OperatoreFiltroProdotto.nonInElenco,
      OperatoreFiltroProdotto.iniziaCon,
      OperatoreFiltroProdotto.finisceCon,
      OperatoreFiltroProdotto.contieneSensibile,
      OperatoreFiltroProdotto.nonContieneSensibile,
      OperatoreFiltroProdotto.uguale,
      OperatoreFiltroProdotto.diverso,
      OperatoreFiltroProdotto.maggiore,
      OperatoreFiltroProdotto.maggioreUguale,
      OperatoreFiltroProdotto.minore,
      OperatoreFiltroProdotto.minoreUguale,
      OperatoreFiltroProdotto.tra,
    ];
  }

  /// Nome tradotto del gruppo di operatori a cui appartiene quello scelto.
  static String operatorSectionLabel(
    AppLocalizations l10n,
    OperatoreFiltroProdotto operatore,
  ) {
    switch (operatore) {
      case OperatoreFiltroProdotto.contiene:
      case OperatoreFiltroProdotto.nonContiene:
      case OperatoreFiltroProdotto.ugualeEsatto:
      case OperatoreFiltroProdotto.diversoEsatto:
      case OperatoreFiltroProdotto.inElenco:
      case OperatoreFiltroProdotto.nonInElenco:
        return l10n.prodottiFiltroSezioneComuni;
      case OperatoreFiltroProdotto.iniziaCon:
      case OperatoreFiltroProdotto.finisceCon:
      case OperatoreFiltroProdotto.contieneSensibile:
      case OperatoreFiltroProdotto.nonContieneSensibile:
        return l10n.prodottiFiltroSezioneTestoAvanzato;
      case OperatoreFiltroProdotto.uguale:
      case OperatoreFiltroProdotto.diverso:
      case OperatoreFiltroProdotto.maggiore:
      case OperatoreFiltroProdotto.maggioreUguale:
      case OperatoreFiltroProdotto.minore:
      case OperatoreFiltroProdotto.minoreUguale:
      case OperatoreFiltroProdotto.tra:
        return l10n.prodottiFiltroSezioneNumerici;
    }
  }

  static CampoFiltroProdotto? resolveCampoFromInput(
    AppLocalizations l10n,
    String input,
  ) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final entry in campoAliases.entries) {
      final label = campoLabel(l10n, entry.key).toLowerCase();
      if (label == normalized ||
          entry.value.any((alias) => alias == normalized)) {
        return entry.key;
      }
    }
    return null;
  }

  static bool isNumericField(CampoFiltroProdotto campo) {
    return campo == CampoFiltroProdotto.id ||
        campo == CampoFiltroProdotto.prezzo ||
        campo == CampoFiltroProdotto.giacenza;
  }

  static bool isBooleanField(CampoFiltroProdotto campo) {
    return campo == CampoFiltroProdotto.disponibilita;
  }

  static bool supportsOperator(
    CampoFiltroProdotto campo,
    OperatoreFiltroProdotto operatore,
  ) {
    if (isNumericField(campo)) {
      return operatore == OperatoreFiltroProdotto.uguale ||
          operatore == OperatoreFiltroProdotto.diverso ||
          operatore == OperatoreFiltroProdotto.maggiore ||
          operatore == OperatoreFiltroProdotto.maggioreUguale ||
          operatore == OperatoreFiltroProdotto.minore ||
          operatore == OperatoreFiltroProdotto.minoreUguale ||
          operatore == OperatoreFiltroProdotto.tra;
    }
    if (isBooleanField(campo)) {
      return operatore == OperatoreFiltroProdotto.uguale ||
          operatore == OperatoreFiltroProdotto.diverso;
    }
    return operatore == OperatoreFiltroProdotto.contiene ||
        operatore == OperatoreFiltroProdotto.nonContiene ||
        operatore == OperatoreFiltroProdotto.contieneSensibile ||
        operatore == OperatoreFiltroProdotto.nonContieneSensibile ||
        operatore == OperatoreFiltroProdotto.ugualeEsatto ||
        operatore == OperatoreFiltroProdotto.diversoEsatto ||
        operatore == OperatoreFiltroProdotto.iniziaCon ||
        operatore == OperatoreFiltroProdotto.finisceCon ||
        operatore == OperatoreFiltroProdotto.inElenco ||
        operatore == OperatoreFiltroProdotto.nonInElenco;
  }

  static bool matchesQuickSearch(ProdottoGlobal prodotto, String query) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) return true;

    final barcodeValues = <String>{
      ..._metadataTextValues(prodotto.metadatiCustom, 'barcode'),
      for (final variante
          in prodotto.varianti ?? const <VarianteProductGlobal>[])
        ..._metadataTextValues(variante.metadatiCustom, 'barcode'),
    };
    if (barcodeValues.any(
      (value) => normalizeText(value).contains(normalizedQuery),
    )) {
      return true;
    }

    for (final campo in searchableFields) {
      final values = _extractTextValues(prodotto, campo);
      if (values.any(
        (value) => normalizeText(value).contains(normalizedQuery),
      )) {
        return true;
      }
    }
    return false;
  }

  static bool matchesFilters(
    ProdottoGlobal prodotto,
    List<FiltroProdotto> filtri,
  ) {
    for (final filtro in filtri) {
      if (!matchesSingleFilter(prodotto, filtro)) return false;
    }
    return true;
  }

  static bool matchesSingleFilter(
    ProdottoGlobal prodotto,
    FiltroProdotto filtro,
  ) {
    if (filtro.campo == CampoFiltroProdotto.ricercaRapida) {
      return matchesQuickSearch(prodotto, filtro.valori.join(' '));
    }
    if (isNumericField(filtro.campo)) {
      return _matchNumericValues(
        values: _extractNumericValues(prodotto, filtro.campo),
        filtro: filtro,
      );
    }
    if (isBooleanField(filtro.campo)) {
      return _matchBooleanValue(
        value: _extractBooleanValue(prodotto, filtro.campo),
        filtro: filtro,
      );
    }
    return _matchTextSet(
      values: _extractTextValues(prodotto, filtro.campo).toSet(),
      filtro: filtro,
    );
  }

  static List<String> getFilterValueSuggestions(
    List<ProdottoGlobal> prodotti,
    CampoFiltroProdotto campo,
    String query, {
    int limit = 60,
  }) {
    if (isNumericField(campo) || isBooleanField(campo)) {
      return const <String>[];
    }

    final values = <String>{};
    for (final prodotto in prodotti) {
      values.addAll(_extractTextValues(prodotto, campo));
    }

    final normalizedQuery = normalizeText(query);
    final ordered = values.where((value) => value.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (normalizedQuery.isEmpty) return ordered.take(limit).toList();

    final startsWith = <String>[];
    final contains = <String>[];
    for (final value in ordered) {
      final normalized = normalizeText(value);
      if (normalized.startsWith(normalizedQuery)) {
        startsWith.add(value);
      } else if (normalized.contains(normalizedQuery)) {
        contains.add(value);
      }
    }
    return <String>[...startsWith, ...contains].take(limit).toList();
  }

  static String normalizeText(String input) {
    var out = input.trim().toLowerCase();
    const map = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    map.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    return out;
  }

  static double? parseNumericFlexible(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static List<String> _extractTextValues(
    ProdottoGlobal prodotto,
    CampoFiltroProdotto campo,
  ) {
    switch (campo) {
      case CampoFiltroProdotto.ricercaRapida:
        return <String>{
          ..._extractTextValues(prodotto, CampoFiltroProdotto.id),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.nome),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.codiceArticolo),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.barcode),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.categoria),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.tag),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.marchio),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.prezzo),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.giacenza),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.descrizioneBreve),
          ..._extractTextValues(
            prodotto,
            CampoFiltroProdotto.descrizioneCompleta,
          ),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.stanza),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.scaffale),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.mensola),
          ..._extractTextValues(prodotto, CampoFiltroProdotto.status),
        }.toList();
      case CampoFiltroProdotto.id:
        return _singleNumeric((prodotto.id ?? 0).toDouble());
      case CampoFiltroProdotto.nome:
        return <String>{
          ..._singleText(prodotto.nome),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ..._singleText(variante.nomeVisualizzabile),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ...variante.attributi
                .map((attr) => attr.opzione.trim())
                .where((value) => value.isNotEmpty),
        }.toList();
      case CampoFiltroProdotto.codiceArticolo:
        return <String>{
          ..._singleText(prodotto.codiceProdotto),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ..._singleText(variante.codiceProdotto),
        }.toList();
      case CampoFiltroProdotto.barcode:
        return <String>{
          ..._singleText(prodotto.barcodeInterno),
          ..._singleText(prodotto.barcodeProduttore),
          ..._externalBarcodeMetadataValues(prodotto.metadatiCustom),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ..._singleText(variante.barcodeInterno),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ..._singleText(variante.barcodeFornitore),
          for (final variante
              in prodotto.varianti ?? const <VarianteProductGlobal>[])
            ..._externalBarcodeMetadataValues(variante.metadatiCustom),
        }.toList();
      case CampoFiltroProdotto.categoria:
        return prodotto.categoria
                ?.map((categoria) => categoria.nome.trim())
                .where((value) => value.isNotEmpty)
                .toList() ??
            const <String>[];
      case CampoFiltroProdotto.tag:
        return prodotto.tag
                ?.map((tag) => tag.nome.trim())
                .where((value) => value.isNotEmpty)
                .toList() ??
            const <String>[];
      case CampoFiltroProdotto.marchio:
        return _singleText(prodotto.marca);
      case CampoFiltroProdotto.prezzo:
        return _singleNumeric(prodotto.prezzoEffettivo);
      case CampoFiltroProdotto.giacenza:
        return _singleNumeric(prodotto.quantitaTotaleVarianti.toDouble());
      case CampoFiltroProdotto.disponibilita:
        return _singleText(
          prodotto.isDisponibile ? 'disponibile' : 'non disponibile',
        );
      case CampoFiltroProdotto.descrizioneBreve:
        return _singleText(prodotto.descrizioneBreve);
      case CampoFiltroProdotto.descrizioneCompleta:
        return _singleText(prodotto.descrizioneCompleta);
      case CampoFiltroProdotto.stanza:
        return _singleText(prodotto.stanza);
      case CampoFiltroProdotto.scaffale:
        return _singleText(prodotto.scaffale);
      case CampoFiltroProdotto.mensola:
        return _singleText(prodotto.mensola);
      case CampoFiltroProdotto.status:
        return _singleText(prodotto.status);
    }
  }

  static List<double> _extractNumericValues(
    ProdottoGlobal prodotto,
    CampoFiltroProdotto campo,
  ) {
    switch (campo) {
      case CampoFiltroProdotto.id:
        return prodotto.id == null
            ? const <double>[]
            : <double>[prodotto.id!.toDouble()];
      case CampoFiltroProdotto.prezzo:
        return <double>[prodotto.prezzoEffettivo];
      case CampoFiltroProdotto.giacenza:
        return <double>[prodotto.quantitaTotaleVarianti.toDouble()];
      default:
        return const <double>[];
    }
  }

  static bool _extractBooleanValue(
    ProdottoGlobal prodotto,
    CampoFiltroProdotto campo,
  ) {
    switch (campo) {
      case CampoFiltroProdotto.disponibilita:
        return prodotto.isDisponibile;
      default:
        return false;
    }
  }

  static List<String> _singleText(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }

  static List<String> _metadataTextValues(
    Map<String, dynamic>? metadata,
    String key,
  ) {
    final value = metadata?[key]?.toString().trim() ?? '';
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  /// Copre i dati precedenti al campo ufficiale `barcode_manufacturer` senza
  /// confondere mai barcode e SKU.
  static List<String> _externalBarcodeMetadataValues(
    Map<String, dynamic>? metadata,
  ) {
    const keys = <String>[
      'barcode_manufacturer',
      'barcode_produttore',
      'supplier_sku',
      'barcode',
    ];
    return <String>{
      for (final key in keys) ..._metadataTextValues(metadata, key),
    }.toList();
  }

  static List<String> _singleNumeric(double? value) {
    if (value == null) return const <String>[];
    return <String>[value.toString()];
  }

  static bool _matchTextSet({
    required Set<String> values,
    required FiltroProdotto filtro,
  }) {
    final rawTokens = filtro.valori;
    final normalizedValues = values.map(normalizeText).toSet();
    final normalizedTokens = rawTokens.map(normalizeText).toList();
    switch (filtro.operatore) {
      case OperatoreFiltroProdotto.contiene:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.contains(token)),
        );
      case OperatoreFiltroProdotto.nonContiene:
        return normalizedValues.every(
          (value) => normalizedTokens.every((token) => !value.contains(token)),
        );
      case OperatoreFiltroProdotto.contieneSensibile:
        return values.any(
          (value) => rawTokens.any((token) => value.contains(token)),
        );
      case OperatoreFiltroProdotto.nonContieneSensibile:
        return values.every(
          (value) => rawTokens.every((token) => !value.contains(token)),
        );
      case OperatoreFiltroProdotto.ugualeEsatto:
      case OperatoreFiltroProdotto.inElenco:
      case OperatoreFiltroProdotto.uguale:
        return normalizedTokens.any(
          (token) => normalizedValues.contains(token),
        );
      case OperatoreFiltroProdotto.diversoEsatto:
      case OperatoreFiltroProdotto.nonInElenco:
      case OperatoreFiltroProdotto.diverso:
        return normalizedTokens.every(
          (token) => !normalizedValues.contains(token),
        );
      case OperatoreFiltroProdotto.iniziaCon:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.startsWith(token)),
        );
      case OperatoreFiltroProdotto.finisceCon:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.endsWith(token)),
        );
      case OperatoreFiltroProdotto.maggioreUguale:
      case OperatoreFiltroProdotto.maggiore:
      case OperatoreFiltroProdotto.minoreUguale:
      case OperatoreFiltroProdotto.minore:
      case OperatoreFiltroProdotto.tra:
        return false;
    }
  }

  static bool _matchNumericValues({
    required List<double> values,
    required FiltroProdotto filtro,
  }) {
    if (values.isEmpty) return false;
    final numeri = filtro.valori
        .map(parseNumericFlexible)
        .whereType<double>()
        .toList();
    if (numeri.isEmpty) return false;

    bool matchesValue(double value) {
      switch (filtro.operatore) {
        case OperatoreFiltroProdotto.uguale:
          return numeri.any((n) => value == n);
        case OperatoreFiltroProdotto.diverso:
          return numeri.every((n) => value != n);
        case OperatoreFiltroProdotto.maggioreUguale:
          return numeri.any((n) => value >= n);
        case OperatoreFiltroProdotto.maggiore:
          return numeri.any((n) => value > n);
        case OperatoreFiltroProdotto.minoreUguale:
          return numeri.any((n) => value <= n);
        case OperatoreFiltroProdotto.minore:
          return numeri.any((n) => value < n);
        case OperatoreFiltroProdotto.tra:
          if (numeri.length < 2) return false;
          final min = numeri[0] <= numeri[1] ? numeri[0] : numeri[1];
          final max = numeri[0] <= numeri[1] ? numeri[1] : numeri[0];
          return value >= min && value <= max;
        default:
          return false;
      }
    }

    return values.any(matchesValue);
  }

  static bool _matchBooleanValue({
    required bool value,
    required FiltroProdotto filtro,
  }) {
    final boolTokens = filtro.valori
        .map(_parseBooleanFlexible)
        .whereType<bool>()
        .toList();
    if (boolTokens.isEmpty) return false;

    switch (filtro.operatore) {
      case OperatoreFiltroProdotto.uguale:
        return boolTokens.any((token) => token == value);
      case OperatoreFiltroProdotto.diverso:
        return boolTokens.every((token) => token != value);
      default:
        return false;
    }
  }

  static bool? _parseBooleanFlexible(String input) {
    final normalized = normalizeText(input);
    if (<String>{
      'true',
      '1',
      'si',
      'yes',
      'disponibile',
      'instock',
      'in stock',
    }.contains(normalized)) {
      return true;
    }
    if (<String>{
      'false',
      '0',
      'no',
      'non disponibile',
      'outofstock',
      'out of stock',
    }.contains(normalized)) {
      return false;
    }
    return null;
  }
}
