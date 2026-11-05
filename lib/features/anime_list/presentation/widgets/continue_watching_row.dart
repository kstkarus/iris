import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Keep the same useful record, source grouping and five-title limit as before.
List<WatchProgress> continueWatchingItems(List<WatchProgress> history) {
  final seen = <String>{};
  return latestPerTorrent(history.where((item) => item.isWorthContinuing))
      .where(
        (item) =>
            seen.add(item.hasAnime ? 'anime:${item.animeId}' : item.torrentKey),
      )
      .take(ContinueWatchingRow.maxItems)
      .toList();
}

/// The compact contents shared by the catalog's popover and phone sheet.
class ContinueWatchingRow extends StatelessWidget {
  const ContinueWatchingRow({
    required this.items,
    required this.onOpen,
    required this.onOpenAnime,
    required this.onRemove,
    this.posters = const {},
    super.key,
  });

  static const maxItems = 5;
  final List<WatchProgress> items;
  final Map<String, String> posters;
  final ValueChanged<WatchProgress> onOpen;
  final ValueChanged<WatchProgress> onOpenAnime;
  final ValueChanged<WatchProgress> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final titleStyle = theme.textTheme.titleSmall;
    final painter = TextPainter(
      text: TextSpan(text: 'M\nM', style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final titleHeight = painter.height;
    painter.dispose();
    return Column(
      key: const Key('continue_watching_row'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.continueWatchingTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        for (final (index, progress) in items.indexed) ...[
          if (index > 0) const Divider(height: 1),
          Tooltip(
            message: progress.isFinished
                ? l10n.watchProgressPlayNextButton
                : l10n.watchProgressContinueButton,
            child: TapRow(
              inkKey: ValueKey('continue_watching_${progress.torrentKey}'),
              onTap: () => onOpen(progress),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 72,
                      child: PosterImage(
                        url: posters[progress.animeId] ?? '',
                        fallback: ColoredBox(
                          color: theme.colorScheme.surfaceContainer,
                          child: const Center(
                            child: PixelIcon(PixelGlyph.file, size: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: titleHeight,
                            child: Text(
                              progress.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          Text(
                            fileDisplayName(progress.fileName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          WatchProgressLine(
                            progress: progress,
                            showBar: false,
                            timesOnly: true,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<void>(
                      tooltip: l10n.commonMoreActions,
                      constraints: const BoxConstraints(minWidth: 160),
                      icon: const PixelIcon(PixelGlyph.more, size: 16),
                      itemBuilder: (_) => [
                        if (progress.hasAnime)
                          PopupMenuItem(
                            onTap: () => onOpenAnime(progress),
                            child: Text(l10n.downloadOpenAnime),
                          ),
                        PopupMenuItem(
                          onTap: () => onRemove(progress),
                          child: Text(l10n.continueWatchingRemove),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
