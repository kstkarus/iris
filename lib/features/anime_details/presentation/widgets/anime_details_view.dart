import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_desktop_layout.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_sections.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_passport.dart';
import 'package:iris/features/anime_details/presentation/widgets/friends_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/related_anime_section.dart';
import 'package:iris/features/characters/presentation/widgets/characters_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// A title page. While its details load, what [preview] already knows is
/// shown as is and the rest is pixel noise in the shape of the page; the
/// details develop out of it as they arrive.
class AnimeDetailsView extends StatelessWidget {
  const AnimeDetailsView({this.preview, super.key});

  final AnimeDetailsPreview? preview;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeDetailsCubit, AnimeDetailsState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final preview = this.preview;
        void retry() => context.read<AnimeDetailsCubit>().loadAnime();
        final child = switch (state) {
          AnimeDetailsInitial() || AnimeDetailsLoading() => _Content(
            key: const ValueKey('content'),
            head: preview,
            loading: true,
          ),
          AnimeDetailsSuccess(:final details) => _Content(
            key: const ValueKey('content'),
            head: AnimeDetailsPreview.fromDetails(details),
            description: details.description,
            related: details.related,
          ),
          // What the list already knew stays, with its way to the sources.
          AnimeDetailsFailure() when preview != null => _Content(
            key: const ValueKey('content'),
            head: preview,
            onRetry: retry,
          ),
          AnimeDetailsFailure() => RetryView(
            key: const ValueKey('failure'),
            message: l10n.animeDetailsLoadError,
            onRetry: retry,
          ),
        };
        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 240),
          child: child,
        );
      },
    );
  }
}

/// Stand-in used to give the skeleton noise the shape of a typical title.
const _standInHead = AnimeDetailsPreview.fromSummary(
  AnimeSummary(
    id: '',
    name: 'A typical anime title',
    russian: 'Its name in Russian',
    kind: 'tv',
    score: 8.5,
    status: 'released',
    episodes: 24,
    episodesAired: 24,
    airedOn: '2020-01-01',
    posterUrl: '',
  ),
);

/// The page from what is known so far: a null [head] or [description] is
/// still loading, unless [onRetry] says the details failed to load.
class _Content extends StatelessWidget {
  const _Content({
    required this.head,
    this.loading = false,
    this.description,
    this.related = const [],
    this.onRetry,
    super.key,
  });

  final AnimeDetailsPreview? head;
  final bool loading;
  final String? description;
  final VoidCallback? onRetry;
  final List<RelatedAnime> related;

  @override
  Widget build(BuildContext context) {
    final head = this.head ?? _standInHead;
    return AppSkeleton(
      enabled: this.head == null,
      semanticLabel: AppLocalizations.of(context).animeDetailsLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
          if (sizeClass.isAtLeast(WindowSizeClass.expanded)) {
            return AnimeDetailsDesktopLayout(
              head: head,
              loading: loading,
              description: description,
              related: related,
              onRetry: onRetry,
              sizeClass: sizeClass,
            );
          }
          return _StackedLayout(
            head: head,
            loading: loading,
            description: description,
            related: related,
            onRetry: onRetry,
            isMedium: sizeClass == WindowSizeClass.medium,
          );
        },
      ),
    );
  }
}

/// Phones and portrait tablets: compact hero masthead, full-width primary
/// action, unified telemetry passport, and sections in close vertical rhythm.
class _StackedLayout extends StatelessWidget {
  const _StackedLayout({
    required this.head,
    required this.loading,
    required this.description,
    required this.related,
    required this.onRetry,
    required this.isMedium,
  });

  final AnimeDetailsPreview head;
  final bool loading;
  final String? description;
  final List<RelatedAnime> related;
  final VoidCallback? onRetry;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLargeText = DetailLayout.isLargeText(context);
    final gap = isMedium ? 24.0 : 14.0;

    return SingleChildScrollView(
      key: const Key('anime_details_scroll'),
      padding: EdgeInsets.only(
        top: isMedium ? 24 : 12,
        bottom: isMedium ? 40 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final posterWidth = isMedium
                  ? (constraints.maxWidth * 0.28).clamp(148.0, 196.0)
                  : isLargeText
                  ? (constraints.maxWidth * 0.30).clamp(92.0, 116.0)
                  : (constraints.maxWidth * 0.34).clamp(98.0, 144.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: posterWidth,
                    child: AspectRatio(
                      aspectRatio: PosterImage.aspectRatio,
                      child: AnimeDetailsFramedPoster(head: head),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: AnimeDetailsTitles(
                      head: head,
                      maxSize: isMedium ? 44 : 40,
                      minSize: 16,
                      maxHeight: posterWidth / PosterImage.aspectRatio,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          AnimeDetailsWatchSourcesButton(head: head),
          DitherSwitcher(
            resizeDuration: const Duration(milliseconds: 200),
            collapse: true,
            duration: const Duration(milliseconds: 220),
            child: onRetry == null
                ? const SizedBox.shrink(key: ValueKey('no_retry'))
                : Padding(
                    key: const ValueKey('retry'),
                    padding: const EdgeInsets.only(top: 12),
                    child: AnimeDetailsRetryBanner(onRetry: onRetry!),
                  ),
          ),
          const SizedBox(height: 16),
          AnimePassportCard(
            entries: buildAnimePassportEntries(l10n, head, loading: loading),
            loading: loading,
          ),
          MyListSection(totalEpisodes: head.anime.episodes),
          RecentlyWatchedSection(animeId: head.anime.id),
          DitherSwitcher(
            resizeDuration: const Duration(milliseconds: 200),
            collapse: true,
            duration: const Duration(milliseconds: 220),
            child: onRetry == null
                ? AnimeDetailsDescription(
                    key: const ValueKey('description'),
                    description: description,
                  )
                : const SizedBox.shrink(key: ValueKey('no_description')),
          ),
          RelatedAnimeSection(related: related),
          CharactersSection(
            animeId: head.anime.id,
            animeName: head.anime.name,
            labelStyle: DetailLayout.sectionTitleStyle(Theme.of(context)),
            uppercase: false,
            hairlineDivider: true,
          ),
          FriendsSection(totalEpisodes: head.anime.episodes),
        ],
      ),
    );
  }
}
