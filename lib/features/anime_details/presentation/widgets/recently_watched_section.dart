import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_layout.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// Sources the user actually streamed from this anime's page, most recent
/// first. Nothing is matched by title: only playback started here counts.
class RecentlyWatchedSection extends StatelessWidget {
  const RecentlyWatchedSection({required this.animeId, super.key});

  static const maxSources = 3;

  final String animeId;

  @override
  Widget build(BuildContext context) {
    final recent = recentForAnime(
      context.watchWatchProgress(),
      animeId,
    ).take(maxSources).toList();
    final Widget child = recent.isEmpty
        ? const SizedBox.shrink(key: ValueKey('empty'))
        : Padding(
            key: const ValueKey('content'),
            padding: const EdgeInsets.only(top: 32),
            child: DetailSection(
              label: AppLocalizations.of(context).recentlyWatchedTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, progress) in recent.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _RecentSource(
                      progress: progress,
                      emphasizeResume: index == 0,
                    ),
                  ],
                ],
              ),
            ),
          );
    final switcher = DitherSwitcher(
      collapse: true,
      duration: const Duration(milliseconds: 240),
      child: child,
    );
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    if (duration == Duration.zero) return switcher;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}

class _RecentSource extends StatelessWidget {
  const _RecentSource({required this.progress, required this.emphasizeResume});

  final WatchProgress progress;
  final bool emphasizeResume;

  void _continue(BuildContext context) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs.resume(progress),
    );
  }

  /// Says what the button will do: a file only looked at starts from the
  /// beginning, a finished one leads to the next.
  String _actionLabel(AppLocalizations l10n) {
    if (progress.isFinished) return l10n.watchProgressPlayNextButton;
    if (progress.resumePosition == null) return l10n.watchProgressWatchButton;
    return l10n.watchProgressContinueButton;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = DetailLayout.isLargeText(context);
    final highlightResume =
        emphasizeResume &&
        !progress.isFinished &&
        progress.resumePosition != null;

    final progressWidget = AnimatedSwitcher(
      duration: motionDuration(context, const Duration(milliseconds: 180)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: progress.isFinished
          ? WatchProgressLine(
              key: const ValueKey('finished'),
              progress: progress,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: DetailLayout.sansFont,
              ),
            )
          : ConstrainedBox(
              key: const ValueKey('in_progress'),
              constraints: const BoxConstraints(
                maxWidth: WatchProgressLine.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SegmentedBar(
                      value: progress.fraction,
                      height: 4,
                      segment: 6,
                      trackColor: DetailLayout.progressTrackColor(scheme),
                    ),
                  ),
                  const SizedBox(height: 6),
                  MixedDataText(
                    l10n.watchProgressStoppedAt(
                      formatPlaybackPosition(progress.position),
                      formatPlaybackPosition(progress.duration),
                    ),
                    maxLines: largeText ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    sansStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                    ),
                    monoStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.monoFont,
                    ),
                  ),
                ],
              ),
            ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelSeparatedText(
          progress.sourceTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: DetailLayout.sansFont,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.watchProgressLastFile(fileDisplayName(progress.fileName)),
          maxLines: largeText ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: DetailLayout.sansFont,
          ),
        ),
        const SizedBox(height: 10),
        progressWidget,
      ],
    );

    final actionLabel = _actionLabel(l10n);
    final action = OutlinedButton(
      key: const Key('recently_watched_continue_button'),
      onPressed: () => _continue(context),
      style: highlightResume
          ? ButtonStyle(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? null
                    : BorderSide(color: scheme.tertiary, width: 1.5),
              ),
              backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
              foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
            )
          : null,
      child: AnimatedSwitcher(
        duration: motionDuration(context, const Duration(milliseconds: 180)),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: Text(actionLabel, key: ValueKey(actionLabel)),
      ),
    );

    return DecoratedBox(
      key: ValueKey('recently_watched_${progress.torrentKey}'),
      decoration: DetailLayout.cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (AnimeDetailsLayout.stackCardAction(
              context,
              constraints.maxWidth,
            )) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: action,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: details),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
