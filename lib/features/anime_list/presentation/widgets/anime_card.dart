import 'package:flutter/material.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/poster_image.dart';

/// A catalog title: the cover first, then the names and one short line of
/// facts. Airing titles carry the signal mark.
class AnimeCard extends StatelessWidget {
  const AnimeCard({required this.item, this.onTap, super.key});

  final AnimeListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final airing = item.status == 'ongoing';
    final year = yearOfIsoDate(item.airedOn);
    final facts = [
      formatAnimeKind(l10n, item.kind),
      if (airing)
        formatAnimeStatus(l10n, item.status)
      else if (year != null)
        '$year',
    ].join(' · ');
    final factStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );

    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PosterImage(url: item.posterMainUrl),
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (item.russian.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.russian,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (airing) ...[
                    SizedBox.square(
                      dimension: 6,
                      child: ColoredBox(color: scheme.tertiary),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      facts,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: factStyle,
                    ),
                  ),
                  if (item.score > 0)
                    Text(
                      formatAnimeScoreValue(l10n, item.score),
                      semanticsLabel: formatAnimeScore(l10n, item.score),
                      style: factStyle?.copyWith(color: scheme.onSurface),
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
