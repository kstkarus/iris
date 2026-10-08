import 'package:flutter/material.dart';

import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';

class AnimeDetailsPage extends StatelessWidget {
  const AnimeDetailsPage({this.preview, super.key});

  /// What the catalog already knows about the title, if it was opened
  /// from there.
  final AnimeDetailsPreview? preview;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      // The anime name heads the content, so the bar only navigates back.
      appBar: const FramedAppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: AnimeDetailsView(preview: preview),
        ),
      ),
    );
  }
}
