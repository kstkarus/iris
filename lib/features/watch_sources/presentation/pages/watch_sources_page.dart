import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/online_sources/presentation/widgets/online_releases_list.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/marked_tab.dart';

/// Online releases and torrents, each on its own tab with the whole page:
/// people pick one kind and seldom compare across them. A kind with
/// nothing found takes its tab away, so a tab never opens on nothing; with
/// one kind left the page is that kind alone.
class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({required this.args, super.key});

  final AnimeWatchSourcesArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
    final hasOnline = context.select<OnlineReleasesCubit, bool>(
      (cubit) => cubit.state is! OnlineReleasesEmpty,
    );
    final hasTorrents = context.select<WatchSourcesCubit, bool>(
      (cubit) => cubit.state is! WatchSourcesEmpty,
    );
    final chosen = context.watch<WatchSourcesTabCubit>().state;
    final both = hasOnline && hasTorrents;
    final tab = both
        ? chosen
        : hasOnline
        ? WatchSourcesTab.online
        : WatchSourcesTab.torrents;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The tabs go once a kind turns out empty: they dissolve,
              // then give their height back.
              DitherSwitcher(
                collapse: true,
                child: both
                    ? Padding(
                        key: const ValueKey('tabs'),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _Tabs(selected: tab),
                      )
                    : const SizedBox.shrink(key: ValueKey('no_tabs')),
              ),
              // Both stay built, so each keeps its scroll and the torrent
              // search while the other is shown.
              Expanded(
                child: IndexedStack(
                  index: tab.index,
                  sizing: StackFit.expand,
                  children: [
                    TickerMode(
                      enabled: tab == WatchSourcesTab.online,
                      child: hasOnline
                          ? OnlineReleasesList(
                              animeId: args.animeId,
                              animeTitle: args.animeTitle,
                            )
                          : const SizedBox.shrink(),
                    ),
                    TickerMode(
                      enabled: tab == WatchSourcesTab.torrents,
                      child: const WatchSourcesView(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's views as the app's own sections are: text tabs, the current
/// one marked. The glyph of the first tab lines up with the content.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected});

  /// [MarkedTab]'s own padding, pulled back over the page margin.
  static const _inset = 10.0;

  final WatchSourcesTab selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WatchSourcesTabCubit>();
    MarkedTab tab(WatchSourcesTab tab, String label) => MarkedTab(
      label: label,
      selected: tab == selected,
      onTap: () => cubit.select(tab),
    );
    return Transform.translate(
      offset: const Offset(-_inset, 0),
      child: Row(
        children: [
          tab(WatchSourcesTab.online, l10n.watchSourcesOnlineSection),
          tab(WatchSourcesTab.torrents, l10n.watchSourcesTorrentsSection),
        ],
      ),
    );
  }
}
