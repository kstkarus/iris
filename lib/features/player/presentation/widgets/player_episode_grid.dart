import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/features/player/presentation/widgets/release_episode_tap_row.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The source picker's unnamed episodes, with the suggested one outlined.
class PlayerEpisodeGrid extends StatefulWidget {
  const PlayerEpisodeGrid({
    required this.source,
    required this.highlightedFileIndex,
    required this.progressByFile,
    required this.listed,
    required this.onSelected,
    this.isOnline = false,
    this.onLongPressed,
    super.key,
  });

  final PlayerSourceReady source;
  List<PlayerVideoFile> get files => source.files;
  final int? highlightedFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final ValueChanged<PlayerVideoFile> onSelected;
  final ValueChanged<PlayerVideoFile>? onLongPressed;
  final bool isOnline;

  @override
  State<PlayerEpisodeGrid> createState() => _PlayerEpisodeGridState();
}

class _PlayerEpisodeGridState extends State<PlayerEpisodeGrid> {
  final _scroll = ScrollController();
  (int?, int)? _target;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealHighlighted(int columns, double rowStride) {
    final highlighted = widget.highlightedFileIndex;
    final index = widget.files.indexWhere((file) => file.index == highlighted);
    final target = (highlighted, index);
    if (_target == target) return;
    _target = target;
    if (index < 0) return;

    final animate = _scroll.hasClients;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _target != target) return;
      final position = _scroll.position;
      final offset =
          (index ~/ columns * rowStride - 0.3 * position.viewportDimension)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      final duration = animate
          ? motionDuration(context, const Duration(milliseconds: 250))
          : Duration.zero;
      if (duration == Duration.zero) {
        _scroll.jumpTo(offset);
      } else {
        _scroll.animateTo(offset, duration: duration, curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final rowHeight = MediaQuery.textScalerOf(context).scale(52);
        final columns = adaptiveColumnCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: rowHeight,
          spacing: spacing,
          maxColumns: 16,
        );
        _revealHighlighted(columns, rowHeight + spacing);
        return GridView.builder(
          controller: _scroll,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: rowHeight,
          ),
          itemCount: widget.files.length,
          itemBuilder: (context, position) {
            final file = widget.files[position];
            final source = widget.source;
            final index = file.index;
            final available = source.canDownload(index);
            return _EpisodeTile(
              index: index,
              number: episodeNumberLabel(file, position),
              isOnline: widget.isOnline,
              highlighted:
                  !source.selecting && index == widget.highlightedFileIndex,
              progress: widget.progressByFile[index],
              listed: widget.listed.contains(index),
              download: source.downloadFor(index),
              selecting: source.selecting,
              selected: available && source.selected.contains(index),
              unavailable: source.selecting && !available,
              onTap: source.selecting && (!available || source.addingBatch)
                  ? null
                  : () => widget.onSelected(file),
              onLongPress:
                  !source.selecting &&
                      available &&
                      !source.addingBatch &&
                      widget.onLongPressed != null
                  ? () => widget.onLongPressed!(file)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.index,
    required this.number,
    required this.isOnline,
    required this.highlighted,
    required this.progress,
    required this.listed,
    required this.download,
    required this.selecting,
    required this.selected,
    required this.unavailable,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final String number;
  final bool isOnline;
  final bool highlighted;
  final WatchProgress? progress;
  final bool listed;
  final DownloadItem? download;
  final bool selecting;
  final bool selected;
  final bool unavailable;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final rule = DetailLayout.ruleColor(scheme);
    final download = this.download;
    final progress = this.progress;
    final finished = progress?.isFinished ?? listed;
    final partial =
        progress != null &&
        !finished &&
        progress.position > Duration.zero &&
        progress.duration > Duration.zero;
    final muted = unavailable || (!selecting && finished && !highlighted);
    final background = switch ((selected, unavailable, highlighted, muted)) {
      (true, _, _, _) => scheme.onSurface,
      (_, true, _, _) =>
        light ? scheme.surfaceDim : scheme.surfaceContainerLowest,
      (_, _, true, _) => scheme.surfaceContainerHigh,
      (_, _, _, true) =>
        light ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      _ => light ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
    };
    final anim = motionDuration(context, const Duration(milliseconds: 150));
    final numberStyle = DetailLayout.monoTelemetryStyle(
      theme.textTheme.titleSmall,
      color: selected
          ? scheme.surface
          : muted
          ? scheme.onSurfaceVariant
          : scheme.onSurface,
      fontWeight: FontWeight.w600,
    )!;
    return AnimatedContainer(
      duration: anim,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        border: unavailable
            ? null
            : Border.all(
                width: selected || highlighted ? 1.5 : 1,
                color: selected || highlighted
                    ? scheme.onSurface
                    : muted
                    ? rule.withValues(alpha: 0.7)
                    : rule,
              ),
      ),
      child: ReleaseEpisodeTapRow(
        index: index,
        number: number,
        isOnline: isOnline,
        progress: progress,
        finished: finished,
        download: download,
        selecting: selecting,
        selected: selected,
        highlighted: highlighted,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AnimatedDefaultTextStyle(
                  duration: anim,
                  curve: Curves.easeOutCubic,
                  style: numberStyle,
                  child: Text(number, maxLines: 1),
                ),
              ),
              if (download != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: ReleaseDownloadGlyph(download, compact: true),
                ),
              if (finished)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: DitherSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selecting
                        ? const SizedBox.shrink(key: ValueKey('hidden'))
                        : PixelIcon(
                            PixelGlyph.check,
                            key: const ValueKey('watched'),
                            size: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                  ),
                ),
              if (partial && !selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SegmentedBar(
                    value: progress.fraction,
                    height: 3,
                    segment: 3,
                    gap: 0,
                    color: unavailable
                        ? scheme.onSurfaceVariant
                        : scheme.tertiary,
                    trackColor: DetailLayout.progressTrackColor(scheme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
