import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/headline_page.dart';

/// The anime name heads the content, so the bar only navigates back until
/// the name scrolls under it; then the bar shows the name.
class AnimeDetailsPage extends StatelessWidget {
  const AnimeDetailsPage({this.preview, super.key});

  /// What the catalog already knows about the title, if it was opened
  /// from there.
  final AnimeDetailsPreview? preview;

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<AnimeDetailsCubit, String?>(
      (cubit) => switch (cubit.state) {
        AnimeDetailsSuccess(:final details) => details.anime.name,
        _ => null,
      },
    );
    return HeadlinePage(
      title: loaded ?? preview?.anime.name ?? '',
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: WindowSizeClass.of(context).pageMargin,
        ),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: AnimeDetailsView(preview: preview),
        ),
      ),
    );
  }
}
