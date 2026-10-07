import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The latest file of each recently watched torrent, from the catalog and
/// from saved torrents alike.
List<WatchProgress> continueWatchingItems(List<WatchProgress> history) {
  return latestPerTorrent(history).take(ContinueWatchingRow.maxItems).toList();
}

/// The most recent title large, with where it stopped on a position
/// panel; the next few below it as numbered rows.
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({required this.items, super.key});

  static const maxItems = 5;

  /// From here the title and the position panel sit side by side.
  static const _twoColumnMinWidth = 840.0;

  final List<WatchProgress> items;

  @override
  Widget build(BuildContext context) {
    final latest = items.first;
    return Column(
      key: const Key('continue_watching_row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(AppLocalizations.of(context).continueWatchingTitle),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumnMinWidth;
            final title = _LatestTitle(progress: latest, wide: wide);
            final panel = _PositionPanel(progress: latest, compact: !wide);
            return KeyedSubtree(
              key: ValueKey('continue_watching_${latest.torrentKey}'),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: title),
                        const SizedBox(width: 40),
                        Expanded(flex: 5, child: panel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 20), panel],
                    ),
            );
          },
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 24),
          for (final (index, progress) in items.skip(1).indexed) ...[
            const SegmentedRule(),
            _QueuedRow(number: index + 2, progress: progress),
          ],
        ],
      ],
    );
  }
}

void _open(BuildContext context, WatchProgress progress) {
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

class _LatestTitle extends StatelessWidget {
  const _LatestTitle({required this.progress, required this.wide});

  final WatchProgress progress;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DisplayTitle(
          progress.displayTitle,
          maxSize: wide ? 80 : 30,
          minSize: wide ? 36 : 26,
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        Text(
          fileDisplayName(progress.fileName),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Where the latest file stopped, set like a readout: the position in
/// large figures over a block bar that fades out where the file goes on.
class _PositionPanel extends StatelessWidget {
  const _PositionPanel({required this.progress, required this.compact});

  final WatchProgress progress;

  /// Phones get a smaller readout, so the catalog still shows below it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = progress.isFinished;
    final shown = finished ? progress.duration : progress.position;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (finished
                            ? l10n.continueWatchingFinishedLabel
                            : l10n.continueWatchingStoppedAtLabel)
                        .toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _RemoveMenu(progress: progress),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: formatPlaybackPosition(shown)),
                        TextSpan(
                          text:
                              ' / ${formatPlaybackPosition(progress.duration)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    style:
                        DisplayTitle.styleAt(
                          theme.textTheme.displayMedium!,
                          compact ? 36 : 48,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: 14),
                  ExcludeSemantics(
                    child: SegmentedBar(
                      value: finished ? 1 : progress.fraction,
                      height: compact ? 12 : 18,
                      segment: compact ? 14 : 20,
                      gap: 4,
                      ditherTrack: true,
                      animateIn: true,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 20),
                  FilledButton(
                    onPressed: () => _open(context, progress),
                    child: Text(
                      finished
                          ? l10n.watchProgressPlayNextButton
                          : l10n.watchProgressContinueButton,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedRow extends StatelessWidget {
  const _QueuedRow({required this.number, required this.progress});

  final int number;
  final WatchProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('continue_watching_${progress.torrentKey}'),
        onTap: () => _open(context, progress),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final names = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileDisplayName(progress.fileName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (!wide) ...[
                    const SizedBox(height: 6),
                    WatchProgressLine(progress: progress, showBar: false),
                  ],
                ],
              );
              return Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      number.toString().padLeft(2, '0'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: names),
                  if (wide) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 300,
                      child: WatchProgressLine(
                        progress: progress,
                        showBar: false,
                      ),
                    ),
                  ],
                  _RemoveMenu(progress: progress),
                  if (wide)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, right: 8),
                      child: PixelIcon(PixelGlyph.arrowRight, size: 16),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoveMenu extends StatelessWidget {
  const _RemoveMenu({required this.progress});

  final WatchProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<void>(
      tooltip: l10n.savedTorrentsMoreTooltip,
      icon: const PixelIcon(PixelGlyph.more, size: 18),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => context.read<WatchProgressCubit>().removeTorrent(
            progress.torrentKey,
          ),
          child: Text(l10n.continueWatchingRemove),
        ),
      ],
    );
  }
}
