import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_auth.dart';
import 'package:mgws_inventory/login/mgws/connection/mgws_connection.dart';

/// Auth finto: la verifica resta in volo finche [release] non viene chiamato.
class _SlowAuth implements MgwsAuth {
  _SlowAuth(this.available);

  final bool available;
  final Completer<void> _gate = Completer<void>();
  bool released = false;

  void release() {
    if (!released) {
      released = true;
      _gate.complete();
    }
  }

  @override
  Future<MgwsAuthResult> verify() async {
    await _gate.future;
    return MgwsAuthResult(
      available: available,
      reason: available
          ? MgwsUnavailableReason.unknown
          : MgwsUnavailableReason.unreachable,
    );
  }
}

void main() {
  test('logout durante una verifica non riattiva MGWS', () async {
    final auth = _SlowAuth(true);
    final connection = MgwsConnection(auth: auth);

    final inFlight = connection.verify();

    // Il logout invalida lo stato mentre la richiesta e' in volo.
    connection.markDisconnected();
    auth.release();

    expect(await inFlight, isFalse);
    expect(connection.isConnected, isFalse);
    expect(connection.isChecked, isFalse);
  });

  test('verifica riuscita aggiorna lo stato', () async {
    final auth = _SlowAuth(true);
    final connection = MgwsConnection(auth: auth);

    final inFlight = connection.verify();
    auth.release();

    expect(await inFlight, isTrue);
    expect(connection.isConnected, isTrue);
    expect(connection.isChecked, isTrue);
  });

  test('chiamate concorrenti condividono una sola richiesta', () async {
    final auth = _SlowAuth(true);
    final connection = MgwsConnection(auth: auth);

    final prima = connection.verify();
    final seconda = connection.verify();
    auth.release();

    expect(await prima, isTrue);
    expect(await seconda, isTrue);
    expect(auth.released, isTrue);
  });

  test('markDisconnected invalida anche uno stato positivo', () async {
    final auth = _SlowAuth(true);
    final connection = MgwsConnection(auth: auth);

    final inFlight = connection.verify();
    auth.release();
    await inFlight;
    expect(connection.isConnected, isTrue);

    connection.markDisconnected();
    expect(connection.isConnected, isFalse);
    expect(connection.isChecked, isFalse);
  });
}
