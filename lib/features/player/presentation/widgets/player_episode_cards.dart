import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';
import 'package:iris/features/player/presentation/widgets/episode_list_scroll_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The torrent's files as cards for the immersive player's drawer: the
/// episode, its own name when the file has one, and how much is left. The
/// playing card is tinted and scrolled into view.
class PlayerEpisodeCards extends StatelessWidget {
  const PlayerEpisodeCards({
    required this.files,
    required this.currentFileIndex,
    required this.progressByFile,
    required this.onSelected,
    this.listed = const {},
    super.key,
  });

  final List<PlayerVideoFile> files;
  final int currentFileIndex;
  final Map<int, WatchProgress> progressByFile;

  /// Files the user's Shikimori list counts as watched, by index; a file
  /// with progress here shows that instead.
  final Set<int> listed;
  final ValueChanged<PlayerVideoFile> onSelected;

  @override
  Widget build(BuildContext context) {
    final names = distinctEpisodeNames(files);
    return EpisodeListScrollView(
      targetIndex: files.indexWhere((file) => file.index == currentFileIndex),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: files.length,
      itemBuilder: (context, position) {
        final file = files[position];
        final card = _EpisodeCard(
          file: file,
          position: position + 1,
          name: names[file.index],
          isCurrent: file.index == currentFileIndex,
          progress: progressByFile[file.index],
          listed: listed.contains(file.index),
          onTap: () => onSelected(file),
        );
        return position == files.length - 1
            ? card
            : Column(
                children: [
                  card,
                  const Divider(height: 1, thickness: 1, color: Colors.white10),
                ],
              );
      },
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
    required this.listed,
    required this.onTap,
  });

  final PlayerVideoFile file;

  /// Place in the torrent, shown when the name has no episode number.
  final int position;

  /// The episode's own name, when the file has one.
  final String? name;
  final bool isCurrent;
  final WatchProgress? progress;

  /// Counted as watched in the user's Shikimori list.
  final bool listed;
  final VoidCallback onTap;

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  static const _minHeight = 48.0;

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
    final finished = progress?.isFinished ?? widget.listed;
    final partial =
        !finished && progress != null && progress.duration > Duration.zero;
    final numberText = episodeNumberLabel(file, widget.position - 1);
    final name = widget.name;
    final titleText = name != null && name.isNotEmpty
        ? name
        : episode == null
        ? file.displayName
        : l10n.playerEpisodeNumber(episode);

    final Color background;
    if (widget.isCurrent) {
      background = accent.withAlpha(26);
    } else if (_hovered) {
      background = Colors.white12;
    } else {
      background = Colors.transparent;
    }

    return FocusableActionDetector(
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
          decoration: BoxDecoration(color: background),
          // Keyboard focus as an outline: a fill this faint would not show.
          foregroundDecoration: BoxDecoration(
            border: _focused
                ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              if (partial)
                Positioned.fill(
                  key: ValueKey('player_episode_progress_${file.index}'),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.fraction,
                    heightFactor: 1,
                    child: DecoratedBox(
                      key: ValueKey(
                        'player_episode_progress_fill_${file.index}',
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(15),
                        border: Border(
                          right: BorderSide(color: Colors.white.withAlpha(42)),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        numberText,
                        style: DetailLayout.monoTelemetryStyle(
                          const TextStyle(fontSize: 13.5),
                          fontWeight: widget.isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: widget.isCurrent
                              ? accent
                              : finished
                              ? Colors.white38
                              : Colors.white60,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        titleText,
                        maxLines: episode == null ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontSize: 14.5,
                          fontWeight: widget.isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.isCurrent
                              ? playerPlateText
                              : finished
                              ? Colors.white54
                              : Colors.white,
                        ),
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
              ),
              if (widget.isCurrent)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Now playing, watched, or the time left, at the end of the row.
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
    final left = this.left;
    // "Now playing" says it in words; the signal colour marks it live.
    if (isCurrent) {
      return Text(
        l10n.playerNowPlaying,
        style: TextStyle(
          fontFamily: DetailLayout.sansFont,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      );
    }
    // Watched is done, not live: a quiet check, not the signal colour.
    if (finished) {
      return PixelIcon(
        PixelGlyph.check,
        size: 15,
        color: Colors.white38,
        semanticLabel: l10n.watchProgressWatched,
      );
    }
    if (left != null) {
      final time = formatPlaybackPosition(left);
      return Text(
        '\u2212$time',
        semanticsLabel: l10n.playerTimeLeft(time),
        style: DetailLayout.monoTelemetryStyle(
          const TextStyle(fontSize: 12.5),
          color: Colors.white60,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
