import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';

sealed class AuthState {
  const AuthState();
}

/// A session kept from before is being looked at.
final class AuthRestoring extends AuthState {
  const AuthRestoring();

  @override
  bool operator ==(Object other) => other is AuthRestoring;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.failure, this.expired = false});

  /// Why the last sign-in failed, to say once; never [AuthCancelled].
  final AuthFailure? failure;

  /// Shikimori ended the session itself.
  final bool expired;

  @override
  bool operator ==(Object other) =>
      other is AuthSignedOut &&
      other.failure == failure &&
      other.expired == expired;

  @override
  int get hashCode => Object.hash(failure, expired);
}

final class AuthSigningIn extends AuthState {
  const AuthSigningIn();

  @override
  bool operator ==(Object other) => other is AuthSigningIn;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.account);

  final ShikimoriAccount account;

  @override
  bool operator ==(Object other) =>
      other is AuthSignedIn && other.account == account;

  @override
  int get hashCode => account.hashCode;
}

/// The signed-in account's id, the key to its Shikimori list; null when
/// signed out or still restoring.
String? accountIdOf(AuthState state) => switch (state) {
  AuthSignedIn(:final account) => account.id,
  _ => null,
};
