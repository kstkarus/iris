import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
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
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/spec_table.dart';
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
        return switch (state) {
          AnimeDetailsInitial() ||
          AnimeDetailsLoading() => _Content(head: preview),
          AnimeDetailsSuccess(:final details) => _Content(
            head: AnimeDetailsPreview.fromDetails(details),
            description: details.description,
          ),
          AnimeDetailsFailure() => MessageView(
            message: l10n.animeDetailsLoadError,
            action: FilledButton(
              onPressed: () => context.read<AnimeDetailsCubit>().loadAnime(),
              child: Text(l10n.commonRetry),
            ),
          ),
        };
      },
    );
  }
}

/// Stand-ins that give the noise the shape of a typical title.
const _standInHead = AnimeDetailsPreview(
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
);
final _standInDescription = List.filled(
  6,
  'A few sentences about what the title is about and who is in it.',
).join(' ');

/// The page from what is known so far: a null [head] or [description] is
/// still loading.
class _Content extends StatelessWidget {
  const _Content({required this.head, this.description});

  final AnimeDetailsPreview? head;
  final String? description;

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
              description: description,
            ),
            _ => _TwoPaneLayout(
              head: head,
              description: description,
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
    final url = head.posterUrl;
    if (url.isEmpty) {
      return ColoredBox(color: Theme.of(context).colorScheme.surfaceContainer);
    }
    final l10n = AppLocalizations.of(context);
    return DitheredImage(
      image: NetworkImage(url),
      alignment: alignment,
      semanticLabel: head.name,
      showOriginalLabel: l10n.animeDetailsShowCover,
      showHalftoneLabel: l10n.animeDetailsShowHalftone,
    );
  }
}

/// Phones: a band of the cover, the title under it as large as it fits,
/// the action right after it, then the facts and the sections.
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.head, required this.description});

  final AnimeDetailsPreview head;
  final String? description;

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
          const SizedBox(height: 40),
          const Skeleton.keep(child: BlockRule(height: 10)),
          RecentlyWatchedSection(animeId: head.id),
          _Description(description: description),
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
    required this.description,
    required this.posterWidth,
    required this.titleSize,
  });

  static const _gap = 40.0;

  final AnimeDetailsPreview head;
  final String? description;
  final double posterWidth;
  final double titleSize;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Titles(head: head, maxSize: titleSize),
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
            ],
          ),
          const SizedBox(height: 48),
          const Skeleton.keep(child: BlockRule()),
          RecentlyWatchedSection(animeId: head.id, labelWidth: labelWidth),
          _Description(description: description, labelWidth: labelWidth),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DisplayTitle(head.name, maxSize: maxSize, maxLines: 4),
        if (head.russian.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            head.russian,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
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
        SpecRow(l10n.animeDetailsFactKind, formatAnimeKind(l10n, head.kind)),
        SpecRow(
          l10n.animeDetailsFactStatus,
          formatAnimeStatus(l10n, head.status),
        ),
        if (episodes != null) SpecRow(l10n.animeDetailsFactEpisodes, episodes),
        if (head.score > 0)
          SpecRow(
            l10n.animeDetailsFactScore,
            formatAnimeScoreValue(l10n, head.score),
          ),
        if (head.airedOn.isNotEmpty)
          SpecRow(
            l10n.animeDetailsFactAired,
            formatAiredOn(l10n, head.airedOn),
          ),
      ],
    );
  }
}

/// The total for finished titles, aired of total while a title is airing.
String? _episodesValue(AppLocalizations l10n, AnimeDetailsPreview head) {
  final numbers = NumberFormat.decimalPattern(l10n.localeName);
  final total = head.episodes;
  final aired = head.episodesAired;
  if (total > 0 && (head.status == 'released' || aired >= total)) {
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
          pathParameters: {'id': head.id},
          extra: AnimeWatchSourcesArgs(
            animeId: head.id,
            animeEnglishTitle: head.name,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).animeDetailsChooseSourceButton,
        ),
      ),
    );
  }
}

/// The description, as noise while it loads.
class _Description extends StatelessWidget {
  const _Description({required this.description, this.labelWidth});

  final String? description;
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = this.description?.trim();
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
            child: AppSkeleton(
              enabled: description == null,
              semanticLabel: l10n.animeDetailsLoading,
              child: Text(
                description ?? _standInDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
