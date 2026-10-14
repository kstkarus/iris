import 'dart:async';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';

const testAccount = ShikimoriAccount(id: '42', nickname: 'kstk', avatarUrl: '');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.canSignIn = true, this.restored});

  @override
  bool canSignIn;

  ShikimoriAccount? restored;
  AuthFailure? failure;
  Completer<void>? signInGate;
  Completer<void>? restoreGate;
  int signOuts = 0;

  final _expired = StreamController<void>.broadcast();

  void expire() => _expired.add(null);

  @override
  Stream<void> get sessionExpired => _expired.stream;

  @override
  Future<ShikimoriAccount?> restore() async {
    await restoreGate?.future;
    return restored;
  }

  @override
  Future<ShikimoriAccount> signIn() async {
    await signInGate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return testAccount;
  }

  @override
  Future<void> signOut() async => signOuts++;
}
