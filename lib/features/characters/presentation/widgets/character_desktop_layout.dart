import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/widgets/character_sections.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Desktop and landscape tablets: a sticky left dossier rail (portrait and
/// name variants) beside a reading-width editorial column where the headline
/// and every section align flush to [AdaptiveContentWidth.reading].
class CharacterDesktopLayout extends StatefulWidget {
  const CharacterDesktopLayout({
    required this.head,
    required this.details,
    required this.onOpenAnime,
    required this.onRetry,
    required this.sizeClass,
    super.key,
  });

  final CharacterSummary head;
  final CharacterDetails? details;
  final ValueChanged<AnimeSummary> onOpenAnime;
  final VoidCallback? onRetry;
  final WindowSizeClass sizeClass;

  @override
  State<CharacterDesktopLayout> createState() => _CharacterDesktopLayoutState();
}

class _CharacterDesktopLayoutState extends State<CharacterDesktopLayout> {
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
    if (_railScroll.position.maxScrollExtent > 0) return;
    final position = _mainScroll.position;
    final next = (position.pixels + event.scrollDelta.dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) position.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLarge = widget.sizeClass.isAtLeast(WindowSizeClass.large);
    final posterWidth = isLarge ? 296.0 : 240.0;
    final gap = isLarge ? 44.0 : 28.0;

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
                  child: CharacterPortrait(posterUrl: widget.head.posterUrl),
                ),
                CharacterNamesCard(details: widget.details, topSpacing: 16),
              ],
            ),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('character_scroll'),
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
                    DetailHeroTitles(
                      title: characterName(l10n, widget.head),
                      subtitle: otherCharacterName(l10n, widget.head),
                      maxSize: isLarge ? 56 : 46,
                      minSize: 24,
                      maxLines: 3,
                    ),
                    if (widget.onRetry != null) ...[
                      const SizedBox(height: 16),
                      DetailRetryBanner(
                        message: l10n.characterLoadError,
                        onRetry: widget.onRetry!,
                      ),
                    ],
                    if (widget.onRetry == null)
                      CharacterDescriptionSection(
                        description: widget.details?.description,
                      ),
                    CharacterAppearancesSection(
                      appearances: widget.details?.appearances ?? const [],
                      onOpenAnime: widget.onOpenAnime,
                    ),
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
