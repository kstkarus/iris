import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The anime's releases on video servers, one row per dub, over its
/// torrents. A row opens the release's episodes in the file picker, as a
/// torrent row opens its files. Nothing is shown when no server has the
/// anime.
///
/// An anime may have dozens of dubs: the page keeps [shownRows] of them,
/// those watched from first, and lists the rest in a sheet, so the torrents
/// stay on screen.
class OnlineReleasesSection extends StatelessWidget {
  const OnlineReleasesSection({
    required this.animeId,
    required this.animeTitle,
    super.key,
  });

  static const shownRows = 3;

  final String animeId;

  /// How history names the anime of a release played from here.
  final String animeTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnlineReleasesCubit, OnlineReleasesState>(
      builder: (context, state) {
        final Widget rows = switch (state) {
          OnlineReleasesEmpty() => const SizedBox.shrink(),
          // The search takes a second or two; the row's shape is known.
          OnlineReleasesLoading() => AppSkeleton(
            enabled: true,
            semanticLabel: l10n.watchSourcesOnlineLoading,
            child: _ReleaseRow(release: _standIn, watched: false, onTap: () {}),
          ),
          OnlineReleasesLoaded(:final releases) => AppSkeleton(
            enabled: false,
            child: _loadedRows(context, releases),
          ),
          OnlineReleasesFailure() => const _FailureRow(),
        };
        if (state is OnlineReleasesEmpty) return rows;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(l10n.watchSourcesOnlineSection),
            const SizedBox(height: 8),
            const SegmentedRule(),
            rows,
            const SegmentedRule(),
          ],
        );
      },
    );
  }

  Widget _loadedRows(BuildContext context, List<OnlineRelease> releases) {
    final l10n = AppLocalizations.of(context);
    final watchedLinks = {
      for (final progress in context.watchWatchProgress()) progress.magnet,
    };
    bool watched(OnlineRelease release) =>
        watchedLinks.contains(_link(release));
    final ordered = [
      ...releases.where(watched),
      ...releases.where((release) => !watched(release)),
    ];
    final shown = ordered.take(shownRows).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, release) in shown.indexed) ...[
          if (index > 0) const SegmentedRule(),
          _ReleaseRow(
            release: release,
            watched: watched(release),
            onTap: () => _open(context, release),
          ),
        ],
        if (ordered.length > shown.length) ...[
          const SegmentedRule(),
          _AllReleasesRow(
            count: ordered.length,
            onTap: () => showAdaptiveSheet<void>(
              context: context,
              builder: (sheetContext) => _AllReleasesSheet(
                title: l10n.watchSourcesOnlineAllTitle,
                releases: ordered,
                watched: watched,
                onSelected: (release) {
                  Navigator.of(sheetContext).pop();
                  _open(context, release);
                },
              ),
            ),
          ),
        ],
      ],
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
}

/// What the row looks like while the search runs.
const _standIn = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '',
  title: '',
  dub: 'AniLibria',
  episodes: [],
  bestQuality: 1080,
);

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({
    required this.release,
    required this.watched,
    required this.onTap,
  });

  final OnlineRelease release;

  /// The user watched from this dub before.
  final bool watched;
  final VoidCallback onTap;

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

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('online_release_${release.provider.name}_${release.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(release.dub, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    if (watched) ...[
                      TextSpan(
                        text: l10n.watchSourceUsedBadge,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      if (facts.isNotEmpty) const TextSpan(text: ' · '),
                    ],
                    TextSpan(text: facts),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way to the dubs the page does not show.
class _AllReleasesRow extends StatelessWidget {
  const _AllReleasesRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('online_releases_all'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            l10n.watchSourcesOnlineAll(count),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _AllReleasesSheet extends StatelessWidget {
  const _AllReleasesSheet({
    required this.title,
    required this.releases,
    required this.watched,
    required this.onSelected,
  });

  final String title;
  final List<OnlineRelease> releases;
  final bool Function(OnlineRelease release) watched;
  final ValueChanged<OnlineRelease> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: releases.length,
              separatorBuilder: (context, index) => const SegmentedRule(),
              itemBuilder: (context, index) => _ReleaseRow(
                release: releases[index],
                watched: watched(releases[index]),
                onTap: () => onSelected(releases[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A failed search says so in the row's place; torrents below still work.
class _FailureRow extends StatelessWidget {
  const _FailureRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.watchSourcesOnlineLoadError,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => context.read<OnlineReleasesCubit>().load(),
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
