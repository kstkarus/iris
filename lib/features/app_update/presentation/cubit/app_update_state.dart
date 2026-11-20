import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';

enum AppUpdateCheckStatus { idle, checking, upToDate, available, failed }

enum AppUpdatePhase {
  available,
  downloading,
  verifying,
  ready,
  installing,
  failed,
}

final class AppUpdateState {
  const AppUpdateState({
    this.release,
    this.phase = AppUpdatePhase.available,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.failure,
    this.checkStatus = AppUpdateCheckStatus.idle,
    this.installedVersion,
  });

  final AppRelease? release;
  final AppUpdatePhase phase;
  final int receivedBytes;
  final int totalBytes;
  final AppUpdateFailureKind? failure;
  final AppUpdateCheckStatus checkStatus;
  final AppVersion? installedVersion;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0;

  bool get busy => switch (phase) {
    AppUpdatePhase.downloading ||
    AppUpdatePhase.verifying ||
    AppUpdatePhase.installing => true,
    _ => false,
  };

  AppUpdateState copyWith({
    AppRelease? release,
    AppUpdatePhase? phase,
    int? receivedBytes,
    int? totalBytes,
    AppUpdateFailureKind? failure,
    AppUpdateCheckStatus? checkStatus,
    AppVersion? installedVersion,
  }) => AppUpdateState(
    release: release ?? this.release,
    phase: phase ?? this.phase,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    failure: failure ?? this.failure,
    checkStatus: checkStatus ?? this.checkStatus,
    installedVersion: installedVersion ?? this.installedVersion,
  );

  @override
  bool operator ==(Object other) =>
      other is AppUpdateState &&
      other.release == release &&
      other.phase == phase &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.failure == failure &&
      other.checkStatus == checkStatus &&
      other.installedVersion == installedVersion;

  @override
  int get hashCode => Object.hash(
    release,
    phase,
    receivedBytes,
    totalBytes,
    failure,
    checkStatus,
    installedVersion,
  );
}
