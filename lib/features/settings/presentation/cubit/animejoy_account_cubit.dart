import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_state.dart';
import 'package:iris/shared/network/network_exceptions.dart';

final class AnimejoyAccountCubit extends Cubit<AnimejoyAccountState> {
  AnimejoyAccountCubit({required AnimejoyAccountRepository repository})
    : _repository = repository,
      super(const AnimejoyAccountInitial()) {
    _subscription = repository.sessionChanges.listen(_sessionChanged);
  }

  final AnimejoyAccountRepository _repository;
  late final StreamSubscription<bool> _subscription;
  int _operation = 0;
  bool _working = false;
  bool _signingOut = false;

  Future<void> ensureRestored() async {
    if (state is AnimejoyAccountInitial) await _run(_restore);
  }

  Future<void> verify() async {
    if (state case AnimejoyAccountSignedIn(unverified: true)) {
      await _run(_restore);
    }
  }

  Future<void> _restore(int operation) async {
    var hasSavedSession = state is AnimejoyAccountSignedIn;
    try {
      hasSavedSession = await _repository.hasSavedSession();
      if (!_current(operation)) return;
      if (!hasSavedSession) {
        emit(const AnimejoyAccountSignedOut());
        return;
      }
      emit(const AnimejoyAccountChecking());
      final restored = await _repository.restore();
      if (!_current(operation)) return;
      emit(
        restored
            ? const AnimejoyAccountSignedIn()
            : const AnimejoyAccountSignedOut(expired: true),
      );
    } on Object catch (error) {
      if (!_current(operation)) return;
      final failure = error is NetworkRequestException
          ? AnimejoyAuthFailure.network
          : AnimejoyAuthFailure.unavailable;
      emit(
        hasSavedSession
            ? AnimejoyAccountSignedIn(unverified: true, failure: failure)
            : AnimejoyAccountSignedOut(failure: failure),
      );
    }
  }

  Future<void> signIn({required String login, required String password}) =>
      _run((operation) async {
        final previous = state;
        emit(const AnimejoyAccountSigningIn());
        try {
          await _repository.signIn(login: login.trim(), password: password);
          if (_current(operation)) emit(const AnimejoyAccountSignedIn());
        } on Object catch (error) {
          if (!_current(operation)) return;
          final failure = switch (error) {
            AnimejoySignInRejected() => AnimejoyAuthFailure.invalidCredentials,
            NetworkRequestException() => AnimejoyAuthFailure.network,
            _ => AnimejoyAuthFailure.unavailable,
          };
          emit(_withFailure(previous, failure));
        }
      });

  Future<void> signOut() => _run((operation) async {
    try {
      await _repository.signOut();
      if (_current(operation)) emit(const AnimejoyAccountSignedOut());
    } on Object {
      if (_current(operation)) {
        emit(_withFailure(state, AnimejoyAuthFailure.unavailable));
      }
    }
  }, signingOut: true);

  AnimejoyAccountState _withFailure(
    AnimejoyAccountState previous,
    AnimejoyAuthFailure failure,
  ) => switch (previous) {
    AnimejoyAccountSignedIn(:final unverified) => AnimejoyAccountSignedIn(
      unverified: unverified,
      failure: failure,
    ),
    _ => AnimejoyAccountSignedOut(failure: failure),
  };

  Future<void> _run(
    Future<void> Function(int operation) action, {
    bool signingOut = false,
  }) async {
    if (isClosed || _working) return;
    final operation = ++_operation;
    _working = true;
    _signingOut = signingOut;
    try {
      await action(operation);
    } finally {
      _working = false;
      _signingOut = false;
    }
  }

  bool _current(int operation) => !isClosed && operation == _operation;

  void _sessionChanged(bool signedIn) {
    if (isClosed) return;
    if (signedIn) {
      ++_operation;
      emit(const AnimejoyAccountSignedIn());
    } else if (_signingOut ||
        state is AnimejoyAccountSignedIn ||
        state is AnimejoyAccountChecking) {
      ++_operation;
      emit(AnimejoyAccountSignedOut(expired: !_signingOut));
    }
  }

  @override
  Future<void> close() async {
    ++_operation;
    await Future.wait([_subscription.cancel(), super.close()]);
  }
}
