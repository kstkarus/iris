import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';

/// The release to offer: newer than the running version and not put off;
/// null when there is none. A check that fails offers nothing, as an
/// update is never urgent enough to say so.
class AppUpdateCubit extends Cubit<AppRelease?> {
  AppUpdateCubit({required AppUpdateRepository repository})
    : _repository = repository,
      super(null);

  final AppUpdateRepository _repository;

  Future<void> check() async {
    try {
      final latest = await _repository.latestRelease();
      final installed = await _repository.installedVersion();
      if (isClosed || latest == null || installed == null) return;
      if (!latest.version.isNewerThan(installed)) return;
      if (latest.version == _repository.dismissedVersion) return;
      emit(latest);
    } on Object catch (error) {
      developer.log(
        'Update check failed.',
        name: 'iris.app_update',
        error: error,
      );
    }
  }

  /// Puts the offered release off until a newer one comes out.
  Future<void> dismiss() async {
    final release = state;
    if (release == null) return;
    emit(null);
    await _repository.dismiss(release.version);
  }
}
