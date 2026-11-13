import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

String downloadStatusLabel(AppLocalizations l10n, DownloadStatus status) {
  return switch (status) {
    DownloadStatus.queued => l10n.downloadStatusQueued,
    DownloadStatus.downloading => l10n.downloadStatusDownloading,
    DownloadStatus.paused => l10n.downloadStatusPaused,
    DownloadStatus.completed => l10n.downloadStatusCompleted,
    DownloadStatus.failed => l10n.downloadStatusFailed,
  };
}

String downloadFailureMessage(AppLocalizations l10n, DownloadFailure failure) {
  return switch (failure) {
    DownloadFailure.noSpace => l10n.downloadFailedNoSpace,
    DownloadFailure.noAccess => l10n.downloadFailedNoAccess,
    DownloadFailure.fileMissing => l10n.downloadFailedFileMissing,
    DownloadFailure.couldNotStart => l10n.downloadFailedCouldNotStart,
    DownloadFailure.connectionLost => l10n.downloadFailedConnectionLost,
    DownloadFailure.notDownloadable => l10n.downloadFailedNotDownloadable,
    DownloadFailure.other => l10n.downloadFailedMessage,
  };
}
