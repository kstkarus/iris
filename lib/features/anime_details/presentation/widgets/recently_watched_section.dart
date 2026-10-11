import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// Sources the user actually streamed from this anime's page, most recent
/// first. Nothing is matched by title: only playback started here counts.
class RecentlyWatchedSection extends StatelessWidget {
  const RecentlyWatchedSection({
    required this.animeId,
    this.labelWidth,
    super.key,
  });

  static const maxSources = 3;

  final String animeId;

  /// Width of the label column; null puts the label above the rows.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final recent = recentForAnime(
      context.watchWatchProgress(),
      animeId,
    ).take(maxSources).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: AppLocalizations.of(context).recentlyWatchedTitle,
        labelWidth: labelWidth,
        // The description's measure: the action stays by its row
        // instead of at the far edge of a wide window.
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdaptiveContentWidth.reading,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, progress) in recent.indexed) ...[
                  if (index > 0) const SegmentedRule(),
                  _RecentSource(progress: progress, first: index == 0),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSource extends StatelessWidget {
  const _RecentSource({required this.progress, required this.first});

  final WatchProgress progress;

  /// The first row starts level with the section label.
  final bool first;

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
    return Padding(
      key: ValueKey('recently_watched_${progress.torrentKey}'),
      padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.sourceTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.watchProgressLastFile(
                    fileDisplayName(progress.fileName),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                WatchProgressLine(progress: progress),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            key: const Key('recently_watched_continue_button'),
            onPressed: () => _continue(context),
            child: Text(_actionLabel(l10n)),
          ),
        ],
      ),
    );
  }
}
