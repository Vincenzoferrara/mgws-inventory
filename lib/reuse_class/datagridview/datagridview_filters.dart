import '../../l10n/generated/app_localizations.dart';
import 'datagridview.code.dart';

/// Operatori dei filtri avanzati. I nomi sono quelli dei filtri prodotti di
/// prima della libreria, perche' finiscono nei log e nei filtri ricordati.
enum DataGridFilterOperator {
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

/// Un filtro attivo: campo del modello, operatore e valori scritti
/// dall'utente (piu' valori separati da virgola o punto e virgola).
class DataGridFilter {
  final String fieldName;
  final DataGridFilterOperator operatore;
  final List<String> valori;

  const DataGridFilter({
    required this.fieldName,
    required this.operatore,
    required this.valori,
  });

  /// Etichetta del chip mostrata nell'elenco dei filtri attivi.
  String chipLabel<T>(AppLocalizations l10n, List<DataGridField<T>> fields) {
    final field = DataGridFilterEngine.fieldByName(fields, fieldName);
    final campo = field?.label(l10n) ?? fieldName;
    final testi = field == null
        ? valori
        : valori.map((v) => field.optionLabel(l10n, v));
    return '$campo ${DataGridFilterEngine.operatoreLabel(l10n, operatore)} '
        '${testi.join(', ')}';
  }

  /// Forma compatta per i log: slug del campo, simbolo e valori. Le etichette
  /// cambiano con la lingua e renderebbero i log non confrontabili.
  String get logExpression =>
      '$fieldName${DataGridFilterEngine.operatoreSymbol(operatore)}'
      '${valori.join('|')}';

  @override
  bool operator ==(Object other) =>
      other is DataGridFilter &&
      other.fieldName == fieldName &&
      other.operatore == operatore &&
      _sameList(other.valori, valori);

  @override
  int get hashCode => Object.hash(fieldName, operatore, Object.hashAll(valori));

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Motore dei filtri delle liste gestionali.
///
/// Lavora solo sui [DataGridField] passati dalla schermata: per ogni elemento
/// legge i valori con `field.read` e li confronta secondo il tipo del campo.
class DataGridFilterEngine {
  static DataGridField<T>? fieldByName<T>(
    List<DataGridField<T>> fields,
    String name,
  ) {
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }

  /// Campo indicato dall'utente con il nome, l'etichetta o un alias.
  static DataGridField<T>? resolveField<T>(
    AppLocalizations l10n,
    List<DataGridField<T>> fields,
    String input,
  ) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final field in fields) {
      if (field.matchesName(l10n, normalized)) return field;
    }
    return null;
  }

