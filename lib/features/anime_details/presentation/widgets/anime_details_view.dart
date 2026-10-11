import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/headline_anchor.dart';
import 'package:iris/features/anime_details/presentation/widgets/headline_column.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/presentation/widgets/dubs_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/friends_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/related_anime_section.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/dithered_image.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/spec_table.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/network_image.dart';

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
        return switch (state) {
          AnimeDetailsInitial() ||
          AnimeDetailsLoading() => _Content(head: preview, loading: true),
          AnimeDetailsSuccess(:final details) => _Content(
            head: AnimeDetailsPreview.fromDetails(details),
            description: details.description,
            related: details.related,
            dubs: details.fandubbers,
          ),
          // What the list already knew stays, with its way to the sources.
          AnimeDetailsFailure() when preview != null => _Content(
            head: preview,
            onRetry: retry,
          ),
          AnimeDetailsFailure() => RetryView(
            message: l10n.animeDetailsLoadError,
            onRetry: retry,
          ),
        };
      },
    );
  }
}

/// Stand-ins that give the noise the shape of a typical title.
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
final _standInDescription = List.filled(
  6,
  'A few sentences about what the title is about and who is in it.',
).join(' ');

/// The page from what is known so far: a null [head] or [description] is
/// still loading, unless [onRetry] says the details failed to load.
class _Content extends StatelessWidget {
  const _Content({
    required this.head,
    this.loading = false,
    this.description,
    this.related = const [],
    this.dubs = const [],
    this.onRetry,
  });

  final AnimeDetailsPreview? head;

  /// The details are on their way: what they will surely bring shows as
  /// noise in its shape, so nothing above the reader jumps when it lands.
  final bool loading;
  final String? description;
  final VoidCallback? onRetry;

  /// Empty while loading: the list appears with the details rather than
  /// as noise of a guessed length.
  final List<RelatedAnime> related;
  final List<String> dubs;

  @override
  Widget build(BuildContext context) {
    final head = this.head ?? _standInHead;
    return AppSkeleton(
      enabled: this.head == null,
      semanticLabel: AppLocalizations.of(context).animeDetailsLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);

          return switch (sizeClass) {
            WindowSizeClass.compact => _CompactLayout(
              head: head,
              loading: loading,
              description: description,
              related: related,
              dubs: dubs,
              onRetry: onRetry,
            ),
            _ => _TwoPaneLayout(
              head: head,
              loading: loading,
              description: description,
              related: related,
              dubs: dubs,
              onRetry: onRetry,
              posterWidth: sizeClass.isAtLeast(WindowSizeClass.large)
                  ? 320
                  : sizeClass == WindowSizeClass.expanded
                  ? 260
                  : 200,
              titleSize: sizeClass.isAtLeast(WindowSizeClass.large) ? 112 : 72,
            ),
          };
        },
      ),
    );
  }
}

/// The cover as a colour halftone, set in the same square grain as the
/// rest of the page; a tap develops it into the original and back.
class _Halftone extends StatelessWidget {
  const _Halftone({required this.head, this.alignment = Alignment.center});

  final AnimeDetailsPreview head;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final url = head.anime.posterUrl;
    if (url.isEmpty) {
      return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainer);
    }
    final l10n = AppLocalizations.of(context);
    return DitheredImage(
      image: networkImage(url),
      alignment: alignment,
      semanticLabel: head.anime.name,
      showOriginalLabel: l10n.animeDetailsShowCover,
      showHalftoneLabel: l10n.animeDetailsShowHalftone,
    );
  }
}

/// Phones: a band of the cover, the title under it as large as it fits,
/// the action right after it, then the facts and the sections.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.head,
    required this.loading,
    required this.description,
    required this.related,
    required this.dubs,
    required this.onRetry,
  });

  final AnimeDetailsPreview head;
  final bool loading;
  final String? description;
  final List<RelatedAnime> related;
  final List<String> dubs;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _Halftone(head: head, alignment: const Alignment(0, -0.5)),
          ),
          const SizedBox(height: 20),
          _Titles(head: head, maxSize: 48),
          const SizedBox(height: 24),
          _WatchSourcesButton(head: head),
          const SizedBox(height: 28),
          _Facts(head: head, labelWidth: 96),
          _MoreFacts(head: head, loading: loading, labelWidth: 96),
          const SizedBox(height: 40),
          MyListSection(totalEpisodes: head.anime.episodes),
          RecentlyWatchedSection(animeId: head.anime.id),
          _Description(description: description, onRetry: onRetry),
          DubsSection(dubs: dubs),
          RelatedAnimeSection(related: related),
          // Last: it arrives a while after the page, and shifts nothing.
          FriendsSection(totalEpisodes: head.anime.episodes),
        ],
      ),
    );
  }
}

