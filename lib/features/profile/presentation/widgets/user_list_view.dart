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
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
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
  static const _switchDuration = Duration(milliseconds: 200);
  static const _entryRemovalDuration = Duration(milliseconds: 220);

  final _headerKey = GlobalKey();
  ScrollableState? _scrollable;
  bool _friendsShown = false;
  bool _prefetchCheckScheduled = false;
  UserRateStatus? _shownEntriesStatus;

  bool get _canLoadMore {
    final state = context.read<UserListCubit>().state;
    return state.load == UserListLoad.loaded &&
        state.hasMore &&
        !state.loadingMore &&
        !state.refreshing &&
        !state.moreFailed &&
        !(_friendsShown && widget.onOpenFriend != null) &&
        TickerMode.valuesOf(context).enabled;
  }

  void _loadMoreIfNearEnd() {
    final scrollable = _scrollable;
    if (!mounted ||
        !_canLoadMore ||
        scrollable == null ||
        !scrollable.mounted) {
      return;
    }
    final position = scrollable.position;
    if (position.hasContentDimensions &&
        position.extentAfter < UserListView._loadMoreExtent) {
      context.read<UserListCubit>().loadMore();
    }
  }

  void _schedulePrefetchCheck() {
    if (_prefetchCheckScheduled || !_canLoadMore) return;
    _prefetchCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchCheckScheduled = false;
      _loadMoreIfNearEnd();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showList() => _showSection(friends: false);

  void _showFriends() {
    _showSection(friends: true);
    context.read<FriendsCubit>().load();
  }

  void _showSection({required bool friends}) {
    if (_friendsShown == friends) return;
    setState(() => _friendsShown = friends);
    final position = _scrollable?.position;
    final headerHeight = _headerKey.currentContext?.size?.height;
    if (position != null &&
        headerHeight != null &&
        position.pixels > headerHeight) {
      position.jumpTo(headerHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserListCubit>();
    final state = context.watch<UserListCubit>().state;
    final onOpenFriend = widget.onOpenFriend;
    final friendsShown = _friendsShown && onOpenFriend != null;
    if (_shownEntriesStatus != state.status ||
        state.load != UserListLoad.loaded) {
      _shownEntriesStatus = null;
    }
    final (Object contentKey, List<Widget> contentSlivers) = friendsShown
        ? _friendsContent(context, onOpenFriend)
        : _content(context, state);
    _schedulePrefetchCheck();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _loadMoreIfNearEnd();
        return false;
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            _scrollable = Scrollable.maybeOf(notification.context);
            _schedulePrefetchCheck();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: KeyedSubtree(key: _headerKey, child: widget.header),
            ),
            PinnedHeaderSliver(
              child: _Bar(
                status: friendsShown ? null : state.status,
                onStatus: cubit.select,
                sections: onOpenFriend == null
                    ? null
                    : (onList: _showList, onFriends: _showFriends),
              ),
            ),
            _SliverFadeSwitch(
              switchKey: contentKey,
              duration: _switchDuration,
              slivers: contentSlivers,
            ),
          ],
        ),
      ),
    );
  }

  (Object, List<Widget>) _friendsContent(
    BuildContext context,
    ValueChanged<Friend> onOpenFriend,
  ) {
    final friendsState = context.watch<FriendsCubit>().state;
    final phase = switch (friendsState) {
      FriendsFailed() => 'failed',
      FriendsLoaded(:final friends) when friends.isEmpty => 'empty',
      FriendsLoading() || FriendsLoaded() => 'entries',
    };
    return (
      ('friends', phase),
      friendListSlivers(context, onOpen: onOpenFriend),
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

  (Object, List<Widget>) _content(BuildContext context, UserListState state) {
    final l10n = AppLocalizations.of(context);
    final retry = context.read<UserListCubit>().retry;
    if (state.load == UserListLoad.failed) {
      return (
        ('list', state.status, 'failed'),
        [
          SliverFillRemaining(
            hasScrollBody: false,
            child: RetryView(
              message: l10n.profileListLoadError,
              onRetry: retry,
            ),
          ),
        ],
      );
    }
    final loading = state.load == UserListLoad.loading;
    final entries = loading ? _standIns : _shown(context, state);
    if (!loading && entries.isNotEmpty) {
      _shownEntriesStatus = state.status;
    }
    final holdForDeparture =
        !loading &&
        entries.isEmpty &&
        _shownEntriesStatus == state.status &&
        !MediaQuery.disableAnimationsOf(context);
    if (entries.isEmpty &&
        !holdForDeparture &&
        !state.hasMore &&
        !state.loadingMore &&
        !state.moreFailed) {
      final status = userRateStatusLabel(l10n, state.status);
      return (
        ('list', state.status, 'empty'),
        [
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
        ],
      );
    }
    return (
      ('list', state.status, 'entries'),
      [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final columns = gridColumns(
              constraints.crossAxisExtent,
              minWidth: _EntryRow.minWidth,
            );
            return _UserListSliver(
              status: state.status,
              loading: loading,
              entries: entries,
              columns: columns,
              removalDuration: _entryRemovalDuration,
              onOpen: widget.onOpen,
              onEmptied: () {
                if (!mounted || _shownEntriesStatus != state.status) return;
                setState(() => _shownEntriesStatus = null);
              },
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
      ],
    );
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

  /// The one-line bar keeps its height when the filter is hidden.
  static const _minHeight = 48.0;
  static const _menuDuration = Duration(milliseconds: 180);

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
    final rule = DetailLayout.ruleColor(scheme);
    final statusMenu = _AnimatedStatusMenu(
      status: status,
      onSelected: onStatus,
      leadingGap: sections == null ? 0 : 16,
      duration: _menuDuration,
    );
    final controls = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sections != null)
          Wrap(
            children: [
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
            ],
          ),
        statusMenu,
      ],
    );
    return ColoredBox(
      // The list scrolls under it.
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minHeight),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Transform.translate(
                offset: const Offset(-_inset, 0),
                child: controls,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: rule),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SliverFadeSwitch extends StatefulWidget {
  const _SliverFadeSwitch({
    required this.switchKey,
    required this.duration,
    required this.slivers,
  });

  final Object switchKey;
  final Duration duration;
  final List<Widget> slivers;

  @override
  State<_SliverFadeSwitch> createState() => _SliverFadeSwitchState();
}

class _SliverFadeSwitchState extends State<_SliverFadeSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(covariant _SliverFadeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.switchKey != oldWidget.switchKey) {
      final duration = motionDuration(context, widget.duration);
      if (duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller
          ..duration = duration
          ..forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sliver = widget.slivers.length == 1
        ? widget.slivers.single
        : SliverMainAxisGroup(slivers: widget.slivers);
    return SliverFadeTransition(opacity: _opacity, sliver: sliver);
  }
}

class _ListRowEntry {
  _ListRowEntry(this.entry, {this.leaving = false});

  final UserListEntry entry;
  final bool leaving;

  String get id => entry.anime.id;

  _ListRowEntry update(UserListEntry entry) => _ListRowEntry(entry);

  _ListRowEntry leave() => _ListRowEntry(entry, leaving: true);
}

class _UserListSliver extends StatefulWidget {
  const _UserListSliver({
    required this.status,
    required this.loading,
    required this.entries,
    required this.columns,
    required this.removalDuration,
    required this.onOpen,
    required this.onEmptied,
  });

  final UserRateStatus status;
  final bool loading;
  final List<UserListEntry> entries;
  final int columns;
  final Duration removalDuration;
  final ValueChanged<UserListEntry> onOpen;
  final VoidCallback onEmptied;

  @override
  State<_UserListSliver> createState() => _UserListSliverState();
}

class _UserListSliverState extends State<_UserListSliver> {
  late List<_ListRowEntry> _entries = [
    for (final entry in widget.entries) _ListRowEntry(entry),
  ];
  final _animatingRemovals = <String>{};
  bool _reportedEmpty = false;

  @override
  void didUpdateWidget(covariant _UserListSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading ||
        oldWidget.loading ||
        widget.status != oldWidget.status ||
        MediaQuery.disableAnimationsOf(context)) {
      _animatingRemovals.clear();
      _reportedEmpty = false;
      _entries = [for (final entry in widget.entries) _ListRowEntry(entry)];
      return;
    }
    final current = {for (final entry in widget.entries) entry.anime.id: entry};
    if (current.isNotEmpty) {
      _reportedEmpty = false;
      _animatingRemovals.removeWhere(current.containsKey);
    }
    final shown = {for (final item in _entries) item.id: item};
    final updated = [
      for (final entry in widget.entries)
        shown[entry.anime.id]?.update(entry) ?? _ListRowEntry(entry),
    ];
    for (final (index, item) in _entries.indexed) {
      if (current.containsKey(item.id)) continue;
      updated.insert(index.clamp(0, updated.length), item.leave());
    }
    _entries = updated;
  }

  void _left(String id) {
    if (!mounted) return;
    _animatingRemovals.remove(id);
    setState(() {
      _entries.removeWhere((item) => item.id == id && item.leaving);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty && !widget.loading && !_reportedEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _reportedEmpty ||
            widget.entries.isNotEmpty ||
            _animatingRemovals.isNotEmpty) {
          return;
        }
        _reportedEmpty = true;
        widget.onEmptied();
      });
    }
    final l10n = AppLocalizations.of(context);
    final columns = widget.columns;
    final rowCount = (_entries.length / columns).ceil();
    return SliverList.builder(
      itemCount: rowCount,
      itemBuilder: (context, row) {
        final rowEntries = _entries.skip(row * columns).take(columns).toList();
        final collapseRow = rowEntries.every((item) => item.leaving);
        return _RowCollapse(
          collapsing: collapseRow,
          duration: widget.removalDuration,
          child: AppSkeleton(
            enabled: widget.loading,
            semanticLabel: row == 0 ? l10n.profileListLoading : null,
            child: AdaptiveGridRow(
              columns: columns,
              spacing: gridGap,
              children: [
                for (final item in rowEntries)
                  _EntryPresence(
                    key: widget.loading ? null : ValueKey(item.id),
                    leaving: item.leaving,
                    duration: widget.removalDuration,
                    onLeaving: () => _animatingRemovals.add(item.id),
                    onLeft: () => _left(item.id),
                    child: _EntryRow(
                      entry: item.entry,
                      onOpen: widget.loading
                          ? null
                          : () => widget.onOpen(item.entry),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedStatusMenu extends StatefulWidget {
  const _AnimatedStatusMenu({
    required this.status,
    required this.onSelected,
    required this.leadingGap,
    required this.duration,
  });

  final UserRateStatus? status;
  final ValueChanged<UserRateStatus> onSelected;
  final double leadingGap;
  final Duration duration;

  @override
  State<_AnimatedStatusMenu> createState() => _AnimatedStatusMenuState();
}

class _AnimatedStatusMenuState extends State<_AnimatedStatusMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.status != null ? 1 : 0,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late UserRateStatus? _lastStatus = widget.status;

  @override
  void didUpdateWidget(covariant _AnimatedStatusMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null) {
      _lastStatus = widget.status;
    }
    final visible = widget.status != null;
    final wasVisible = oldWidget.status != null;
    if (visible != wasVisible) {
      final duration = motionDuration(context, widget.duration);
      if (duration == Duration.zero) {
        _controller.value = visible ? 1 : 0;
      } else {
        _controller.duration = duration;
        visible ? _controller.forward() : _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.status != null;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!visible && _controller.isDismissed) {
          return const SizedBox.shrink();
        }
        return ExcludeFocus(
          excluding: !visible,
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: FadeTransition(
                opacity: _curved,
                child: SizeTransition(
                  axis: Axis.horizontal,
                  alignment: AlignmentDirectional.centerStart,
                  sizeFactor: _curved,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: _lastStatus == null
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(start: widget.leadingGap),
              child: _StatusMenu(
                status: _lastStatus!,
                onSelected: widget.onSelected,
              ),
            ),
    );
  }
}

class _RowCollapse extends StatefulWidget {
  const _RowCollapse({
    required this.collapsing,
    required this.duration,
    required this.child,
  });

  final bool collapsing;
  final Duration duration;
  final Widget child;

  @override
  State<_RowCollapse> createState() => _RowCollapseState();
}

class _RowCollapseState extends State<_RowCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.collapsing ? 0 : 1,
  );

  @override
  void didUpdateWidget(covariant _RowCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsing != oldWidget.collapsing) {
      final duration = motionDuration(context, widget.duration);
      if (duration == Duration.zero) {
        _controller.value = widget.collapsing ? 0 : 1;
      } else {
        _controller.duration = duration;
        widget.collapsing ? _controller.reverse() : _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        if (value >= 1) return child!;
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: value,
            child: child,
          ),
        );
      },
    );
  }
}

class _EntryPresence extends StatefulWidget {
  const _EntryPresence({
    required this.leaving,
    required this.duration,
    required this.onLeaving,
    required this.onLeft,
    required this.child,
    super.key,
  });

  final bool leaving;
  final Duration duration;
  final VoidCallback onLeaving;
  final VoidCallback onLeft;
  final Widget child;

  @override
  State<_EntryPresence> createState() => _EntryPresenceState();
}

class _EntryPresenceState extends State<_EntryPresence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  bool _gone = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && widget.leaving) _leaveNextFrame();
    _started = true;
  }

  @override
  void didUpdateWidget(covariant _EntryPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving != oldWidget.leaving) {
      if (widget.leaving) {
        final duration = motionDuration(context, widget.duration);
        if (duration == Duration.zero) {
          _controller.value = 0;
          _leaveNextFrame();
        } else {
          widget.onLeaving();
          _controller
            ..duration = duration
            ..reverse().whenCompleteOrCancel(() {
              if (_controller.isDismissed) _leave();
            });
        }
      } else {
        _gone = false;
        _controller.value = 1;
      }
    }
  }

  void _leaveNextFrame() {
    final onLeft = widget.onLeft;
    WidgetsBinding.instance.addPostFrameCallback((_) => _leave(onLeft));
  }

  void _leave([VoidCallback? onLeft]) {
    if (_gone) return;
    _gone = true;
    (onLeft ?? widget.onLeft)();
  }

  @override
  void dispose() {
    if (widget.leaving && !_gone) _leaveNextFrame();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animated = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        if (value >= 1) return child!;
        return Opacity(opacity: value, child: child);
      },
    );
    return ExcludeFocus(
      excluding: widget.leaving,
      child: IgnorePointer(
        ignoring: widget.leaving,
        child: ExcludeSemantics(excluding: widget.leaving, child: animated),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
    );
    return MenuAnchor(
      alignmentOffset: const Offset(0, 2),
      menuChildren: [
        for (final option in _userListStatuses)
          CheckedMenuItem(
            key: ValueKey('user_list_status_${option.name}'),
            checked: option == status,
            onPressed: () => onSelected(option),
            child: Text(
              userRateStatusLabel(l10n, option),
              style: const TextStyle(
                fontFamily: DetailLayout.sansFont,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => TextButton(
        key: UserListView.statusButtonKey,
        onPressed: controller.toggle,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(_Bar._minHeight),
          padding: const EdgeInsets.symmetric(horizontal: _Bar._inset),
          foregroundColor: scheme.onSurface,
          textStyle: labelStyle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(userRateStatusLabel(l10n, status))),
            const SizedBox(width: 6),
            PixelIcon(
              PixelGlyph.expand,
              size: 10,
              color: scheme.onSurfaceVariant,
            ),
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
  static const _posterWidth = 56.0;
  static const _posterHeight = _posterWidth / PosterImage.aspectRatio;

  final UserListEntry entry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final anime = entry.anime;
    final rate = entry.rate;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final muted = scheme.onSurfaceVariant;
    final russian = anime.russian.trim();
    final episodes = _episodes(l10n, rate, anime);
    final next = _nextEpisode(l10n, anime);
    final sansMeta = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 12.5,
      color: muted,
    );
    final monoMeta = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
      color: muted,
    );
    final metaSpans = <InlineSpan>[
      if (episodes != null)
        DetailLayout.mixedDataSpan(
          episodes,
          sansStyle: sansMeta,
          monoStyle: monoMeta,
        ),
      if (next != null)
        DetailLayout.mixedDataSpan(
          next,
          sansStyle: sansMeta?.copyWith(
            color: scheme.tertiary,
            fontWeight: FontWeight.w500,
          ),
          monoStyle: monoMeta?.copyWith(
            color: scheme.tertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
    ];
    final titleWidget = Text(
      anime.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        fontFamily: DetailLayout.sansFont,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: DetailLayout.ruleColor(scheme).withValues(alpha: 0.65),
          ),
        ),
      ),
      child: InkWell(
        key: ValueKey('user_list_entry_${anime.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _posterWidth,
                child: PosterImage(url: anime.posterUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _posterHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: metaSpans.isEmpty
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Two lines: a season and its film often share the
                          // first one (`Kono Subarashii Sekai ni Shukufuku…`).
                          if (rate.score > 0)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: titleWidget),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: _StarScore(
                                    score: rate.score,
                                    semanticLabel: l10n.userRateScore(
                                      rate.score,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            titleWidget,
                          if (russian.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              russian,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: DetailLayout.sansFont,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (metaSpans.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        PixelSeparatedText.spans(
                          metaSpans,
                          style: sansMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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

class _StarScore extends StatelessWidget {
  const _StarScore({required this.score, required this.semanticLabel});

  final int score;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
      color: scheme.onSurface,
    );
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelIcon(
              PixelGlyph.star,
              size: 11,
              fineGrain: true,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 4),
            Text('$score', style: style),
          ],
        ),
      ),
    );
  }
}

/// Stand-in rows: the noise takes the shape of typical entries, with names
/// of different lengths so the rows do not repeat one shape.
const _standIns = [
  UserListEntry(
    rate: UserRate(
      id: '',
      status: UserRateStatus.watching,
      episodes: 5,
      score: 9,
    ),
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
    rate: UserRate(
      id: '',
      status: UserRateStatus.watching,
      episodes: 2,
      score: 8,
    ),
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
