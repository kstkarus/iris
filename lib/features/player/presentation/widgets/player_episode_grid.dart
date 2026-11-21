import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// The source picker's unnamed episodes, with the suggested one outlined.
class PlayerEpisodeGrid extends StatefulWidget {
  const PlayerEpisodeGrid({
    required this.files,
    required this.highlightedFileIndex,
    required this.progressByFile,
    required this.listed,
    required this.onSelected,
    super.key,
  });

  final List<PlayerVideoFile> files;
  final int? highlightedFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final ValueChanged<PlayerVideoFile> onSelected;

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
            return _EpisodeTile(
              file: file,
              number: episodeNumberLabel(file, position),
              highlighted: file.index == widget.highlightedFileIndex,
              progress: widget.progressByFile[file.index],
              listed: widget.listed.contains(file.index),
              onTap: () => widget.onSelected(file),
            );
          },
        );
      },
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.file,
    required this.number,
    required this.highlighted,
    required this.progress,
    required this.listed,
    required this.onTap,
  });

  final PlayerVideoFile file;
  final String number;
  final bool highlighted;
  final WatchProgress? progress;
  final bool listed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final finished = progress?.isFinished ?? listed;
    final partial =
        progress != null && !finished && progress.duration > Duration.zero;
    return Semantics(
      selected: highlighted,
      child: TapRow(
        inkKey: ValueKey('player_episode_${file.index}'),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: highlighted
                ? scheme.surfaceContainerHigh
                : finished
                ? scheme.surfaceContainerLowest
                : scheme.surfaceContainerLow,
            border: Border.all(
              width: highlighted ? 1.5 : 1,
              color: highlighted
                  ? scheme.onSurface
                  : finished
                  ? DetailLayout.ruleColor(scheme).withValues(alpha: 0.7)
                  : DetailLayout.ruleColor(scheme),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  number,
                  maxLines: 1,
                  style: DetailLayout.monoTelemetryStyle(
                    theme.textTheme.titleSmall,
                    color: finished && !highlighted
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (finished)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: PixelIcon(
                    PixelGlyph.check,
                    size: 10,
                    color: scheme.onSurfaceVariant,
                    semanticLabel: AppLocalizations.of(
                      context,
                    ).watchProgressWatched,
                  ),
                ),
              if (partial)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SegmentedBar(
                    value: progress.fraction,
                    height: 3,
                    gap: 0,
                    color: scheme.tertiary,
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
