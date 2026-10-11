import 'package:flutter/material.dart';

import 'package:iris/entities/user_rate/presentation/user_rate_badge.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

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
    final anime = item.anime;
    final rate = context.watchUserRate(anime.id, item.userRate);
    final airing = anime.status == 'ongoing';
    final year = yearOfIsoDate(anime.airedOn);
    final facts = [
      formatAnimeKind(l10n, anime.kind),
      if (airing)
        formatAnimeStatus(l10n, anime.status)
      else if (year != null)
        '$year',
    ].join(' · ');
    final factStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );

    return TapRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                PosterImage(url: anime.posterUrl),
                if (rate != null)
                  PositionedDirectional(
                    start: 0,
                    bottom: 0,
                    end: 0,
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: UserRateBadge(
                        rate: rate,
                        totalEpisodes: anime.episodes,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              anime.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            if (anime.russian.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                anime.russian,
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
                if (anime.score > 0)
                  Text(
                    formatAnimeScoreValue(l10n, anime.score),
                    semanticsLabel: formatAnimeScore(l10n, anime.score),
                    style: factStyle?.copyWith(color: scheme.onSurface),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
