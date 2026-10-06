import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';

/// The torrent's video files with watch progress; the playing one stays
/// highlighted and scrolled into view so the list and the player read as
/// one place.
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
    // Episode lists are short enough to build eagerly, which lets the
    // current item be scrolled to directly.
    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final file in widget.files)
            _EpisodeTile(
              key: file.index == widget.currentFileIndex ? _currentKey : null,
              file: file,
              isCurrent: file.index == widget.currentFileIndex,
              progress: widget.progressByFile[file.index],
              showSize: widget.showSizes,
              onTap: () => widget.onSelected(file),
            ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.file,
    required this.isCurrent,
    required this.progress,
    required this.showSize,
    required this.onTap,
    super.key,
  });

  final PlayerVideoFile file;
  final bool isCurrent;
  final WatchProgress? progress;
  final bool showSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = this.progress;
    final Widget? subtitle = isCurrent
        ? Text(l10n.playerNowPlaying)
        : progress == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: WatchProgressLine(progress: progress),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        key: ValueKey('player_episode_${file.index}'),
        selected: isCurrent,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        selectedColor: theme.colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          isCurrent
              ? Icons.play_arrow
              : progress?.isFinished == true
              ? Icons.check_circle_outline
              : Icons.movie_outlined,
        ),
        title: Text(
          fileDisplayName(file.name),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle,
        trailing: showSize
            ? Text(
                formatByteSize(file.size),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        // The current file is already playing.
        onTap: isCurrent ? null : onTap,
      ),
    );
  }
}
