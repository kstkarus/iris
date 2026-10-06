import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);

        return switch (sizeClass) {
          WindowSizeClass.compact => _CompactLayout(details: details),
          WindowSizeClass.medium => _MediumLayout(details: details),
          _ => _TwoPaneLayout(
            details: details,
            posterWidth: sizeClass.isAtLeast(WindowSizeClass.large) ? 360 : 280,
          ),
        };
      },
    );
  }
}

/// Phones: a single scrolling column with a centered poster.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _Poster(details: details, width: 220)),
          const SizedBox(height: 24),
          _TitleBlock(details: details),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _WatchSourcesButton(details: details),
          ),
          RecentlyWatchedSection(animeId: details.id),
          const SizedBox(height: 20),
          _Description(details: details),
        ],
      ),
    );
  }
}

/// Tablets in portrait: poster beside the header, text width capped.
class _MediumLayout extends StatelessWidget {
  const _MediumLayout({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: MaxWidthBox(
        maxWidth: AdaptiveContentWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Poster(details: details, width: 180),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleBlock(details: details),
                      const SizedBox(height: 20),
                      _WatchSourcesButton(details: details),
                    ],
                  ),
                ),
              ],
            ),
            RecentlyWatchedSection(animeId: details.id),
            const SizedBox(height: 24),
            _Description(details: details),
          ],
        ),
      ),
    );
  }
}

/// Expanded and wider: the poster beside the title, metadata, actions and
/// description, which keep a readable line length.
class _TwoPaneLayout extends StatelessWidget {
  const _TwoPaneLayout({required this.details, required this.posterWidth});

  final AnimeDetails details;
  final double posterWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scrolls on its own so a short window never clips the poster.
        SingleChildScrollView(
          primary: false,
          child: _Poster(details: details, width: posterWidth),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: SingleChildScrollView(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AdaptiveContentWidth.reading,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleBlock(details: details),
                    const SizedBox(height: 20),
                    _WatchSourcesButton(details: details),
                    RecentlyWatchedSection(animeId: details.id),
                    const SizedBox(height: 24),
                    _Description(details: details),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.details, required this.width});

  static const _aspectRatio = 220 / 320;

  final AnimeDetails details;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Image.network(
            details.posterOriginalUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  Icons.movie_outlined,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 12),
        Text(
          formatAnimeMeta(
            AppLocalizations.of(context),
            kind: details.kind,
            status: details.status,
            score: details.score,
            episodes: details.episodes,
            episodesAired: details.episodesAired,
            airedOn: details.airedOn,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WatchSourcesButton extends StatelessWidget {
  const _WatchSourcesButton({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
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
      child: Text(AppLocalizations.of(context).animeDetailsChooseSourceButton),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.details});

  final AnimeDetails details;

  @override
  Widget build(BuildContext context) {
    return Text(
      details.description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
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
