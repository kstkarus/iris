import 'dart:async';

import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/domain/repositories/app_settings_repository.dart';

class FakeAnimejoyAccountRepository implements AnimejoyAccountRepository {
  final changes = StreamController<bool>.broadcast(sync: true);
  final credentials = <(String, String)>[];
  bool saved = false;
  int savedReads = 0;
  int restores = 0;
  int signOuts = 0;
  Future<bool> Function()? readSaved;
  Future<bool> Function()? restoreSession;
  Future<void> Function()? signInSession;
  Future<void> Function()? clearSession;
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  Stream<bool> get sessionChanges => changes.stream;

  @override
  Future<bool> hasSavedSession() async {
    savedReads++;
    return await readSaved?.call() ?? saved;
  }

  @override
  Future<bool> restore() async {
    restores++;
    return await restoreSession?.call() ?? saved;
  }

  @override
  Future<void> signIn({required String login, required String password}) async {
    credentials.add((login, password));
    await signInSession?.call();
    publish(true);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    await clearSession?.call();
    publish(false);
  }

  void publish(bool signedIn) {
    saved = signedIn;
    _generation++;
    changes.add(signedIn);
  }
}

class MemoryAppSettingsRepository implements AppSettingsRepository {
  MemoryAppSettingsRepository(this._saved);

  AppSettings _saved;
  final writes = <AppSettings>[];
  Future<void> Function(AppSettings)? onSave;

  @override
  AppSettings load() => _saved;

  @override
  Future<void> save(AppSettings settings) async {
    writes.add(settings);
    await onSave?.call(settings);
    _saved = settings;
  }
}
