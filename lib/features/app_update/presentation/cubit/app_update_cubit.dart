import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';

class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit({
    required AppUpdateRepository repository,
    AppUpdateDownloadRepository? downloads,
  }) : _repository = repository,
       _downloads = downloads,
       super(const AppUpdateState());

  final AppUpdateRepository _repository;
  final AppUpdateDownloadRepository? _downloads;
  String? _preparedPath;
  int _operation = 0;
  bool _cancelling = false;
  bool _closing = false;
  bool _awaitingPermission = false;

  bool get supportsInAppUpdate => _downloads != null;

  bool _current(int operation) =>
      !_closing && !isClosed && operation == _operation;

  Future<void> check() async {
    if (_closing || isClosed || state.busy || _cancelling) return;
    final operation = ++_operation;
    try {
      final latest = await _repository.latestRelease();
      final installed = await _repository.installedVersion();
      if (!_current(operation) || latest == null || installed == null) return;
      if (!latest.version.isNewerThan(installed)) return;
      if (latest.version == _repository.dismissedVersion) return;
      _preparedPath = null;
      emit(AppUpdateState(release: latest));
      final path = await _downloads?.restore(latest);
      if (!_current(operation) || path == null) return;
      _preparedPath = path;
      emit(AppUpdateState(release: latest, phase: AppUpdatePhase.ready));
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
    final release = state.release;
    if (release == null || state.busy || state.phase == AppUpdatePhase.ready) {
      return;
    }
    ++_operation;
    emit(const AppUpdateState());
    await _repository.dismiss(release.version);
  }

  Future<void> download() async {
    final downloads = _downloads;
    final release = state.release;
    if (downloads == null || release == null || state.busy || _cancelling) {
      return;
    }
    final operation = ++_operation;
    _preparedPath = null;
    emit(
      AppUpdateState(
        release: release,
        phase: AppUpdatePhase.downloading,
        totalBytes: release.sizeBytes,
      ),
    );
    int? lastPercent;
    try {
      final path = await downloads.download(
        release,
        onProgress: (received, total) {
          if (!_current(operation)) return;
          final expected = total > 0 ? total : release.sizeBytes;
          if (expected > 0) {
            final percent = received * 100 ~/ expected;
            if (lastPercent == percent && state.totalBytes == expected) return;
            lastPercent = percent;
          }
          emit(
            AppUpdateState(
              release: release,
              phase: expected > 0 && received >= expected
                  ? AppUpdatePhase.verifying
                  : AppUpdatePhase.downloading,
              receivedBytes: received,
              totalBytes: expected,
            ),
          );
        },
      );
      if (!_current(operation)) return;
      _preparedPath = path;
      emit(AppUpdateState(release: release, phase: AppUpdatePhase.ready));
    } on Object catch (error) {
      if (!_current(operation)) return;
      final kind = error is AppUpdateFailure
          ? error.kind
          : AppUpdateFailureKind.network;
      emit(
        AppUpdateState(
          release: release,
          phase: kind == AppUpdateFailureKind.cancelled
              ? AppUpdatePhase.available
              : AppUpdatePhase.failed,
          failure: kind == AppUpdateFailureKind.cancelled ? null : kind,
        ),
      );
    }
  }

  Future<void> cancelDownload() async {
    if (_cancelling ||
        (state.phase != AppUpdatePhase.downloading &&
            state.phase != AppUpdatePhase.verifying)) {
      return;
    }
    final release = state.release;
    final operation = ++_operation;
    _cancelling = true;
    try {
      await _downloads?.cancel();
    } finally {
      _cancelling = false;
      if (_current(operation)) emit(AppUpdateState(release: release));
    }
  }

  Future<void> install() async {
    if (state.phase != AppUpdatePhase.ready || _awaitingPermission) return;
    await _install(requestPermission: true);
  }

  Future<void> resumeInstallation() async {
    if (!_awaitingPermission || _closing || isClosed) return;
    _awaitingPermission = false;
    await _install(requestPermission: false);
  }

  Future<void> _install({required bool requestPermission}) async {
    final downloads = _downloads;
    final release = state.release;
    final path = _preparedPath;
    if (downloads == null || release == null || path == null || state.busy) {
      return;
    }
    final operation = ++_operation;
    emit(AppUpdateState(release: release, phase: AppUpdatePhase.installing));
    try {
      final allowed = await downloads.canInstall();
      if (!_current(operation)) return;
      if (!allowed) {
        emit(
          AppUpdateState(
            release: release,
            phase: AppUpdatePhase.ready,
            failure: requestPermission ? null : AppUpdateFailureKind.permission,
          ),
        );
        if (requestPermission) {
          _awaitingPermission = true;
          await downloads.openInstallPermissionSettings();
        }
        return;
      }
      await downloads.install(path);
      if (!_current(operation)) return;
      // This only opens Android's confirmation; cancellation leaves the APK ready.
      emit(AppUpdateState(release: release, phase: AppUpdatePhase.ready));
    } on Object catch (error) {
      if (!_current(operation)) return;
      _awaitingPermission = false;
      final kind = error is AppUpdateFailure
          ? error.kind
          : AppUpdateFailureKind.install;
      if (kind == AppUpdateFailureKind.invalidFile) _preparedPath = null;
      emit(
        AppUpdateState(
          release: release,
          phase: kind == AppUpdateFailureKind.invalidFile
              ? AppUpdatePhase.failed
              : AppUpdatePhase.ready,
          failure: kind,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    ++_operation;
    await _downloads?.cancel();
    await super.close();
  }
}
