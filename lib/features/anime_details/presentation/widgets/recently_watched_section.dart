import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';

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
    if (recent.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).recentlyWatchedTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final progress in recent) ...[
            _RecentSourceCard(progress: progress),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RecentSourceCard extends StatelessWidget {
  const _RecentSourceCard({required this.progress});

  final WatchProgress progress;

  void _continue(BuildContext context) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: progress.animeId,
        animeTitle: progress.animeTitle,
        sourceTitle: progress.sourceTitle,
        magnet: progress.magnet,
        // A finished file opens the picker, which offers the next one.
        autoOpenFileIndex: progress.isFinished ? null : progress.fileIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('recently_watched_${progress.torrentKey}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress.sourceTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.watchProgressLastFile(fileDisplayName(progress.fileName)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            WatchProgressLine(progress: progress),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: const Key('recently_watched_continue_button'),
                onPressed: () => _continue(context),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.watchProgressContinueButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
