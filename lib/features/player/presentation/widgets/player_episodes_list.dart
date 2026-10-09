import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The torrent's video files as numbered rows with watch progress; the
/// playing one stays marked and scrolled into view so the list and the
/// player read as one place.
class PlayerEpisodesList extends StatefulWidget {
  const PlayerEpisodesList({
    required this.files,
    required this.currentFileIndex,
    required this.progressByFile,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
    this.showSizes = false,
    super.key,
  });

  final List<PlayerVideoFile> files;

  /// The playing file; null when nothing plays yet (the file picker).
  final int? currentFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final ValueChanged<PlayerVideoFile> onSelected;
  final EdgeInsetsGeometry padding;

  /// Shows each file's size, which helps to tell releases apart before
  /// one is picked.
  final bool showSizes;

  @override
  State<PlayerEpisodesList> createState() => _PlayerEpisodesListState();
}

class _PlayerEpisodesListState extends State<PlayerEpisodesList> {
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealCurrent(animate: false);
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentFileIndex != widget.currentFileIndex) {
      _revealCurrent(animate: true);
    }
  }

  void _revealCurrent({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = _currentKey.currentContext;
      if (!mounted || currentContext == null) return;
      Scrollable.ensureVisible(
        currentContext,
        alignment: 0.3,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = distinctEpisodeNames(widget.files);
    // Episode lists are short enough to build eagerly, which lets the
    // current item be scrolled to directly.
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (position, file) in widget.files.indexed) ...[
            if (position > 0) const SegmentedRule(),
            _EpisodeRow(
              key: file.index == widget.currentFileIndex ? _currentKey : null,
              file: file,
              number: file.number ?? position + 1,
              ownName: names[file.index],
              isCurrent: file.index == widget.currentFileIndex,
              progress: widget.progressByFile[file.index],
              showSize: widget.showSizes,
              onTap: () => widget.onSelected(file),
            ),
          ],
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.file,
    required this.number,
    required this.ownName,
    required this.isCurrent,
    required this.progress,
    required this.showSize,
    required this.onTap,
    super.key,
  });

  final PlayerVideoFile file;

  /// The episode number from the name, or the file's place in the torrent.
  final int number;

  /// The episode's own title, when the file name carries one.
  final String? ownName;
  final bool isCurrent;
  final WatchProgress? progress;
  final bool showSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final finished = progress?.isFinished ?? false;
    final fileName = fileDisplayName(file.name);
    final ownName = this.ownName;

    return Material(
      color: isCurrent ? scheme.surfaceContainer : Colors.transparent,
      child: InkWell(
        key: ValueKey('player_episode_${file.index}'),
        // The current file is already playing.
        onTap: isCurrent ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isCurrent
                        ? scheme.tertiary
                        : finished
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownName ?? fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: finished && !isCurrent
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    // An online episode has no file name to add.
                    if (ownName != null && file.title.isEmpty)
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.playerNowPlaying.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ] else if (progress != null) ...[
                      const SizedBox(height: 10),
                      WatchProgressLine(progress: progress),
                    ],
                  ],
                ),
              ),
              if (showSize) ...[
                const SizedBox(width: 16),
                Text(switch (file.duration) {
                  final duration? => l10n.playerEpisodeMinutes(
                    (duration.inSeconds / 60).round(),
                  ),
                  null => formatByteSize(l10n, file.size),
                }, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
