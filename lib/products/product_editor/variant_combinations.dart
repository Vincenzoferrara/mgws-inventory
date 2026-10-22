import '../class_products.dart';

/// Funzioni pure per generare e confrontare combinazioni di varianti.
abstract final class VariantCombinations {
  static String key(List<AttributoVariante> attributes) {
    final pairs =
        attributes
            .map(
              (attribute) =>
                  '${attribute.nome.trim().toLowerCase()}=${attribute.opzione.trim().toLowerCase()}',
            )
            .where((pair) => !pair.startsWith('=') && !pair.endsWith('='))
            .toList()
          ..sort();
    return pairs.join('|');
  }

  static List<List<AttributoVariante>> generate(
    List<AttributoVariante> attributes,
  ) {
    final grouped = <String, List<String>>{};
    for (final attribute in attributes) {
      grouped
          .putIfAbsent(attribute.nome, () => <String>[])
          .add(attribute.opzione);
    }

    var combinations = <List<AttributoVariante>>[<AttributoVariante>[]];
    for (final entry in grouped.entries) {
      final values = entry.value.toSet().toList()..sort();
      final next = <List<AttributoVariante>>[];
      for (final combination in combinations) {
        for (final value in values) {
          next.add([
            ...combination,
            AttributoVariante(nome: entry.key, opzione: value),
          ]);
        }
      }
      combinations = next;
    }
    return combinations;
  }
}
