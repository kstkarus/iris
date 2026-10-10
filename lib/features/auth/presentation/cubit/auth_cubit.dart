import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';

/// The Shikimori session for the whole app: the profile tab shows it, and
/// the anime page's list status needs its account.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthRepository repository})
    : _repository = repository,
      super(const AuthRestoring()) {
    _expiredSubscription = repository.sessionExpired.listen((_) {
      if (state is AuthSignedIn) emit(const AuthSignedOut(expired: true));
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expiredSubscription;

  bool get canSignIn => _repository.canSignIn;

  Future<void> restore() async {
    final account = await _repository.restore();
    if (isClosed || state is! AuthRestoring) return;
    emit(account == null ? const AuthSignedOut() : AuthSignedIn(account));
  }

  Future<void> signIn() async {
    if (state is AuthSigningIn || state is AuthSignedIn) return;
    emit(const AuthSigningIn());
    try {
      final account = await _repository.signIn();
      if (!isClosed) emit(AuthSignedIn(account));
    } on AuthCancelled {
      if (!isClosed) emit(const AuthSignedOut());
    } on AuthFailure catch (failure) {
      if (!isClosed) emit(AuthSignedOut(failure: failure));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    if (!isClosed) emit(const AuthSignedOut());
  }

  @override
  Future<void> close() async {
    await _expiredSubscription.cancel();
    return super.close();
  }
}
