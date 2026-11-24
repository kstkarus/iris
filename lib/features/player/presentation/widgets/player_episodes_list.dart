import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/episode_list_scroll_view.dart';
import 'package:iris/features/player/presentation/widgets/episode_tag_badge.dart';
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
    this.metadataByFile = const {},
    this.horizontalPadding = 0,
    this.tabular = false,
    this.topPadding = 4,
    this.isOnline = false,
    this.onLongPressed,
    this.onQuickDownload,
    super.key,
  });

  final PlayerSourceReady source;
  final int? highlightedFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final Map<int, EpisodeMetadata> metadataByFile;
  final double horizontalPadding;

  /// Single-line desktop table layout with right-aligned telemetry columns.
  final bool tabular;
  final double topPadding;
  final ValueChanged<PlayerVideoFile> onSelected;
  final ValueChanged<PlayerVideoFile>? onLongPressed;
  final ValueChanged<PlayerVideoFile>? onQuickDownload;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final files = source.files;
    final names = distinctEpisodeNames(files, metadata: metadataByFile);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dividerColor = DetailLayout.ruleColor(scheme).withValues(alpha: 0.45);
    final numberWidth = _numberColumnWidth(context, theme, files.length);
    final anim = motionDuration(context, const Duration(milliseconds: 150));

    bool isSelectedAt(int pos) {
      if (pos < 0 || pos >= files.length || !source.selecting) return false;
      final index = files[pos].index;
      return source.canDownload(index) && source.selected.contains(index);
    }

    final list = EpisodeListScrollView(
      targetIndex: files.indexWhere(
        (file) => file.index == highlightedFileIndex,
      ),
      padding: EdgeInsets.only(top: topPadding, bottom: 24),
      itemCount: files.length,
      itemBuilder: (context, position) {
        final file = files[position];
        final index = file.index;
        final available = source.canDownload(index);
        final selected =
            source.selecting && available && source.selected.contains(index);
        final highlighted = !source.selecting && index == highlightedFileIndex;
        final progress = progressByFile[index];
        final row = AnimatedContainer(
          duration: anim,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? scheme.surfaceContainer : Colors.transparent,
            border: tabular
                ? Border(
                    left: BorderSide(
                      width: 2,
                      color: highlighted
                          ? scheme.onSurface
                          : Colors.transparent,
                    ),
                  )
                : null,
          ),
          child: _EpisodeRow(
            file: file,
            number: episodeNumberLabel(file, position),
            numberWidth: numberWidth,
            horizontalPadding: horizontalPadding,
            tabular: tabular,
            name: names[index] ?? file.displayName,
            episodeMetadata: metadataByFile[index],
            progress: progress,
            listed: listed.contains(index),
            highlighted: highlighted,
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
            onSecondaryTap:
                !source.selecting &&
                    available &&
                    !source.addingBatch &&
                    onLongPressed != null
                ? () => onLongPressed!(file)
                : null,
            onQuickDownload:
                tabular &&
                    !source.selecting &&
                    available &&
                    !source.addingBatch &&
                    onQuickDownload != null
                ? () => onQuickDownload!(file)
                : null,
          ),
        );
        if (position == files.length - 1) return row;
        final nextSelected = isSelectedAt(position + 1);
        final boundary = selected != nextSelected;
        final bothSelected = selected && nextSelected;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            if (boundary)
              const SizedBox(height: 1)
            else
              ColoredBox(
                color: bothSelected
                    ? scheme.surfaceContainer
                    : Colors.transparent,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  indent: horizontalPadding + numberWidth,
                  endIndent: horizontalPadding,
                  color: dividerColor,
                ),
              ),
          ],
        );
      },
    );
    if (!tabular) return list;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              FocusScope.of(context).nextFocus(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              FocusScope.of(context).previousFocus(),
        },
        child: list,
      ),
    );
  }
}

