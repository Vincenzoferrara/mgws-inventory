import 'package:flutter/foundation.dart';

/// Lets a section ask the home to open another section by its id, e.g. the
/// products list opening "Templates and print" to print labels.
///
/// The home listens and opens the section with the same checks used by its
/// cards (login and MGWS availability), then clears the request.
final ValueNotifier<String?> homeSectionRequest = ValueNotifier<String?>(null);

void requestHomeSection(String sectionId) {
  homeSectionRequest.value = null;
  homeSectionRequest.value = sectionId;
}
