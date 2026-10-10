import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
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
          child: MessageView(
            message: l10n.profileFriendsLoadError,
            action: TextButton(
              onPressed: cubit.load,
              child: Text(l10n.commonRetry),
            ),
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
    SliverList.builder(
      itemCount: friends.length,
      // Each row develops out of its own noise when the friends arrive.
      itemBuilder: (context, index) => AppSkeleton(
        enabled: loading,
        semanticLabel: index == 0 ? l10n.profileFriendsLoading : null,
        child: _FriendRow(
          friend: friends[index],
          onOpen: loading ? null : () => onOpen(friends[index]),
        ),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
  ];
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onOpen});

  static const _avatarSize = 40.0;

  final Friend friend;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('friend_${friend.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SquareAvatar(url: friend.avatarUrl, size: _avatarSize),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                friend.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
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
