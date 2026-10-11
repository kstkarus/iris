import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';
import 'package:iris/features/player/presentation/widgets/reveal_after_layout.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/caption_text.dart';
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
    revealAfterLayout(_currentKey);
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
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = playerAccentColor(theme.colorScheme);
    final file = widget.file;
    final progress = widget.progress;
    final episode = file.number;
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
      child: FocusableActionDetector(
        // The current file is already playing: Tab passes it by.
        enabled: !widget.isCurrent,
        mouseCursor: widget.isCurrent
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        // Only keyboard focus, as in the downloads list.
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        // Space here picks the card instead of pausing the player.
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          key: ValueKey('player_episode_card_${file.index}'),
          onTap: widget.isCurrent ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: _minHeight),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(color: background),
            // Keyboard focus as an outline: a fill this faint would not show.
            foregroundDecoration: BoxDecoration(
              border: _focused
                  ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                  : null,
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
                                ? file.displayName
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
      return CaptionText(l10n.playerNowPlaying, color: accent);
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
