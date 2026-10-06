import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';

/// A thin bar with "Watched" or "Stopped at 12:34 of 24:00".
class WatchProgressLine extends StatelessWidget {
  const WatchProgressLine({required this.progress, super.key});

  final WatchProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final finished = progress.isFinished;
    final label = finished
        ? l10n.watchProgressWatched
        : l10n.watchProgressStoppedAt(
            formatPlaybackPosition(progress.position),
            formatPlaybackPosition(progress.duration),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: finished ? 1 : progress.fraction,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (finished) ...[
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
