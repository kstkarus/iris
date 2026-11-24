import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';

enum EpisodeTagKind { filler, recap }

/// Tags carried by [metadata], in display order.
List<EpisodeTagKind> episodeTags(EpisodeMetadata? metadata) {
  if (metadata == null || !metadata.hasTag) return const [];
  return [
    if (metadata.filler) EpisodeTagKind.filler,
    if (metadata.recap) EpisodeTagKind.recap,
  ];
}

String episodeTagLabel(AppLocalizations l10n, EpisodeTagKind kind) =>
    switch (kind) {
      EpisodeTagKind.filler => l10n.playerEpisodeFiller,
      EpisodeTagKind.recap => l10n.playerEpisodeRecap,
    };

/// Localized tag labels (Filler, Recap) for semantics, in display order.
List<String> episodeTagLabels(
  AppLocalizations l10n,
  EpisodeMetadata? metadata,
) => [for (final tag in episodeTags(metadata)) episodeTagLabel(l10n, tag)];

/// Compact corner marker for grid tiles (`PlayerEpisodeGrid`): solid 4×4 square
/// for Filler, hollow 5×5 1 px square for Recap.
class EpisodeTagMark extends StatelessWidget {
  const EpisodeTagMark(this.kind, {required this.color, super.key});

  final EpisodeTagKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      EpisodeTagKind.filler => SizedBox.square(
        dimension: 4,
        child: ColoredBox(color: color),
      ),
      EpisodeTagKind.recap => SizedBox.square(
        dimension: 5,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: color)),
        ),
      ),
    };
  }
}

/// Compact framed tag marking an episode as Filler or Recap, matching
/// `QualityBadge` in sentence case (`Medeo Sans`, 1 px border, no fill).
class EpisodeTagBadge extends StatelessWidget {
  const EpisodeTagBadge(this.kind, {this.overVideo = false, super.key});

  final EpisodeTagKind kind;
  final bool overVideo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = episodeTagLabel(l10n, kind);
    final color = overVideo
        ? playerPlateSecondary
        : theme.colorScheme.onSurfaceVariant;
    final borderColor = overVideo
        ? Colors.white24
        : theme.colorScheme.outlineVariant;
    final style =
        (overVideo
                ? const TextStyle(fontSize: 10.5, height: 1.2)
                : theme.textTheme.labelSmall)
            ?.copyWith(
              color: color,
              fontFamily: DetailLayout.sansFont,
              letterSpacing: 0,
            );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: borderColor)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(label, maxLines: 1, style: style),
        ),
      ),
    );
  }
}
