import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The anime's place in the signed-in user's Shikimori list: its status,
/// and the episodes watched once it is in the list. Signed out, nothing.
class MyListSection extends StatelessWidget {
  const MyListSection({
    required this.totalEpisodes,
    this.labelWidth,
    super.key,
  });

  static const statusButtonKey = Key('my_list_status_button');
  static const scoreButtonKey = Key('my_list_score_button');
  static const episodeMoreKey = Key('my_list_episode_more');
  static const episodeLessKey = Key('my_list_episode_less');

  /// The anime's episode count; 0 when Shikimori does not know it yet.
  final int totalEpisodes;

  /// Width of the label column; null puts the label above.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Pages built without the list (as in tests) show no section.
    final state =
        context.watch<UserRateCubit?>()?.state ?? const UserRateSignedOut();
    final Widget content;
    switch (state) {
      case UserRateSignedOut():
        return const SizedBox.shrink();
      case UserRateLoading():
        content = const Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: 80, child: BlockSpinner()),
        );
      case UserRateLoadFailure():
        content = Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.userRateLoadError),
            TextButton(
              onPressed: context.read<UserRateCubit>().load,
              child: Text(l10n.commonRetry),
            ),
          ],
        );
      case UserRateLoaded():
        content = _Controls(state: state, total: totalEpisodes);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: l10n.userRateTitle,
        labelWidth: labelWidth,
        child: content,
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.total});

  final UserRateLoaded state;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = state.rate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusMenu(rate: rate, saving: state.saving),
            if (rate != null) _EpisodeStepper(rate: rate, total: total),
            _ScoreMenu(score: rate?.score ?? 0),
          ],
        ),
        if (state.saveFailed) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).userRateSaveError,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The current status, or an invitation to add; the menu picks a status
/// or takes the anime out of the list.
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.rate, required this.saving});

  final UserRate? rate;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<UserRateCubit>();
    final rate = this.rate;
    return MenuAnchor(
      menuChildren: [
        for (final status in UserRateStatus.values)
          MenuItemButton(
            onPressed: status == rate?.status
                ? null
                : () => cubit.setStatus(status),
            leadingIcon: SizedBox.square(
              dimension: 14,
              child: status == rate?.status
                  ? const PixelIcon(PixelGlyph.check, size: 14)
                  : null,
            ),
            child: Text(userRateStatusLabel(l10n, status)),
          ),
        if (rate != null)
          MenuItemButton(
            onPressed: saving ? null : cubit.remove,
            leadingIcon: const SizedBox.square(dimension: 14),
            child: Text(l10n.userRateRemove),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton(
        key: MyListSection.statusButtonKey,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Text(
          rate == null
              ? l10n.userRateAdd
              : userRateStatusLabel(l10n, rate.status),
        ),
      ),
    );
  }
}

/// The score as a menu of 10 down to 1, and a way to clear it.
class _ScoreMenu extends StatelessWidget {
  const _ScoreMenu({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<UserRateCubit>();
    return MenuAnchor(
      menuChildren: [
        for (var value = UserRate.maxScore; value > 0; value--)
          MenuItemButton(
            onPressed: value == score ? null : () => cubit.setScore(value),
            leadingIcon: SizedBox.square(
              dimension: 14,
              child: value == score
                  ? const PixelIcon(PixelGlyph.check, size: 14)
                  : null,
            ),
            child: Text('$value'),
          ),
        if (score > 0)
          MenuItemButton(
            onPressed: () => cubit.setScore(0),
            leadingIcon: const SizedBox.square(dimension: 14),
            child: Text(l10n.userRateNoScore),
          ),
      ],
      builder: (context, controller, _) => TextButton(
        key: MyListSection.scoreButtonKey,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Text(score > 0 ? l10n.userRateScore(score) : l10n.userRateRate),
      ),
    );
  }
}

/// `− 3 / 12 +`: the episodes watched, a step at a time.
class _EpisodeStepper extends StatelessWidget {
  const _EpisodeStepper({required this.rate, required this.total});

  final UserRate rate;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(l10n.localeName);
    final cubit = context.read<UserRateCubit>();
    final watched = numbers.format(rate.episodes);
    final shown = total > 0 ? '$watched / ${numbers.format(total)}' : watched;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: MyListSection.episodeLessKey,
          tooltip: l10n.userRateEpisodeLess,
          onPressed: rate.episodes > 0
              ? () => cubit.stepEpisodes(-1, total: total)
              : null,
          icon: const PixelIcon(PixelGlyph.minus, size: 14),
        ),
        Semantics(
          label: l10n.userRateEpisodesWatched(shown),
          child: ExcludeSemantics(
            child: Text(
              shown,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        IconButton(
          key: MyListSection.episodeMoreKey,
          tooltip: l10n.userRateEpisodeMore,
          onPressed: total <= 0 || rate.episodes < total
              ? () => cubit.stepEpisodes(1, total: total)
              : null,
          icon: const PixelIcon(PixelGlyph.plus, size: 14),
        ),
      ],
    );
  }
}
