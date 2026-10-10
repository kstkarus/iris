import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_badge.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/anime_details/presentation/cubit/friend_rates_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

/// Friends who have the anime in their lists: who, the status, how far
/// along and the score. Nothing while they are read, or if none has it.
class FriendsSection extends StatelessWidget {
  const FriendsSection({
    required this.totalEpisodes,
    this.labelWidth,
    super.key,
  });

  /// The anime's episode count; 0 when Shikimori does not know it yet.
  final int totalEpisodes;

  /// Width of the label column; null puts the label above.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    // Pages built without friends (as in tests) show no section.
    final rates = context.watch<FriendRatesCubit?>()?.state ?? const [];
    if (rates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: AppLocalizations.of(context).animeDetailsFriendsTitle,
        labelWidth: labelWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, rate) in rates.indexed)
              _FriendRow(rate: rate, total: totalEpisodes, first: index == 0),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.rate,
    required this.total,
    required this.first,
  });

  static const _avatarSize = 32.0;

  final FriendRate rate;
  final int total;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = rate.rate;
    final facts = [
      userRateStatusLabel(l10n, entry.status),
      ?userRateProgress(entry, total),
      if (entry.score > 0) l10n.userRateScore(entry.score),
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 12),
      child: Row(
        children: [
          SquareAvatar(url: rate.friend.avatarUrl, size: _avatarSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate.friend.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  facts.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
