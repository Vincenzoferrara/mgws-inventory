// inventory_module.code.dart
//
// I moduli del magazzino e il seme che li riapre.
//
// L'enum vive in un file suo, non in inventory.gui.dart: la pagina lo usa per
// il dropdown, ma anche i pannelli e il seme di modifica lo nominano, e senza
// questo file separato si chiuderebbe un ciclo di import fra pagina e pannelli.

import '../l10n/extensions.dart';

/// I moduli del magazzino.
///
/// `choose` non e' un modulo: e' la voce "nessun modulo scelto" del dropdown,
/// quindi non ha pannello. `ledger` e' l'unico che non muove stock: legge la
/// storia delle operazioni, e per questo non ha i campi di un movimento in
/// corso.
enum InventoryModule { choose, add, fix, move, ledger }

/// Nome del modulo, mostrato nel dropdown dei moduli.
///
/// Non piu' una mappa costante: le stringhe sono localizzate, quindi servono
/// le traduzioni del contesto per restituirle.
String inventoryModuleLabel(AppLocalizations l10n, InventoryModule module) =>
    switch (module) {
      InventoryModule.choose => l10n.inventoryModuleScegli,
      InventoryModule.add => l10n.inventoryModuleAggiungi,
      InventoryModule.fix => l10n.inventoryModuleRettifica,
      InventoryModule.move => l10n.inventoryModuleSposta,
      InventoryModule.ledger => l10n.inventoryModuleMovimenti,
    };

/// Riga di chiarimento sotto il dropdown, per il modulo scelto.
///
/// `null` per `choose`: non c'e' nessun modulo scelto, quindi non c'e' niente da
/// spiegare.
String? inventoryModuleDescription(
  AppLocalizations l10n,
  InventoryModule module,
) => switch (module) {
  InventoryModule.choose => null,
  InventoryModule.add => l10n.inventoryModuleDescAggiungi,
  InventoryModule.fix => l10n.inventoryModuleDescRettifica,
  InventoryModule.move => l10n.inventoryModuleDescSposta,
  InventoryModule.ledger => l10n.inventoryModuleDescMovimenti,
};

extension InventoryModuleX on InventoryModule {
  /// `true` se il modulo registra un movimento di magazzino.
  ///
  /// Serve a decidere se il campo "Dettagli" ha senso: il ledger non crea
  /// movimenti, quindi scrivere un dettaglio li' non avrebbe nessun posto dove
  /// finire. Un campo che raccoglie testo e poi lo perde e' peggio che non
  /// averlo.
  bool get writesStock => switch (this) {
    InventoryModule.add || InventoryModule.fix || InventoryModule.move => true,
    InventoryModule.choose || InventoryModule.ledger => false,
  };

  /// `true` se il modulo si puo' riaprire da un movimento del ledger.
  ///
  /// Rettifica e Sposta si possono riprendere: entrambe le rotte di scrittura
  /// ricostruiscono da sole quello che serve a rifare lo stesso gesto. La
  /// rettifica riporta il prodotto al valore assoluto che il movimento gli aveva
  /// lasciato, lo spostamento riparte dai due magazzini che le righe portano.
  ///
  /// Aggiungi no, e non per scelta: l'unica rotta che ha e' il carico, che sa
  /// solo aumentare lo stock. Un carico modificato in meno e' una diminuzione, e
  /// una diminuzione non e' un carico: non c'e' modo di esprimerla li'. Riaprirlo
  /// produrrebbe un movimento diverso da quello che l'operatore sta guardando,
  /// che e' il male che questo intero meccanismo cerca di evitare.
  ///
  /// Meglio un pulsante assente che un pulsante che produce un movimento
  /// diverso da quello che l'operatore sta guardando.
  bool get canResumeFromLedger =>
      this == InventoryModule.fix || this == InventoryModule.move;
}
