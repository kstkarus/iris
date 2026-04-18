import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';

class AnimeDetailsView extends StatelessWidget {
  const AnimeDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeDetailsCubit, AnimeDetailsState>(
      builder: (context, state) {
        return switch (state) {
          AnimeDetailsInitial() ||
          AnimeDetailsLoading() => const _LoadingState(),
          AnimeDetailsSuccess(:final details) => _SuccessState(
            details: details,
          ),
          AnimeDetailsFailure() => const _FailureState(),
        };
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.animeDetailsLoading),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 220,
                height: 320,
                child: Image.network(
                  details.posterOriginalUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.movie_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            details.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (details.russian.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details.russian,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: formatAnimeKindAndStatus(
                  l10n,
                  details.kind,
                  details.status,
                ),
              ),
              _MetaChip(label: formatAnimeScore(l10n, details.score)),
              _MetaChip(
                label: formatEpisodeProgress(
                  l10n,
                  details.episodesAired,
                  details.episodes,
                ),
              ),
              _MetaChip(label: formatAiredOn(l10n, details.airedOn)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.pushNamed(
                  'anime-watch-sources',
                  pathParameters: {'id': details.id},
                  extra: AnimeWatchSourcesArgs(
                    animeId: details.id,
                    animeEnglishTitle: details.name,
                  ),
                );
              },
              child: Text(l10n.watchSourcesOpenButton),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            details.description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(l10n.animeDetailsLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<AnimeDetailsCubit>().loadAnime(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