  /// Divide il testo scritto dall'utente nei singoli valori del filtro.
  static List<String> splitValues(String input) => input
      .split(RegExp(r'[,;]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  /// Etichetta tradotta dell'operatore di filtro.
  static String operatoreLabel(
    AppLocalizations l10n,
    DataGridFilterOperator operatore,
  ) => switch (operatore) {
    DataGridFilterOperator.contiene => l10n.prodottiFiltroOperatore_contiene,
    DataGridFilterOperator.nonContiene =>
      l10n.prodottiFiltroOperatore_nonContiene,
    DataGridFilterOperator.contieneSensibile =>
      l10n.prodottiFiltroOperatore_contieneSensibile,
    DataGridFilterOperator.nonContieneSensibile =>
      l10n.prodottiFiltroOperatore_nonContieneSensibile,
    DataGridFilterOperator.ugualeEsatto =>
      l10n.prodottiFiltroOperatore_ugualeEsatto,
    DataGridFilterOperator.diversoEsatto =>
      l10n.prodottiFiltroOperatore_diversoEsatto,
    DataGridFilterOperator.iniziaCon => l10n.prodottiFiltroOperatore_iniziaCon,
    DataGridFilterOperator.finisceCon =>
      l10n.prodottiFiltroOperatore_finisceCon,
    DataGridFilterOperator.inElenco => l10n.prodottiFiltroOperatore_inElenco,
    DataGridFilterOperator.nonInElenco =>
      l10n.prodottiFiltroOperatore_nonInElenco,
    DataGridFilterOperator.uguale => l10n.prodottiFiltroOperatore_uguale,
    DataGridFilterOperator.diverso => l10n.prodottiFiltroOperatore_diverso,
    DataGridFilterOperator.maggioreUguale =>
      l10n.prodottiFiltroOperatore_maggioreUguale,
    DataGridFilterOperator.maggiore => l10n.prodottiFiltroOperatore_maggiore,
    DataGridFilterOperator.minoreUguale =>
      l10n.prodottiFiltroOperatore_minoreUguale,
    DataGridFilterOperator.minore => l10n.prodottiFiltroOperatore_minore,
    DataGridFilterOperator.tra => l10n.prodottiFiltroOperatore_tra,
  };

  /// Spiegazione tradotta dell'operatore di filtro.
  static String operatoreTooltip(
    AppLocalizations l10n,
    DataGridFilterOperator operatore,
  ) => switch (operatore) {
    DataGridFilterOperator.uguale => l10n.prodottiFiltroTooltip_uguale,
    DataGridFilterOperator.diverso => l10n.prodottiFiltroTooltip_diverso,
    DataGridFilterOperator.contiene => l10n.prodottiFiltroTooltip_contiene,
    DataGridFilterOperator.nonContiene =>
      l10n.prodottiFiltroTooltip_nonContiene,
    DataGridFilterOperator.contieneSensibile =>
      l10n.prodottiFiltroTooltip_contieneSensibile,
    DataGridFilterOperator.nonContieneSensibile =>
      l10n.prodottiFiltroTooltip_nonContieneSensibile,
    DataGridFilterOperator.ugualeEsatto =>
      l10n.prodottiFiltroTooltip_ugualeEsatto,
    DataGridFilterOperator.diversoEsatto =>
      l10n.prodottiFiltroTooltip_diversoEsatto,
    DataGridFilterOperator.iniziaCon => l10n.prodottiFiltroTooltip_iniziaCon,
    DataGridFilterOperator.finisceCon => l10n.prodottiFiltroTooltip_finisceCon,
    DataGridFilterOperator.inElenco => l10n.prodottiFiltroTooltip_inElenco,
    DataGridFilterOperator.nonInElenco =>
      l10n.prodottiFiltroTooltip_nonInElenco,
    DataGridFilterOperator.maggioreUguale =>
      l10n.prodottiFiltroTooltip_maggioreUguale,
    DataGridFilterOperator.maggiore => l10n.prodottiFiltroTooltip_maggiore,
    DataGridFilterOperator.minoreUguale =>
      l10n.prodottiFiltroTooltip_minoreUguale,
    DataGridFilterOperator.minore => l10n.prodottiFiltroTooltip_minore,
    DataGridFilterOperator.tra => l10n.prodottiFiltroTooltip_tra,
  };

  static String operatoreSymbol(DataGridFilterOperator op) => switch (op) {
    DataGridFilterOperator.contiene => '~',
    DataGridFilterOperator.nonContiene => '!~',
    DataGridFilterOperator.contieneSensibile => '~!',
    DataGridFilterOperator.nonContieneSensibile => '!~!',
    DataGridFilterOperator.ugualeEsatto => '==',
    DataGridFilterOperator.diversoEsatto => '!==',
    DataGridFilterOperator.iniziaCon => '^',
    DataGridFilterOperator.finisceCon => r'$',
    DataGridFilterOperator.inElenco => 'IN',
    DataGridFilterOperator.nonInElenco => 'NOT IN',
    DataGridFilterOperator.uguale => '=',
    DataGridFilterOperator.diverso => '!=',
    DataGridFilterOperator.maggioreUguale => '>=',
    DataGridFilterOperator.maggiore => '>',
    DataGridFilterOperator.minoreUguale => '<=',
    DataGridFilterOperator.minore => '<',
    DataGridFilterOperator.tra => 'BETWEEN',
  };

  static const List<DataGridFilterOperator> orderedOperators =
      <DataGridFilterOperator>[
        DataGridFilterOperator.contiene,
        DataGridFilterOperator.nonContiene,
        DataGridFilterOperator.ugualeEsatto,
        DataGridFilterOperator.diversoEsatto,
        DataGridFilterOperator.inElenco,
        DataGridFilterOperator.nonInElenco,
        DataGridFilterOperator.iniziaCon,
        DataGridFilterOperator.finisceCon,
        DataGridFilterOperator.contieneSensibile,
        DataGridFilterOperator.nonContieneSensibile,
        DataGridFilterOperator.uguale,
        DataGridFilterOperator.diverso,
        DataGridFilterOperator.maggiore,
        DataGridFilterOperator.maggioreUguale,
        DataGridFilterOperator.minore,
        DataGridFilterOperator.minoreUguale,
        DataGridFilterOperator.tra,
      ];

  /// Nome tradotto del gruppo di operatori a cui appartiene quello scelto.
  static String operatorSectionLabel(
    AppLocalizations l10n,
    DataGridFilterOperator operatore,
  ) {
    switch (operatore) {
      case DataGridFilterOperator.contiene:
      case DataGridFilterOperator.nonContiene:
      case DataGridFilterOperator.ugualeEsatto:
      case DataGridFilterOperator.diversoEsatto:
      case DataGridFilterOperator.inElenco:
      case DataGridFilterOperator.nonInElenco:
        return l10n.prodottiFiltroSezioneComuni;
      case DataGridFilterOperator.iniziaCon:
      case DataGridFilterOperator.finisceCon:
      case DataGridFilterOperator.contieneSensibile:
      case DataGridFilterOperator.nonContieneSensibile:
        return l10n.prodottiFiltroSezioneTestoAvanzato;
      case DataGridFilterOperator.uguale:
      case DataGridFilterOperator.diverso:
      case DataGridFilterOperator.maggiore:
      case DataGridFilterOperator.maggioreUguale:
      case DataGridFilterOperator.minore:
      case DataGridFilterOperator.minoreUguale:
      case DataGridFilterOperator.tra:
        return l10n.prodottiFiltroSezioneNumerici;
    }
  }

  /// Operatore proposto quando si sceglie un campo e quello corrente non vale.
  static DataGridFilterOperator defaultOperator(DataGridFieldType type) =>
      switch (type) {
        DataGridFieldType.numero ||
        DataGridFieldType.booleano ||
        DataGridFieldType.data ||
        DataGridFieldType.elenco => DataGridFilterOperator.uguale,
        DataGridFieldType.testo => DataGridFilterOperator.contiene,
      };

  static bool supportsOperator(
    DataGridFieldType type,
    DataGridFilterOperator operatore,
  ) {
    switch (type) {
      case DataGridFieldType.numero:
      case DataGridFieldType.data:
        return operatore == DataGridFilterOperator.uguale ||
            operatore == DataGridFilterOperator.diverso ||
            operatore == DataGridFilterOperator.maggiore ||
            operatore == DataGridFilterOperator.maggioreUguale ||
            operatore == DataGridFilterOperator.minore ||
            operatore == DataGridFilterOperator.minoreUguale ||
            operatore == DataGridFilterOperator.tra;
      case DataGridFieldType.booleano:
        return operatore == DataGridFilterOperator.uguale ||
            operatore == DataGridFilterOperator.diverso;
      case DataGridFieldType.elenco:
        return operatore == DataGridFilterOperator.uguale ||
            operatore == DataGridFilterOperator.diverso ||
            operatore == DataGridFilterOperator.inElenco ||
            operatore == DataGridFilterOperator.nonInElenco;
      case DataGridFieldType.testo:
        return operatore == DataGridFilterOperator.contiene ||
            operatore == DataGridFilterOperator.nonContiene ||
            operatore == DataGridFilterOperator.contieneSensibile ||
            operatore == DataGridFilterOperator.nonContieneSensibile ||
            operatore == DataGridFilterOperator.ugualeEsatto ||
            operatore == DataGridFilterOperator.diversoEsatto ||
            operatore == DataGridFilterOperator.iniziaCon ||
            operatore == DataGridFilterOperator.finisceCon ||
            operatore == DataGridFilterOperator.inElenco ||
            operatore == DataGridFilterOperator.nonInElenco;
    }
  }

  // ── Lettura dei valori ──────────────────────────────────────────────────

  /// Valori del campo come testo, come li vede la ricerca rapida.
  static List<String> textValues<T>(DataGridField<T> field, T item) {
    final out = <String>{};
    for (final value in field.read(item)) {
      final text = valueAsText(value);
      if (text.isNotEmpty) out.add(text);
    }
    return out.toList();
  }

  static String valueAsText(Object? value) {
    if (value == null) return '';
    if (value is double) {
      return value == value.truncateToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    if (value is DateTime) return _formatDate(value);
    return value.toString().trim();
  }

  static List<double> _numericValues<T>(DataGridField<T> field, T item) {
    final out = <double>[];
    for (final value in field.read(item)) {
      if (value is num) {
        out.add(value.toDouble());
      } else if (value is String) {
        final parsed = parseNumericFlexible(value);
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  static List<DateTime> _dateValues<T>(DataGridField<T> field, T item) {
    final out = <DateTime>[];
    for (final value in field.read(item)) {
      if (value is DateTime) {
        out.add(_dayOf(value));
      } else if (value is String) {
        final parsed = parseDateFlexible(value);
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }

  static bool? _booleanValue<T>(DataGridField<T> field, T item) {
    for (final value in field.read(item)) {
      if (value is bool) return value;
      if (value is String) {
        final parsed = parseBooleanFlexible(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // ── Confronto ───────────────────────────────────────────────────────────

  static bool matchesQuickSearch<T>(
    T item,
    List<DataGridField<T>> fields,
    String query,
  ) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) return true;
    for (final field in fields) {
      if (!field.searchable) continue;
      for (final value in field.read(item)) {
        if (normalizeText(valueAsText(value)).contains(normalizedQuery)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool matchesFilters<T>(
    T item,
    List<DataGridField<T>> fields,
    List<DataGridFilter> filtri,
  ) {
    for (final filtro in filtri) {
      if (!matchesSingleFilter(item, fields, filtro)) return false;
    }
    return true;
  }

  static bool matchesSingleFilter<T>(
    T item,
    List<DataGridField<T>> fields,
    DataGridFilter filtro,
  ) {
    final field = fieldByName(fields, filtro.fieldName);
    // Un filtro su un campo che la schermata non dichiara piu' non deve
    // svuotare la lista: lo si ignora.
    if (field == null) return true;
    switch (field.type) {
      case DataGridFieldType.numero:
        return _matchNumericValues(
          values: _numericValues(field, item),
          filtro: filtro,
        );
      case DataGridFieldType.data:
        return _matchDateValues(values: _dateValues(field, item), filtro: filtro);
      case DataGridFieldType.booleano:
        return _matchBooleanValue(
          value: _booleanValue(field, item) ?? false,
          filtro: filtro,
        );
      case DataGridFieldType.testo:
      case DataGridFieldType.elenco:
        return _matchTextSet(
          values: textValues(field, item).toSet(),
          filtro: filtro,
        );
    }
  }

  /// Valori gia' presenti nell'elenco per il campo scelto, per suggerire cosa
  /// scrivere nel filtro.
  static List<String> getFilterValueSuggestions<T>(
    List<T> items,
    DataGridField<T> field,
    String query, {
    int limit = 60,
  }) {
    if (field.type != DataGridFieldType.testo &&
        field.type != DataGridFieldType.elenco) {
      return const <String>[];
    }

    final values = <String>{};
    for (final item in items) {
      values.addAll(textValues(field, item));
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

  /// Applica ricerca, filtri e ordinamento a un elenco gia' in memoria.
  static List<T> apply<T>(
    List<T> items,
    List<DataGridField<T>> fields, {
    String search = '',
    List<DataGridFilter> filtri = const <DataGridFilter>[],
    DataGridSort? sort,
    bool Function(T item)? where,
  }) {
    final out = items.where((item) {
      if (where != null && !where(item)) return false;
      return matchesQuickSearch(item, fields, search) &&
          matchesFilters(item, fields, filtri);
    }).toList();
    final sortField = sort == null ? null : fieldByName(fields, sort.fieldName);
    if (sort != null && sortField != null) {
      // Ordinamento stabile: a parita' di valore resta l'ordine del server.
      final indexed = <(int, T)>[
        for (var i = 0; i < out.length; i++) (i, out[i]),
      ];
      indexed.sort((a, b) {
        final cmp = compare(sortField, a.$2, b.$2);
        if (cmp != 0) return sort.ascending ? cmp : -cmp;
        return a.$1.compareTo(b.$1);
      });
      return [for (final entry in indexed) entry.$2];
    }
    return out;
  }

  /// Confronto di due elementi sul primo valore del campo. I valori mancanti
  /// vanno in fondo all'ordinamento crescente.
  static int compare<T>(DataGridField<T> field, T a, T b) {
    final va = _firstValue(field, a);
    final vb = _firstValue(field, b);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;
    if (va is num && vb is num) return va.compareTo(vb);
    if (va is DateTime && vb is DateTime) return va.compareTo(vb);
    if (va is bool && vb is bool) return va == vb ? 0 : (va ? 1 : -1);
    return normalizeText(
      valueAsText(va),
    ).compareTo(normalizeText(valueAsText(vb)));
  }

  static Object? _firstValue<T>(DataGridField<T> field, T item) {
    for (final value in field.read(item)) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (field.type == DataGridFieldType.numero && value is String) {
        return parseNumericFlexible(value);
      }
      return value;
    }
    return null;
  }

  // ── Normalizzazione ─────────────────────────────────────────────────────

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

  /// Data scritta come `gg/mm/aaaa` (anche con `-` o `.`) oppure ISO
  /// `aaaa-mm-gg`. Restituisce il giorno, senza ora.
  static DateTime? parseDateFlexible(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return _dayOf(iso);
    final match = RegExp(
      r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})$',
    ).firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  static bool? parseBooleanFlexible(String input) {
    final normalized = normalizeText(input);
    if (<String>{
      'true',
      '1',
      'si',
      'yes',
      'disponibile',
      'instock',
      'in stock',
      'attivo',
      'active',
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
      'non attivo',
      'inactive',
    }.contains(normalized)) {
      return false;
    }
    return null;
  }

  static DateTime _dayOf(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  static bool _matchTextSet({
    required Set<String> values,
    required DataGridFilter filtro,
  }) {
    final rawTokens = filtro.valori;
    final normalizedValues = values.map(normalizeText).toSet();
    final normalizedTokens = rawTokens.map(normalizeText).toList();
    switch (filtro.operatore) {
      case DataGridFilterOperator.contiene:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.contains(token)),
        );
      case DataGridFilterOperator.nonContiene:
        return normalizedValues.every(
          (value) => normalizedTokens.every((token) => !value.contains(token)),
        );
      case DataGridFilterOperator.contieneSensibile:
        return values.any(
          (value) => rawTokens.any((token) => value.contains(token)),
        );
      case DataGridFilterOperator.nonContieneSensibile:
        return values.every(
          (value) => rawTokens.every((token) => !value.contains(token)),
        );
      case DataGridFilterOperator.ugualeEsatto:
      case DataGridFilterOperator.inElenco:
      case DataGridFilterOperator.uguale:
        return normalizedTokens.any(
          (token) => normalizedValues.contains(token),
        );
      case DataGridFilterOperator.diversoEsatto:
      case DataGridFilterOperator.nonInElenco:
      case DataGridFilterOperator.diverso:
        return normalizedTokens.every(
          (token) => !normalizedValues.contains(token),
        );
      case DataGridFilterOperator.iniziaCon:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.startsWith(token)),
        );
      case DataGridFilterOperator.finisceCon:
        return normalizedValues.any(
          (value) => normalizedTokens.any((token) => value.endsWith(token)),
        );
      case DataGridFilterOperator.maggioreUguale:
      case DataGridFilterOperator.maggiore:
      case DataGridFilterOperator.minoreUguale:
      case DataGridFilterOperator.minore:
      case DataGridFilterOperator.tra:
        return false;
    }
  }

  static bool _matchOrdered<V extends Comparable<V>>({
    required List<V> values,
    required List<V> tokens,
    required DataGridFilterOperator operatore,
  }) {
    if (values.isEmpty || tokens.isEmpty) return false;

    bool matchesValue(V value) {
      switch (operatore) {
        case DataGridFilterOperator.uguale:
          return tokens.any((n) => value.compareTo(n) == 0);
        case DataGridFilterOperator.diverso:
          return tokens.every((n) => value.compareTo(n) != 0);
        case DataGridFilterOperator.maggioreUguale:
          return tokens.any((n) => value.compareTo(n) >= 0);
        case DataGridFilterOperator.maggiore:
          return tokens.any((n) => value.compareTo(n) > 0);
        case DataGridFilterOperator.minoreUguale:
          return tokens.any((n) => value.compareTo(n) <= 0);
        case DataGridFilterOperator.minore:
          return tokens.any((n) => value.compareTo(n) < 0);
        case DataGridFilterOperator.tra:
          if (tokens.length < 2) return false;
          final first = tokens[0];
          final second = tokens[1];
          final min = first.compareTo(second) <= 0 ? first : second;
          final max = first.compareTo(second) <= 0 ? second : first;
          return value.compareTo(min) >= 0 && value.compareTo(max) <= 0;
        default:
          return false;
      }
    }

    return values.any(matchesValue);
  }

  static bool _matchNumericValues({
    required List<double> values,
    required DataGridFilter filtro,
  }) {
    final numeri = filtro.valori
        .map(parseNumericFlexible)
        .whereType<double>()
        .toList();
    return _matchOrdered<num>(
      values: values,
      tokens: numeri,
      operatore: filtro.operatore,
    );
  }

  static bool _matchDateValues({
    required List<DateTime> values,
    required DataGridFilter filtro,
  }) {
    final date = filtro.valori
        .map(parseDateFlexible)
        .whereType<DateTime>()
        .toList();
    return _matchOrdered<DateTime>(
      values: values,
      tokens: date,
      operatore: filtro.operatore,
    );
  }

  static bool _matchBooleanValue({
    required bool value,
    required DataGridFilter filtro,
  }) {
    final boolTokens = filtro.valori
        .map(parseBooleanFlexible)
        .whereType<bool>()
        .toList();
    if (boolTokens.isEmpty) return false;

    switch (filtro.operatore) {
      case DataGridFilterOperator.uguale:
        return boolTokens.any((token) => token == value);
      case DataGridFilterOperator.diverso:
        return boolTokens.every((token) => token != value);
      default:
        return false;
    }
  }
}
