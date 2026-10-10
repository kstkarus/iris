import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';

/// Signed out, with sign-in not set up: the mock app never leaves the
/// device.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  bool get canSignIn => false;

  @override
  Stream<void> get sessionExpired => const Stream.empty();

  @override
  Future<ShikimoriAccount?> restore() async => null;

  @override
  Future<ShikimoriAccount> signIn() async => throw const AuthUnavailable();

  @override
  Future<void> signOut() async {}
}
