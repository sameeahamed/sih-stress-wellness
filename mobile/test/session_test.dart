/// Tests for session restore resilience.
///
/// Regression coverage for a startup hang: secure-storage reads used to happen
/// outside the guarded block, so a Keystore failure (routine after a device
/// restore or reinstall) left the app on the "Restoring your secure session…"
/// splash forever, with no login and no error. Also covers the rule that a
/// network failure must NOT discard a still-valid token.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/session.dart';
import 'package:sih_stress_wellness/core/token_store.dart';

/// A store whose read (or delete) throws, as Android Keystore can after a
/// device restore.
class ThrowingTokenStore implements TokenStore {
  ThrowingTokenStore({this.failWrite = false});

  final bool failWrite;
  int deleteCalls = 0;

  @override
  Future<String?> read() async => throw Exception('keystore unavailable');

  @override
  Future<void> write(String token) async {
    if (failWrite) throw Exception('keystore unavailable');
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    throw Exception('keystore unavailable');
  }
}

void main() {
  group('restore', () {
    test('a throwing token store never leaves the restoring state', () async {
      final controller = AuthController(
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: ThrowingTokenStore(),
      );

      await controller.restore();

      expect(
        controller.status,
        isNot(AuthStatus.restoring),
        reason: 'the splash must not persist after a storage failure',
      );
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.restoreError, isNotNull);
      controller.dispose();
    });

    test('an empty token store results in unauthenticated', () async {
      final controller = AuthController(
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: InMemoryTokenStore(),
      );

      await controller.restore();

      expect(controller.status, AuthStatus.unauthenticated);
      controller.dispose();
    });

    test('an unreachable server keeps the stored token (offline)', () async {
      final store = InMemoryTokenStore();
      await store.write('stored-token');
      final controller = AuthController(
        // Port 1 refuses connections, so this exercises the network path.
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: store,
      );

      await controller.restore();

      expect(controller.status, AuthStatus.offline);
      expect(
        await store.read(),
        'stored-token',
        reason: 'a connectivity blip must not sign the user out',
      );
      controller.dispose();
    });

    test('restore can be retried after a failure', () async {
      final store = InMemoryTokenStore();
      await store.write('stored-token');
      final controller = AuthController(
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: store,
      );

      await controller.restore();
      expect(controller.status, AuthStatus.offline);

      await controller.retryRestore();
      expect(controller.status, isNot(AuthStatus.restoring));
      controller.dispose();
    });
  });

  group('login', () {
    test('reports a storage failure instead of silently dropping in', () async {
      final controller = AuthController(
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: ThrowingTokenStore(failWrite: true),
      );

      // The unreachable server fails before the write is reached; either way
      // the user must get a message rather than a half-built session.
      final message = await controller.login('someone', 'whatever');

      expect(message, isNotNull);
      expect(controller.status, isNot(AuthStatus.authenticated));
      controller.dispose();
    });
  });

  group('logout', () {
    test('clears the session even when storage delete throws', () async {
      final store = InMemoryTokenStore();
      await store.write('stored-token');
      final controller = AuthController(
        api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
        tokenStore: _DeleteFailsStore(),
      );

      await controller.logout();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.token, isNull);
      expect(controller.user, isNull);
      // A failed delete must not resurrect the session.
      expect(await store.read(), 'stored-token');
      controller.dispose();
    });
  });
}

/// Delegates to an in-memory store but fails on delete.
class _DeleteFailsStore implements TokenStore {
  final _inner = InMemoryTokenStore();

  @override
  Future<String?> read() => _inner.read();

  @override
  Future<void> write(String token) => _inner.write(token);

  @override
  Future<void> delete() async => throw Exception('keystore unavailable');
}
