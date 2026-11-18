import 'package:flutter/material.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';

/// The anime's place in the user's list as a compact scrim plate laid on
/// the cover: the status, and how far along while it is being watched.
class UserRateBadge extends StatelessWidget {
  const UserRateBadge({
    required this.rate,
    required this.totalEpisodes,
    super.key,
  });

  static const _plateBackground = Color(0xDC0B0C0E);
  static const _plateBorder = Color(0x26FFFFFF);
  static const _plateText = Color(0xFFF2F2F0);
  static const _plateMutedText = Color(0xFFDAD9D4);

  final UserRate rate;

  /// 0 when unknown: then only the episodes watched show.
  final int totalEpisodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = userRateStatusLabel(l10n, rate.status);
    final progress = userRateProgress(rate, totalEpisodes);
    final text = progress == null ? label : '$label $progress';
    final isLive =
        rate.status == UserRateStatus.watching ||
        rate.status == UserRateStatus.rewatching;
    final textColor = isLive ? _plateText : _plateMutedText;
    final sansStyle = theme.textTheme.labelSmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 11.5,
      fontWeight: isLive ? FontWeight.w600 : FontWeight.w500,
      color: textColor,
      height: 1.15,
    );
    final monoStyle = DetailLayout.monoTelemetryStyle(
      theme.textTheme.labelSmall?.copyWith(fontSize: 11.5, height: 1.15),
      fontWeight: FontWeight.w500,
      color: textColor,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _plateBackground,
        border: Border(
          top: BorderSide(color: _plateBorder),
          right: BorderSide(color: _plateBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              Container(width: 5, height: 5, color: scheme.tertiaryFixed),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: MixedDataText(
                text,
                sansStyle: sansStyle,
                monoStyle: monoStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
