import 'package:flutter/material.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/widgets/profile_header.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

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
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    return Scaffold(
      appBar: const FramedAppBar(),
      body: Padding(
        // The same gap above the header as on the Profile tab.
        padding: EdgeInsets.fromLTRB(margin, sizeClass.pageTop, margin, 0),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: UserListView(
            header: ProfileHeader(
              nickname: friend.nickname,
              avatarUrl: friend.avatarUrl,
            ),
            onOpen: onOpenAnime,
          ),
        ),
      ),
    );
  }
}
