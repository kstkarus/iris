import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_cubit.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_state.dart';
import 'package:iris/shared/network/network_exceptions.dart';

import '../../settings_test_doubles.dart';

void main() {
  late FakeAnimejoyAccountRepository repository;
  late AnimejoyAccountCubit cubit;

  setUp(() {
    repository = FakeAnimejoyAccountRepository();
    cubit = AnimejoyAccountCubit(repository: repository);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await repository.changes.close();
  });

  test('restores lazily and skips the network without saved cookies', () async {
    final saved = Completer<bool>();
    repository.readSaved = () => saved.future;
    expect(cubit.state, const AnimejoyAccountInitial());
    expect(repository.savedReads, 0);

    final restoring = cubit.ensureRestored();
    await cubit.ensureRestored();
    await cubit.signIn(login: 'name', password: 'password');
    expect(repository.credentials, isEmpty);
    expect(repository.savedReads, 1);
    expect(cubit.state, const AnimejoyAccountInitial());

    saved.complete(false);
    await restoring;
    await cubit.ensureRestored();
    expect(cubit.state, const AnimejoyAccountSignedOut());
    expect(repository.savedReads, 1);
    expect(repository.restores, 0);
  });

  test(
    'checks a saved account and only verifies unverified sessions',
    () async {
      repository.saved = true;
      final states = expectLater(
        cubit.stream,
        emitsInOrder([
          const AnimejoyAccountChecking(),
          const AnimejoyAccountSignedIn(),
        ]),
      );

      await cubit.ensureRestored();
      await states;
      await cubit.ensureRestored();
      await cubit.verify();

      expect(repository.savedReads, 1);
      expect(repository.restores, 1);
    },
  );

  test('a rejected saved session is expired', () async {
    repository.saved = true;
    repository.restoreSession = () async => false;

    await cubit.ensureRestored();

    expect(cubit.state, const AnimejoyAccountSignedOut(expired: true));
  });

  for (final (error, failure) in const [
    (NetworkRequestException('offline'), AnimejoyAuthFailure.network),
    (
      RemoteResponseException('unexpected reply'),
      AnimejoyAuthFailure.unavailable,
    ),
  ]) {
    test(
      'keeps saved cookies on ${failure.name} and retries verification',
      () async {
        repository.saved = true;
        repository.restoreSession = () async => throw error;

        await cubit.ensureRestored();
        expect(
          cubit.state,
          AnimejoyAccountSignedIn(unverified: true, failure: failure),
        );
        expect(repository.saved, isTrue);

        repository.restoreSession = null;
        await cubit.verify();
        expect(cubit.state, const AnimejoyAccountSignedIn());
        expect(repository.savedReads, 2);
        expect(repository.restores, 2);
      },
    );
  }

  test('verification notices that the saved session is gone', () async {
    repository.saved = true;
    repository.restoreSession = () async =>
        throw const NetworkRequestException('offline');
    await cubit.ensureRestored();

    repository.saved = false;
    await cubit.verify();

    expect(cubit.state, const AnimejoyAccountSignedOut());
    expect(repository.restores, 1);
  });

  test(
    'trims the login, preserves password whitespace, and guards busy calls',
    () async {
      final response = Completer<void>();
      repository.signInSession = () => response.future;

      final signingIn = cubit.signIn(login: '  name  ', password: ' secret ');
      expect(cubit.state, const AnimejoyAccountSigningIn());
      await cubit.signIn(login: 'other', password: 'other');
      await cubit.signOut();
      expect(repository.credentials, [('name', ' secret ')]);
      expect(repository.signOuts, 0);

      response.complete();
      await signingIn;
      expect(cubit.state, const AnimejoyAccountSignedIn());
    },
  );

  for (final (error, failure) in const [
    (AnimejoySignInRejected(), AnimejoyAuthFailure.invalidCredentials),
    (NetworkRequestException('offline'), AnimejoyAuthFailure.network),
    (
      RemoteResponseException('unexpected reply'),
      AnimejoyAuthFailure.unavailable,
    ),
  ]) {
    test('reports ${failure.name} when sign-in fails', () async {
      repository.signInSession = () async => throw error;

      await cubit.signIn(login: 'name', password: 'password');

      expect(cubit.state, AnimejoyAccountSignedOut(failure: failure));
    });
  }

  test(
    'treats external sign-out as expiry and its own sign-out as voluntary',
    () async {
      repository.publish(true);
      expect(cubit.state, const AnimejoyAccountSignedIn());
      repository.publish(false);
      expect(cubit.state, const AnimejoyAccountSignedOut(expired: true));

      repository.publish(true);
      await cubit.signOut();
      expect(cubit.state, const AnimejoyAccountSignedOut());
      expect(repository.saved, isFalse);
    },
  );

  test('keeps the known session visible when sign-out storage fails', () async {
    repository.publish(true);
    repository.clearSession = () async =>
        throw StateError('keystore unavailable');

    await cubit.signOut();

    expect(
      cubit.state,
      const AnimejoyAccountSignedIn(failure: AnimejoyAuthFailure.unavailable),
    );
    expect(repository.saved, isTrue);
  });

  test(
    'ignores a late local lookup when an external sign-in supersedes it',
    () async {
      final saved = Completer<bool>();
      repository.readSaved = () => saved.future;
      final restoring = cubit.ensureRestored();

      repository.publish(true);
      saved.complete(false);
      await restoring;

      expect(cubit.state, const AnimejoyAccountSignedIn());
      expect(repository.restores, 0);
    },
  );

  test('ignores a late verification reply after the account expires', () async {
    repository.saved = true;
    final response = Completer<bool>();
    repository.restoreSession = () => response.future;
    final checking = cubit.stream.firstWhere(
      (state) => state is AnimejoyAccountChecking,
    );
    final restoring = cubit.ensureRestored();
    await checking;

    repository.publish(false);
    response.complete(true);
    await restoring;

    expect(cubit.state, const AnimejoyAccountSignedOut(expired: true));
  });

  test('closing unsubscribes and ignores an outstanding sign-in', () async {
    final response = Completer<void>();
    repository.signInSession = () => response.future;
    final signingIn = cubit.signIn(login: 'name', password: 'password');

    await cubit.close();
    expect(repository.changes.hasListener, isFalse);
    response.complete();
    await signingIn;
    expect(cubit.state, const AnimejoyAccountSigningIn());
  });
}
