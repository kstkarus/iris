import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

/// Whose list the page shows: the picture beside the name, which is the
/// page's one large voice. Kept short, so the list starts within the first
/// screen.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.nickname,
    required this.avatarUrl,
    this.trailing,
    super.key,
  });

  static const compactRowHeight = 56.0;

  final String nickname;
  final String avatarUrl;

  /// A quiet action at the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSizeClass.of(context).isCompact;
    final avatarSize = compact ? compactRowHeight : 72.0;
    final trailing = this.trailing;
    final alignActionToTop = compact && trailing != null;
    final title = HeadlineAnchor(
      child: DisplayTitle(
        nickname,
        maxSize: compact ? 40 : 64,
        preferredMinSize: 22,
        minSize: 16,
        maxLines: 1,
        fallbackStyleAt: DetailLayout.fallbackTitleStyle,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 20),
      child: Row(
        crossAxisAlignment: alignActionToTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (avatarUrl.isNotEmpty) ...[
            SquareAvatar(url: avatarUrl, size: avatarSize),
            SizedBox(width: compact ? 16 : 24),
          ],
          Expanded(
            child: alignActionToTop
                ? ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: compactRowHeight,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      heightFactor: 1,
                      child: title,
                    ),
                  )
                : title,
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }
}
