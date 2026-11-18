import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
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
            semanticLabel: head.anime.name,
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
  Widget build(BuildContext context) => DetailHeroTitles(
    title: head.anime.name,
    subtitle: head.anime.russian,
    maxSize: maxSize,
    minSize: minSize,
    maxLines: maxLines,
    maxHeight: maxHeight,
  );
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
            name: head.anime.name,
            english: head.anime.english,
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

  final String? description;

  @override
  Widget build(BuildContext context) {
    final trimmed = description?.trim();
    final l10n = AppLocalizations.of(context);
    final Widget child = trimmed != null && trimmed.isEmpty
        ? const SizedBox.shrink(key: ValueKey('empty_description'))
        : Padding(
            key: const ValueKey('description'),
            padding: const EdgeInsets.only(top: 32),
            child: DetailSection(
              label: l10n.animeDetailsDescriptionTitle,
              child: AppSkeleton(
                enabled: trimmed == null,
                semanticLabel: l10n.animeDetailsLoading,
                child: Text(
                  trimmed ?? standInDescription,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                  ),
                ),
              ),
            ),
          );
    final switcher = DitherSwitcher(
      collapse: true,
      duration: const Duration(milliseconds: 220),
      child: child,
    );
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    if (duration == Duration.zero) return switcher;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switcher,
    );
  }
}
