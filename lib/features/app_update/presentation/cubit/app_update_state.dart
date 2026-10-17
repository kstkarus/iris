import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';

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
  });

  final AppRelease? release;
  final AppUpdatePhase phase;
  final int receivedBytes;
  final int totalBytes;
  final AppUpdateFailureKind? failure;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0;

  bool get busy => switch (phase) {
    AppUpdatePhase.downloading ||
    AppUpdatePhase.verifying ||
    AppUpdatePhase.installing => true,
    _ => false,
  };

  @override
  bool operator ==(Object other) =>
      other is AppUpdateState &&
      other.release == release &&
      other.phase == phase &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.failure == failure;

  @override
  int get hashCode =>
      Object.hash(release, phase, receivedBytes, totalBytes, failure);
}
