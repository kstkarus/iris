import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/poster_image.dart';
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = watchAnimeTitleLabels(context, title.animeTitles).primary;
    final poster = showPoster
        ? DownloadTitlePoster(title: title, width: 56)
        : null;
    final metaSans = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurfaceVariant,
    );
    final metaMono = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: scheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (poster != null) ...[poster, const SizedBox(width: 16)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              PixelSeparatedText.spans([
                DetailLayout.mixedDataSpan(
                  l10n.downloadTitleReady(
                    title.count(DownloadStatus.completed),
                    title.items.length,
                  ),
                  sansStyle: metaSans,
                  monoStyle: metaMono,
                ),
                DetailLayout.mixedDataSpan(
                  _titleBytes(l10n, title),
                  sansStyle: metaSans,
                  monoStyle: metaMono,
                ),
              ], style: metaSans),
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
    this.selectionActions,
    this.onHoldToSelect,
    super.key,
  });

  final DownloadTitle? title;
  final bool desktop;
  final Widget? menu;
  final Widget Function(Widget? header) buildList;
  final Widget? selectionActions;
  final VoidCallback? onHoldToSelect;

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
    if (widget.desktop) return const SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('download_header_expanded_identity'),
          child: HeadlineAnchor(
            key: _expandedIdentityKey,
            child: _holdToSelect(
              Semantics(
                header: true,
                child: DownloadTitleIdentity(title: title),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _holdToSelect(Widget child) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    supportedDevices: const {PointerDeviceKind.touch},
    onLongPress: widget.onHoldToSelect,
    child: child,
  );

  Widget _toolbar() {
    final title = widget.title;
    final selecting = widget.selectionActions != null;
    final scheme = Theme.of(context).colorScheme;
    final actionTextStyle =
        TextButtonTheme.of(context).style?.textStyle?.resolve(const {}) ??
        Theme.of(context).textTheme.labelLarge;
    final toolbar = Row(
      children: [
        if (!widget.desktop)
          Transform.translate(
            offset: const Offset(-10, 0),
            child: const BackButton(),
          ),
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
                          label: watchAnimeTitleLabels(
                            context,
                            title.animeTitles,
                          ).primary,
                          child: _CollapsedDownloadTitle(
                            title: title,
                            showPoster: false,
                          ),
                        )
                      : _CollapsedDownloadTitle(title: title, showPoster: true),
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
              final identity = title != null && (shown || widget.desktop)
                  ? _holdToSelect(switcher)
                  : switcher;
              return widget.desktop
                  ? identity
                  : ExcludeSemantics(child: identity);
            },
          ),
        ),
        if (widget.menu != null) ...[const SizedBox(width: 8), widget.menu!],
      ],
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _headlineGone,
      builder: (context, shown, child) => DecoratedBox(
        key: _toolbarKey,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: !widget.desktop || shown || selecting
                  ? DetailLayout.ruleColor(scheme)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.desktop ? 12 : 4),
          child: child,
        ),
      ),
      child: Stack(
        children: [
          // Keep measuring the original toolbar: entering selection must
          // not move the episodes, including with a wrapped desktop title.
          ExcludeFocus(
            excluding: selecting,
            child: IgnorePointer(
              ignoring: selecting,
              child: ExcludeSemantics(
                excluding: selecting,
                child: AnimatedOpacity(
                  opacity: selecting ? 0 : 1,
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 200),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _lineHeight(context, actionTextStyle),
                    ),
                    child: toolbar,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !selecting,
              child: ExcludeSemantics(
                excluding: !selecting,
                child: DitherSwitcher(
                  expand: true,
                  duration: const Duration(milliseconds: 200),
                  child: selecting
                      ? Row(
                          key: const ValueKey('download_delete_actions'),
                          children: [
                            if (widget.desktop && title != null) ...[
                              Expanded(
                                child: _CollapsedDownloadTitle(
                                  title: title,
                                  showPoster: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Flexible(
                              fit: FlexFit.tight,
                              child: widget.selectionActions!,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('download_delete_no_actions'),
                        ),
                ),
              ),
            ),
          ),
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
    final theme = Theme.of(context);
    final name = watchAnimeTitleLabels(context, title.animeTitles).primary;
    return Row(
      children: [
        if (showPoster) ...[
          SizedBox(
            width: 24,
            height: 36,
            child: DownloadTitlePoster(title: title, width: 24),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Tooltip(
            message: name,
            child: ExcludeSemantics(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                  fontWeight: FontWeight.w600,
                ),
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
        borderColor: DetailLayout.ruleColor(Theme.of(context).colorScheme),
        fallback: showFallbackTitle
            ? _PosterFallback(
                watchAnimeTitleLabels(context, title.animeTitles).primary,
              )
            : null,
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
    final scheme = theme.colorScheme;
    final status = downloadTitleStatus(title);
    final statusMark = _statusMark(context, status);
    final l10n = AppLocalizations.of(context);
    final activity = downloadTitleActivity(l10n, title);
    final name = watchAnimeTitleLabels(context, title.animeTitles).primary;
    final countText = l10n.downloadTitleEpisodeCount(
      title.count(DownloadStatus.completed),
      title.items.length,
    );
    final bytes = _titleByteCount(title);
    final metaSans = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurfaceVariant,
    );
    final metaMono = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: scheme.onSurfaceVariant,
    );
    final downloading = status == DownloadStatus.downloading;
    final progress = downloading ? _titleProgress(title) : 0.0;

    return Tooltip(
      message: name,
      child: Semantics(
        label: '$name, $activity',
        selected: selected,
        button: true,
        child: TapRow(
          inkKey: ValueKey('download_title_${title.key}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 150),
            ),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? scheme.surfaceContainer : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DownloadTitlePoster(title: title, width: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: DetailLayout.sansFont,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                height: 1.2,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (statusMark != null) ...[
                                  statusMark,
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: PixelSeparatedText.spans(
                                    [
                                      DetailLayout.mixedDataSpan(
                                        countText,
                                        sansStyle: metaSans,
                                        monoStyle: metaMono,
                                      ),
                                      if (bytes > 0)
                                        DetailLayout.mixedDataSpan(
                                          formatByteSize(
                                            l10n,
                                            bytes,
                                            compact: true,
                                          ),
                                          sansStyle: metaSans,
                                          monoStyle: metaMono,
                                        ),
                                    ],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: metaSans,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (downloading && progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ThinProgressBar(
                      value: progress,
                      height: 2,
                      color: scheme.tertiary,
                      trackColor: Colors.transparent,
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
    this.onEmptied,
    super.key,
  });

  final List<DownloadTitle> titles;
  final ValueChanged<DownloadTitle> onOpenTitle;
  final VoidCallback? onEmptied;

  @override
  Widget build(BuildContext context) {
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
          removalDuration: const Duration(milliseconds: 320),
          onEmptied: onEmptied,
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final activity = downloadTitleActivity(l10n, title);
    final name = watchAnimeTitleLabels(context, title.animeTitles).primary;
    final status = downloadTitleStatus(title);
    final statusMark = _statusMark(context, status);
    final posterWidth = horizontal ? 80.0 : double.infinity;
    final titleStyle = theme.textTheme.titleSmall!.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurface,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final countSans = theme.textTheme.labelMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
    );
    final countMono = DetailLayout.monoTelemetryStyle(
      theme.textTheme.labelMedium,
      color: scheme.onSurfaceVariant,
    );
    final titleCount = l10n.downloadTitleEpisodeCount(
      title.count(DownloadStatus.completed),
      title.items.length,
    );
    final bytes = _titleByteCount(title);
    final countWidget = MixedDataText(
      titleCount,
      key: ValueKey('download_title_count_${title.key}'),
      sansStyle: countSans,
      monoStyle: countMono,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final factsRow = Row(
      children: [
        if (statusMark != null) ...[statusMark, const SizedBox(width: 6)],
        Expanded(child: countWidget),
        if (bytes > 0) ...[
          const SizedBox(width: 8),
          Text(formatByteSize(l10n, bytes, compact: true), style: countMono),
        ],
      ],
    );
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      label: '$name, $titleCount, $activity',
      child: Tooltip(
        message: '$name\n$titleCount\n$activity',
        child: TapRow(
          inkKey: ValueKey('download_title_${title.key}'),
          onTap: onTap,
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _galleryPoster(context, posterWidth, status),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: titleStyle),
                          const SizedBox(height: 6),
                          factsRow,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _galleryPoster(context, posterWidth, status),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: _lineHeight(context, titleStyle, lines: 2),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    factsRow,
                  ],
                ),
        ),
      ),
    );
  }

  Widget _galleryPoster(
    BuildContext context,
    double width,
    DownloadStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final downloading = status == DownloadStatus.downloading;
    final progress = downloading ? _titleProgress(title) : 0.0;
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          DownloadTitlePoster(title: title, width: width),
          if (downloading && progress > 0)
            Positioned(
              left: 1,
              right: 1,
              bottom: 1,
              child: ExcludeSemantics(
                child: _ThinProgressBar(
                  value: progress,
                  height: 3,
                  color: scheme.tertiary,
                  trackColor: DetailLayout.progressTrackColor(scheme),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
            fontFamily: DetailLayout.sansFont,
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

Widget? _statusMark(BuildContext context, DownloadStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    DownloadStatus.downloading => SizedBox.square(
      dimension: 6,
      child: ColoredBox(color: scheme.tertiary),
    ),
    DownloadStatus.failed => PixelIcon(
      PixelGlyph.close,
      size: 10,
      color: scheme.error,
    ),
    DownloadStatus.paused || DownloadStatus.queued => SizedBox.square(
      dimension: 6,
      child: ColoredBox(color: scheme.onSurfaceVariant),
    ),
    DownloadStatus.completed => null,
  };
}

class _ThinProgressBar extends StatelessWidget {
  const _ThinProgressBar({
    required this.value,
    required this.height,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double height;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ColoredBox(
        color: trackColor,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: clamped, end: clamped),
          duration: motionDuration(context, const Duration(milliseconds: 240)),
          curve: Curves.easeOutCubic,
          builder: (context, filled, _) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: filled,
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

int _titleByteCount(DownloadTitle title) =>
    title.items.fold<int>(0, (sum, item) => sum + item.downloadedBytes);

String _titleBytes(AppLocalizations l10n, DownloadTitle title) =>
    formatByteSize(l10n, _titleByteCount(title));

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
