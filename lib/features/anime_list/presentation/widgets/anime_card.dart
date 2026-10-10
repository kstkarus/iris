import 'package:flutter/material.dart';

import 'package:iris/entities/user_rate/presentation/user_rate_badge.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/poster_image.dart';

/// A catalog title: the cover first, then the names and one short line of
/// facts. Airing titles carry the signal mark; one in the user's list
/// carries its status on the cover.
class AnimeCard extends StatelessWidget {
  const AnimeCard({required this.item, this.onTap, super.key});

  final AnimeListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final rate = context.watchUserRate(item.id, item.userRate);
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
              Stack(
                children: [
                  PosterImage(url: item.posterMainUrl),
                  if (rate != null)
                    PositionedDirectional(
                      start: 0,
                      bottom: 0,
                      end: 0,
                      child: Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: UserRateBadge(
                          rate: rate,
                          totalEpisodes: item.episodes,
                        ),
                      ),
                    ),
                ],
              ),
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
