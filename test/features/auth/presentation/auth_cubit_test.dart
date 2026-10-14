import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';

import 'auth_test_doubles.dart';

void main() {
  test(
    'an expired session cannot be restored by a late account response',
    () async {
      final repository = FakeAuthRepository(restored: testAccount)
        ..restoreGate = Completer<void>();
      final cubit = AuthCubit(repository: repository);
      addTearDown(cubit.close);
      final restoring = cubit.restore();
      repository.expire();
      await pumpEventQueue();
      repository.restoreGate!.complete();
      await restoring;
      expect(cubit.state, const AuthSignedOut(expired: true));
    },
  );

  test('restores a kept session, or settles signed out', () async {
    final kept = AuthCubit(
      repository: FakeAuthRepository(restored: testAccount),
    );
    await kept.restore();
    expect(kept.state, const AuthSignedIn(testAccount));

    final none = AuthCubit(repository: FakeAuthRepository());
    await none.restore();
    expect(none.state, const AuthSignedOut());
  });

  test('signs in through a waiting state', () async {
    final repository = FakeAuthRepository()..signInGate = Completer();
    final cubit = AuthCubit(repository: repository);
    await cubit.restore();

    final signingIn = cubit.signIn();
    expect(cubit.state, const AuthSigningIn());
    repository.signInGate!.complete();
    await signingIn;

    expect(cubit.state, const AuthSignedIn(testAccount));
  });

  test('a cancelled sign-in is quiet, a failed one says why', () async {
    final repository = FakeAuthRepository()..failure = const AuthCancelled();
    final cubit = AuthCubit(repository: repository);
    await cubit.restore();

    await cubit.signIn();
    expect(cubit.state, const AuthSignedOut());

    repository.failure = const AuthNetworkFailure();
    await cubit.signIn();
    expect(
      cubit.state,
      isA<AuthSignedOut>().having(
        (state) => state.failure,
        'failure',
        isA<AuthNetworkFailure>(),
      ),
    );
  });

  test('signs out', () async {
    final repository = FakeAuthRepository(restored: testAccount);
    final cubit = AuthCubit(repository: repository);
    await cubit.restore();

    await cubit.signOut();

    expect(cubit.state, const AuthSignedOut());
    expect(repository.signOuts, 1);
  });

  test('a session Shikimori ends is shown as expired', () async {
    final repository = FakeAuthRepository(restored: testAccount);
    final cubit = AuthCubit(repository: repository);
    await cubit.restore();

    repository.expire();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignedOut(expired: true));
    await cubit.close();
  });
}
