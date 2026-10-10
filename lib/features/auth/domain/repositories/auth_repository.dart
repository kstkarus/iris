import 'package:iris/features/auth/domain/entities/shikimori_account.dart';

abstract interface class AuthRepository {
  /// Whether this build and device can sign in at all.
  bool get canSignIn;

  /// Fires when Shikimori stops accepting the session on its own.
  Stream<void> get sessionExpired;

  /// The account of a session kept from before, if there is one.
  Future<ShikimoriAccount?> restore();

  /// Asks the user on Shikimori's page. Throws an `AuthFailure`.
  Future<ShikimoriAccount> signIn();

  Future<void> signOut();
}
