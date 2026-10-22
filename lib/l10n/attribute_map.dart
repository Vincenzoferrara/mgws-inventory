import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';

/// Gli attributi di variante che l'app gestisce in modo esplicito.
///
/// Il nome canonico e sempre in inglese, indipendentemente dalla lingua
/// dell'interfaccia: e il nome con cui l'app identifica l'attributo nel proprio
/// codice. Il testo mostrato all'utente invece e tradotto, e lo slug salvato nel
/// catalogo WooCommerce resta quello gia presente.
///
/// Questa separazione serve a non rompere i cataloghi esistenti, che possono
/// avere attributi chiamati `Taglia` e `Colore` invece di `Size` e `Color`.
enum AttributoCanonico {
  /// Attributo del colore della variante.
  color,

  /// Attributo della taglia della variante.
  size;

  /// Codice canonico inglese usato internamente e nelle chiavi di persistenza.
  String get codice => name;

  /// Alias italiani storici, perche i cataloghi creati prima possono usarli.
  ///
  /// Non sono nuovi attributi: sono gli stessi, riconosciuti per compatibilita.
  List<String> get alias => switch (this) {
    AttributoCanonico.color => const ['colore', 'colour'],
    AttributoCanonico.size => const ['taglia'],
  };

  /// Nome con cui l'app crea l'attributo quando non ne esiste gia uno adatto.
  ///
  /// La creazione usa il nome canonico inglese, come richiesto dalle convenzioni
  /// del progetto.
  String get nomeInglese => switch (this) {
    AttributoCanonico.color => 'Color',
    AttributoCanonico.size => 'Size',
  };
}

/// Un attributo letto dal catalogo, ridotto ai dati necessari per il confronto.
///
/// Vive qui, e non come tipo `ProductAttribute`, perche `lib/l10n` non deve
/// dipendere dal layer di integrazione con il backend.
class AttributoCatalogo {
  final int id;
  final String nome;
  final String? slug;

  const AttributoCatalogo({required this.id, required this.nome, this.slug});
}

/// Cerca nel catalogo l'attributo corrispondente a un attributo canonico.
///
/// Riconosce sia il nome canonico inglese sia gli alias italiani storici, cosi lo
/// stesso codice funziona sui catalogi vecchi e su quelli nuovi.
/// Restituisce `null` se il catalogo non contiene nulla di adatto.
AttributoCatalogo? trovaAttributo(
  AttributoCanonico canonico,
  List<AttributoCatalogo> attributi,
) {
  for (final candidato in [canonico.nomeInglese, ...canonico.alias]) {
    final testo = candidato.toLowerCase();
    for (final attributo in attributi) {
      if (attributo.nome.toLowerCase() == testo) {
        return attributo;
      }
    }
  }

  // Ultimo tentativo: confronto parziale, per catalogi con nomi come
  // "Colore principale" o "EU Taglia".
  for (final candidato in [canonico.nomeInglese, ...canonico.alias]) {
    final testo = candidato.toLowerCase();
    for (final attributo in attributi) {
      if (attributo.nome.toLowerCase().contains(testo)) {
        return attributo;
      }
    }
  }

  return null;
}

/// Collega gli attributi canonici dell'app agli attributi reali del catalogo.
///
/// La mappa e una scelta dell'utente: se nel catalogo esiste gia un attributo
/// chiamato `Taglia`, l'utente puo indicare che quello e il suo attributo taglia,
/// e l'app non ne crea uno nuovo `Size`.
///
/// Se l'utente non mappa nulla, l'app torna al riconoscimento automatico.
class MappaAttributi extends ChangeNotifier {
  static const String _chiavePreferenza = 'attributi_mappa';

  /// Codice canonico -> id dell'attributo WooCommerce scelto dall'utente.
  Map<String, int> _mappa = <String, int>{};

  /// Mappa attuale, letta sola dai consumer.
  Map<String, int> get mappa => Map.unmodifiable(_mappa);

  /// Id mappato per un attributo canonico, oppure `null` se non mappato.
  int? idMappato(AttributoCanonico canonico) => _mappa[canonico.codice];

  /// `true` se l'attributo canonico e stato collegato a un attributo del catalogo.
  bool isMappato(AttributoCanonico canonico) =>
      _mappa.containsKey(canonico.codice);

  /// Carica la mappa dalle preferenze.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final grezzo = prefs.getStringList(_chiavePreferenza) ?? <String>[];

      final caricata = <String, int>{};
      for (final voce in grezzo) {
        final parti = voce.split(':');
        if (parti.length != 2) continue;

        final id = int.tryParse(parti[1]);
        if (id == null) continue;

        // Scarta chiavi non piu riconosciute, cosi una voce rimasta indietro
        // non viene usata al posto dell'attributo giusto.
        if (AttributoCanonico.values.any((c) => c.codice == parti[0])) {
          caricata[parti[0]] = id;
        }
      }

      _mappa = caricata;
    } catch (e) {
      log.d('Errore nel caricamento della mappa attributi: $e');
    }
  }

  /// Collega un attributo canonico all'attributo del catalogo indicato.
  /// Passando `null` si rimuove il collegamento e si torna al riconoscimento
  /// automatico.
  Future<void> imposta(AttributoCanonico canonico, int? idCatalogo) async {
    if (idCatalogo == null) {
      _mappa.remove(canonico.codice);
    } else {
      _mappa[canonico.codice] = idCatalogo;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _chiavePreferenza,
        _mappa.entries.map((e) => '${e.key}:${e.value}').toList(),
      );
    } catch (e) {
      log.d('Errore nel salvataggio della mappa attributi: $e');
    }

    notifyListeners();
  }

  /// Rimuove tutti i collegamenti.
  Future<void> svuota() async {
    _mappa = <String, int>{};

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chiavePreferenza);
    } catch (e) {
      log.d('Errore nella cancellazione della mappa attributi: $e');
    }

    notifyListeners();
  }
}
