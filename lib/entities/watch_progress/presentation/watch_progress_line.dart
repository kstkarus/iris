import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// "Stopped at 12:34 of 24:00" under a block bar in the signal colour, or
/// a quiet "Watched" mark once the file is done: a list of watched files
/// should not read as a wall of full bars.
class WatchProgressLine extends StatelessWidget {
  const WatchProgressLine({
    required this.progress,
    this.showBar = true,
    super.key,
  });

  /// Bars stop growing here, so a wide row keeps a readable bar.
  static const maxWidth = 360.0;

  final WatchProgress progress;

  /// False where the same file's bar is already on screen, so the text is
  /// all that is left to say.
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;

    if (progress.isFinished) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(
            PixelGlyph.check,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(l10n.watchProgressWatched, style: style),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBar) ...[
            ExcludeSemantics(
              child: SegmentedBar(
                value: progress.fraction,
                height: 4,
                segment: 6,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            l10n.watchProgressStoppedAt(
              formatPlaybackPosition(progress.position),
              formatPlaybackPosition(progress.duration),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }
}
