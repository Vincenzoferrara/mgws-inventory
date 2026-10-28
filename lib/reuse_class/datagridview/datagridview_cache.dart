import 'package:flutter/foundation.dart';

import '../logic/global_pagination_controller.dart';

/// Cache condivisa di una lista gestionale, una per chiave di modello
/// (`prodotti`, `clienti`, `ordini`, ...).
///
/// Tiene due cose:
/// - l'elenco completo degli elementi, quando la lista lavora in memoria
///   (filtri e paginazione locali). Si riempie a pezzi con [append] mentre
///   arrivano le pagine dal server e si sostituisce con [replace];
/// - le pagine gia' lette dal server, per combinazione di filtri, ordinamento
///   e pagina, quando la lista lavora sul server.
///
/// E' globale perche' due schede della stessa sezione, o due sezioni che
/// mostrano lo stesso modello, devono vedere gli stessi dati senza
/// riscaricarli. Chi modifica gli elementi chiama [replace] o [updateWhere]:
/// le liste aperte ascoltano la cache e si ridisegnano.
class DataGridViewCache<T> extends ChangeNotifier {
  DataGridViewCache._(this.key);

  static final Map<String, DataGridViewCache<dynamic>> _instances =
      <String, DataGridViewCache<dynamic>>{};

  /// Cache della chiave [key]. La stessa chiave deve usare sempre lo stesso
  /// tipo di elemento.
  static DataGridViewCache<T> of<T>(String key) {
    final existing = _instances[key];
    if (existing != null) return existing as DataGridViewCache<T>;
    final created = DataGridViewCache<T>._(key);
    _instances[key] = created;
    return created;
  }

  /// Segna da ricaricare tutte le cache, per esempio al cambio di negozio.
  static void markAllDirty() {
    for (final cache in _instances.values) {
      cache.markDirty();
    }
  }

  final String key;

  List<T>? _items;
  DateTime? _itemsAt;
  bool _dirty = true;
  bool _complete = false;
  int _revision = 0;

  final Map<String, _CachedPage<T>> _pages = <String, _CachedPage<T>>{};

  /// Cresce a ogni modifica degli elementi: chi ha copiato l'elenco capisce
  /// se la sua copia e' ancora quella attuale.
  int get revision => _revision;

  bool get hasItems => _items != null && _items!.isNotEmpty;

  /// L'elenco e' arrivato fino all'ultima pagina del server.
  bool get isComplete => _complete;

  bool get isDirty => _dirty;

  /// Elenco completo, non segnato da ricaricare e, con [ttl], piu' recente
  /// di [ttl].
  bool isFresh([Duration? ttl]) {
    if (_dirty || !_complete || _items == null || _itemsAt == null) {
      return false;
    }
    if (ttl == null) return true;
    return DateTime.now().difference(_itemsAt!) <= ttl;
  }

  /// Copia dell'elenco, o null se non e' mai stato caricato.
  List<T>? read() {
    final items = _items;
    if (items == null) return null;
    return List<T>.from(items);
  }

  /// Elenco senza copia. Chi lo modifica sul posto chiama poi [touch].
  List<T> get items => _items ??= <T>[];

  /// Sostituisce l'elenco. [complete] dice se contiene tutto quello che c'e'
  /// sul server o solo le prime pagine.
  void replace(List<T> items, {bool complete = true}) {
    _items = List<T>.from(items);
    _itemsAt = DateTime.now();
    _dirty = false;
    _complete = complete;
    _changed();
  }

  /// Aggiunge una pagina in coda all'elenco, durante il caricamento.
  void append(List<T> items, {bool complete = false}) {
    _items = <T>[...?_items, ...items];
    _itemsAt = DateTime.now();
    _dirty = false;
    _complete = complete;
    _changed();
  }

  /// Sostituisce gli elementi che soddisfano [test] con [update]. Ritorna
  /// quanti ne ha cambiati.
  int updateWhere(bool Function(T item) test, T Function(T item) update) {
    final items = _items;
    if (items == null) return 0;
    var changed = 0;
    for (var i = 0; i < items.length; i++) {
      if (test(items[i])) {
        items[i] = update(items[i]);
        changed++;
      }
    }
    if (changed > 0) {
      _pages.clear();
      _changed();
    }
    return changed;
  }

  /// Toglie gli elementi che soddisfano [test].
  int removeWhere(bool Function(T item) test) {
    final items = _items;
    if (items == null) return 0;
    final before = items.length;
    items.removeWhere(test);
    final removed = before - items.length;
    if (removed > 0) {
      _pages.clear();
      _changed();
    }
    return removed;
  }

  /// Avvisa le liste aperte che gli elementi sono stati modificati sul
  /// posto, attraverso [items].
  void touch() {
    _pages.clear();
    _changed();
  }

  /// I dati vanno ricaricati alla prossima apertura: l'elenco resta
  /// leggibile finche' non arriva quello nuovo.
  void markDirty() {
    _dirty = true;
    _pages.clear();
    _changed();
  }

  void clear() {
    _items = null;
    _itemsAt = null;
    _dirty = true;
    _complete = false;
    _pages.clear();
    _changed();
  }

  /// Pagina letta dal server per la richiesta [requestKey], se ancora valida.
  PaginatedResult<T>? readPage(String requestKey, {Duration? ttl}) {
    final cached = _pages[requestKey];
    if (cached == null) return null;
    if (ttl != null && DateTime.now().difference(cached.at) > ttl) {
      _pages.remove(requestKey);
      return null;
    }
    return cached.result;
  }

  void writePage(String requestKey, PaginatedResult<T> result) {
    _pages[requestKey] = _CachedPage<T>(result, DateTime.now());
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }
}

class _CachedPage<T> {
  final PaginatedResult<T> result;
  final DateTime at;

  const _CachedPage(this.result, this.at);
}
