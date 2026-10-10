import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

/// Whose list the page shows: the picture beside the name, which is the
/// page's one large voice, over a small caption. Kept short, so the list
/// starts within the first screen.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.nickname,
    required this.avatarUrl,
    required this.caption,
    this.trailing,
    super.key,
  });

  final String nickname;
  final String avatarUrl;
  final String caption;

  /// A quiet action at the end of the row, such as signing out.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = WindowSizeClass.of(context).isCompact;
    final avatarSize = compact ? 56.0 : 72.0;
    final trailing = this.trailing;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BlockRule(),
          SizedBox(height: compact ? 20 : 28),
          Row(
            children: [
              if (avatarUrl.isNotEmpty) ...[
                SquareAvatar(url: avatarUrl, size: avatarSize),
                SizedBox(width: compact ? 16 : 24),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DisplayTitle(
                      nickname,
                      maxSize: compact ? 40 : 64,
                      minSize: 24,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        ],
      ),
    );
  }
}
