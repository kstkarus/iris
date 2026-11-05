import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/widgets/reveal_after_layout.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
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
  final _highlightedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    revealAfterLayout(_highlightedKey);
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightedFileIndex != widget.highlightedFileIndex) {
      revealAfterLayout(_highlightedKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final scaler = MediaQuery.textScalerOf(context);
          final columns = adaptiveColumnCount(
            availableWidth: constraints.maxWidth,
            minItemWidth: scaler.scale(52),
            spacing: spacing,
            maxColumns: 16,
          );
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final (position, file) in widget.files.indexed)
                SizedBox(
                  key: file.index == widget.highlightedFileIndex
                      ? _highlightedKey
                      : null,
                  width: width,
                  height: scaler.scale(52),
                  child: _EpisodeTile(
                    file: file,
                    number: episodeNumberLabel(file, position),
                    highlighted: file.index == widget.highlightedFileIndex,
                    progress: widget.progressByFile[file.index],
                    listed: widget.listed.contains(file.index),
                    onTap: () => widget.onSelected(file),
                  ),
                ),
            ],
          );
        },
      ),
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
            border: Border.all(
              color: highlighted
                  ? scheme.onSurface
                  : finished
                  ? scheme.outlineVariant
                  : scheme.outline,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  number,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    trackColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
