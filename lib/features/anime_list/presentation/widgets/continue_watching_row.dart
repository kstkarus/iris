import 'package:flutter/material.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Keep the same useful record, source grouping and five-title limit as before.
List<WatchProgress> continueWatchingItems(List<WatchProgress> history) {
  final seen = <String>{};
  return latestPerTorrent(history.where((item) => item.isWorthContinuing))
      .where(
        (item) =>
            seen.add(item.hasAnime ? 'anime:${item.animeId}' : item.torrentKey),
      )
      .take(ContinueWatchingRow.maxItems)
      .toList();
}

/// The compact contents shared by the catalog's popover and phone sheet.
class ContinueWatchingRow extends StatefulWidget {
  const ContinueWatchingRow({
    required this.items,
    required this.onOpen,
    required this.onOpenAnime,
    required this.onRemove,
    this.posters = const {},
    super.key,
  });

  static const maxItems = 5;
  final List<WatchProgress> items;
  final Map<String, String> posters;
  final ValueChanged<WatchProgress> onOpen;
  final ValueChanged<WatchProgress> onOpenAnime;
  final ValueChanged<WatchProgress> onRemove;

  @override
  State<ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends State<ContinueWatchingRow> {
  late List<_Entry> _entries = [for (final item in widget.items) _Entry(item)];

  @override
  void didUpdateWidget(covariant ContinueWatchingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = {for (final item in widget.items) item.torrentKey: item};
    final shown = {for (final entry in _entries) entry.key: entry};
    final entries = [
      for (final item in widget.items)
        shown[item.torrentKey]?.update(item) ?? _Entry(item),
    ];
    for (final (index, entry) in _entries.indexed) {
      if (current.containsKey(entry.key)) continue;
      entries.insert(index.clamp(0, entries.length), entry.leave());
    }
    _entries = entries;
  }

  void _left(String key) {
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.key == key && e.leaving));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final titleStyle = theme.textTheme.titleSmall;
    final painter = TextPainter(
      text: TextSpan(text: 'M\nM', style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final titleHeight = painter.height;
    painter.dispose();
    return Column(
      key: const Key('continue_watching_row'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.continueWatchingTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        for (final (index, entry) in _entries.indexed)
          _RowPresence(
            key: ValueKey(entry.key),
            leaving: entry.leaving,
            onLeft: () => _left(entry.key),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (index > 0) const Divider(height: 1),
                _ProgressEntryRow(
                  progress: entry.item,
                  posterUrl: widget.posters[entry.item.animeId] ?? '',
                  titleHeight: titleHeight,
                  titleStyle: titleStyle,
                  onOpen: widget.onOpen,
                  onOpenAnime: widget.onOpenAnime,
                  onRemove: widget.onRemove,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Entry {
  _Entry(this.item, {this.leaving = false});

  final WatchProgress item;
  final bool leaving;

  String get key => item.torrentKey;

  _Entry update(WatchProgress item) => _Entry(item);

  _Entry leave() => _Entry(item, leaving: true);
}

class _RowPresence extends StatefulWidget {
  const _RowPresence({
    required this.leaving,
    required this.onLeft,
    required this.child,
    super.key,
  });

  final bool leaving;
  final VoidCallback onLeft;
  final Widget child;

  @override
  State<_RowPresence> createState() => _RowPresenceState();
}

class _RowPresenceState extends State<_RowPresence>
    with SingleTickerProviderStateMixin {
  static const _removalDuration = Duration(milliseconds: 280);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _removalDuration,
    value: 1,
  );
  bool _animate = true;
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant _RowPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving == oldWidget.leaving) return;
    if (!widget.leaving) {
      _gone = false;
      _animate ? _controller.forward() : _controller.value = 1;
      return;
    }
    if (!_animate) {
      _controller.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
      return;
    }
    _controller.reverse().whenCompleteOrCancel(() {
      if (_controller.isDismissed) _leave();
    });
  }

  void _leave() {
    if (_gone) return;
    _gone = true;
    widget.onLeft();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        if (progress >= 1) return child!;
        final collapsed = Curves.easeOutCubic.transform(
          (1 - progress * 2).clamp(0.0, 1.0),
        );
        final dissolved = (progress * 2 - 1).clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: 1 - collapsed,
            child: BayerMasked(
              open: (dissolved * BayerMask.steps).round(),
              child: child,
            ),
          ),
        );
      },
    );
    return ExcludeFocus(
      excluding: widget.leaving,
      child: IgnorePointer(
        ignoring: widget.leaving,
        child: ExcludeSemantics(excluding: widget.leaving, child: row),
      ),
    );
  }
}

class _ProgressEntryRow extends StatelessWidget {
  const _ProgressEntryRow({
    required this.progress,
    required this.posterUrl,
    required this.titleHeight,
    required this.titleStyle,
    required this.onOpen,
    required this.onOpenAnime,
    required this.onRemove,
  });

  final WatchProgress progress;
  final String posterUrl;
  final double titleHeight;
  final TextStyle? titleStyle;
  final ValueChanged<WatchProgress> onOpen;
  final ValueChanged<WatchProgress> onOpenAnime;
  final ValueChanged<WatchProgress> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: progress.isFinished
          ? l10n.watchProgressPlayNextButton
          : l10n.watchProgressContinueButton,
      child: TapRow(
        inkKey: ValueKey('continue_watching_${progress.torrentKey}'),
        onTap: () => onOpen(progress),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 72,
                child: PosterImage(
                  url: posterUrl,
                  fallback: ColoredBox(
                    color: theme.colorScheme.surfaceContainer,
                    child: const Center(
                      child: PixelIcon(PixelGlyph.file, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: titleHeight,
                      child: Text(
                        progress.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    Text(
                      fileDisplayName(progress.fileName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    WatchProgressLine(
                      progress: progress,
                      showBar: false,
                      timesOnly: true,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<void>(
                tooltip: l10n.commonMoreActions,
                constraints: const BoxConstraints(minWidth: 160),
                icon: const PixelIcon(PixelGlyph.more, size: 16),
                itemBuilder: (_) => [
                  if (progress.hasAnime)
                    PopupMenuItem(
                      onTap: () => onOpenAnime(progress),
                      child: Text(l10n.downloadOpenAnime),
                    ),
                  PopupMenuItem(
                    onTap: () => onRemove(progress),
                    child: Text(l10n.continueWatchingRemove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
