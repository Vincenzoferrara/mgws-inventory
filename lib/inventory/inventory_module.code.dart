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

  /// Whether this module can reopen a movement from the ledger.
  ///
  /// All three writing modules can be reopened. Each one rebuilds the same
  /// operation from what the ledger records: Adjustment from the absolute stock
  /// left by the movement, Transfer from the route carried by its rows, and
  /// Add from the products and quantities of the stock-in. Editing an Add in
  /// place writes the stock difference, not a new load.
  ///
  /// The "last movement only" rule is not a property of the module: it is a
  /// separate guard, checked when the movement is opened and enforced by MGWS.
  bool get canResumeFromLedger => switch (this) {
    InventoryModule.add || InventoryModule.fix || InventoryModule.move => true,
    InventoryModule.choose || InventoryModule.ledger => false,
  };
}
