import 'package:flutter/material.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/widgets/character_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// A character's page: it needs a `CharacterCubit` for the character.
class CharacterPage extends StatelessWidget {
  const CharacterPage({this.preview, required this.onOpenAnime, super.key});

  /// What the list it was opened from knows of the character.
  final CharacterSummary? preview;
  final ValueChanged<AnimeSummary> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FramedAppBar(),
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
