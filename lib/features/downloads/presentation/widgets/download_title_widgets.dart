import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/dither_list.dart';
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
              if (title.count(DownloadStatus.completed) !=
                  title.items.length) ...[
                const SizedBox(height: 4),
                Text(
                  downloadTitleActivity(l10n, title),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: downloadTitleStatusColor(context, title),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: statusColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: PixelIcon(
                        _statusGlyph(status),
                        size: 14,
                        color: statusColor,
                        fill: status == DownloadStatus.downloading
                            ? _titleProgress(title)
                            : null,
                      ),
                    ),
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
    final status = downloadTitleStatus(title);
    final color = downloadTitleStatusColor(context, title);
    final posterWidth = horizontal ? 80.0 : double.infinity;
    return TapRow(
      inkKey: ValueKey('download_title_${title.key}'),
      onTap: onTap,
      child: horizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DownloadTitlePoster(title: title, width: posterWidth),
                const SizedBox(width: 16),
                Expanded(child: _caption(theme, l10n, status, color)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DownloadTitlePoster(title: title, width: posterWidth),
                const SizedBox(height: 8),
                _caption(theme, l10n, status, color),
              ],
            ),
    );
  }

  Widget _caption(
    ThemeData theme,
    AppLocalizations l10n,
    DownloadStatus status,
    Color color,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Tooltip(
        message: title.name,
        child: Text(
          title.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          Text(
            l10n.downloadTitleEpisodeCount(
              title.count(DownloadStatus.completed),
              title.items.length,
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            _titleBytes(l10n, title),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: PixelIcon(
              _statusGlyph(status),
              size: 15,
              color: color,
              fill: status == DownloadStatus.downloading
                  ? _titleProgress(title)
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              downloadTitleActivity(l10n, title),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ],
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
