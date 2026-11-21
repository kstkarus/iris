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

const _keep = Object();

final class AppUpdateState {
  const AppUpdateState({
    this.release,
    this.dismissedRelease,
    this.phase = AppUpdatePhase.available,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.failure,
    this.cancelling = false,
    this.checkStatus = AppUpdateCheckStatus.idle,
    this.installedVersion,
  });

  final AppRelease? release;

  /// A newer release the user put off with Later: hidden from the top strip,
  /// but still surfaced quietly on Settings and directly actionable in About.
  final AppRelease? dismissedRelease;
  final AppUpdatePhase phase;
  final int receivedBytes;
  final int totalBytes;
  final AppUpdateFailureKind? failure;
  final bool cancelling;
  final AppUpdateCheckStatus checkStatus;
  final AppVersion? installedVersion;

  bool get hasDismissedUpdate => release == null && dismissedRelease != null;

  AppRelease? get availableRelease => release ?? dismissedRelease;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0;

  int get progressPercent => (progress * 100).round();

  bool get hasFailure =>
      phase == AppUpdatePhase.failed ||
      (phase == AppUpdatePhase.ready && failure != null);

  bool get showsProgress =>
      phase == AppUpdatePhase.downloading || phase == AppUpdatePhase.verifying;

  bool get busy => switch (phase) {
    AppUpdatePhase.downloading ||
    AppUpdatePhase.verifying ||
    AppUpdatePhase.installing => true,
    _ => false,
  };

  AppUpdateState copyWith({
    AppRelease? release,
    Object? dismissedRelease = _keep,
    AppUpdatePhase? phase,
    int? receivedBytes,
    int? totalBytes,
    AppUpdateFailureKind? failure,
    bool? cancelling,
    AppUpdateCheckStatus? checkStatus,
    AppVersion? installedVersion,
  }) => AppUpdateState(
    release: release ?? this.release,
    dismissedRelease: identical(dismissedRelease, _keep)
        ? this.dismissedRelease
        : dismissedRelease as AppRelease?,
    phase: phase ?? this.phase,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    failure: failure ?? this.failure,
    cancelling: cancelling ?? this.cancelling,
    checkStatus: checkStatus ?? this.checkStatus,
    installedVersion: installedVersion ?? this.installedVersion,
  );

  @override
  bool operator ==(Object other) =>
      other is AppUpdateState &&
      other.release == release &&
      other.dismissedRelease == dismissedRelease &&
      other.phase == phase &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.failure == failure &&
      other.cancelling == cancelling &&
      other.checkStatus == checkStatus &&
      other.installedVersion == installedVersion;

  @override
  int get hashCode => Object.hash(
    release,
    dismissedRelease,
    phase,
    receivedBytes,
    totalBytes,
    failure,
    cancelling,
    checkStatus,
    installedVersion,
  );
}
