import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';

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
    this.tags = const [],
    this.highlighted = false,
    this.showTooltip = false,
    this.onLongPress,
    this.onSecondaryTap,
    super.key,
  });

  final int index;
  final String number;
  final bool isOnline;
  final String? name;
  final List<String> tags;
  final WatchProgress? progress;
  final bool finished;
  final DownloadItem? download;
  final bool selecting;
  final bool selected;
  final bool highlighted;
  final bool showTooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = download;
    final label = [
      isOnline
          ? l10n.playerSourceEpisodeLabel(number)
          : l10n.playerSourceFileLabel(number),
      ?name,
      ...tags,
      releaseWatchStatus(l10n, finished: finished, progress: progress),
      if (item != null) releaseDownloadStatus(l10n, item),
    ].join(', ');
    Widget row = FocusableListRow(
      inkKey: ValueKey('player_episode_$index'),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      child: child,
    );
    if (showTooltip) {
      row = Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 450),
        // Hover still shows the tooltip without intercepting touch long-press.
        triggerMode: TooltipTriggerMode.manual,
        child: row,
      );
    }
    return Semantics(
      label: label,
      excludeSemantics: true,
      button: !selecting,
      checked: selecting ? selected : null,
      selected: selecting ? null : highlighted,
      enabled: onTap != null,
      onTap: onTap,
      onLongPress: onLongPress,
      child: row,
    );
  }
}
