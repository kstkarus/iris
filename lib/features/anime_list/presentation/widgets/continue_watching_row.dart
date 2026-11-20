import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// The newest useful record per title or unlinked source, when not hidden.
List<WatchProgress> continueWatchingItems(List<WatchProgress> history) {
  final sorted = history.where((item) => item.isWorthContinuing).toList()
    ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  final seen = <String>{};
  return [
    for (final item in sorted)
      if (seen.add(item.continueWatchingKey) &&
          !item.hiddenFromContinueWatching)
        item,
  ].take(ContinueWatchingRow.maxItems).toList();
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
        DitherList<WatchProgress>.column(
          items: items,
          keyOf: (item) => item.continueWatchingKey,
          separator: const Divider(height: 1),
          removalDuration: const Duration(milliseconds: 280),
          itemBuilder: (context, item) => _ProgressEntryRow(
            progress: item,
            posterUrl: posters[item.animeId] ?? '',
            titleHeight: titleHeight,
            titleStyle: titleStyle,
            onOpen: onOpen,
            onOpenAnime: onOpenAnime,
            onRemove: onRemove,
          ),
        ),
      ],
    );
  }
}

class _ProgressEntryRow extends StatelessWidget {
  const _ProgressEntryRow({
    required this.progress,
    required this.posterUrl,
    required this.titleHeight,
    required this.titleStyle,
    required this.onOpen,
    required this.onOpenAnime,
    required this.onRemove,
  });

  final WatchProgress progress;
  final String posterUrl;
  final double titleHeight;
  final TextStyle? titleStyle;
  final ValueChanged<WatchProgress> onOpen;
  final ValueChanged<WatchProgress> onOpenAnime;
  final ValueChanged<WatchProgress> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: progress.isFinished
          ? l10n.watchProgressPlayNextButton
          : l10n.watchProgressContinueButton,
      child: TapRow(
        inkKey: ValueKey('continue_watching_${progress.continueWatchingKey}'),
        onTap: () => onOpen(progress),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 72,
                child: PosterImage(
                  url: posterUrl,
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
    );
  }
}
