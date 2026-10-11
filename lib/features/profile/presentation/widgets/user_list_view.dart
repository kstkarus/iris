import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_state.dart';
import 'package:iris/features/profile/presentation/widgets/friend_list.dart';
import 'package:iris/features/profile/presentation/widgets/list_grid.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The statuses, what is being watched first.
const _userListStatuses = [
  UserRateStatus.watching,
  UserRateStatus.planned,
  UserRateStatus.completed,
  UserRateStatus.onHold,
  UserRateStatus.dropped,
  UserRateStatus.rewatching,
];

/// A user's list under [header], one status at a time, read further as the
/// page scrolls down.
///
/// The bar with the status stays pinned once the header has scrolled away,
/// so another status is one tap from anywhere in the list. Given
/// [onOpenFriend], the bar also switches between the list and the user's
/// friends (from a `FriendsCubit`).
class UserListView extends StatefulWidget {
  const UserListView({
    required this.header,
    required this.onOpen,
    this.onOpenFriend,
    this.onBrowseCatalog,
    this.mine = false,
    super.key,
  });

  static const statusButtonKey = Key('user_list_status_button');
  static const listTabKey = Key('user_list_tab_list');
  static const friendsTabKey = Key('user_list_tab_friends');
  static const browseCatalogKey = Key('user_list_browse_catalog');

  /// The rest of the page loads this far from the end.
  static const _loadMoreExtent = 600.0;

  final Widget header;
  final ValueChanged<UserListEntry> onOpen;
  final ValueChanged<Friend>? onOpenFriend;

  /// Where an empty Watching or Planned list leads: the catalog, to find
  /// something to put there.
  final VoidCallback? onBrowseCatalog;

  /// The signed-in user's own list: rows show what was changed since it
  /// was read (the rate book), and leave a status their anime has left.
  final bool mine;

  @override
  State<UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<UserListView> {
  bool _friendsShown = false;

  void _showList() => setState(() => _friendsShown = false);

  void _showFriends() {
    setState(() => _friendsShown = true);
    context.read<FriendsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserListCubit>();
    final state = context.watch<UserListCubit>().state;
    final onOpenFriend = widget.onOpenFriend;
    final friendsShown = _friendsShown && onOpenFriend != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!friendsShown &&
            notification.metrics.extentAfter < UserListView._loadMoreExtent) {
          cubit.loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: widget.header),
          PinnedHeaderSliver(
            child: _Bar(
              status: friendsShown ? null : state.status,
              onStatus: cubit.select,
              sections: onOpenFriend == null
                  ? null
                  : (onList: _showList, onFriends: _showFriends),
            ),
          ),
          if (friendsShown)
            ...friendListSlivers(context, onOpen: onOpenFriend)
          else
            ..._content(context, state),
        ],
      ),
    );
  }

  /// Only where an empty list is a gap to fill: nobody looks for
  /// something to drop.
  Widget? _browseCatalog(BuildContext context, UserRateStatus status) {
    final onBrowse = widget.onBrowseCatalog;
    if (onBrowse == null) return null;
    if (status != UserRateStatus.watching && status != UserRateStatus.planned) {
      return null;
    }
    return OutlinedButton(
      key: UserListView.browseCatalogKey,
      onPressed: onBrowse,
      child: Text(AppLocalizations.of(context).commonBrowseCatalog),
    );
  }

  List<Widget> _content(BuildContext context, UserListState state) {
    final l10n = AppLocalizations.of(context);
    final retry = context.read<UserListCubit>().retry;
    if (state.load == UserListLoad.failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: RetryView(
            message: l10n.profileListLoadError,
            onRetry: retry,
            quiet: true,
          ),
        ),
      ];
    }
    final loading = state.load == UserListLoad.loading;
    final entries = loading ? _standIns : _shown(context, state);
    if (entries.isEmpty) {
      final status = userRateStatusLabel(l10n, state.status);
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: widget.mine
              ? MessageView(
                  title: l10n.profileListEmpty(status),
                  message: l10n.profileListEmptyHint,
                  action: _browseCatalog(context, state.status),
                )
              : MessageView(message: l10n.profileListEmpty(status)),
        ),
      ];
    }
    return [
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = gridColumns(
            constraints.crossAxisExtent,
            minWidth: _EntryRow.minWidth,
          );
          return SliverList.builder(
            itemCount: (entries.length / columns).ceil(),
            // Each row develops out of its own noise when the list arrives.
            itemBuilder: (context, row) => AppSkeleton(
              enabled: loading,
              semanticLabel: row == 0 ? l10n.profileListLoading : null,
              child: AdaptiveGridRow(
                columns: columns,
                spacing: gridGap,
                children: [
                  for (final entry in entries.skip(row * columns).take(columns))
                    _EntryRow(
                      entry: entry,
                      onOpen: loading ? null : () => widget.onOpen(entry),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      SliverToBoxAdapter(
        child: PagingFooter(
          loadingMore: state.loadingMore,
          failed: state.moreFailed,
          failedMessage: l10n.profileListLoadError,
          onRetry: retry,
          idle: const SizedBox(height: 24),
        ),
      ),
    ];
  }

  /// The entries as they are now: in the user's own list, an anime changed
  /// elsewhere shows its latest entry, and one moved to another status (or
  /// out of the list) leaves this one.
  List<UserListEntry> _shown(BuildContext context, UserListState state) {
    final book = widget.mine
        ? context.watch<UserRateBookCubit?>()?.state
        : null;
    if (book == null || book.isEmpty) return state.entries;
    return [
      for (final entry in state.entries)
        if (book.containsKey(entry.anime.id) ? book[entry.anime.id] : entry.rate
            case final rate? when rate.status == state.status)
          UserListEntry(rate: rate, anime: entry.anime),
    ];
  }
}

/// What the page shows and, for the list, which status: the sections as
/// text tabs (as the app's own), the status as a menu at the end, as it
/// is one choice of six.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.status,
    required this.onStatus,
    required this.sections,
  });

  /// [MarkedTab]'s and the menu button's own padding, pulled back over the
  /// page margin.
  static const _inset = 10.0;

  /// The same with or without the status menu, so switching to the
  /// friends does not move the content.
  static const _height = 48.0;

  /// Null while the friends are shown.
  final UserRateStatus? status;
  final ValueChanged<UserRateStatus> onStatus;

  /// The list and friends tabs; null on a page with only the list.
  final ({VoidCallback onList, VoidCallback onFriends})? sections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sections = this.sections;
    final status = this.status;
    return ColoredBox(
      // The list scrolls under it.
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _height),
            // Everything starts at the margin and stays together: the menu
            // filters the list, so it sits beside the tabs, not across a
            // wide window from them.
            child: Transform.translate(
              offset: const Offset(-_inset, 0),
              child: Row(
                children: [
                  if (sections != null) ...[
                    MarkedTab(
                      key: UserListView.listTabKey,
                      label: l10n.profileListTab,
                      selected: status != null,
                      onTap: sections.onList,
                    ),
                    MarkedTab(
                      key: UserListView.friendsTabKey,
                      label: l10n.profileFriendsTab,
                      selected: status == null,
                      onTap: sections.onFriends,
                    ),
                    if (status != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          height: 16,
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: scheme.outline,
                          ),
                        ),
                      ),
                  ],
                  if (status != null)
                    _StatusMenu(status: status, onSelected: onStatus),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}

/// The shown status, which opens the list of statuses.
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.status, required this.onSelected});

  final UserRateStatus status;
  final ValueChanged<UserRateStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final option in _userListStatuses)
          CheckedMenuItem(
            key: ValueKey('user_list_status_${option.name}'),
            checked: option == status,
            onPressed: () => onSelected(option),
            child: Text(userRateStatusLabel(l10n, option)),
          ),
      ],
      builder: (context, controller, _) => TextButton(
        key: UserListView.statusButtonKey,
        onPressed: controller.toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(userRateStatusLabel(l10n, status)),
            const SizedBox(width: 8),
            const PixelIcon(PixelGlyph.expand, size: 10),
          ],
        ),
      ),
    );
  }
}

