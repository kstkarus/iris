import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/widgets/reveal_after_layout.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/caption_text.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
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
    this.listed = const {},
    this.padding = EdgeInsets.zero,
    this.showSizes = false,
    super.key,
  });

  final List<PlayerVideoFile> files;

  /// The playing file; null when nothing plays yet (the file picker).
  final int? currentFileIndex;
  final Map<int, WatchProgress> progressByFile;

  /// Files the user's Shikimori list counts as watched, by index; a file
  /// with progress here shows that instead.
  final Set<int> listed;
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
    revealAfterLayout(
      _currentKey,
      duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
    );
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
              number: episodeNumberLabel(file, position),
              ownName: names[file.index],
              isCurrent: file.index == widget.currentFileIndex,
              progress: widget.progressByFile[file.index],
              listed: widget.listed.contains(file.index),
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
    required this.listed,
    required this.showSize,
    required this.onTap,
    super.key,
  });

  final PlayerVideoFile file;

  /// The episode number from the source or the name, or the file's place
  /// in the torrent, as shown: "04", "12.5".
  final String number;

  /// The episode's own title, when the file name carries one.
  final String? ownName;
  final bool isCurrent;
  final WatchProgress? progress;

  /// Counted as watched in the user's Shikimori list.
  final bool listed;
  final bool showSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final finished = progress?.isFinished ?? listed;
    // Progress short of the end is worth its own line; done is a mark.
    final partial = progress != null && !progress.isFinished;
    final fileName = fileDisplayName(file.name);
    final ownName = this.ownName;
    final name = ownName ?? fileName;
    final showName = !nameIsJustNumber(name, number);
    final size = showSize ? _sizeLabel(l10n) : null;

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
                  number,
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
                    if (showName)
                      Text(
                        name,
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
                      if (showName) const SizedBox(height: 6),
                      CaptionText(
                        l10n.playerNowPlaying,
                        color: scheme.tertiary,
                      ),
                    ] else if (partial) ...[
                      if (showName) const SizedBox(height: 10),
                      WatchProgressLine(progress: progress),
                    ],
                  ],
                ),
              ),
              if (finished && !isCurrent) ...[
                const SizedBox(width: 16),
                Padding(
                  // Level with the size's first line.
                  padding: const EdgeInsets.only(top: 1),
                  child: PixelIcon(
                    PixelGlyph.check,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                    semanticLabel: l10n.watchProgressWatched,
                  ),
                ),
              ],
              if (size != null) ...[
                SizedBox(width: finished && !isCurrent ? 8 : 16),
                Text(size, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The episode's length, or the file's size; nothing for an online
  /// episode the source gave no length for.
  String? _sizeLabel(AppLocalizations l10n) {
    final duration = file.duration;
    if (duration != null) {
      return l10n.playerEpisodeMinutes((duration.inSeconds / 60).round());
    }
    return file.size > 0 ? formatByteSize(l10n, file.size) : null;
  }
}
