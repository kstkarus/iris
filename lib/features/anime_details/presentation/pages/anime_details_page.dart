import 'package:flutter/material.dart';

import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

class AnimeDetailsPage extends StatelessWidget {
  const AnimeDetailsPage({this.preview, super.key});

  /// What the catalog already knows about the title, if it was opened
  /// from there.
  final AnimeDetailsPreview? preview;

  /// Cover column + gap + readable text column; wider windows get side
  /// margins.
  static const _maxContentWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      // The anime name heads the content, so the bar only navigates back.
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: AnimeDetailsView(preview: preview),
          ),
        ),
      ),
    );
  }
}
