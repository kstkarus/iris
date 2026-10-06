import 'package:flutter/material.dart';

import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/page_title.dart';

class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({required this.args, super.key});

  final AnimeWatchSourcesArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      appBar: AppBar(
        title: PageTitle(
          title: l10n.watchSourcesTitle,
          subtitle: args.animeEnglishTitle,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(margin, 16, margin, 24),
        child: const MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: WatchSourcesView(),
        ),
      ),
    );
  }
}
