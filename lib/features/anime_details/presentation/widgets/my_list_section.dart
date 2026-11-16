import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The anime's place in the signed-in user's Shikimori list: grouped into
/// status/score menu rows above a paired episode counter and split stepper.
/// Signed out, nothing.
class MyListSection extends StatelessWidget {
  const MyListSection({required this.totalEpisodes, super.key});

  static const statusButtonKey = Key('my_list_status_button');
  static const scoreButtonKey = Key('my_list_score_button');
  static const episodeMoreKey = Key('my_list_episode_more');
  static const episodeLessKey = Key('my_list_episode_less');

  /// The anime's episode count; 0 when Shikimori does not know it yet.
  final int totalEpisodes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state =
        context.watch<UserRateCubit?>()?.state ?? const UserRateSignedOut();
    final Widget content;
    switch (state) {
      case UserRateSignedOut():
        return const SizedBox.shrink();
      case UserRateLoading():
        content = AppSkeleton(
          enabled: true,
          semanticLabel: l10n.userRateLoading,
          child: const _StandInControls(),
        );
      case UserRateLoadFailure():
        content = Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.userRateLoadError),
              TextButton(
                onPressed: context.read<UserRateCubit>().load,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        );
      case UserRateLoaded():
        content = AppSkeleton(
          enabled: false,
          child: _Controls(state: state, total: totalEpisodes),
        );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: DetailSection(
        label: l10n.userRateTitle,
        child: Container(
          color: scheme.surfaceContainerLow,
          foregroundDecoration: DetailLayout.cardDecoration(
            scheme,
            background: Colors.transparent,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Stand-in grouped picker row matching the loaded container geometry.
class _StandInControls extends StatelessWidget {
  const _StandInControls();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PickerBand(
      left: _PickerCell(
        onTap: null,
        leading: const Skeleton.keep(
          child: PixelIcon(PixelGlyph.plus, size: 10),
        ),
        label: l10n.userRateAdd,
      ),
      right: _PickerCell(onTap: null, label: l10n.userRateRate),
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
    final scheme = theme.colorScheme;
    final ruleColor = DetailLayout.ruleColor(scheme);
    final rate = state.rate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerBand(
          left: _StatusMenu(rate: rate, saving: state.saving),
          right: _ScoreMenu(score: rate?.score ?? 0),
        ),
        if (rate != null) ...[
          Divider(height: 1, thickness: 1, color: ruleColor),
          _ProgressBand(rate: rate, total: total),
        ],
        if (state.saveFailed) ...[
          Divider(height: 1, thickness: 1, color: ruleColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              AppLocalizations.of(context).userRateSaveError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hairline-divided band holding the status and score menu triggers. Stacks on
/// narrow widths or large text scales so long status labels never wrap tightly.
class _PickerBand extends StatelessWidget {
  const _PickerBand({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ruleColor = DetailLayout.ruleColor(Theme.of(context).colorScheme);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            DetailLayout.isLargeText(context) || constraints.maxWidth < 330;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              Divider(height: 1, thickness: 1, color: ruleColor),
              right,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              VerticalDivider(width: 1, thickness: 1, color: ruleColor),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

/// Interactive grouped-form cell with full-area hit target and menu chevron.
class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.onTap,
    required this.label,
    this.leading,
    this.emphasize = false,
    this.highlighted = false,
    this.isData = false,
    this.cellKey,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget? leading;
  final bool emphasize;
  final bool highlighted;
  final bool isData;
  final Key? cellKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sansStyle = theme.textTheme.titleSmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
    );
    final monoStyle = theme.textTheme.titleSmall?.copyWith(
      fontFamily: DetailLayout.monoFont,
      fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return TextButton(
      key: cellKey,
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: highlighted
            ? scheme.surfaceContainer
            : Colors.transparent,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 9)],
          Expanded(
            child: isData
                ? MixedDataText(
                    label,
                    sansStyle: sansStyle,
                    monoStyle: monoStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: sansStyle,
                  ),
          ),
          const SizedBox(width: 8),
          PixelIcon(
            PixelGlyph.expand,
            size: 10,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<UserRateCubit>();
    final rate = this.rate;
    final isLive =
        rate?.status == UserRateStatus.watching ||
        rate?.status == UserRateStatus.rewatching;

    return MenuAnchor(
      menuChildren: [
        for (final status in UserRateStatus.values)
          CheckedMenuItem(
            checked: status == rate?.status,
            onPressed: status == rate?.status
                ? null
                : () => cubit.setStatus(status),
            child: Text(userRateStatusLabel(l10n, status)),
          ),
        if (rate != null)
          CheckedMenuItem(
            checked: false,
            onPressed: saving ? null : cubit.remove,
            child: Text(l10n.userRateRemove),
          ),
      ],
      builder: (context, controller, _) => _PickerCell(
        cellKey: MyListSection.statusButtonKey,
        onTap: controller.toggle,
        emphasize: true,
        highlighted: rate == null,
        leading: isLive
            ? Container(width: 7, height: 7, color: scheme.tertiary)
            : rate == null
            ? PixelIcon(PixelGlyph.plus, size: 10, color: scheme.onSurface)
            : null,
        label: rate == null
            ? l10n.userRateAdd
            : userRateStatusLabel(l10n, rate.status),
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
        for (var value = UserRate.maxScore; value >= 1; value--)
          CheckedMenuItem(
            checked: value == score,
            onPressed: value == score ? null : () => cubit.setScore(value),
            child: Text('$value'),
          ),
        if (score > 0)
          CheckedMenuItem(
            checked: false,
            onPressed: () => cubit.setScore(0),
            child: Text(l10n.userRateNoScore),
          ),
      ],
      builder: (context, controller, _) => _PickerCell(
        cellKey: MyListSection.scoreButtonKey,
        onTap: controller.toggle,
        emphasize: score > 0,
        isData: score > 0,
        label: score > 0 ? l10n.userRateScore(score) : l10n.userRateRate,
      ),
    );
  }
}

/// Lower band pairing the current episode count with a connected split stepper
/// (`[ − | + ]`), keeping the value outside per HIG without a redundant bar.
class _ProgressBand extends StatelessWidget {
  const _ProgressBand({required this.rate, required this.total});

  final UserRate rate;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final watched = rate.episodes.toString();
    final shown = total > 0 ? '$watched / $total' : watched;

    final counter = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.animeDetailsFactEpisodes,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: DetailLayout.sansFont,
          ),
        ),
        const SizedBox(height: 2),
        Semantics(
          label: l10n.userRateEpisodesWatched(shown),
          child: ExcludeSemantics(
            child: Text(
              shown,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );

    final stepper = _SplitStepper(rate: rate, total: total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              DetailLayout.isLargeText(context) || constraints.maxWidth < 250;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [counter, const SizedBox(height: 10), stepper],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: counter),
              const SizedBox(width: 12),
              stepper,
            ],
          );
        },
      ),
    );
  }
}

/// Connected `[ − | + ]` stepper pairing two [IconButton]s behind one border
/// and a vertical hairline divider, keeping the value outside per HIG.
class _SplitStepper extends StatelessWidget {
  const _SplitStepper({required this.rate, required this.total});

  final UserRate rate;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<UserRateCubit>();
    final ruleColor = DetailLayout.ruleColor(scheme);

    return Container(
      color: scheme.surfaceContainer,
      foregroundDecoration: DetailLayout.cardDecoration(
        scheme,
        background: Colors.transparent,
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IconButton(
              key: MyListSection.episodeLessKey,
              tooltip: l10n.userRateEpisodeLess,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: rate.episodes > 0
                  ? () => cubit.stepEpisodes(-1, total: total)
                  : null,
              icon: const PixelIcon(PixelGlyph.minus, size: 13),
            ),
            VerticalDivider(width: 1, thickness: 1, color: ruleColor),
            IconButton(
              key: MyListSection.episodeMoreKey,
              tooltip: l10n.userRateEpisodeMore,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: total <= 0 || rate.episodes < total
                  ? () => cubit.stepEpisodes(1, total: total)
                  : null,
              icon: const PixelIcon(PixelGlyph.plus, size: 13),
            ),
          ],
        ),
      ),
    );
  }
}
