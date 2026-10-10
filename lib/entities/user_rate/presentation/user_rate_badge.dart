import 'package:flutter/material.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// The anime's place in the user's list as a small inverse plate laid on
/// the cover: the status, and how far along while it is being watched.
class UserRateBadge extends StatelessWidget {
  const UserRateBadge({
    required this.rate,
    required this.totalEpisodes,
    super.key,
  });

  final UserRate rate;

  /// 0 when unknown: then only the episodes watched show.
  final int totalEpisodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = userRateStatusLabel(l10n, rate.status).toUpperCase();
    final progress = userRateProgress(rate, totalEpisodes);
    final text = progress == null ? label : '$label $progress';
    return ColoredBox(
      color: scheme.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onInverseSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// `5/12` for an anime under way (just `5` while the total is unknown);
/// nothing before the first episode, or once the count says nothing new
/// (planned, completed).
String? userRateProgress(UserRate rate, int totalEpisodes) {
  final underWay = switch (rate.status) {
    UserRateStatus.watching ||
    UserRateStatus.rewatching ||
    UserRateStatus.onHold ||
    UserRateStatus.dropped => true,
    UserRateStatus.planned || UserRateStatus.completed => false,
  };
  if (!underWay || rate.episodes <= 0) return null;
  return totalEpisodes > 0
      ? '${rate.episodes}/$totalEpisodes'
      : '${rate.episodes}';
}
