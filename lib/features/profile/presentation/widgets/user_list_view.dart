import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The statuses in the order Shikimori's own profile shows them.
const userListStatuses = [
  UserRateStatus.watching,
  UserRateStatus.planned,
  UserRateStatus.completed,
  UserRateStatus.onHold,
  UserRateStatus.dropped,
  UserRateStatus.rewatching,
];

/// A user's list under [header]: a text tab per status, then the entries
/// of the chosen one, read further as the page scrolls down.
class UserListView extends StatelessWidget {
  const UserListView({
    required this.header,
    required this.onOpen,
    this.mine = false,
    super.key,
  });

  /// The rest of the page loads this far from the end.
  static const _loadMoreExtent = 600.0;

  final Widget header;
  final ValueChanged<UserListEntry> onOpen;

  /// The signed-in user's own list: rows show what was changed since it
  /// was read (the rate book), and leave a tab their anime has left.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserListCubit>();
    final state = context.watch<UserListCubit>().state;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < _loadMoreExtent) {
          cubit.loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverToBoxAdapter(child: _StatusTabs(selected: state.status)),
          ..._content(context, state),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, UserListState state) {
    final l10n = AppLocalizations.of(context);
    final retry = context.read<UserListCubit>().retry;
    if (state.load == UserListLoad.failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            message: l10n.profileListLoadError,
            action: TextButton(onPressed: retry, child: Text(l10n.commonRetry)),
          ),
        ),
      ];
    }
    final loading = state.load == UserListLoad.loading;
    if (!loading && state.entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(message: l10n.profileListEmpty),
        ),
      ];
    }
    final entries = loading ? _standIns : state.entries;
    return [
      SliverList.builder(
        itemCount: entries.length,
        // Each row develops out of its own noise when the list arrives.
        itemBuilder: (context, index) => AppSkeleton(
          enabled: loading,
          semanticLabel: index == 0 ? l10n.profileListLoading : null,
          child: _EntryRow(
            entry: entries[index],
            status: state.status,
            mine: mine && !loading,
            onOpen: loading ? null : () => onOpen(entries[index]),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _Footer(state: state, onRetry: retry),
      ),
    ];
  }
}

/// The page's views as the app's sections are: text tabs, the current one
/// marked; they scroll sideways where they do not fit.
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected});

  /// [MarkedTab]'s own padding, pulled back over the page margin.
  static const _inset = 10.0;

  final UserRateStatus selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<UserListCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Transform.translate(
        offset: const Offset(-_inset, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (final status in userListStatuses)
                MarkedTab(
                  key: ValueKey('user_list_tab_${status.name}'),
                  label: userRateStatusLabel(l10n, status),
                  selected: status == selected,
                  onTap: () => cubit.select(status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small cover, the names, how far along and the score, and for an
/// airing anime when the next episode comes.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.status,
    required this.mine,
    required this.onOpen,
  });

  static const _posterWidth = 48.0;

  final UserListEntry entry;
  final UserRateStatus status;
  final bool mine;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final anime = entry.anime;
    final rate = mine
        ? context.watchUserRate(anime.id, entry.rate)
        : entry.rate;
    // Moved to another status or out of the list since the tab was read.
    if (rate == null || (mine && rate.status != status)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final russian = anime.russian.trim();
    final facts = [
      ?_progress(rate, anime),
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
                  Text(
                    anime.name,
                    maxLines: 1,
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

  /// `5 / 12` while the anime is under way; planned and completed say
  /// nothing more than their tab.
  static String? _progress(UserRate rate, ListedAnime anime) {
    final underWay = switch (rate.status) {
      UserRateStatus.watching ||
      UserRateStatus.rewatching ||
      UserRateStatus.onHold ||
      UserRateStatus.dropped => true,
      UserRateStatus.planned || UserRateStatus.completed => false,
    };
    if (!underWay) return null;
    final total = anime.episodes > 0 ? '${anime.episodes}' : '?';
    return '${rate.episodes} / $total';
  }

  static String? _nextEpisode(AppLocalizations l10n, ListedAnime anime) {
    final at = anime.nextEpisodeAt;
    if (anime.status != 'ongoing' || at == null) return null;
    final when = formatNextEpisodeTime(l10n, at, DateTime.now());
    if (when == null) return null;
    return l10n.profileListNextEpisode(anime.episodesAired + 1, when);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final UserListState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 120, child: BlockSpinner())),
      );
    }
    if (state.moreFailed) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          const SegmentedRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(l10n.profileListLoadError)),
                const SizedBox(width: 12),
                TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox(height: 24);
  }
}

/// Stand-in rows: the noise takes the shape of typical entries, with names
/// of different lengths so the rows do not repeat one shape.
const _standIns = [
  UserListEntry(
    rate: UserRate(id: '', status: UserRateStatus.watching, episodes: 5),
    anime: ListedAnime(
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
    anime: ListedAnime(
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
    anime: ListedAnime(
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
