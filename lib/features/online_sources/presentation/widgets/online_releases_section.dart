import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_source_link.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The anime's releases on video servers, one row each, over its torrents.
/// A row opens the release's episodes in the file picker, as a torrent row
/// opens its files. Nothing is shown when no server has the anime.
class OnlineReleasesSection extends StatelessWidget {
  const OnlineReleasesSection({
    required this.animeId,
    required this.animeTitle,
    super.key,
  });

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
            child: _ReleaseRow(release: _standIn, onTap: () {}),
          ),
          OnlineReleasesLoaded(:final releases) => AppSkeleton(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, release) in releases.indexed) ...[
                  if (index > 0) const SegmentedRule(),
                  _ReleaseRow(
                    release: release,
                    onTap: () => _open(context, release),
                  ),
                ],
              ],
            ),
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

  void _open(BuildContext context, OnlineRelease release) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: animeId,
        animeTitle: animeTitle,
        sourceTitle: release.dub,
        magnet: OnlineSourceLink(
          provider: release.provider,
          releaseId: release.id,
        ).toString(),
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
  const _ReleaseRow({required this.release, required this.onTap});

  final OnlineRelease release;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final link = OnlineSourceLink(
      provider: release.provider,
      releaseId: release.id,
    ).toString();
    final key = torrentKeyFromMagnet(link);
    final watched = context.watchWatchProgress().any(
      (progress) => progress.torrentKey == key,
    );
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
        key: ValueKey('online_release_$link'),
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