/// Tablets and wider: the cover in its own column with the title, action
/// and facts beside it; under a heavy rule, the sections as spec rows
/// whose labels share the cover's column.
class _TwoPaneLayout extends StatelessWidget {
  const _TwoPaneLayout({
    required this.head,
    required this.loading,
    required this.description,
    required this.related,
    required this.dubs,
    required this.posterWidth,
    required this.titleSize,
    required this.onRetry,
  });

  static const _gap = 40.0;

  /// Long titles shrink to fit beside the cover, down to this.
  static const _minTitleSize = 36.0;

  final AnimeDetailsPreview head;
  final bool loading;
  final String? description;
  final List<RelatedAnime> related;
  final List<String> dubs;
  final double posterWidth;
  final double titleSize;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final labelWidth = posterWidth + _gap;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: posterWidth,
                child: AspectRatio(
                  aspectRatio: PosterImage.aspectRatio,
                  child: _Halftone(head: head),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                // The column keeps to the cover's height: a long title
                // sets smaller rather than pushing the facts below it.
                child: LayoutBuilder(
                  builder: (context, constraints) => HeadlineColumn(
                    height: posterWidth / PosterImage.aspectRatio,
                    minHeadlineHeight: displayTitleHeight(
                      head.anime.name,
                      base: Theme.of(context).textTheme.displayLarge!,
                      size: _minTitleSize,
                      width: constraints.maxWidth,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    headline: HeadlineAnchor(
                      child: DisplayTitle(
                        head.anime.name,
                        maxSize: titleSize,
                        minSize: _minTitleSize,
                      ),
                    ),
                    rest: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RussianTitle(head: head),
                        const SizedBox(height: 32),
                        _WatchSourcesButton(head: head),
                        const SizedBox(height: 40),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _Facts(head: head, labelWidth: 120),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          _MoreFacts(
            head: head,
            loading: loading,
            labelWidth: labelWidth,
            top: 40,
          ),
          MyListSection(
            totalEpisodes: head.anime.episodes,
            labelWidth: labelWidth,
          ),
          RecentlyWatchedSection(
            animeId: head.anime.id,
            labelWidth: labelWidth,
          ),
          _Description(
            description: description,
            labelWidth: labelWidth,
            onRetry: onRetry,
          ),
          DubsSection(dubs: dubs, labelWidth: labelWidth),
          RelatedAnimeSection(related: related, labelWidth: labelWidth),
          FriendsSection(
            totalEpisodes: head.anime.episodes,
            labelWidth: labelWidth,
          ),
        ],
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.head, required this.maxSize});

  final AnimeDetailsPreview head;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineAnchor(
          child: DisplayTitle(head.anime.name, maxSize: maxSize, maxLines: 4),
        ),
        _RussianTitle(head: head),
      ],
    );
  }
}

/// The Russian title under the main one, when it has one.
class _RussianTitle extends StatelessWidget {
  const _RussianTitle({required this.head});

  final AnimeDetailsPreview head;

  @override
  Widget build(BuildContext context) {
    if (head.anime.russian.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        head.anime.russian,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.head, required this.labelWidth});

  final AnimeDetailsPreview head;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final episodes = _episodesValue(l10n, head);
    return SpecTable(
      labelWidth: labelWidth,
      rows: [
        SpecRow(
          l10n.animeDetailsFactKind,
          formatAnimeKind(l10n, head.anime.kind),
        ),
        SpecRow(
          l10n.animeDetailsFactStatus,
          formatAnimeStatus(l10n, head.anime.status),
        ),
        if (episodes != null) SpecRow(l10n.animeDetailsFactEpisodes, episodes),
        if (head.anime.score > 0)
          SpecRow(
            l10n.animeDetailsFactScore,
            formatAnimeScoreValue(l10n, head.anime.score),
          ),
        if (head.anime.airedOn.isNotEmpty)
          SpecRow(
            l10n.animeDetailsFactAired,
            formatAiredOn(l10n, head.anime.airedOn),
          ),
      ],
    );
  }
}

/// The facts only the details carry: the next episode, studio, genres and
/// age rating. Kept apart from [_Facts] beside a wide cover, where the
/// title is sized to the facts and would shrink when these arrive.
class _MoreFacts extends StatelessWidget {
  const _MoreFacts({
    required this.head,
    required this.loading,
    required this.labelWidth,
    this.top = 0,
  });

