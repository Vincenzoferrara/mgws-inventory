import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/updater/updater_service.dart';

void main() {
  group('UpdaterService.isNewerVersion', () {
    test('riconosce una release successiva', () {
      expect(UpdaterService.isNewerVersion('v1.0.32', '1.0.26'), isTrue);
      expect(UpdaterService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(UpdaterService.isNewerVersion('1.1', '1.0.99'), isTrue);
    });

    test('ignora la stessa versione e quelle precedenti', () {
      expect(UpdaterService.isNewerVersion('v1.0.26', '1.0.26'), isFalse);
      expect(UpdaterService.isNewerVersion('1.0.26+30', '1.0.26'), isFalse);
      expect(UpdaterService.isNewerVersion('1.0.9', '1.0.10'), isFalse);
    });

    test('non segnala nulla con versioni non leggibili', () {
      expect(UpdaterService.isNewerVersion('', '1.0.0'), isFalse);
      expect(UpdaterService.isNewerVersion('nightly', '1.0.0'), isFalse);
    });
  });
}
