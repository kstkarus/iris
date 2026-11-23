import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
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
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/quality_badge.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/source_facts_line.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// The anime's releases on video servers, one row per dub, the dubs the
/// user watched from first. Each row opens the release's episodes.
///
/// Rows come as the servers answer, updating the same list after its first
/// reveal. While a server is still searching a noise row waits at the end.
/// The page hides the list when no server has the anime.
class OnlineReleasesList extends StatelessWidget {
  const OnlineReleasesList({
    required this.animeId,
    required this.animeTitles,
    this.posterUrl = '',
    this.downloadedCounts = const {},
    super.key,
  });

  /// Noise rows while nothing is found yet: a few dubs is the usual case.
  static const _standInRows = 3;

  static const _minColumnWidth = 280.0;
  static const _columnGap = 24.0;

  final String animeId;

  final AnimeTitles animeTitles;
  final String posterUrl;
  final Map<String, int> downloadedCounts;

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
            'loaded',
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
    final scheme = Theme.of(context).colorScheme;
    final items = <_OnlineRowItem>[
      for (final release in ordered)
        _ReleaseItem(
          key: _link(release),
          release: release,
          watched: watched(release),
        ),
      for (var index = 0; index < standIns; index++)
        _StandInItem(key: ('stand_in', index)),
    ];
    // Each dub its own node: dubs side by side would be heard, and
    // tapped, as one.
    Widget cell(_OnlineRowItem item) => Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: DetailLayout.ruleColor(scheme)),
          ),
          child: switch (item) {
            _ReleaseItem(:final release, :final watched) => _ReleaseRow(
              release: release,
              watched: watched,
              downloadedCount:
                  downloadedCounts[downloadSourceKey(_link(release))] ?? 0,
              onTap: () => _open(context, release),
            ),
            _StandInItem() => const _StandInRow(),
          },
        ),
      ),
    );
    // A dub's name is short: wide windows set the dubs in columns, read
    // row by row, rather than one narrow line across the whole width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: _minColumnWidth,
          spacing: _columnGap,
        );
        return DitherList<_OnlineRowItem>(
          padding: const EdgeInsets.only(bottom: 24),
          items: items,
          keyOf: (item) => item.key,
          crossAxisCount: columns,
          columnSpacing: _columnGap,
          removalDuration: const Duration(milliseconds: 240),
          itemBuilder: (context, item) => cell(item),
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
        animeTitles: animeTitles,
        sourceTitle: release.dub,
        magnet: _link(release),
        posterUrl: posterUrl,
      ),
    );
  }
}

/// An entry in [OnlineReleasesList]: either a resolved dub or a trailing noise
/// row while a slower server is still searching.
sealed class _OnlineRowItem {
  const _OnlineRowItem(this.key);

  final Object key;
}

final class _ReleaseItem extends _OnlineRowItem {
  const _ReleaseItem({
    required Object key,
    required this.release,
    required this.watched,
  }) : super(key);

  final OnlineRelease release;
  final bool watched;
}

final class _StandInItem extends _OnlineRowItem {
  const _StandInItem({required Object key}) : super(key);
}

/// A row's shape in noise while a server is still searching.
class _StandInRow extends StatelessWidget {
  const _StandInRow();

  static const _standIn = OnlineRelease(
    provider: OnlineProvider.anilibria,
    id: '',
    dub: 'Studio Dub',
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
        downloadedCount: 0,
        onTap: () {},
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({
    required this.release,
    required this.watched,
    required this.downloadedCount,
    required this.onTap,
  });

  final OnlineRelease release;

  /// The user watched from this dub before.
  final bool watched;
  final int downloadedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final count = release.episodes.length;
    final quality = release.bestQuality;
    final facts = [
      if (count > 0) l10n.animeEpisodeCount('$count', count),
      if (downloadedCount > 0)
        l10n.playerSourceDownloadedCount(downloadedCount),
    ];

    return TapRow(
      inkKey: ValueKey('online_release_${release.provider.name}_${release.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    release.dub,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (watched || facts.isNotEmpty)
                        SourceFactsLine(
                          watched: watched,
                          facts: facts.isEmpty ? null : facts.join(' · '),
                          cleanLineWrap: true,
                        ),
                      if (quality != null && quality > 0)
                        QualityBadge(
                          l10n.watchSourcesOnlineBestQuality(quality),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PixelIcon(
              PixelGlyph.arrowRight,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
