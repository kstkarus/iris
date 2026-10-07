import 'package:flutter/material.dart';

import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// The catalog. The search field heads the page: the section's name is
/// already in the navigation.
class AnimeListPage extends StatelessWidget {
  const AnimeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, sizeClass.pageTop, margin, 0),
          child: const MaxWidthBox(
            maxWidth: AdaptiveContentWidth.page,
            child: AnimeListView(),
          ),
        ),
      ),
    );
  }
}
