import 'package:flutter/material.dart';

import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

class AnimeDetailsPage extends StatelessWidget {
  const AnimeDetailsPage({super.key});

  /// Poster pane + gap + readable text column; wider windows get side margins.
  static const _maxContentWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      // The anime name heads the content, so the bar only navigates back.
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.fromLTRB(margin, 8, margin, 24),
        child: const MaxWidthBox(
          maxWidth: _maxContentWidth,
          child: AnimeDetailsView(),
        ),
      ),
    );
  }
}
