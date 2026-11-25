// Verifies that translations are complete and consistent.
//
// Checks that every key in the English template exists in every translation,
// that there are no obsolete keys, that values are not empty, and that placeholders
// match across languages.
//
// This script is intended to run in CI: it exits with code 1 when it detects a
// problem, blocking a pull request if a contributor adds a string and forgets
// to translate it.
//
// Usage:
//   dart run lib/l10n/check_translations.dart

import 'dart:convert';
import 'dart:io';

/// Where the ARB files are located, relative to the project root.
const String _cartellaArb = 'lib/l10n';

/// Template from which all keys are derived.
const String _template = 'app_en.arb';

/// Languages that must remain aligned with the template.
const List<String> _traduzioni = ['app_it.arb'];

void main(List<String> args) {
  final cartella = Directory(_cartellaArb);

  if (!cartelleEsiste(cartella)) {
    stderr.writeln('ARB folder not found: $_cartellaArb');
    exit(2);
  }

  final template = _leggi(cartella, _template);
  if (template == null) {
    stderr.writeln('Template not found or invalid: $_cartellaArb/$_template');
    exit(2);
  }

  final errori = <String>[];

  for (final nome in _traduzioni) {
    final traduzioni = _leggi(cartella, nome);
    if (traduzioni == null) {
      errori.add('File not found or invalid: $_cartellaArb/$nome');
      continue;
    }

    errori.addAll(_confronta(nome, template, traduzioni));
  }

  if (errori.isEmpty) {
    stdout.writeln(
      'Translations OK: '
      '${_chiaviVisibili(template).length} keys verified in '
      '${_traduzioni.length + 1} languages.',
    );
    exit(0);
  }

  stderr.writeln('Incomplete or inconsistent translations:');
  for (final errore in errori) {
    stderr.writeln('  - $errore');
  }
  stderr.writeln('');
  stderr.writeln(
    'Fix the issues listed above. Each key in the template must '
    'be present and non-empty in every translation file, with the same '
    'placeholders.',
  );
  exit(1);
}

/// Compares a translation with the template and returns any problems found.
List<String> _confronta(
  String nomeTraduzione,
  Map<String, dynamic> template,
  Map<String, dynamic> traduzioni,
) {
  final problemi = <String>[];

  final chiaviTemplate = _chiaviVisibili(template).toSet();
  final chiaviTraduzione = _chiaviVisibili(traduzioni).toSet();

  // Keys present in the template but missing from the translation.
  final mancanti = chiaviTemplate.difference(chiaviTraduzione).toList()..sort();
  for (final chiave in mancanti) {
    problemi.add('$nomeTraduzione: missing key "$chiave"');
  }

  // Keys left in the translation after being removed from the template.
  final obsolete = chiaviTraduzione.difference(chiaviTemplate).toList()..sort();
  for (final chiave in obsolete) {
    problemi.add(
      '$nomeTraduzione: obsolete key "$chiave", no longer in the template',
    );
  }

  // Checks on keys present in both.
  for (final chiave in chiaviTemplate.intersection(chiaviTraduzione)) {
    final valore = traduzioni[chiave];

    if (valore is! String) {
      problemi.add('$nomeTraduzione: "$chiave" is not a string');
      continue;
    }

    if (valore.trim().isEmpty) {
      problemi.add('$nomeTraduzione: "$chiave" has an empty value');
      continue;
    }

    // A value left identical to the placeholder is not a translation.
    final segnaposto = RegExp(r'\{[a-zA-Z0-9_]+\}');
    if (valore.trim() == segnaposto.firstMatch(valore)?.group(0)) {
      problemi.add(
        '$nomeTraduzione: "$chiave" contains only a placeholder, '
        'missing surrounding text',
      );
    }

    final attesi = _placeholderDi(template[chiave]);
    final trovati = _placeholderDi(valore).toSet();
    final mancantiQui = attesi.difference(trovati);

    if (mancantiQui.isNotEmpty) {
      problemi.add(
        '$nomeTraduzione: "$chiave" does not use the placeholder '
        '${mancantiQui.join(", ")} present in the template',
      );
    }

    // Placeholders used in a different number or manner than the template.
    final estranei = trovati.difference(attesi);
    if (estranei.isNotEmpty) {
      problemi.add(
        '$nomeTraduzione: "$chiave" uses placeholder '
        '${estranei.join(", ")} not present in the template',
      );
    }
  }

  return problemi;
}

/// Visible keys are those that do not start with `@`.
///
/// In ARB, keys starting with `@` are metadata: descriptions, examples, and
/// placeholder definitions. They are not strings to be translated.
Set<String> _chiaviVisibili(Map<String, dynamic> dati) =>
    dati.keys.where((k) => !k.startsWith('@')).toSet();

/// The names of the placeholders present in an ICU text.
///
/// Covers both simple placeholders (`{name}`) and those with plural and
/// gender forms (`{n, plural, ...}`), serving the name that follows the brace.
Set<String> _placeholderDi(Object? valore) {
  if (valore is! String) return const <String>{};

  final trovati = <String>{};
  final pattern = RegExp(r'\{\s*([a-zA-Z0-9_]+)\s*[,}]');

  for (final corrispondenza in pattern.allMatches(valore)) {
    final nome = corrispondenza.group(1);
    if (nome != null) trovati.add(nome);
  }

  return trovati;
}

/// Reads an ARB file, returning `null` if it is missing or not valid JSON.
Map<String, dynamic>? _leggi(Directory cartella, String nome) {
  final file = File('${cartella.path}/$nome');
  if (!file.existsSync()) return null;

  try {
    final contenuto = jsonDecode(file.readAsStringSync());
    if (contenuto is Map<String, dynamic>) return contenuto;
  } on FormatException catch (e) {
    stderr.writeln('$nome is not valid JSON: ${e.message}');
  }

  return null;
}

/// `true` if the folder exists.
bool cartelleEsiste(Directory cartella) => cartella.existsSync();
