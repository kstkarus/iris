import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class ReleaseEpisodeTapRow extends StatelessWidget {
  const ReleaseEpisodeTapRow({
    required this.index,
    required this.number,
    required this.isOnline,
    required this.progress,
    required this.finished,
    required this.download,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.child,
    this.name,
    this.highlighted = false,
    this.onLongPress,
    super.key,
  });

  final int index;
  final String number;
  final bool isOnline;
  final String? name;
  final WatchProgress? progress;
  final bool finished;
  final DownloadItem? download;
  final bool selecting;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = download;
    return Semantics(
      label: [
        isOnline
            ? l10n.playerSourceEpisodeLabel(number)
            : l10n.playerSourceFileLabel(number),
        ?name,
        releaseWatchStatus(l10n, finished: finished, progress: progress),
        if (item != null) releaseDownloadStatus(l10n, item),
      ].join(', '),
      excludeSemantics: true,
      button: !selecting,
      checked: selecting ? selected : null,
      selected: selecting ? null : highlighted,
      enabled: onTap != null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: TapRow(
        inkKey: ValueKey('player_episode_$index'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