  final AnimeDetailsPreview head;

  /// Noise in the shape nearly every title has (studio, genres, rating,
  /// and the next episode of an airing one) until the details land.
  final bool loading;
  final double labelWidth;

  /// Space above, when there is anything to show.
  final double top;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = loading ? _standIns(l10n) : _rows(l10n);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: AppSkeleton(
        enabled: loading,
        semanticLabel: l10n.animeDetailsLoading,
        child: SpecTable(
          key: const Key('anime_details_more_facts'),
          labelWidth: labelWidth,
          rows: rows,
        ),
      ),
    );
  }

  List<SpecRow> _standIns(AppLocalizations l10n) => [
    if (head.anime.status == 'ongoing')
      SpecRow(l10n.animeDetailsFactNextEpisode, 'Episode 7 in 3 days'),
    SpecRow(l10n.animeDetailsFactStudio, 'Studio name'),
    SpecRow(l10n.animeDetailsFactGenres, 'Action, Drama, Fantasy'),
    SpecRow(l10n.animeDetailsFactRating, 'PG-13'),
  ];

  List<SpecRow> _rows(AppLocalizations l10n) {
    return [
      ?_nextEpisodeRow(l10n, head),
      if (head.studios.isNotEmpty)
        SpecRow(l10n.animeDetailsFactStudio, head.studios.join(', ')),
      if (head.genres.isNotEmpty)
        SpecRow(
          l10n.animeDetailsFactGenres,
          [for (final genre in head.genres) _genreName(l10n, genre)].join(', '),
        ),
      if (formatAgeRating(head.rating) case final rating?)
        SpecRow(l10n.animeDetailsFactRating, rating),
    ];
  }
}

/// The next episode of an airing title, while its date is ahead.
SpecRow? _nextEpisodeRow(AppLocalizations l10n, AnimeDetailsPreview head) {
  final at = head.anime.nextEpisodeAt;
  if (head.anime.status != 'ongoing' || at == null) return null;
  final when = formatNextEpisodeTime(l10n, at, DateTime.now());
  if (when == null) return null;
  return SpecRow(
    l10n.animeDetailsFactNextEpisode,
    l10n.animeNextEpisode(head.anime.episodesAired + 1, when),
  );
}

/// The Russian name in Russian, where there is one.
String _genreName(AppLocalizations l10n, AnimeGenreName genre) =>
    l10n.localeName == 'ru' && genre.russian.isNotEmpty
    ? genre.russian
    : genre.name;

/// The total for finished titles, aired of total while a title is airing.
String? _episodesValue(AppLocalizations l10n, AnimeDetailsPreview head) {
  final numbers = NumberFormat.decimalPattern(l10n.localeName);
  final total = head.anime.episodes;
  final aired = head.anime.episodesAired;
  if (total > 0 && (head.anime.status == 'released' || aired >= total)) {
    return numbers.format(total);
  }
  if (total > 0) {
    return l10n.animeDetailsEpisodesAired(
      numbers.format(aired),
      numbers.format(total),
    );
  }
  if (aired > 0) return numbers.format(aired);
  return null;
}

class _WatchSourcesButton extends StatelessWidget {
  const _WatchSourcesButton({required this.head});

  final AnimeDetailsPreview head;

  @override
  Widget build(BuildContext context) {
    // As noise, the button is one block, frame included.
    return Skeleton.unite(
      child: FilledButton(
        onPressed: () => context.pushNamed(
          'anime-watch-sources',
          pathParameters: {'id': head.anime.id},
          extra: AnimeWatchSourcesArgs.forAnime(
            animeId: head.anime.id,
            name: head.anime.name,
            english: head.anime.english,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).animeDetailsChooseSourceButton,
        ),
      ),
    );
  }
}

/// The description, as noise while it loads; with [onRetry], the failure
/// to load it in its place.
class _Description extends StatelessWidget {
  const _Description({
    required this.description,
    this.labelWidth,
    this.onRetry,
  });

  final String? description;
  final double? labelWidth;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = this.description?.trim();
    final onRetry = this.onRetry;
    if (description != null && description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: l10n.animeDetailsDescriptionTitle,
        labelWidth: labelWidth,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdaptiveContentWidth.reading,
            ),
            child: onRetry == null
                ? AppSkeleton(
                    enabled: description == null,
                    semanticLabel: l10n.animeDetailsLoading,
                    child: Text(
                      description ?? _standInDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : InlineRetry(
                    message: l10n.animeDetailsLoadError,
                    onRetry: onRetry,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
          ),
        ),
      ),
    );
  }
}
