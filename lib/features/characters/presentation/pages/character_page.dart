import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/cubit/character_cubit.dart';
import 'package:iris/features/characters/presentation/cubit/character_state.dart';
import 'package:iris/features/characters/presentation/widgets/character_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/headline_page.dart';

/// A character's page: it needs a [CharacterCubit] for the character. The
/// bar takes the name over once the page's own has scrolled under it.
class CharacterPage extends StatelessWidget {
  const CharacterPage({this.preview, required this.onOpenAnime, super.key});

  /// What the list it was opened from knows of the character.
  final CharacterSummary? preview;
  final ValueChanged<AnimeSummary> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<CharacterCubit, CharacterSummary?>(
      (cubit) => switch (cubit.state) {
        CharacterLoaded(:final details) => details.character,
        _ => null,
      },
    );
    final character = loaded ?? preview;
    return HeadlinePage(
      title: character == null
          ? ''
          : characterName(AppLocalizations.of(context), character),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: WindowSizeClass.of(context).pageMargin,
        ),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: CharacterView(preview: preview, onOpenAnime: onOpenAnime),
        ),
      ),
    );
  }
}