/// A small cover, the names, how far along and the score, and for an
/// airing anime when the next episode comes.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onOpen});

  /// Narrower than this, a second column would cut the names too short.
  static const minWidth = 360.0;
  static const _posterWidth = 48.0;

  final UserListEntry entry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final anime = entry.anime;
    final rate = entry.rate;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final russian = anime.russian.trim();
    final facts = [
      ?_episodes(l10n, rate, anime),
      if (rate.score > 0) l10n.userRateScore(rate.score),
    ].join(' · ');
    final next = _nextEpisode(l10n, anime);
    return InkWell(
      key: ValueKey('user_list_entry_${anime.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: _posterWidth,
              child: PosterImage(url: anime.posterUrl),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Two lines: a season and its film often share the
                  // first one (`Kono Subarashii Sekai ni Shukufuku…`).
                  Text(
                    anime.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (russian.isNotEmpty)
                    Text(
                      russian,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      facts.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (next != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      next.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// How far along while the anime is under way; for a planned one, how
  /// long it is; nothing once it is finished.
  static String? _episodes(
    AppLocalizations l10n,
    UserRate rate,
    AnimeSummary anime,
  ) {
    switch (rate.status) {
      case UserRateStatus.completed:
        return null;
      case UserRateStatus.planned:
        return formatEpisodes(
          l10n,
          anime.status,
          anime.episodes,
          anime.episodesAired,
        );
      case UserRateStatus.watching ||
          UserRateStatus.rewatching ||
          UserRateStatus.onHold ||
          UserRateStatus.dropped:
        return anime.episodes > 0
            ? l10n.profileListProgress(rate.episodes, anime.episodes)
            : l10n.profileListWatched(rate.episodes);
    }
  }

  static String? _nextEpisode(AppLocalizations l10n, AnimeSummary anime) {
    final at = anime.nextEpisodeAt;
    if (anime.status != 'ongoing' || at == null) return null;
    final when = formatNextEpisodeTime(l10n, at, DateTime.now());
    if (when == null) return null;
    return l10n.animeNextEpisode(anime.episodesAired + 1, when);
  }
}

/// Stand-in rows: the noise takes the shape of typical entries, with names
/// of different lengths so the rows do not repeat one shape.
const _standIns = [
  UserListEntry(
    rate: UserRate(id: '', status: UserRateStatus.watching, episodes: 5),
    anime: AnimeSummary(
      id: '',
      name: 'An anime title',
      russian: 'Its name in Russian',
      kind: 'tv',
      score: 0,
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      airedOn: '',
      posterUrl: '',
    ),
  ),
  UserListEntry(
    rate: UserRate(id: '', status: UserRateStatus.watching, episodes: 11),
    anime: AnimeSummary(
      id: '',
      name: 'A rather longer anime title',
      russian: 'Name',
      kind: 'tv',
      score: 0,
      status: 'released',
      episodes: 24,
      episodesAired: 24,
      airedOn: '',
      posterUrl: '',
    ),
  ),
  UserListEntry(
    rate: UserRate(id: '', status: UserRateStatus.watching, episodes: 2),
    anime: AnimeSummary(
      id: '',
      name: 'Title',
      russian: 'A longer name in Russian',
      kind: 'tv',
      score: 0,
      status: 'released',
      episodes: 13,
      episodesAired: 13,
      airedOn: '',
      posterUrl: '',
    ),
  ),
];
