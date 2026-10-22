// Verifica che le traduzioni siano complete e coerenti.
//
// Controlla che ogni chiave presente nel template inglese esista anche nel file
// italiano, che non ci siano chiavi obsolete rimaste nel file italiano, che i
// valori non siano vuoti e che i placeholder siano allineati fra le due lingue.
//
// E' pensato per girare in CI: esce con codice 1 se trova problemi, cosi la pull
// request di chi aggiunge una stringa viene bloccata se si dimentica di
// tradurla.
//
// Uso:
//   dart run lib/l10n/check_translations.dart

import 'dart:convert';
import 'dart:io';

/// Dove si trovano i file ARB, relativo alla radice del progetto.
const String _cartellaArb = 'lib/l10n';

/// Template da cui nascono tutte le chiavi.
const String _template = 'app_en.arb';

/// Lingue che devono restare allineate al template.
const List<String> _traduzioni = ['app_it.arb'];

void main(List<String> args) {
  final cartella = Directory(_cartellaArb);

  if (!cartelleEsiste(cartella)) {
    stderr.writeln('Cartella ARB non trovata: $_cartellaArb');
    exit(2);
  }

  final template = _leggi(cartella, _template);
  if (template == null) {
    stderr.writeln(
      'Template non trovato o non valido: $_cartellaArb/$_template',
    );
    exit(2);
  }

  final errori = <String>[];

  for (final nome in _traduzioni) {
    final traduzioni = _leggi(cartella, nome);
    if (traduzioni == null) {
      errori.add('File non trovato o non valido: $_cartellaArb/$nome');
      continue;
    }

    errori.addAll(_confronta(nome, template, traduzioni));
  }

  if (errori.isEmpty) {
    stdout.writeln(
      'Traduzioni OK: '
      '${_chiaviVisibili(template).length} chiavi verificate in '
      '${_traduzioni.length + 1} lingue.',
    );
    exit(0);
  }

  stderr.writeln('Traduzioni incomplete o incoerenti:');
  for (final errore in errori) {
    stderr.writeln('  - $errore');
  }
  stderr.writeln('');
  stderr.writeln(
    'Correggi i problemi elencati sopra. Ogni chiave del template deve '
    'essere presente e non vuota in ogni file di traduzione, con gli stessi '
    'placeholder.',
  );
  exit(1);
}

/// Confronta una traduzione con il template e restituisce i problemi trovati.
List<String> _confronta(
  String nomeTraduzione,
  Map<String, dynamic> template,
  Map<String, dynamic> traduzioni,
) {
  final problemi = <String>[];

  final chiaviTemplate = _chiaviVisibili(template).toSet();
  final chiaviTraduzione = _chiaviVisibili(traduzioni).toSet();

  // Chiavi presenti nel template ma assenti dalla traduzione.
  final mancanti = chiaviTemplate.difference(chiaviTraduzione).toList()..sort();
  for (final chiave in mancanti) {
    problemi.add('$nomeTraduzione: chiave mancante "$chiave"');
  }

  // Chiavi rimaste nella traduzione dopo che il template le ha rimosse.
  final obsolete = chiaviTraduzione.difference(chiaviTemplate).toList()..sort();
  for (final chiave in obsolete) {
    problemi.add(
      '$nomeTraduzione: chiave obsoleta "$chiave", non piu nel template',
    );
  }

  // Controlli sulle chiave presenti in entrambi.
  for (final chiave in chiaviTemplate.intersection(chiaviTraduzione)) {
    final valore = traduzioni[chiave];

    if (valore is! String) {
      problemi.add('$nomeTraduzione: "$chiave" non e una stringa');
      continue;
    }

    if (valore.trim().isEmpty) {
      problemi.add('$nomeTraduzione: "$chiave" ha un valore vuoto');
      continue;
    }

    // Un valore lasciato identico al placeholder non e una traduzione.
    final segnaposto = RegExp(r'\{[a-zA-Z0-9_]+\}');
    if (valore.trim() == segnaposto.firstMatch(valore)?.group(0)) {
      problemi.add(
        '$nomeTraduzione: "$chiave" contiene solo un placeholder, '
        'manca il testo circostante',
      );
    }

    final attesi = _placeholderDi(template[chiave]);
    final trovati = _placeholderDi(valore).toSet();
    final mancantiQui = attesi.difference(trovati);

    if (mancantiQui.isNotEmpty) {
      problemi.add(
        '$nomeTraduzione: "$chiave" non usa i placeholder '
        '${mancantiQui.join(", ")} presenti nel template',
      );
    }

    // Placeholder usati in piu' o diversi rispetto al template.
    final estranei = trovati.difference(attesi);
    if (estranei.isNotEmpty) {
      problemi.add(
        '$nomeTraduzione: "$chiave" usa placeholder '
        '${estranei.join(", ")} assenti nel template',
      );
    }
  }

  return problemi;
}

/// Le chiavi visibili sono quelle che non iniziano con `@`.
///
/// In ARB le chiavi che iniziano con `@` sono metadati: descrizioni, esempi e
/// definizioni dei placeholder. Non sono stringhe da tradurre.
Set<String> _chiaviVisibili(Map<String, dynamic> dati) =>
    dati.keys.where((k) => !k.startsWith('@')).toSet();

/// I nomi dei placeholder presenti in un testo ICU.
///
/// Copre sia i placeholder semplici (`{nome}`) sia le forme con plural e
/// genere (`{n, plural, ...}`), servendo il nome che segue la graffa.
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

/// Legge un file ARB, restituendo `null` se manca o non e JSON valido.
Map<String, dynamic>? _leggi(Directory cartella, String nome) {
  final file = File('${cartella.path}/$nome');
  if (!file.existsSync()) return null;

  try {
    final contenuto = jsonDecode(file.readAsStringSync());
    if (contenuto is Map<String, dynamic>) return contenuto;
  } on FormatException catch (e) {
    stderr.writeln('$nome non e JSON valido: ${e.message}');
  }

  return null;
}

/// `true` se la cartella esiste.
bool cartelleEsiste(Directory cartella) => cartella.existsSync();
