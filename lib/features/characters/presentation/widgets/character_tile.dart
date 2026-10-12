import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Room for a portrait and its name in a row of [CharacterTile]s.
abstract final class CharacterTileSizes {
  static const gap = 12.0;
  static const compactMinWidth = 88.0;
  static const minWidth = 112.0;
}

/// A character's portrait over their name; a tap opens their page.
class CharacterTile extends StatelessWidget {
  const CharacterTile({required this.character, super.key});

  final CharacterSummary character;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = characterName(l10n, character);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: TapRow(
        inkKey: ValueKey('character_${character.id}'),
        onTap: () => context.pushNamed(
          'character',
          pathParameters: {'id': character.id},
          extra: character,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PosterImage(url: character.posterUrl),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to [columns] tiles side by side, as wide as a full row's would be.
class CharacterTileRow extends StatelessWidget {
  const CharacterTileRow({
    required this.characters,
    required this.columns,
    super.key,
  });

  final List<CharacterSummary> characters;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns; index++) ...[
          if (index > 0) const SizedBox(width: CharacterTileSizes.gap),
          Expanded(
            child: index < characters.length
                ? CharacterTile(character: characters[index])
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
