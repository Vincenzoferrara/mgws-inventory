import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log_viewer/app_logger.dart';

/// Gestisce la lingua dell'interfaccia.
///
/// La lingua puo essere forzata dall'utente oppure seguire l'impostazione del
/// sistema operativo, che e il comportamento predefinito. Quando segue il sistema
/// si restituisce `null` a `MaterialApp.locale`: in questo modo Flutter sceglie la
/// lingua migliore fra quelle supportate, con fallback su inglese.
///
/// La scelta viene conservata in SharedPreferences, quindi sopravvive al riavvio.
class LocaleSettings extends ChangeNotifier {
  /// Lingua seguita dal sistema operativo: non viene salvata.
  static const Locale? sistema = null;

  /// Codice lingua inglese, usata come fallback.
  static const Locale inglese = Locale('en');

  /// Codice lingua italiana.
  static const Locale italiano = Locale('it');

  /// Lingue offerte all'utente nelle impostazioni.
  static const List<Locale> supportate = <Locale>[inglese, italiano];

  /// Nome del codice lingua leggibile per l'utente, mostrato nelle impostazioni.
  /// Resta nel nome nativo cosi l'utente riconosce la lingua anche senza leggerla.
  static const Map<String, String> nomiNativi = <String, String>{
    'en': 'English',
    'it': 'Italiano',
  };

  static const String _chiavePreferenza = 'app_locale';

  Locale? _lingua;

  /// Lingua forzata, oppure `null` se si segue il sistema.
  Locale? get lingua => _lingua;

  /// `true` quando si segue l'impostazione del sistema operativo.
  bool get segueSistema => _lingua == null;

  /// Nome leggibile della lingua attualmente attiva.
  /// Se si segue il sistema e il sistema non e fra le lingue supportate,
  /// il risultato e quello della lingua di fallback.
  String get nomeLinguaAttiva {
    final attiva = _lingua ?? _linguaFallback();
    return nomiNativi[attiva.languageCode] ?? attiva.languageCode;
  }

  /// Carica la lingua salvata dalle preferenze.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codice = prefs.getString(_chiavePreferenza);

      // Una lingua salvata che non e piu supportata viene ignorata,
      // cosi l'app non resta ferma su una lingua non piu disponibile.
      if (codice != null) {
        for (final l in supportate) {
          if (l.languageCode == codice) {
            _lingua = l;
            break;
          }
        }
      }
    } catch (e) {
      log.d('Errore nel caricamento della lingua: $e');
    }
  }

  /// Imposta la lingua dell'interfaccia e la salva.
  /// Passando `null` si torna a seguire il sistema operativo.
  Future<void> impostaLingua(Locale? lingua) async {
    _lingua = (lingua != null && !supportate.contains(lingua)) ? null : lingua;

    try {
      final prefs = await SharedPreferences.getInstance();
      final codice = _lingua?.languageCode;

      if (codice == null) {
        await prefs.remove(_chiavePreferenza);
      } else {
        await prefs.setString(_chiavePreferenza, codice);
      }
    } catch (e) {
      log.d('Errore nel salvataggio della lingua: $e');
    }

    notifyListeners();
  }

  /// Lingua effettivamente usata quando si segue il sistema.
  Locale _linguaFallback() {
    final diSistema = PlatformDispatcher.instance.locale;
    return supportate.firstWhere(
      (l) => l.languageCode == diSistema.languageCode,
      orElse: () => inglese,
    );
  }
}
