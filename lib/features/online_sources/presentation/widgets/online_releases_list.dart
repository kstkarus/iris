import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/quality_badge.dart';
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
    this.horizontalPadding = 0,
    this.tabular = false,
    this.onOpenSource,
    super.key,
  });

  /// Noise rows while nothing is found yet: a few dubs is the usual case.
  static const _standInRows = 3;

  final String animeId;
  final AnimeTitles animeTitles;
  final String posterUrl;
  final Map<String, int> downloadedCounts;

  /// Horizontal gutter inside rows so tap/hover fills can bleed edge-to-edge
  /// while text and dividers align with the page frame.
  final double horizontalPadding;

  /// Single-line desktop table layout with right-aligned telemetry columns.
  final bool tabular;

  /// Optional inline handler (used by desktop anime details to stay in the
  /// same dossier frame instead of pushing a separate route).
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: RetryView(
                message: l10n.watchSourcesOnlineLoadError,
                onRetry: () => context.read<OnlineReleasesCubit>().load(),
              ),
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
    final dividerColor = DetailLayout.ruleColor(scheme).withValues(alpha: 0.45);
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

    Widget cell(_OnlineRowItem item) => Semantics(
      container: true,
      child: switch (item) {
        _ReleaseItem(:final release, :final watched) => _ReleaseRow(
          release: release,
          watched: watched,
          downloadedCount:
              downloadedCounts[downloadSourceKey(_link(release))] ?? 0,
          horizontalPadding: horizontalPadding,
          tabular: tabular,
          onTap: () => _open(context, release),
        ),
        _StandInItem() => _StandInRow(
          horizontalPadding: horizontalPadding,
          tabular: tabular,
        ),
      },
    );

    final list = DitherList<_OnlineRowItem>(
      padding: const EdgeInsets.only(bottom: 24),
      items: items,
      keyOf: (item) => item.key,
      removalDuration: const Duration(milliseconds: 240),
      separator: Divider(
        height: 1,
        thickness: 1,
        indent: tabular ? 0 : horizontalPadding,
        endIndent: tabular ? 0 : horizontalPadding,
        color: dividerColor,
      ),
      itemBuilder: (context, item) => cell(item),
    );
    if (!tabular) return list;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              FocusScope.of(context).nextFocus(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              FocusScope.of(context).previousFocus(),
        },
        child: list,
      ),
    );
  }

  String _link(OnlineRelease release) => OnlineSourceLink(
    provider: release.provider.name,
    releaseId: release.id,
    animeId: animeId,
  ).toString();

  void _open(BuildContext context, OnlineRelease release) {
    final sourceArgs = AnimePlayerSourceArgs(
      animeId: animeId,
      animeTitles: animeTitles,
      sourceTitle: release.dub,
      magnet: _link(release),
      posterUrl: posterUrl,
    );
    final handler = onOpenSource;
    if (handler != null) {
      handler(sourceArgs);
      return;
    }
    context.pushNamed('torrent-stream-files', extra: sourceArgs);
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
  const _StandInRow({required this.horizontalPadding, required this.tabular});

  static const _standIn = OnlineRelease(
    provider: OnlineProvider.anilibria,
    id: '',
    dub: 'Studio Dub',
    episodes: [],
    bestQuality: 1080,
  );

  final double horizontalPadding;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      enabled: true,
      semanticLabel: AppLocalizations.of(context).watchSourcesOnlineLoading,
      child: _ReleaseRow(
        release: _standIn,
        watched: false,
        downloadedCount: 0,
        horizontalPadding: horizontalPadding,
        tabular: tabular,
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
    required this.horizontalPadding,
    required this.tabular,
    required this.onTap,
  });

  final OnlineRelease release;

  /// The user watched from this dub before.
  final bool watched;
  final int downloadedCount;
  final double horizontalPadding;
  final bool tabular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final count = release.episodes.length;
    final quality = release.bestQuality;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
      fontSize: 15,
      height: 1.32,
      color: scheme.onSurface,
    );

    if (tabular) {
      final base = theme.textTheme.bodySmall;
      final sansSmall = base?.copyWith(
        fontFamily: DetailLayout.sansFont,
        color: scheme.onSurfaceVariant,
      );
      final monoSmall = DetailLayout.monoTelemetryStyle(
        base,
        color: scheme.onSurfaceVariant,
      );
      final statusFacts = downloadedCount > 0
          ? l10n.playerSourceDownloadedCount(downloadedCount)
          : null;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 2,
              color: watched ? scheme.onSurface : Colors.transparent,
            ),
          ),
        ),
        child: TapRow(
          inkKey: ValueKey(
            'online_release_${release.provider.name}_${release.id}',
          ),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 13,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    release.dub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                if (watched || statusFacts != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: SourceFactsLine(
                      watched: watched,
                      facts: statusFacts,
                    ),
                  ),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 82),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: MixedDataText(
                          l10n.animeEpisodeCount('$count', count),
                          maxLines: 1,
                          sansStyle: sansSmall,
                          monoStyle: monoSmall,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 92),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: quality != null && quality > 0
                          ? QualityBadge(
                              l10n.watchSourcesOnlineBestQuality(quality),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                PixelIcon(
                  PixelGlyph.arrowRight,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final facts = [
      if (count > 0) l10n.animeEpisodeCount('$count', count),
      if (downloadedCount > 0)
        l10n.playerSourceDownloadedCount(downloadedCount),
    ];

    return TapRow(
      inkKey: ValueKey('online_release_${release.provider.name}_${release.id}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(release.dub, style: titleStyle),
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
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
