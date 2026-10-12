import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/utils/watched_first.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/source_facts_line.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// The anime's releases on video servers, one row per dub, the dubs the
/// user watched from first. A row opens the release's episodes in the
/// file picker, and its download button in the download picker, as a
/// torrent row does.
///
/// Rows come as the servers answer: each answer develops the list anew out
/// of the last one, and while a server is still searching a noise row
/// waits at the end. The page hides the list when no server has the anime.
class OnlineReleasesList extends StatelessWidget {
  const OnlineReleasesList({
    required this.animeId,
    required this.animeTitle,
    super.key,
  });

  /// Noise rows while nothing is found yet: a few dubs is the usual case.
  static const _standInRows = 3;

  static const _minColumnWidth = 280.0;
  static const _columnGap = 24.0;

  final String animeId;

  /// How history names the anime of a release played from here.
  final String animeTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnlineReleasesCubit, OnlineReleasesState>(
      builder: (context, state) {
        final (Object key, Widget list) = switch (state) {
          // Nothing found: the noise stays while the page lets the list go.
          OnlineReleasesLoading() || OnlineReleasesEmpty() => (
            'searching',
            _rows(context, const [], standIns: _standInRows),
          ),
          OnlineReleasesLoaded(:final releases, :final searching) => (
            '${releases.length} $searching',
            _rows(context, releases, standIns: searching ? 1 : 0),
          ),
          OnlineReleasesFailure() => (
            'failure',
            RetryView(
              message: l10n.watchSourcesOnlineLoadError,
              onRetry: () => context.read<OnlineReleasesCubit>().load(),
            ),
          ),
        };
        return DitherSwitcher(
          expand: true,
          child: KeyedSubtree(key: ValueKey(key), child: list),
        );
      },
    );
  }

  Widget _rows(
    BuildContext context,
    List<OnlineRelease> releases, {
    required int standIns,
  }) {
    final watchedLinks = {
      for (final progress in context.watchWatchProgress()) progress.magnet,
    };
    bool watched(OnlineRelease release) =>
        watchedLinks.contains(_link(release));
    final ordered = watchedFirst(releases, watched);
    // Each dub its own node: dubs side by side would be heard, and
    // tapped, as one.
    Widget cell(int index) => Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SegmentedRule(),
          if (index < ordered.length)
            _ReleaseRow(
              release: ordered[index],
              watched: watched(ordered[index]),
              onTap: () => _open(context, ordered[index]),
              onDownload: () => _download(context, ordered[index]),
            )
          else
            const _StandInRow(),
        ],
      ),
    );
    final count = ordered.length + standIns;
    // A dub's name is short: wide windows set the dubs in columns, read
    // row by row, rather than one narrow line across the whole width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: _minColumnWidth,
          spacing: _columnGap,
        );
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: (count / columns).ceil(),
          itemBuilder: (context, row) => AdaptiveGridRow(
            columns: columns,
            spacing: _columnGap,
            children: [
              for (
                var index = row * columns;
                index < count && index < (row + 1) * columns;
                index++
              )
                cell(index),
            ],
          ),
        );
      },
    );
  }

  String _link(OnlineRelease release) => OnlineSourceLink(
    provider: release.provider.name,
    releaseId: release.id,
    animeId: animeId,
  ).toString();

  void _open(BuildContext context, OnlineRelease release) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: animeId,
        animeTitle: animeTitle,
        sourceTitle: release.dub,
        magnet: _link(release),
      ),
    );
  }

  void _download(BuildContext context, OnlineRelease release) {
    context.pushNamed(
      'torrent-download-files',
      extra: DownloadSelectionArgs(
        animeId: animeId,
        animeTitle: animeTitle,
        sourceTitle: release.dub,
        magnet: _link(release),
      ),
    );
  }
}

/// A row's shape in noise while a server is still searching.
class _StandInRow extends StatelessWidget {
  const _StandInRow();

  static const _standIn = OnlineRelease(
    provider: OnlineProvider.anilibria,
    id: '',
    dub: 'AniLibria',
    episodes: [],
    bestQuality: 1080,
  );

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      enabled: true,
      semanticLabel: AppLocalizations.of(context).watchSourcesOnlineLoading,
      child: _ReleaseRow(
        release: _standIn,
        watched: false,
        onTap: () {},
        onDownload: () {},
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({
    required this.release,
    required this.watched,
    required this.onTap,
    required this.onDownload,
  });

  final OnlineRelease release;

  /// The user watched from this dub before.
  final bool watched;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final count = release.episodes.length;
    final quality = release.bestQuality;
    final facts = [
      // The stand-in has no episodes to count.
      if (count > 0) l10n.animeEpisodeCount('$count', count),
      if (quality != null) l10n.watchSourcesOnlineBestQuality(quality),
    ].join(' · ');

    return TapRow(
      inkKey: ValueKey('online_release_${release.provider.name}_${release.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(release.dub, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  SourceFactsLine(
                    watched: watched,
                    facts: facts.isEmpty ? null : facts,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: ValueKey(
                'online_release_download_${release.provider.name}_${release.id}',
              ),
              tooltip: l10n.downloadsOpenButton,
              icon: const PixelIcon(PixelGlyph.download, size: 18),
              onPressed: onDownload,
            ),
          ],
        ),
      ),
    );
  }
}
