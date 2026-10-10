import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

String userRateStatusLabel(AppLocalizations l10n, UserRateStatus status) =>
    switch (status) {
      UserRateStatus.planned => l10n.userRateStatusPlanned,
      UserRateStatus.watching => l10n.userRateStatusWatching,
      UserRateStatus.rewatching => l10n.userRateStatusRewatching,
      UserRateStatus.completed => l10n.userRateStatusCompleted,
      UserRateStatus.onHold => l10n.userRateStatusOnHold,
      UserRateStatus.dropped => l10n.userRateStatusDropped,
    };