/// Aligns the episode title rail with `FramedAppBar`'s title offset (`42 px`
/// after the back arrow glyph) for standard 2–3 digit releases, expanding only
/// when needed for 4-digit series (`1080`) or large text scales in O(1).
double _numberColumnWidth(
  BuildContext context,
  ThemeData theme,
  int fileCount,
) {
  const appBarTitleOffset = 42.0;
  final textScaler = MediaQuery.textScalerOf(context);
  final minWidth = textScaler
      .scale(appBarTitleOffset)
      .clamp(appBarTitleOffset, 56.0);
  if (fileCount <= 0) return minWidth;
  final sample = '${fileCount.clamp(10, 9999)}';
  final style = DetailLayout.monoTelemetryStyle(
    theme.textTheme.titleSmall,
    fontWeight: FontWeight.w600,
  );
  final painter = TextPainter(
    text: TextSpan(text: sample, style: style),
    textDirection: Directionality.of(context),
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final measured = painter.width + 14;
  painter.dispose();
  return measured.clamp(minWidth, 64.0);
}

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    required this.file,
    required this.number,
    required this.numberWidth,
    required this.horizontalPadding,
    required this.tabular,
    required this.name,
    required this.episodeMetadata,
    required this.progress,
    required this.listed,
    required this.highlighted,
    required this.isOnline,
    required this.source,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
    required this.onQuickDownload,
  });

  final PlayerVideoFile file;
  final String number;
  final double numberWidth;
  final double horizontalPadding;
  final bool tabular;
  final String name;
  final EpisodeMetadata? episodeMetadata;
  final WatchProgress? progress;
  final bool listed;
  final bool highlighted;
  final bool isOnline;
  final PlayerSourceReady source;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onQuickDownload;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final number = widget.number;
    final numberWidth = widget.numberWidth;
    final horizontalPadding = widget.horizontalPadding;
    final tabular = widget.tabular;
    final name = widget.name;
    final episodeMetadata = widget.episodeMetadata;
    final progress = widget.progress;
    final listed = widget.listed;
    final highlighted = widget.highlighted;
    final isOnline = widget.isOnline;
    final source = widget.source;
    final onTap = widget.onTap;
    final onLongPress = widget.onLongPress;
    final onSecondaryTap = widget.onSecondaryTap;
    final onQuickDownload = widget.onQuickDownload;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = progress?.isFinished ?? listed;
    final partial =
        progress != null && !finished && progress.position > Duration.zero;
    final selecting = source.selecting;
    final available = source.canDownload(file.index);
    final unavailable = selecting && !available;
    final selected =
        selecting && available && source.selected.contains(file.index);
    final muted = unavailable || (!selecting && finished && !highlighted);
    final showName = !nameIsJustNumber(name, number);
    final tags = episodeTags(episodeMetadata);
    final tagLabels = episodeTagLabels(l10n, episodeMetadata);
    final download = source.downloadFor(file.index);
    final duration = file.duration;
    final size = file.size > 0 ? file.size : download?.totalBytes ?? 0;
    final hasProgressDuration = partial && progress.duration > Duration.zero;
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

    final durationOrProgress = partial
        ? meta(
            progress.duration > Duration.zero
                ? '${formatPlaybackPosition(progress.position)} / '
                      '${formatPlaybackPosition(progress.duration)}'
                : formatPlaybackPosition(progress.position),
          )
        : duration != null && duration > Duration.zero
        ? meta(l10n.playerEpisodeMinutes((duration.inSeconds / 60).round()))
        : size > 0
        ? meta(formatByteSize(l10n, size))
        : null;
    final torrentSizeWithProgress = partial && duration == null && size > 0
        ? meta(formatByteSize(l10n, size))
        : null;
    final downloadSpan = download != null
        ? meta(releaseDownloadStatus(l10n, download), color: downloadColor)
        : null;

    final anim = motionDuration(context, const Duration(milliseconds: 150));
    final numberStyle = DetailLayout.monoTelemetryStyle(
      theme.textTheme.titleSmall,
      fontWeight: selected || highlighted ? FontWeight.w600 : FontWeight.w500,
      color: selected || highlighted
          ? scheme.onSurface
          : muted
          ? scheme.onSurfaceVariant
          : scheme.onSurface.withValues(alpha: 0.72),
    )!;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 15,
      height: 1.32,
      fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
      color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
    );

    Widget buildTrailing({required bool compactPadding}) {
      if (selecting && available) {
        return Padding(
          key: const ValueKey('select_box'),
          padding: EdgeInsets.only(
            left: compactPadding ? 12 : 0,
            top: compactPadding ? 1 : 0,
          ),
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: SizedBox.square(
                dimension: 18,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) {},
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (!selecting && _hovered && onQuickDownload != null) {
        return Tooltip(
          key: const ValueKey('quick_download'),
          message: l10n.downloadsOpenButton,
          waitDuration: const Duration(milliseconds: 350),
          triggerMode: TooltipTriggerMode.manual,
          child: InkResponse(
            key: ValueKey('player_episode_download_${file.index}'),
            onTap: onQuickDownload,
            radius: 16,
            child: SizedBox.square(
              dimension: 28,
              child: Center(
                child: PixelIcon(
                  PixelGlyph.download,
                  size: 14,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      }
      if (!selecting && finished) {
        return Padding(
          key: const ValueKey('watched'),
          padding: EdgeInsets.only(
            left: compactPadding ? 12 : 0,
            top: compactPadding ? 3 : 0,
          ),
          child: PixelIcon(
            PixelGlyph.check,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        );
      }
      return const SizedBox.shrink(key: ValueKey('empty'));
    }

    final progressBar = hasProgressDuration
        ? SegmentedBar(
            value: progress.fraction,
            height: 2,
            segment: 4,
            gap: 0,
            color: selecting ? scheme.onSurfaceVariant : scheme.tertiary,
            trackColor: DetailLayout.progressTrackColor(
              scheme,
            ).withValues(alpha: 0.4),
          )
        : null;

    final Widget content;
    if (tabular) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: numberWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedDefaultTextStyle(
                      duration: anim,
                      curve: Curves.easeOutCubic,
                      style: numberStyle,
                      child: Text(number, maxLines: 1),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (showName)
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    for (final tag in tags) ...[
                      if (showName || tag != tags.first)
                        const SizedBox(width: 8),
                      EpisodeTagBadge(tag),
                    ],
                  ],
                ),
              ),
              if (downloadSpan != null) ...[
                const SizedBox(width: 20),
                Text.rich(downloadSpan, maxLines: 1),
              ],
              if (torrentSizeWithProgress != null) ...[
                const SizedBox(width: 20),
                Text.rich(torrentSizeWithProgress, maxLines: 1),
              ],
              if (durationOrProgress != null) ...[
                const SizedBox(width: 20),
                SizedBox(
                  width: 108,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        durationOrProgress,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                      ),
                      if (progressBar != null) ...[
                        const SizedBox(height: 5),
                        progressBar,
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 28,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: DitherSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: buildTrailing(compactPadding: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final metadata = [
        ?torrentSizeWithProgress,
        ?durationOrProgress,
        ?downloadSpan,
      ];
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: numberWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, right: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: AnimatedDefaultTextStyle(
                      duration: anim,
                      curve: Curves.easeOutCubic,
                      style: numberStyle,
                      child: Text(number, maxLines: 1),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showName)
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    if (metadata.isNotEmpty || tags.isNotEmpty) ...[
                      if (showName) const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (metadata.isNotEmpty)
                            PixelSeparatedText.spans(
                              metadata,
                              style: sans,
                              cleanLineWrap: true,
                            ),
                          for (final tag in tags) EpisodeTagBadge(tag),
                        ],
                      ),
                    ],
                    if (progressBar != null) ...[
                      const SizedBox(height: 8),
                      progressBar,
                    ],
                  ],
                ),
              ),
              DitherSwitcher(
                duration: const Duration(milliseconds: 180),
                child: buildTrailing(compactPadding: true),
              ),
            ],
          ),
        ),
      );
    }

    final row = ReleaseEpisodeTapRow(
      index: file.index,
      number: number,
      isOnline: isOnline,
      name: showName ? name : null,
      tags: tagLabels,
      progress: progress,
      finished: finished,
      download: download,
      selecting: selecting,
      selected: selected,
      highlighted: highlighted,
      showTooltip: tabular && unavailable,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      child: content,
    );
    if (!tabular) return row;
    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: row,
    );
  }
}
