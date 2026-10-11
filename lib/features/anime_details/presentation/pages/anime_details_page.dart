import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/features/anime_details/presentation/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/page_title.dart';

/// The anime name heads the content, so the bar only navigates back until
/// the name scrolls under it; then the bar shows the name.
class AnimeDetailsPage extends StatefulWidget {
  const AnimeDetailsPage({this.preview, super.key});

  /// What the catalog already knows about the title, if it was opened
  /// from there.
  final AnimeDetailsPreview? preview;

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage> {
  final _headline = HeadlineTracker();
  final _headlineGone = ValueNotifier(false);
  final _body = GlobalKey();

  @override
  void dispose() {
    _headlineGone.dispose();
    super.dispose();
  }

  bool _checkHeadline(Notification notification) {
    final body = _body.currentContext?.findRenderObject();
    if (body is RenderBox && body.hasSize) {
      // The body starts where the bar ends.
      _headlineGone.value = _headline.isAbove(
        body.localToGlobal(Offset.zero).dy,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      appBar: FramedAppBar(
        title: _BarTitle(preview: widget.preview, shown: _headlineGone),
      ),
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: _checkHeadline,
        child: NotificationListener<ScrollNotification>(
          onNotification: _checkHeadline,
          child: Padding(
            key: _body,
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: HeadlineScope(
              tracker: _headline,
              child: MaxWidthBox(
                maxWidth: AdaptiveContentWidth.page,
                child: AnimeDetailsView(preview: widget.preview),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The anime name in the bar while the page's own is out of sight. It
/// develops cell by cell, quicker than content does, as it answers the
/// finger. Screen readers already have the page's heading.
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.preview, required this.shown});

  static const _duration = Duration(milliseconds: 300);

  final AnimeDetailsPreview? preview;
  final ValueListenable<bool> shown;

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<AnimeDetailsCubit, String?>(
      (cubit) => switch (cubit.state) {
        AnimeDetailsSuccess(:final details) => details.anime.name,
        _ => null,
      },
    );
    final name = loaded ?? preview?.anime.name ?? '';
    return ExcludeSemantics(
      child: ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, shown, _) => DitherSwitcher(
          duration: _duration,
          child: shown && name.isNotEmpty
              ? PageTitle(key: ValueKey(name), title: name)
              : const SizedBox.shrink(key: ValueKey('no_title')),
        ),
      ),
    );
  }
}
