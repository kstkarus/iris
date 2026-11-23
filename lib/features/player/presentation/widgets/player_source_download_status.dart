import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

String releaseWatchPosition(AppLocalizations l10n, WatchProgress progress) =>
    l10n.watchProgressStoppedAt(
      formatPlaybackPosition(progress.position),
      formatPlaybackPosition(progress.duration),
    );

String releaseWatchStatus(
  AppLocalizations l10n, {
  required bool finished,
  required WatchProgress? progress,
}) {
  if (finished) return l10n.watchProgressWatched;
  if (progress != null && progress.position > Duration.zero) {
    return releaseWatchPosition(l10n, progress);
  }
  return l10n.playerSourceUnwatched;
}

String releaseDownloadStatus(AppLocalizations l10n, DownloadItem item) =>
    switch (item.status) {
      DownloadStatus.completed => l10n.playerSourceDownloaded,
      DownloadStatus.downloading when item.totalBytes > 0 =>
        l10n.downloadSelectionLoading(
          (item.progressUntilCompleted * 100).round(),
        ),
      DownloadStatus.downloading => l10n.downloadStatusDownloading,
      DownloadStatus.queued => l10n.downloadStatusQueued,
      DownloadStatus.paused => l10n.downloadStatusPaused,
      DownloadStatus.failed => l10n.downloadStatusFailed,
    };

class ReleaseDownloadGlyph extends StatelessWidget {
  const ReleaseDownloadGlyph(this.item, {this.compact = false, super.key});

  final DownloadItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final (glyph, size, color) = switch (item.status) {
      DownloadStatus.completed => (PixelGlyph.file, 8.0, muted),
      DownloadStatus.downloading => (
        PixelGlyph.download,
        compact ? 9.0 : 16.0,
        scheme.tertiary,
      ),
      DownloadStatus.queued => (
        PixelGlyph.download,
        compact ? 9.0 : 16.0,
        compact ? muted.withValues(alpha: 0.7) : muted,
      ),
      DownloadStatus.paused => (PixelGlyph.pause, compact ? 7.0 : 14.0, muted),
      DownloadStatus.failed => (
        PixelGlyph.markWarning,
        compact ? 9.0 : 16.0,
        scheme.error,
      ),
    };
    return PixelIcon(
      glyph,
      size: size,
      fineGrain: compact,
      color: color,
      fill: item.status == DownloadStatus.downloading
          ? item.progressUntilCompleted
          : null,
      trackColor: muted.withValues(alpha: 0.4),
    );
  }
}
