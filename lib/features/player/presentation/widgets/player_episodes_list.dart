import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/episode_list_scroll_view.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/features/player/presentation/widgets/release_episode_tap_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

class PlayerEpisodesList extends StatelessWidget {
  const PlayerEpisodesList({
    required this.source,
    required this.progressByFile,
    required this.onSelected,
    this.highlightedFileIndex,
    this.listed = const {},
    this.isOnline = false,
    this.onLongPressed,
    super.key,
  });

  final PlayerSourceReady source;
  final int? highlightedFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final ValueChanged<PlayerVideoFile> onSelected;
  final ValueChanged<PlayerVideoFile>? onLongPressed;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final files = source.files;
    final names = distinctEpisodeNames(files);
    final scheme = Theme.of(context).colorScheme;
    final rule = BorderSide(color: DetailLayout.ruleColor(scheme));
    return EpisodeListScrollView(
      targetIndex: files.indexWhere(
        (file) => file.index == highlightedFileIndex,
      ),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: files.length,
      itemBuilder: (context, position) {
        final file = files[position];
        final index = file.index;
        final available = source.canDownload(index);
        return Material(
          color: scheme.surfaceContainerLow,
          shape: Border(
            top: position == 0 ? rule : BorderSide.none,
            left: rule,
            right: rule,
            bottom: rule,
          ),
          child: _EpisodeRow(
            file: file,
            number: episodeNumberLabel(file, position),
            name: names[index] ?? file.displayName,
            progress: progressByFile[index],
            listed: listed.contains(index),
            isOnline: isOnline,
            source: source,
            onTap: source.selecting && (!available || source.addingBatch)
                ? null
                : () => onSelected(file),
            onLongPress:
                !source.selecting &&
                    available &&
                    !source.addingBatch &&
                    onLongPressed != null
                ? () => onLongPressed!(file)
                : null,
          ),
        );
      },
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.file,
    required this.number,
    required this.name,
    required this.progress,
    required this.listed,
    required this.isOnline,
    required this.source,
    required this.onTap,
    required this.onLongPress,
  });

  final PlayerVideoFile file;
  final String number;
  final String name;
  final WatchProgress? progress;
  final bool listed;
  final bool isOnline;
  final PlayerSourceReady source;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final finished = progress?.isFinished ?? listed;
    final partial =
        progress != null && !finished && progress.position > Duration.zero;
    final selecting = source.selecting;
    final available = source.canDownload(file.index);
    final unavailable = selecting && !available;
    final selected =
        selecting && available && source.selected.contains(file.index);
    final muted = unavailable || (!selecting && finished);
    final showName = !nameIsJustNumber(name, number);
    final download = source.downloadFor(file.index);
    final duration = file.duration;
    final size = file.size > 0 ? file.size : download?.totalBytes ?? 0;
    final base = theme.textTheme.bodySmall;
    final sans = base?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurfaceVariant,
    );
    final mono = DetailLayout.monoTelemetryStyle(
      base,
      color: scheme.onSurfaceVariant,
    );
    final downloadColor = switch (download?.status) {
      DownloadStatus.downloading => scheme.tertiary,
      DownloadStatus.failed => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    InlineSpan meta(String text, {Color? color}) => DetailLayout.mixedDataSpan(
      text,
      sansStyle: sans?.copyWith(color: color),
      monoStyle: mono?.copyWith(color: color),
    );
    final metadata = [
      if (duration != null && duration > Duration.zero)
        meta(l10n.playerEpisodeMinutes((duration.inSeconds / 60).round()))
      else if (size > 0)
        meta(formatByteSize(l10n, size)),
      if (partial)
        TextSpan(
          text:
              '${formatPlaybackPosition(progress.position)} / '
              '${formatPlaybackPosition(progress.duration)}',
          style: mono,
        ),
      if (download != null)
        meta(releaseDownloadStatus(l10n, download), color: downloadColor),
    ];

    final anim = motionDuration(context, const Duration(milliseconds: 150));

    return ReleaseEpisodeTapRow(
      index: file.index,
      number: number,
      isOnline: isOnline,
      name: showName ? name : null,
      progress: progress,
      finished: finished,
      download: download,
      selecting: selecting,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: anim,
                    curve: Curves.easeOutCubic,
                    width: 36,
                    height: 36,
                    decoration: selecting && available
                        ? BoxDecoration(
                            color: selected
                                ? scheme.onSurface
                                : scheme.surfaceContainer,
                            border: Border.all(
                              color: selected
                                  ? scheme.onSurface
                                  : DetailLayout.ruleColor(scheme),
                            ),
                          )
                        : const BoxDecoration(),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          number,
                          style: DetailLayout.monoTelemetryStyle(
                            theme.textTheme.titleSmall,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? scheme.surface
                                : muted
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showName)
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: DetailLayout.sansFont,
                              fontWeight: muted
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                              color: muted
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                        if (metadata.isNotEmpty) ...[
                          if (showName) const SizedBox(height: 3),
                          PixelSeparatedText.spans(
                            metadata,
                            style: sans,
                            cleanLineWrap: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (finished)
                    SizedBox(
                      width: 26,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DitherSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: selecting
                              ? const SizedBox.shrink(key: ValueKey('hidden'))
                              : PixelIcon(
                                  PixelGlyph.check,
                                  key: const ValueKey('watched'),
                                  size: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (partial && progress.duration > Duration.zero && !selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SegmentedBar(
                  value: progress.fraction,
                  height: 3,
                  segment: 6,
                  gap: 0,
                  color: unavailable
                      ? scheme.onSurfaceVariant
                      : scheme.tertiary,
                  trackColor: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
