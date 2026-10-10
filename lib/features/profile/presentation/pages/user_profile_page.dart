import 'package:flutter/material.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

/// A friend's list by status, to look at: it needs a `UserListCubit`
/// showing [friend]'s list.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    required this.friend,
    required this.onOpenAnime,
    super.key,
  });

  final Friend friend;
  final ValueChanged<UserListEntry> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;
    return Scaffold(
      appBar: const FramedAppBar(),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: UserListView(
            header: _Header(friend: friend),
            onOpen: onOpenAnime,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.friend});

  static const _avatarSize = 72.0;

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSizeClass.of(context).isCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: compact ? 16 : 32),
        if (friend.avatarUrl.isNotEmpty) ...[
          SquareAvatar(url: friend.avatarUrl, size: _avatarSize),
          const SizedBox(height: 20),
        ],
        DisplayTitle(
          friend.nickname,
          maxSize: compact ? 56 : 144,
          minSize: 32,
          maxLines: 1,
        ),
        SizedBox(height: compact ? 12 : 20),
      ],
    );
  }
}
