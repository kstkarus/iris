import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/online_sources/presentation/widgets/online_releases_section.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';

/// Online releases over the torrents, each under its own label; with no
/// online release the torrents are the whole page and need no label.
class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({required this.args, super.key});

  final AnimeWatchSourcesArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      appBar: FramedAppBar(
        title: PageTitle(
          title: l10n.watchSourcesTitle,
          subtitle: args.animeTitle,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(margin, 24, margin, 0),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: BlocBuilder<OnlineReleasesCubit, OnlineReleasesState>(
            buildWhen: (previous, next) =>
                (previous is OnlineReleasesEmpty) !=
                (next is OnlineReleasesEmpty),
            builder: (context, state) {
              final online = state is! OnlineReleasesEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (online) ...[
                    OnlineReleasesSection(
                      animeId: args.animeId,
                      animeTitle: args.animeTitle,
                    ),
                    const SizedBox(height: 32),
                    SectionLabel(l10n.watchSourcesTorrentsSection),
                    const SizedBox(height: 12),
                  ],
                  // Keyed, so the torrents keep their state when the
                  // labels above them go.
                  const Expanded(
                    key: ValueKey('watch_sources_torrents'),
                    child: WatchSourcesView(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
