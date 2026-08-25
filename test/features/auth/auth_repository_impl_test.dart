import 'package:clinicore_flutter/core/error/exceptions.dart';
import 'package:clinicore_flutter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_datasources.dart';

/// Tests for the one place `AuthRepositoryImpl` does something a
/// `FakeAuthRepository` could never demonstrate: `signOut`'s resilience
/// contract.
///
/// Every other method on this class is a thin translation from an
/// `AppException` to a `Failure`, already exercised indirectly through the
/// bloc tests. `signOut` is different: it is the one method that must NOT
/// let a failure through, and that guarantee is worth its own test — a
/// `guardFailure` wrapped around the wrong line here would silently bring
/// back the exact bug this exists to prevent.
void main() {
  group('AuthRepositoryImpl.signOut', () {
    late FakeAuthRemoteDataSource remote;
    late FakeAuthLocalDataSource local;
    late AuthRepositoryImpl repository;

    setUp(() {
      remote = FakeAuthRemoteDataSource();
      local = FakeAuthLocalDataSource();
      repository = AuthRepositoryImpl(
        remote: remote,
        local: local,
        biometrics: FakeBiometricDataSource(),
      );
    });

    test('calls POST /auth/logout and clears the local session', () async {
      final result = await repository.signOut();

      expect(remote.logoutCallCount, 1);
      expect(local.clearCallCount, 1);
      expect(result.isRight(), isTrue);
    });

    test(
      'clears the local session even when the server call fails',
      () async {
        // The regression this guards: a patient tapping "cerrar sesion" with
        // no internet, or while the server is down, must still end up logged
        // out on THIS device. If `local.clear()` ever moves behind an
        // unguarded `await remote.logout()`, this is what catches it.
        remote.logoutError = const NetworkException(
          message: 'No pudimos conectarnos. Revisa tu internet.',
        );

        await repository.signOut();

        expect(local.clearCallCount, 1);
      },
    );

    test(
      'always reports success, regardless of the server outcome',
      () async {
        remote.logoutError = const ServerException(
          message: 'El servicio no responde.',
        );

        final result = await repository.signOut();

        // A sign-out that can refuse is a trap: there is nothing a caller
        // could do differently in response to a Left here.
        expect(result.isRight(), isTrue);
      },
    );
  });
}
