import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/models/details_description.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/details_description_text.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dithered_image.dart';
import 'package:iris/shared/widgets/network_image.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Stand-in body used to give skeleton noise the shape of a typical synopsis.
final standInDescription = List.filled(
  6,
  'A few sentences about what the title is about and who is in it.',
).join(' ');

/// Framed colour-halftone cover; a tap develops it into the original and back.
class AnimeDetailsFramedPoster extends StatelessWidget {
  const AnimeDetailsFramedPoster({required this.head, super.key});

  final AnimeDetailsPreview head;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = head.anime.posterUrl;
    final l10n = AppLocalizations.of(context);
    final inner = url.isEmpty
        ? ColoredBox(color: scheme.surfaceContainer)
        : DitheredImage(
            image: networkImage(url),
            semanticLabel: watchAnimeTitleLabels(
              context,
              head.anime.titles,
            ).primary,
            showOriginalLabel: l10n.animeDetailsShowCover,
            showHalftoneLabel: l10n.animeDetailsShowHalftone,
          );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: DetailLayout.ruleColor(scheme)),
      ),
      child: inner,
    );
  }
}

/// Primary title block anchored for the collapsing app-bar title transition.
class AnimeDetailsTitles extends StatelessWidget {
  const AnimeDetailsTitles({
    required this.head,
    required this.maxSize,
    required this.minSize,
    this.maxLines = 4,
    this.maxHeight,
    super.key,
  });

  final AnimeDetailsPreview head;
  final double maxSize;
  final double minSize;
  final int maxLines;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final titles = watchAnimeTitleLabels(context, head.anime.titles);
    return DetailHeroTitles(
      title: titles.primary,
      subtitle: titles.secondary,
      maxSize: maxSize,
      minSize: minSize,
      maxLines: maxLines,
      maxHeight: maxHeight,
    );
  }
}

/// Primary action button that opens online and torrent watch sources.
class AnimeDetailsWatchSourcesButton extends StatelessWidget {
  const AnimeDetailsWatchSourcesButton({required this.head, super.key});

  final AnimeDetailsPreview head;

  @override
  Widget build(BuildContext context) {
    return Skeleton.unite(
      child: FilledButton(
        onPressed: () => context.pushNamed(
          'anime-watch-sources',
          pathParameters: {'id': head.anime.id},
          extra: AnimeWatchSourcesArgs.forAnime(
            animeId: head.anime.id,
            animeTitles: head.anime.titles,
            posterUrl: head.anime.posterUrl,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).animeDetailsChooseSourceButton,
        ),
      ),
    );
  }
}

/// Visible above-the-fold retry strip when full details fail to load on top of
/// a preview, so missing fields are clearly explained and recoverable.
class AnimeDetailsRetryBanner extends StatelessWidget {
  const AnimeDetailsRetryBanner({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DetailRetryBanner(
    message: AppLocalizations.of(context).animeDetailsLoadError,
    onRetry: onRetry,
  );
}

/// Full-width editorial synopsis, shown as pixel noise while details load.
class AnimeDetailsDescription extends StatelessWidget {
  const AnimeDetailsDescription({required this.description, super.key});

  final DetailsDescription? description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget child = description?.text.trim().isEmpty == true
        ? const SizedBox.shrink(key: ValueKey('empty_description'))
        : Padding(
            key: const ValueKey('description'),
            padding: const EdgeInsets.only(top: 32),
            child: DetailSection(
              label: l10n.animeDetailsDescriptionTitle,
              child: AppSkeleton(
                enabled: description == null,
                semanticLabel: l10n.animeDetailsLoading,
                child: DetailsDescriptionText(
                  description:
                      description ?? DetailsDescription(standInDescription),
                ),
              ),
            ),
          );
    return DitherSwitcher(
      collapse: true,
      duration: const Duration(milliseconds: 220),
      resizeDuration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}
