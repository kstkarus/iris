import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_badge.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/anime_details/presentation/cubit/friend_rates_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_layout.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

/// Friends who have the anime in their lists: who, the status, how far
/// along and the score. Nothing while they are read, or if none has it.
class FriendsSection extends StatelessWidget {
  const FriendsSection({required this.totalEpisodes, super.key});

  /// The anime's episode count; 0 when Shikimori does not know it yet.
  final int totalEpisodes;

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<FriendRatesCubit?>()?.state ?? const [];
    final Widget child = rates.isEmpty
        ? const SizedBox.shrink(key: ValueKey('empty'))
        : Padding(
            key: const ValueKey('content'),
            padding: const EdgeInsets.only(top: 32),
            child: DetailSection(
              label: AppLocalizations.of(context).animeDetailsFriendsTitle,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = AnimeDetailsLayout.useFriendGrid(
                    context,
                    constraints.maxWidth,
                  );
                  if (!twoColumns) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, rate) in rates.indexed) ...[
                          if (index > 0) const SizedBox(height: 8),
                          _FriendCard(rate: rate, total: totalEpisodes),
                        ],
                      ],
                    );
                  }
                  const gap = 10.0;
                  final itemWidth = (constraints.maxWidth - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final rate in rates)
                        SizedBox(
                          width: itemWidth,
                          child: _FriendCard(rate: rate, total: totalEpisodes),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
    return DitherSwitcher(
      collapse: true,
      duration: const Duration(milliseconds: 240),
      resizeDuration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.rate, required this.total});

  static const _avatarSize = 38.0;

  final FriendRate rate;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final entry = rate.rate;
    final isLive =
        entry.status == UserRateStatus.watching ||
        entry.status == UserRateStatus.rewatching;
    final facts = [
      userRateStatusLabel(l10n, entry.status),
      ?userRateProgress(entry, total),
      if (entry.score > 0) l10n.userRateScore(entry.score),
    ];

    return DecoratedBox(
      decoration: DetailLayout.cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SquareAvatar(url: rate.friend.avatarUrl, size: _avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isLive)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          color: scheme.tertiary,
                        ),
                      Expanded(
                        child: Text(
                          rate.friend.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: DetailLayout.sansFont,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  PixelSeparatedText.parts(
                    facts,
                    sansStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      color: scheme.onSurfaceVariant,
                    ),
                    monoStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.monoFont,
                      color: scheme.onSurfaceVariant,
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
