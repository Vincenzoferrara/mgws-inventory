import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

// Chi importa questo file ha a disposizione anche AppLocalizations.
export 'generated/app_localizations.dart';

/// Accesso rapido alle traduzioni dell'app.
///
/// Si usa come `context.l10n.cassaTotale`. E' il modo consigliato per leggere
/// una stringa visibile: rende evidente a chi legge il codice che quel testo
/// dipende dalla lingua e va tradotto in entrambi i file ARB.
extension TraduzioneContext on BuildContext {
  /// Le traduzioni correnti per il contesto dato.
  ///
  /// Con `nullable-getter: false` in `l10n.yaml` questo valore non e mai nullo:
  /// se fosse nullo significa che il widget non ha `MaterialApp` come antenato,
  /// cioe che mancano le localizzazioni nell'albero dei widget.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
