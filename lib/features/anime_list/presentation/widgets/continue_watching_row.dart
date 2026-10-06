import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';

/// The latest file of each recently watched torrent, from the catalog and
/// from saved torrents alike.
List<WatchProgress> continueWatchingItems(List<WatchProgress> history) {
  return latestPerTorrent(history).take(ContinueWatchingRow.maxItems).toList();
}

class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({required this.items, super.key});

  static const maxItems = 10;
  static const _cardWidth = 280.0;
  static const _height = 156.0;

  final List<WatchProgress> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('continue_watching_row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).continueWatchingTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: _cardWidth,
              child: _ContinueCard(progress: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.progress});

  final WatchProgress progress;

  void _open(BuildContext context) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: progress.animeId,
        animeTitle: progress.displayTitle,
        sourceTitle: progress.sourceTitle,
        magnet: progress.magnet,
        // A finished file opens the picker, which offers the next one.
        autoOpenFileIndex: progress.isFinished ? null : progress.fileIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      key: ValueKey('continue_watching_${progress.torrentKey}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        progress.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<void>(
                    tooltip: l10n.savedTorrentsMoreTooltip,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: () => context
                            .read<WatchProgressCubit>()
                            .removeTorrent(progress.torrentKey),
                        child: Text(l10n.continueWatchingRemove),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileDisplayName(progress.fileName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    WatchProgressLine(progress: progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
