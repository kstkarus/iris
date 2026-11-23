import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/quality_badge.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class SingleFileReleaseCard extends StatelessWidget {
  const SingleFileReleaseCard({
    required this.state,
    required this.progress,
    required this.listed,
    required this.onPlay,
    required this.onOpenDownloads,
    super.key,
  });

  final PlayerSourceReady state;
  final WatchProgress? progress;
  final bool listed;
  final ValueChanged<PlayerVideoFile> onPlay;
  final VoidCallback? onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final file = state.files.single;
    final download = state.downloadFor(file.index);
    final completed = download?.status == DownloadStatus.completed;
    final maxQuality = state.downloadSource?.qualities.firstOrNull;
    final actualQuality = download?.videoHeight;
    final quality = completed
        ? (actualQuality == null
              ? null
              : l10n.onlineQualityHeight(actualQuality))
        : (maxQuality == null
              ? null
              : l10n.watchSourcesOnlineBestQuality(maxQuality));
    final progress = this.progress;
    final finished = progress?.isFinished ?? listed;
    final partial =
        progress != null && !finished && progress.position > Duration.zero;
    final duration = file.duration ?? progress?.duration;
    final metadata = [
      if (duration != null && duration > Duration.zero)
        l10n.playerEpisodeMinutes((duration.inSeconds / 60).round()),
      if (file.size > 0 && !completed)
        formatByteSize(l10n, file.size, decimalDigits: 2),
    ];
    final sans = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFamily: DetailLayout.sansFont,
    );
    final mono = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: scheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(side: BorderSide(color: rule)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        file.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          height: 1.28,
                          letterSpacing: 0,
                        ),
                      ),
                      if (metadata.isNotEmpty || quality != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (metadata.isNotEmpty)
                              PixelSeparatedText.parts(
                                metadata,
                                sansStyle: sans,
                                monoStyle: mono,
                                cleanLineWrap: true,
                              ),
                            if (quality != null) QualityBadge(quality),
                          ],
                        ),
                      ],
                      if (partial) ...[
                        const SizedBox(height: 16),
                        if (progress.duration > Duration.zero) ...[
                          ExcludeSemantics(
                            child: SegmentedBar(
                              value: progress.fraction,
                              height: 4,
                              segment: 6,
                              trackColor: DetailLayout.progressTrackColor(
                                scheme,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        MixedDataText(
                          releaseWatchPosition(l10n, progress),
                          sansStyle: sans,
                          monoStyle: mono,
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => onPlay(file),
                        child: Text(
                          finished
                              ? l10n.playerSourceWatchAgain
                              : partial
                              ? l10n.watchProgressContinueButton
                              : l10n.watchProgressWatchButton,
                        ),
                      ),
                      DitherSwitcher(
                        collapse: true,
                        resizeDuration: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 200),
                        child: download == null
                            ? Column(
                                key: const ValueKey('download_action'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 10),
                                  DitherSwitcher(
                                    collapse: true,
                                    resizeDuration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    duration: const Duration(milliseconds: 180),
                                    child: state.enqueueFailed
                                        ? const Padding(
                                            key: ValueKey('enqueue_error'),
                                            padding: EdgeInsets.only(bottom: 8),
                                            child: ReleaseEnqueueError(),
                                          )
                                        : const SizedBox.shrink(
                                            key: ValueKey('no_enqueue_error'),
                                          ),
                                  ),
                                  _SingleFileDownloadAction(
                                    state: state,
                                    index: file.index,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('no_download_action'),
                              ),
                      ),
                    ],
                  ),
                ),
                DitherSwitcher(
                  collapse: true,
                  resizeDuration: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 200),
                  child: download != null
                      ? Column(
                          key: const ValueKey('download_status'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(height: 1, thickness: 1, color: rule),
                            _DownloadStatusRow(
                              item: download,
                              onTap: onOpenDownloads,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('no_download_status'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleFileDownloadAction extends StatelessWidget {
  const _SingleFileDownloadAction({required this.state, required this.index});

  final PlayerSourceReady state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final button = OutlinedButton.icon(
      style: busyButtonStyle(
        busy: state.addingBatch,
        base: releaseDownloadOutline(context),
      ),
      onPressed: state.canDownload(index) && !state.addingBatch
          ? () => enqueueReleaseDownloads(context, singleIndex: index)
          : null,
      icon: const PixelIcon(PixelGlyph.download, size: 15),
      label: BusyButtonChild(
        l10n.downloadsOpenButton,
        busy: state.addingBatch,
        busySemanticsLabel: l10n.downloadAddingToQueue,
      ),
    );
    if (state.downloadSource?.qualities.isNotEmpty != true) return button;
    return Row(
      children: [
        DownloadQualityMenu(state: state),
        const SizedBox(width: 10),
        Expanded(child: button),
      ],
    );
  }
}

class _DownloadStatusRow extends StatelessWidget {
  const _DownloadStatusRow({required this.item, required this.onTap});

  final DownloadItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final completed = item.status == DownloadStatus.completed;
    final status = PixelSeparatedText.splitSegments(
      releaseDownloadStatus(l10n, item),
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: item.status == DownloadStatus.failed
          ? scheme.error
          : scheme.onSurface,
    );
    final sizeStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: muted,
    );
    return TapRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          children: [
            if (!completed) ...[
              DitherSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(item.status),
                  child: ReleaseDownloadGlyph(item),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: PixelSeparatedText.spans(
                [
                  TextSpan(text: status.first, style: bodyStyle),
                  if (status.length > 1)
                    TextSpan(
                      text: status.last,
                      style: DetailLayout.monoTelemetryStyle(
                        theme.textTheme.bodyMedium,
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (completed && item.totalBytes > 0)
                    DetailLayout.mixedDataSpan(
                      formatByteSize(l10n, item.totalBytes, decimalDigits: 2),
                      sansStyle: sizeStyle,
                      monoStyle: DetailLayout.monoTelemetryStyle(
                        sizeStyle,
                        color: muted,
                      ),
                    ),
                ],
                style: bodyStyle,
                cleanLineWrap: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.playerSourceOpenDownloads,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          color: muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PixelIcon(PixelGlyph.arrowRight, size: 14, color: muted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
