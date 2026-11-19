import 'package:flutter/material.dart';

import 'package:iris/entities/anime/domain/anime_kind.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/theme/cjk_font.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Stand-in body used to give skeleton noise the shape of a character bio.
final standInCharacterDescription = List.filled(
  4,
  'A few sentences about who the character is and what they do.',
).join(' ');

/// The anime worth listing, by air date, undated last.
List<CharacterAppearance> appearancesToShow(
  List<CharacterAppearance> appearances,
) {
  final shown = appearances.where((item) => !isPromoAnimeKind(item.anime.kind));
  return shown.toList()..sort((a, b) {
    final aAiredOn = a.anime.airedOn;
    final bAiredOn = b.anime.airedOn;
    if (aAiredOn.isEmpty != bAiredOn.isEmpty) {
      return aAiredOn.isEmpty ? 1 : -1;
    }
    return aAiredOn.compareTo(bAiredOn);
  });
}

/// Framed character portrait matching the hairline border contrast of the page.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({required this.posterUrl, super.key});

  final String posterUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PosterImage(
      url: posterUrl,
      borderColor: DetailLayout.ruleColor(scheme),
    );
  }
}

/// Framed passport card holding the character's Japanese and alternative names.
class CharacterNamesCard extends StatelessWidget {
  const CharacterNamesCard({
    required this.details,
    this.topSpacing = 0,
    super.key,
  });

  final CharacterDetails? details;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final japanese = details?.japanese.trim() ?? '';
    final altName = details?.altName.trim() ?? '';
    final Widget child;
    if (japanese.isEmpty && altName.isEmpty) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      final ruleColor = DetailLayout.ruleColor(scheme);
      final rows = <(String, String)>[
        if (japanese.isNotEmpty) (l10n.characterFactJapanese, japanese),
        if (altName.isNotEmpty) (l10n.characterFactAltNames, altName),
      ];
      child = Padding(
        key: const ValueKey('content'),
        padding: EdgeInsets.only(top: topSpacing),
        child: DecoratedBox(
          key: const Key('character_names_card'),
          decoration: DetailLayout.cardDecoration(scheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, (label, value)) in rows.indexed) ...[
                if (index > 0)
                  Divider(height: 1, thickness: 1, color: ruleColor),
                _NameCell(label: label, value: value),
              ],
            ],
          ),
        ),
      );
    }
    return DitherSwitcher(
      collapse: true,
      resizeDuration: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 240),
      child: child,
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontFamilyFallback: cjkFontFallback,
            ),
          ),
        ],
      ),
    );
  }
}

/// Who the character is, shown as pixel noise while loading; hidden when empty.
class CharacterDescriptionSection extends StatelessWidget {
  const CharacterDescriptionSection({required this.description, super.key});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final trimmed = description?.trim();
    final l10n = AppLocalizations.of(context);
    final Widget child = trimmed != null && trimmed.isEmpty
        ? const SizedBox.shrink(key: ValueKey('empty_description'))
        : Padding(
            key: const ValueKey('description'),
            padding: const EdgeInsets.only(top: 32),
            child: DetailSection(
              label: l10n.characterDescriptionTitle,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AdaptiveContentWidth.reading,
                  ),
                  child: AppSkeleton(
                    enabled: trimmed == null,
                    semanticLabel: l10n.characterLoading,
                    child: Text(
                      trimmed ?? standInCharacterDescription,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: DetailLayout.sansFont,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
    return DitherSwitcher(
      collapse: true,
      resizeDuration: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }
}

/// The anime the character is in, oldest first, framed in a card like related
/// anime; promos aside, folded after five.
class CharacterAppearancesSection extends StatelessWidget {
  const CharacterAppearancesSection({
    required this.appearances,
    required this.onOpenAnime,
    super.key,
  });

  /// Rows shown before the rest folds away: a long series' hero is in
  /// dozens of films and specials.
  static const _visibleRows = 5;
  static const _minFolded = 2;

  final List<CharacterAppearance> appearances;
  final ValueChanged<AnimeSummary> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    final shown = appearancesToShow(appearances);
    final Widget child;
    if (shown.isEmpty) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      final ruleColor = DetailLayout.ruleColor(scheme);
      child = Padding(
        key: const ValueKey('content'),
        padding: const EdgeInsets.only(top: 32),
        child: DetailSection(
          label: l10n.characterAnimeTitle,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.reading,
              ),
              child: Container(
                color: scheme.surfaceContainerLow,
                foregroundDecoration: DetailLayout.cardDecoration(
                  scheme,
                  background: Colors.transparent,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FoldingList(
                    key: const Key('character_anime'),
                    items: shown,
                    visible: _visibleRows,
                    minFolded: _minFolded,
                    toggleKey: const Key('character_anime_more'),
                    divider: Divider(height: 1, thickness: 1, color: ruleColor),
                    builder: (context, rows) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, item) in rows.indexed) ...[
                          if (index > 0)
                            Divider(height: 1, thickness: 1, color: ruleColor),
                          _AppearanceRow(
                            appearance: item,
                            onOpen: () => onOpenAnime(item.anime),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return DitherSwitcher(
      collapse: true,
      resizeDuration: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 240),
      child: child,
    );
  }
}

/// Poster thumbnail, kind/year/role caption, title, optional Russian title, and
/// navigation arrow.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({required this.appearance, required this.onOpen});

  final CharacterAppearance appearance;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final anime = appearance.anime;
    final year = yearOfIsoDate(anime.airedOn)?.toString() ?? '';
    final captionParts = [
      if (anime.kind.isNotEmpty) formatAnimeKind(l10n, anime.kind),
      if (year.isNotEmpty) year,
      formatCharacterRole(l10n, appearance.role),
    ];
    final russian = anime.russian.trim();
    return TapRow(
      inkKey: ValueKey('character_anime_${anime.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 40, child: PosterImage(url: anime.posterUrl)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelSeparatedText.parts(
                    captionParts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    sansStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      color: muted,
                    ),
                    monoStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.monoFont,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                    ),
                  ),
                  if (russian.isNotEmpty &&
                      russian.toLowerCase() != anime.name.toLowerCase()) ...[
                    const SizedBox(height: 2),
                    Text(
                      russian,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: DetailLayout.sansFont,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: PixelIcon(PixelGlyph.arrowRight, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
