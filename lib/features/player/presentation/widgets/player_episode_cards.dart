import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/widgets/player_immersive_controls.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The torrent's files as cards for the immersive player's drawer: the
/// episode, its own name when the file has one, and how much is left. The
/// playing card is tinted and scrolled into view.
class PlayerEpisodeCards extends StatefulWidget {
  const PlayerEpisodeCards({
    required this.files,
    required this.currentFileIndex,
    required this.progressByFile,
    required this.onSelected,
    super.key,
  });

  final List<PlayerVideoFile> files;
  final int currentFileIndex;
  final Map<int, WatchProgress> progressByFile;
  final ValueChanged<PlayerVideoFile> onSelected;

  @override
  State<PlayerEpisodeCards> createState() => _PlayerEpisodeCardsState();
}

class _PlayerEpisodeCardsState extends State<PlayerEpisodeCards> {
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = _currentKey.currentContext;
      if (!mounted || currentContext == null) return;
      Scrollable.ensureVisible(currentContext, alignment: 0.3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = distinctEpisodeNames(widget.files);
    // Short enough to build eagerly, so the current card can be revealed.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (position, file) in widget.files.indexed)
            _EpisodeCard(
              key: file.index == widget.currentFileIndex ? _currentKey : null,
              file: file,
              position: position + 1,
              name: names[file.index],
              isCurrent: file.index == widget.currentFileIndex,
              progress: widget.progressByFile[file.index],
              onTap: () => widget.onSelected(file),
            ),
        ],
      ),
    );
  }
}

final _bracketGroups = RegExp(r'\[[^\]]*\]|\([^)]*\)');
final _leadingNumber = RegExp(r'^[\s\d._\-–—:#]+');
final _trailingSeparators = RegExp(r'[\s._\-–—:#]+$');
final _letter = RegExp(r'\p{L}', unicode: true);

/// Each file's own episode name, where its name says more than the series
/// and the number every file shares: `Frieren - 11 - The Hero's Party`
/// gives `The Hero's Party`, `Death Note 19` gives nothing.
Map<int, String> distinctEpisodeNames(List<PlayerVideoFile> files) {
  if (files.length < 2) return const {};
  final names = [
    for (final file in files)
      fileDisplayName(
        file.name,
      ).replaceAll(_bracketGroups, ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  final prefix = _commonPrefixLength(names);
  final suffix = _commonSuffixLength(names, prefix);
  return {
    for (final (position, file) in files.indexed)
      file.index: ?_ownName(names[position], prefix, suffix),
  };
}

String? _ownName(String name, int prefix, int suffix) {
  final end = name.length - suffix;
  if (end <= prefix) return null;
  final own = name
      .substring(prefix, end)
      .replaceFirst(_leadingNumber, '')
      .replaceFirst(_trailingSeparators, '')
      .trim();
  return _letter.hasMatch(own) ? own : null;
}

int _commonPrefixLength(List<String> names) {
  var length = names.first.length;
  for (final name in names.skip(1)) {
    var common = 0;
    while (common < length &&
        common < name.length &&
        name.codeUnitAt(common) == names.first.codeUnitAt(common)) {
      common++;
    }
    length = common;
  }
  return length;
}

/// The common ending, not overlapping the common start.
int _commonSuffixLength(List<String> names, int prefix) {
  final first = names.first;
  var length = first.length - prefix;
  for (final name in names) {
    length = length.clamp(0, name.length - prefix);
    var common = 0;
    while (common < length &&
        name.codeUnitAt(name.length - 1 - common) ==
            first.codeUnitAt(first.length - 1 - common)) {
      common++;
    }
    length = common;
  }
  return length;
}

class _EpisodeCard extends StatefulWidget {
  const _EpisodeCard({
    required this.file,
    required this.position,
    required this.name,
    required this.isCurrent,
    required this.progress,
    required this.onTap,
    super.key,
  });

  final PlayerVideoFile file;

  /// Place in the torrent, shown when the name has no episode number.
  final int position;

  /// The episode's own name, when the file has one.
  final String? name;
  final bool isCurrent;
  final WatchProgress? progress;
  final VoidCallback onTap;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  static const _minHeight = 72.0;

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = playerAccentColor(theme.colorScheme);
    final file = widget.file;
    final progress = widget.progress;
    final episode = episodeNumberFromFileName(file.name);
    final finished = progress?.isFinished ?? false;
    final partial =
        !finished && progress != null && progress.duration > Duration.zero;
    final name = widget.name;

    final Color background;
    if (widget.isCurrent) {
      background = accent.withAlpha(46);
    } else if (_hovered) {
      background = Colors.white12;
    } else {
      background = const Color(0x0DFFFFFF);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: widget.isCurrent ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: ValueKey('player_episode_card_${file.index}'),
          // The current file is already playing.
          onTap: widget.isCurrent ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: _minHeight),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${episode ?? widget.position}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: widget.isCurrent
                              ? Colors.white
                              : Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode == null
                                ? fileDisplayName(file.name)
                                : l10n.playerEpisodeNumber(episode),
                            maxLines: episode == null ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (name != null && episode != null)
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Status(
                      isCurrent: widget.isCurrent,
                      finished: finished,
                      left: partial
                          ? progress.duration - progress.position
                          : null,
                      accent: accent,
                    ),
                  ],
                ),
                if (partial) ...[
                  const SizedBox(height: 10),
                  SegmentedBar(
                    value: progress.fraction,
                    height: 3,
                    segment: 6,
                    color: accent,
                    trackColor: Colors.white24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Now playing, watched, or the time left, at the end of the card's row.
class _Status extends StatelessWidget {
  const _Status({
    required this.isCurrent,
    required this.finished,
    required this.left,
    required this.accent,
  });

  final bool isCurrent;
  final bool finished;
  final Duration? left;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final left = this.left;
    // "Now playing" says it in words; the signal colour marks it live.
    if (isCurrent) {
      return Text(
        l10n.playerNowPlaying.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: accent),
      );
    }
    // Watched is done, not live: a quiet check, not the signal colour.
    if (finished) {
      return PixelIcon(
        PixelGlyph.check,
        size: 18,
        color: Colors.white70,
        semanticLabel: l10n.watchProgressWatched,
      );
    }
    if (left != null) {
      return Text(
        l10n.playerTimeLeft(formatPlaybackPosition(left)),
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
      );
    }
    return const SizedBox.shrink();
  }
}
