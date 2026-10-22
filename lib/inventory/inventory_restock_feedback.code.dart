import '../l10n/localized_text.dart';

export '../l10n/localized_text.dart';

class InventoryActionFeedback {
  const InventoryActionFeedback({
    required this.success,
    required this.message,
    this.details = const [],
  });

  final bool success;

  /// Esito da mostrare: la GUI lo traduce con `message(context.l10n)`.
  final LocalizedText message;

  /// Righe di dettaglio, tradotte come [message].
  final List<LocalizedText> details;
}

sealed class InventoryFormParse<T> {
  const InventoryFormParse();
}

class InventoryFormValid<T> extends InventoryFormParse<T> {
  const InventoryFormValid(this.value);

  final T value;
}

class InventoryFormInvalid<T> extends InventoryFormParse<T> {
  const InventoryFormInvalid(this.message);

  final LocalizedText message;
}

class InventoryInputParser {
  static int? parseProductId(String value) => parsePositiveInt(value);

  static int? parseStock(String value) => parseNonNegativeInt(value);

  static int? parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed <= 0 ? null : parsed;
  }

  static int? parseNonNegativeInt(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed < 0 ? null : parsed;
  }

  static int? parseOptionalNonNegativeInt(String value) {
    if (value.trim().isEmpty) return 0;
    return parseNonNegativeInt(value);
  }

  static int? parseOptionalPositiveInt(String value) {
    if (value.trim().isEmpty) return null;
    return parsePositiveInt(value);
  }

  static List<String> parseTags(String value) {
    return value
        .split(RegExp(r'[\s,;]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }
}

class InventoryIdentifierForm {
  const InventoryIdentifierForm(this.idText, {this.label = 'id'});

  /// Nome tecnico del campo (es. `purchase_order_id`), mostrato cosi com'e.

  final String idText;
  final String label;

  InventoryFormParse<int> parse() {
    final id = InventoryInputParser.parsePositiveInt(idText);
    return id == null
        ? InventoryFormInvalid((l10n) => l10n.inventoryInvalidField(label))
        : InventoryFormValid(id);
  }
}

mixin InventoryFeedbackController {
  InventoryActionFeedback? lastFeedback;

  InventoryActionFeedback remember(InventoryActionFeedback feedback) {
    lastFeedback = feedback;
    return feedback;
  }

  InventoryActionFeedback invalid(LocalizedText message) {
    return remember(InventoryActionFeedback(success: false, message: message));
  }
}

/// "<campo> non valido": il nome tecnico del campo resta invariato.
LocalizedText invalidFieldText(String field) =>
    (l10n) => l10n.inventoryInvalidField(field);
