import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class DownloadTitleIdentity extends StatelessWidget {
  const DownloadTitleIdentity({
    required this.title,
    this.showPoster = true,
    this.trailing,
    super.key,
  });

  final DownloadTitle title;
  final bool showPoster;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final poster = showPoster
        ? DownloadTitlePoster(title: title, width: 56)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (poster != null) ...[poster, const SizedBox(width: 16)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${l10n.downloadTitleReady(title.count(DownloadStatus.completed), title.items.length)} · ${_titleBytes(l10n, title)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class DownloadAdaptiveTitleHeader extends StatefulWidget {
  const DownloadAdaptiveTitleHeader({
    required this.title,
    required this.desktop,
    required this.menu,
    required this.buildList,
    super.key,
  });

  final DownloadTitle? title;
  final bool desktop;
  final Widget? menu;
  final Widget Function(Widget? header) buildList;

  @override
  State<DownloadAdaptiveTitleHeader> createState() =>
      _DownloadAdaptiveTitleHeaderState();
}

class _DownloadAdaptiveTitleHeaderState
    extends State<DownloadAdaptiveTitleHeader> {
  final _headline = HeadlineTracker();
  final _headlineGone = ValueNotifier(false);
  final _toolbarKey = GlobalKey();
  final _expandedIdentityKey = GlobalKey();
  double _scrollPixels = 0;
  double? _collapseOffset;
  bool _headlineCheckQueued = false;

  @override
  void dispose() {
    _headlineGone.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DownloadAdaptiveTitleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title?.key != widget.title?.key ||
        oldWidget.desktop != widget.desktop) {
      _headlineGone.value = false;
      _scrollPixels = 0;
      _collapseOffset = null;
      _queueHeadlineCheck();
    }
  }

  bool _checkHeadline(Notification notification) {
    if (notification is ScrollMetricsNotification) {
      _scrollPixels = notification.metrics.pixels;
    } else if (notification is ScrollNotification) {
      _scrollPixels = notification.metrics.pixels;
    }
    _queueHeadlineCheck();
    return false;
  }

  void _queueHeadlineCheck() {
    if (_headlineCheckQueued) return;
    _headlineCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headlineCheckQueued = false;
      if (!mounted) return;
      if (widget.desktop) {
        _headlineGone.value = _scrollPixels > 0;
        return;
      }

      final expandedContext = _expandedIdentityKey.currentContext;
      final toolbarContext = _toolbarKey.currentContext;
      final expanded = expandedContext != null && expandedContext.mounted
          ? expandedContext.findRenderObject()
          : null;
      final toolbar = toolbarContext != null && toolbarContext.mounted
          ? toolbarContext.findRenderObject()
          : null;
      if (expanded is RenderBox &&
          expanded.attached &&
          expanded.hasSize &&
          toolbar is RenderBox &&
          toolbar.attached &&
          toolbar.hasSize) {
        final expandedBottom = expanded
            .localToGlobal(Offset(0, expanded.size.height))
            .dy;
        final toolbarBottom = toolbar
            .localToGlobal(Offset(0, toolbar.size.height))
            .dy;
        _collapseOffset = expandedBottom - toolbarBottom + _scrollPixels;
        _headlineGone.value = _headline.isAbove(toolbarBottom);
      } else if (_collapseOffset case final offset?) {
        _headlineGone.value = _scrollPixels >= offset;
      }
    });
  }

  Widget? _listHeader() {
    final title = widget.title;
    if (title == null) return null;
    if (widget.desktop) return const SizedBox(height: 24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const Key('download_header_expanded_identity'),
          child: HeadlineAnchor(
            key: _expandedIdentityKey,
            child: Semantics(
              header: true,
              child: DownloadTitleIdentity(title: title),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _toolbar() {
    final title = widget.title;
    return Container(
      key: _toolbarKey,
      child: Row(
        children: [
          if (!widget.desktop) const BackButton(),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _headlineGone,
              builder: (context, shown, _) {
                final Widget titleWidget;
                if (shown && title != null) {
                  titleWidget = KeyedSubtree(
                    key: const Key('download_header_compact_identity'),
                    child: widget.desktop
                        ? Semantics(
                            header: true,
                            label: title.name,
                            child: _CollapsedDownloadTitle(
                              title: title,
                              showPoster: false,
                            ),
                          )
                        : _CollapsedDownloadTitle(
                            title: title,
                            showPoster: true,
                          ),
                  );
                } else if (widget.desktop && title != null) {
                  titleWidget = KeyedSubtree(
                    key: const Key('download_header_expanded_identity'),
                    child: Semantics(
                      header: true,
                      child: DownloadTitleIdentity(
                        title: title,
                        showPoster: false,
                      ),
                    ),
                  );
                } else {
                  titleWidget = const SizedBox.shrink(
                    key: ValueKey('download_header_empty'),
                  );
                }
                final switcher = DitherSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: titleWidget,
                );
                return widget.desktop
                    ? switcher
                    : ExcludeSemantics(child: switcher);
              },
            ),
          ),
          if (widget.menu != null) ...[const SizedBox(width: 8), widget.menu!],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _queueHeadlineCheck();
    final list = widget.buildList(_listHeader());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(key: const Key('download_header_bar'), child: _toolbar()),
        if (!widget.desktop) const SizedBox(height: 8),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _checkHeadline,
            child: NotificationListener<ScrollNotification>(
              onNotification: _checkHeadline,
              child: HeadlineScope(tracker: _headline, child: list),
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsedDownloadTitle extends StatelessWidget {
  const _CollapsedDownloadTitle({
    required this.title,
    required this.showPoster,
  });

  final DownloadTitle title;
  final bool showPoster;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(
      children: [
        if (showPoster) ...[
          SizedBox(
            width: 24,
            height: 36,
            child: DownloadTitlePoster(title: title, width: 24),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Tooltip(
            message: title.name,
            child: ExcludeSemantics(
              child: DefaultTextStyle(
                style: style ?? const TextStyle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: PageTitle(title: title.name),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DownloadTitlePoster extends StatelessWidget {
  const DownloadTitlePoster({
    required this.title,
    required this.width,
    this.showFallbackTitle = false,
    super.key,
  });

  final DownloadTitle title;
  final double width;
  final bool showFallbackTitle;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: ExcludeSemantics(
      child: PosterImage(
        url: title.posterUrl,
        fallback: showFallbackTitle ? _PosterFallback(title.name) : null,
      ),
    ),
  );
}

class DownloadPosterOption extends StatelessWidget {
  const DownloadPosterOption({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final DownloadTitle title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = downloadTitleStatus(title);
    final statusColor = downloadTitleStatusColor(context, title);
    final l10n = AppLocalizations.of(context);
    final activity = downloadTitleActivity(l10n, title);
    return Tooltip(
      message: title.name,
      child: Semantics(
        label: '${title.name}, $activity',
        selected: selected,
        button: true,
        child: TapRow(
          inkKey: ValueKey('download_title_${title.key}'),
          onTap: onTap,
          child: SizedBox(
            width: 76,
            child: Stack(
              children: [
                DownloadTitlePoster(
                  title: title,
                  width: 76,
                  showFallbackTitle: true,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: _downloadStatusBadge(
                    context,
                    status,
                    statusColor,
                    fill: status == DownloadStatus.downloading
                        ? _titleProgress(title)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadLibraryGallery extends StatelessWidget {
  const DownloadLibraryGallery({
    required this.titles,
    required this.onOpenTitle,
    required this.menu,
    super.key,
  });

  final List<DownloadTitle> titles;
  final ValueChanged<DownloadTitle> onOpenTitle;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final horizontal = scale >= 1.5;
        final columns = horizontal ? 1 : _galleryColumns(constraints.maxWidth);
        final gap = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return DitherList<DownloadTitle>(
          padding: const EdgeInsets.only(bottom: 32),
          items: titles,
          keyOf: (title) => title.key,
          crossAxisCount: columns,
          columnSpacing: gap,
          rowSpacing: constraints.maxWidth < 600 ? 24 : 32,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    l10n.downloadLibraryCount(titles.length),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  menu,
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SegmentedRule(),
              ),
              const SizedBox(height: 18),
            ],
          ),
          itemBuilder: (context, title) => _GalleryTitle(
            title: title,
            horizontal: horizontal,
            onTap: () => onOpenTitle(title),
          ),
        );
      },
    );
  }
}

class _GalleryTitle extends StatelessWidget {
  const _GalleryTitle({
    required this.title,
    required this.horizontal,
    required this.onTap,
  });

  final DownloadTitle title;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final activity = downloadTitleActivity(l10n, title);
    final badgeStatus = _galleryBadgeStatus(title);
    final badgeColor = badgeStatus == DownloadStatus.failed
        ? theme.colorScheme.error
        : downloadTitleStatusColor(context, title);
    final posterWidth = horizontal ? 80.0 : double.infinity;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final countStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titleCount = l10n.downloadTitleEpisodeCount(
      title.count(DownloadStatus.completed),
      title.items.length,
    );
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: '${title.name}, $titleCount, $activity',
      child: Tooltip(
        message: '${title.name}\n$titleCount\n$activity',
        child: TapRow(
          inkKey: ValueKey('download_title_${title.key}'),
          onTap: onTap,
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _galleryPoster(
                      context,
                      posterWidth,
                      badgeStatus,
                      badgeColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title.name, style: titleStyle),
                          const SizedBox(height: 5),
                          Text(
                            titleCount,
                            key: ValueKey('download_title_count_${title.key}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: countStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _galleryPoster(
                      context,
                      posterWidth,
                      badgeStatus,
                      badgeColor,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: _lineHeight(context, titleStyle, lines: 2),
                      child: Text(
                        title.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      titleCount,
                      key: ValueKey('download_title_count_${title.key}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: countStyle,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _galleryPoster(
    BuildContext context,
    double width,
    DownloadStatus? status,
    Color color,
  ) => SizedBox(
    width: width,
    child: Stack(
      children: [
        DownloadTitlePoster(title: title, width: width),
        if (status != null)
          Positioned(
            right: 5,
            bottom: 5,
            child: ExcludeSemantics(
              child: _downloadStatusBadge(context, status, color),
            ),
          ),
      ],
    ),
  );
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          title,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

String downloadTitleActivity(AppLocalizations l10n, DownloadTitle title) {
  final active = [
    for (final status in const [
      DownloadStatus.downloading,
      DownloadStatus.failed,
      DownloadStatus.paused,
      DownloadStatus.queued,
    ])
      if (title.count(status) > 0)
        '${downloadStatusLabel(l10n, status)}: ${title.count(status)}',
  ];
  return active.isEmpty
      ? downloadStatusLabel(l10n, DownloadStatus.completed)
      : active.join(' · ');
}

DownloadStatus downloadTitleStatus(DownloadTitle title) {
  for (final status in const [
    DownloadStatus.downloading,
    DownloadStatus.failed,
    DownloadStatus.paused,
    DownloadStatus.queued,
    DownloadStatus.completed,
  ]) {
    if (title.count(status) > 0) return status;
  }
  return DownloadStatus.completed;
}

Color downloadTitleStatusColor(BuildContext context, DownloadTitle title) =>
    switch (downloadTitleStatus(title)) {
      DownloadStatus.downloading => Theme.of(context).colorScheme.tertiary,
      DownloadStatus.failed => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };

String _titleBytes(AppLocalizations l10n, DownloadTitle title) =>
    formatByteSize(
      l10n,
      title.items.fold<int>(0, (sum, item) => sum + item.downloadedBytes),
    );

double _lineHeight(BuildContext context, TextStyle? style, {int lines = 2}) {
  final painter = TextPainter(
    text: TextSpan(text: List.filled(lines, 'Mg').join('\n'), style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: lines,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

DownloadStatus? _galleryBadgeStatus(DownloadTitle title) {
  if (title.count(DownloadStatus.failed) > 0) return DownloadStatus.failed;
  final status = downloadTitleStatus(title);
  return status == DownloadStatus.completed ? null : status;
}

Widget _downloadStatusBadge(
  BuildContext context,
  DownloadStatus status,
  Color color, {
  double? fill,
}) => DecoratedBox(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    border: Border.all(color: color),
  ),
  child: Padding(
    padding: const EdgeInsets.all(3),
    child: PixelIcon(_statusGlyph(status), size: 14, color: color, fill: fill),
  ),
);

double _titleProgress(DownloadTitle title) {
  final downloading = title.items.where(
    (item) => item.status == DownloadStatus.downloading,
  );
  final items = downloading.isEmpty ? title.items : downloading;
  final total = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
  if (total <= 0) return 0;
  return (items.fold<int>(0, (sum, item) => sum + item.downloadedBytes) / total)
      .clamp(0.0, 1.0);
}

int _galleryColumns(double width) {
  if (width >= 1180) return 5;
  if (width >= 880) return 4;
  if (width >= 620) return 3;
  return width >= 340 ? 2 : 1;
}

PixelGlyph _statusGlyph(DownloadStatus status) => switch (status) {
  DownloadStatus.queued || DownloadStatus.downloading => PixelGlyph.download,
  DownloadStatus.paused => PixelGlyph.pause,
  DownloadStatus.failed => PixelGlyph.close,
  DownloadStatus.completed => PixelGlyph.check,
};
