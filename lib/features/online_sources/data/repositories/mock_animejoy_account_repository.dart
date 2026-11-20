import 'dart:async';

import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';

final class MockAnimejoyAccountRepository implements AnimejoyAccountRepository {
  final _sessionChanges = StreamController<bool>.broadcast();
  bool _signedIn = false;
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  Stream<bool> get sessionChanges => _sessionChanges.stream;

  @override
  Future<bool> hasSavedSession() async => _signedIn;

  @override
  Future<bool> restore() async => _signedIn;

  @override
  Future<void> signIn({required String login, required String password}) async {
    if (login.trim().isEmpty || password.isEmpty) {
      throw const AnimejoySignInRejected();
    }
    _publish(true);
  }

  @override
  Future<void> signOut() async => _publish(false);

  void _publish(bool signedIn) {
    _signedIn = signedIn;
    _generation++;
    _sessionChanges.add(signedIn);
  }

  Future<void> dispose() => _sessionChanges.close();
}
