import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_cubit.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_state.dart';
import 'package:iris/features/characters/presentation/widgets/character_tile.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// The main characters of an anime, one row of portraits; the rest on a
/// page of their own, as a long series has over a thousand. Nothing
/// while they load, if none are listed, or if they fail: it is secondary.
class CharactersSection extends StatelessWidget {
  const CharactersSection({
    required this.animeId,
    required this.animeName,
    this.labelWidth,
    super.key,
  });

  /// Portraits in the row at most, however wide the window.
  static const _maxColumns = 8;

  final String animeId;

  /// The subtitle of the page of all the characters.
  final String animeName;

  /// Width of the label column; null puts the label above.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    // Pages built without characters (as in tests) show no section.
    final state = context.watch<AnimeCharactersCubit?>()?.state;
    final characters = state is AnimeCharactersLoaded
        ? state.characters
        : const <AnimeCharacter>[];
    // It may well be empty, so no noise for it: it develops in when
    // it arrives, below everything it could push.
    if (characters.isEmpty) {
      return const DitherSwitcher(child: SizedBox.shrink());
    }
    final l10n = AppLocalizations.of(context);
    final ordered = charactersInOrder(l10n, characters);
    final leads = [
      for (final item in ordered)
        if (item.role == CharacterRole.main) item.character,
    ];
    // Without main characters, the first of the rest.
    final candidates = leads.isNotEmpty
        ? leads
        : [for (final item in ordered) item.character];
    return DitherSwitcher(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: LabeledSection(
          label: l10n.charactersTitle,
          labelWidth: labelWidth,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.reading,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = adaptiveColumnCount(
                    availableWidth: constraints.maxWidth,
                    minItemWidth: WindowSizeClass.of(context).isCompact
                        ? CharacterTileSizes.compactMinWidth
                        : CharacterTileSizes.minWidth,
                    spacing: CharacterTileSizes.gap,
                    maxColumns: _maxColumns,
                  );
                  final shown = candidates.take(columns).toList();
                  return Column(
                    key: const Key('characters_section'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CharacterTileRow(characters: shown, columns: columns),
                      if (characters.length > shown.length) ...[
                        const SizedBox(height: 16),
                        const SegmentedRule(),
                        _AllRow(
                          count: characters.length,
                          onTap: () => context.pushNamed(
                            'anime-characters',
                            pathParameters: {'id': animeId},
                            extra: animeName,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the page of all the characters.
class _AllRow extends StatelessWidget {
  const _AllRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: TapRow(
        inkKey: const Key('characters_all'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).charactersAll(count),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: PixelIcon(PixelGlyph.arrowRight, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
