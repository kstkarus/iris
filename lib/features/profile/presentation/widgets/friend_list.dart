import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:iris/features/profile/presentation/widgets/list_grid.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/square_avatar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The friends from the `FriendsCubit`, as slivers for the list's page: a
/// row each, which opens their list.
List<Widget> friendListSlivers(
  BuildContext context, {
  required ValueChanged<Friend> onOpen,
}) {
  final l10n = AppLocalizations.of(context);
  final cubit = context.watch<FriendsCubit>();
  final state = cubit.state;
  final List<Friend> friends;
  switch (state) {
    case FriendsFailed():
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: RetryView(
            message: l10n.profileFriendsLoadError,
            onRetry: cubit.load,
          ),
        ),
      ];
    case FriendsLoaded(friends: final loaded) when loaded.isEmpty:
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(message: l10n.profileFriendsEmpty),
        ),
      ];
    case FriendsLoaded(friends: final loaded):
      friends = loaded;
    case FriendsLoading():
      friends = _standIns;
  }
  final loading = state is FriendsLoading;
  return [
    SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumns(
          constraints.crossAxisExtent,
          minWidth: _FriendRow.minWidth,
        );
        return SliverList.builder(
          itemCount: (friends.length / columns).ceil(),
          // Each row develops out of its own noise when the friends arrive.
          itemBuilder: (context, row) => AppSkeleton(
            enabled: loading,
            semanticLabel: row == 0 ? l10n.profileFriendsLoading : null,
            child: AdaptiveGridRow(
              columns: columns,
              spacing: gridGap,
              children: [
                for (final friend in friends.skip(row * columns).take(columns))
                  _FriendRow(
                    friend: friend,
                    onOpen: loading ? null : () => onOpen(friend),
                  ),
              ],
            ),
          ),
        );
      },
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onOpen});

  static const minWidth = 280.0;
  static const _avatarSize = 40.0;

  final Friend friend;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: DetailLayout.ruleColor(scheme).withValues(alpha: 0.65),
          ),
        ),
      ),
      child: InkWell(
        key: ValueKey('friend_${friend.id}'),
        mouseCursor: onOpen != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SquareAvatar(url: friend.avatarUrl, size: _avatarSize),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  friend.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onOpen != null) ...[
                const SizedBox(width: 8),
                PixelIcon(
                  PixelGlyph.arrowRight,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _standIns = [
  Friend(id: '', nickname: 'A nickname', avatarUrl: ''),
  Friend(id: '', nickname: 'Longer nickname', avatarUrl: ''),
  Friend(id: '', nickname: 'Nick', avatarUrl: ''),
];
