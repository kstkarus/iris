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
