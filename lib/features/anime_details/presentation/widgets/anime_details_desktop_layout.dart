import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_sections.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_highlight_strip.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_passport.dart';
import 'package:iris/features/anime_details/presentation/widgets/friends_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
import 'package:iris/features/anime_details/presentation/widgets/related_anime_section.dart';
import 'package:iris/features/characters/presentation/widgets/characters_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/models/details_description.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/poster_image.dart';

/// Desktop and landscape tablets: a sticky left dossier rail (poster, primary
/// action, static catalog facts) beside a reading-width editorial column where
/// all sections align flush to [AdaptiveContentWidth.reading].
class AnimeDetailsDesktopLayout extends StatefulWidget {
  const AnimeDetailsDesktopLayout({
    required this.head,
    required this.loading,
    required this.description,
    required this.related,
    required this.onRetry,
    required this.sizeClass,
    super.key,
  });

  final AnimeDetailsPreview head;
  final bool loading;
  final DetailsDescription? description;
  final List<RelatedAnime> related;
  final VoidCallback? onRetry;
  final WindowSizeClass sizeClass;

  @override
  State<AnimeDetailsDesktopLayout> createState() =>
      _AnimeDetailsDesktopLayoutState();
}

class _AnimeDetailsDesktopLayoutState extends State<AnimeDetailsDesktopLayout> {
  final _mainScroll = ScrollController();
  final _railScroll = ScrollController();

  @override
  void dispose() {
    _mainScroll.dispose();
    _railScroll.dispose();
    super.dispose();
  }

  void _forwardWheelToMain(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_railScroll.hasClients || !_mainScroll.hasClients) return;
    final rail = _railScroll.position;
    final railPixels = rail.pixels.clamp(
      rail.minScrollExtent,
      rail.maxScrollExtent,
    );
    final flipAxes =
        event.kind == PointerDeviceKind.mouse &&
        HardwareKeyboard.instance.logicalKeysPressed.any(
          ScrollConfiguration.of(context).pointerAxisModifiers.contains,
        );
    final delta = flipAxes ? event.scrollDelta.dx : event.scrollDelta.dy;
    final railDelta = delta.clamp(
      rail.minScrollExtent - railPixels,
      rail.maxScrollExtent - railPixels,
    );
    final remainder = delta - railDelta;
    if (remainder == 0) return;

    final main = _mainScroll.position;
    final next = (main.pixels + remainder).clamp(
      main.minScrollExtent,
      main.maxScrollExtent,
    );
    if (next == main.pixels) return;

    if (railDelta != 0) {
      // The rail has already claimed this event and will use its share.
      main.pointerScroll(remainder);
    } else {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        main.pointerScroll(remainder);
        event.respond(allowPlatformDefault: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLarge = widget.sizeClass.isAtLeast(WindowSizeClass.large);
    final posterWidth = isLarge ? 296.0 : 240.0;
    final gap = isLarge ? 44.0 : 28.0;

    final railEntries = buildAnimePassportEntries(
      l10n,
      widget.head,
      loading: widget.loading,
      includeScore: false,
      includeEpisodes: false,
      includeNextEpisode: false,
      includeGenres: false,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: posterWidth,
          child: Listener(
            onPointerSignal: _forwardWheelToMain,
            // ListView keeps SingleChildScrollView unique for the main column.
            child: ListView(
              controller: _railScroll,
              padding: const EdgeInsets.only(top: 24, bottom: 32),
              children: [
                AspectRatio(
                  aspectRatio: PosterImage.aspectRatio,
                  child: AnimeDetailsFramedPoster(head: widget.head),
                ),
                const SizedBox(height: 16),
                AnimeDetailsWatchSourcesButton(head: widget.head),
                const SizedBox(height: 16),
                AnimePassportCard(
                  entries: railEntries,
                  loading: widget.loading,
                  twoColumns: false,
                  markMoreFactsKey: false,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('anime_details_scroll'),
            controller: _mainScroll,
            padding: const EdgeInsets.only(top: 20, bottom: 48),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AdaptiveContentWidth.reading,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimeDetailsTitles(
                      head: widget.head,
                      maxSize: isLarge ? 56 : 46,
                      minSize: 24,
                      maxLines: 3,
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(height: 16),
                      AnimeDetailsRetryBanner(onRetry: widget.onRetry!),
                    ],
                    const SizedBox(height: 20),
                    AnimeHighlightStrip(
                      head: widget.head,
                      loading: widget.loading,
                    ),
                    MyListSection(totalEpisodes: widget.head.anime.episodes),
                    RecentlyWatchedSection(animeId: widget.head.anime.id),
                    if (widget.onRetry == null)
                      AnimeDetailsDescription(description: widget.description),
                    RelatedAnimeSection(related: widget.related),
                    CharactersSection(
                      animeId: widget.head.anime.id,
                      animeName: widget.head.anime.name,
                      labelStyle: DetailLayout.sectionTitleStyle(
                        Theme.of(context),
                      ),
                      uppercase: false,
                      hairlineDivider: true,
                    ),
                    FriendsSection(totalEpisodes: widget.head.anime.episodes),
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
