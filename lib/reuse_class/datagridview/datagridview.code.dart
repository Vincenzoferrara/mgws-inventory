import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

class DataGridViewColumn {
  final String id;
  final String label;
  final double width;
  final bool numeric;

  /// La colonna assorbe la larghezza che resta dopo tutte le altre.
  ///
  /// Senza questo, con colonne tutte a larghezza fissa la tabella si ferma
  /// alla somma delle larghezze e lascia uno spazio morto a destra. Con
  /// `flexible` la colonna non ha larghezza fissa: `DataTable2` le distribuisce
  /// tutto il residuo, e [width] resta la sua larghezza minima, raggiunta
  /// facendo scorrere la tabella in orizzontale.
  final bool flexible;

  const DataGridViewColumn({
    required this.id,
    required this.label,
    this.width = 120,
    this.numeric = false,
    this.flexible = false,
  });
}

class DataGridViewRowData<T> {
  final String id;
  final T value;
  final Map<String, Widget> cells;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const DataGridViewRowData({
    required this.id,
    required this.value,
    required this.cells,
    this.foregroundColor,
    this.backgroundColor,
  });
}

/// Azione del menu contestuale mostrato dalla [DataGridView] sul click destro
/// (o pressione prolungata sulle card mobili che riusano lo stesso menu).
///
/// La voce di menu (etichetta + icona) e la logica di dispatcher vivono nella
/// griglia riusabile; il chiamante fornisce solo le azioni e il callback
/// applicato alla riga selezionata.
class DataGridViewContextAction<T> {
  final String label;
  final IconData icon;
  final Future<void> Function(T value) onSelected;

  const DataGridViewContextAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });
}

/// Tipo di un campo del modello: decide quali operatori di filtro ha senso
/// offrire e come leggere i valori scritti dall'utente.
enum DataGridFieldType { testo, numero, booleano, data, elenco }

/// Un campo del modello mostrato da una lista gestionale.
///
/// La libreria non conosce i modelli: ogni schermata descrive i campi del
/// suo modello (`ProdottoGlobal`, `ClienteGlobal`, ...) con il loro nome e
/// una funzione che li legge. Filtri, ricerca, ordinamento, colonne e
/// paginazione lavorano solo su questi descrittori.
class DataGridField<T> {
  /// Nome del campo nel modello. E' anche la chiave salvata nelle
  /// preferenze delle colonne e nei filtri, quindi non va cambiato.
  final String name;

  /// Etichetta tradotta mostrata in filtri, ordinamento e colonne.
  final String Function(AppLocalizations l10n) label;

  /// Intestazione della colonna quando deve essere piu' corta di [label].
  final String Function(AppLocalizations l10n)? columnLabel;

  /// Altri nomi che l'utente puo' scrivere nel campo del filtro. Valgono
  /// anche per risolvere le colonne salvate con un nome precedente.
  final List<String> aliases;

  final DataGridFieldType type;

  /// Valori del campo per un elemento. Sono piu' di uno quando il dato si
  /// ripete, come i codici delle varianti o le categorie di un prodotto: il
  /// filtro e' soddisfatto se almeno uno dei valori lo soddisfa.
  ///
  /// I valori sono `String`, `num`, `bool` o `DateTime` secondo [type]; i
  /// null e le stringhe vuote vengono ignorati.
  final Iterable<Object?> Function(T item) read;

  /// Nome del parametro con cui il server filtra o ordina per questo campo.
  /// Senza, il campo si filtra e si ordina solo sull'elenco completo caricato
  /// in memoria.
  final String? serverParam;

  final bool sortable;
  final bool filterable;

  /// Il campo partecipa alla ricerca rapida.
  final bool searchable;

  /// Il campo puo' essere scelto come colonna della griglia.
  final bool column;
  final double width;
  final bool numeric;

  /// Vedi [DataGridViewColumn.flexible].
  final bool flexible;

  /// Testo mostrato nella cella quando la schermata non disegna una cella
  /// personalizzata. Senza, si uniscono i valori letti da [read].
  final String Function(AppLocalizations l10n, T item)? format;

  const DataGridField({
    required this.name,
    required this.label,
    required this.read,
    this.columnLabel,
    this.type = DataGridFieldType.testo,
    this.aliases = const <String>[],
    this.serverParam,
    this.sortable = false,
    this.filterable = true,
    this.searchable = true,
    this.column = true,
    this.width = 140,
    this.numeric = false,
    this.flexible = false,
    this.format,
  });

  /// Vero se [input] (gia' minuscolo e senza spazi ai lati) indica questo
  /// campo: il nome, l'etichetta o uno degli alias.
  bool matchesName(AppLocalizations l10n, String input) =>
      name.toLowerCase() == input ||
      label(l10n).toLowerCase() == input ||
      aliases.any((alias) => alias == input);

  String headerLabel(AppLocalizations l10n) =>
      (columnLabel ?? label).call(l10n);

  DataGridViewColumn toColumn(AppLocalizations l10n) => DataGridViewColumn(
    id: name,
    label: headerLabel(l10n),
    width: width,
    numeric: numeric,
    flexible: flexible,
  );
}

/// Ordinamento attivo di una lista: il campo e la direzione.
class DataGridSort {
  final String fieldName;
  final bool ascending;

  const DataGridSort(this.fieldName, {this.ascending = true});

  @override
  bool operator ==(Object other) =>
      other is DataGridSort &&
      other.fieldName == fieldName &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(fieldName, ascending);
}
