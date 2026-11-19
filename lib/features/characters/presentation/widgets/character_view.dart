import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/cubit/character_cubit.dart';
import 'package:iris/features/characters/presentation/cubit/character_state.dart';
import 'package:iris/features/characters/presentation/widgets/character_desktop_layout.dart';
import 'package:iris/features/characters/presentation/widgets/character_sections.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/status_views.dart';

export 'package:iris/features/characters/presentation/widgets/character_sections.dart'
    show appearancesToShow;

/// A character's page, laid out as a title page is. While it loads, what
/// [preview] knows shows as is and the description is noise in its shape.
class CharacterView extends StatelessWidget {
  const CharacterView({this.preview, required this.onOpenAnime, super.key});

  final CharacterSummary? preview;
  final ValueChanged<AnimeSummary> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CharacterCubit, CharacterState>(
      builder: (context, state) {
        final preview = this.preview;
        void retry() => context.read<CharacterCubit>().load();
        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 240),
          child: switch (state) {
            CharacterLoading() => _Content(
              key: const ValueKey('content'),
              head: preview,
              onOpenAnime: onOpenAnime,
            ),
            CharacterLoaded(:final details) => _Content(
              key: const ValueKey('content'),
              head: _head(details.character),
              details: details,
              onOpenAnime: onOpenAnime,
            ),
            // What the list already knew stays.
            CharacterFailure() when preview != null => _Content(
              key: const ValueKey('content'),
              head: preview,
              onOpenAnime: onOpenAnime,
              onRetry: retry,
            ),
            CharacterFailure() => RetryView(
              key: const ValueKey('failure'),
              message: AppLocalizations.of(context).characterLoadError,
              onRetry: retry,
            ),
          },
        );
      },
    );
  }

  /// The loaded character with the portrait the list showed, which is
  /// already on screen and on disk.
  CharacterSummary _head(CharacterSummary loaded) {
    final shown = preview?.posterUrl ?? '';
    if (shown.isEmpty) return loaded;
    return CharacterSummary(
      id: loaded.id,
      name: loaded.name,
      russian: loaded.russian,
      posterUrl: shown,
    );
  }
}

/// Stand-ins that give the noise the shape of a typical character.
const _standInHead = CharacterSummary(
  id: '',
  name: 'A character name',
  russian: 'A character name',
  posterUrl: '',
);

/// The page from what is known so far: a null [head] or [details] is
/// still loading, unless [onRetry] says the details failed to load.
class _Content extends StatelessWidget {
  const _Content({
    required this.head,
    required this.onOpenAnime,
    this.details,
    this.onRetry,
    super.key,
  });

  final CharacterSummary? head;
  final CharacterDetails? details;
  final ValueChanged<AnimeSummary> onOpenAnime;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final head = this.head ?? _standInHead;
    return AppSkeleton(
      enabled: this.head == null,
      semanticLabel: AppLocalizations.of(context).characterLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
          if (sizeClass.isAtLeast(WindowSizeClass.expanded)) {
            return CharacterDesktopLayout(
              head: head,
              details: details,
              onOpenAnime: onOpenAnime,
              onRetry: onRetry,
              sizeClass: sizeClass,
            );
          }
          return _StackedLayout(
            head: head,
            details: details,
            onOpenAnime: onOpenAnime,
            onRetry: onRetry,
            isMedium: sizeClass == WindowSizeClass.medium,
          );
        },
      ),
    );
  }
}

/// Phones and portrait tablets: compact hero masthead, name passport card, and
/// sections in close vertical rhythm.
class _StackedLayout extends StatelessWidget {
  const _StackedLayout({
    required this.head,
    required this.details,
    required this.onOpenAnime,
    required this.onRetry,
    required this.isMedium,
  });

  final CharacterSummary head;
  final CharacterDetails? details;
  final ValueChanged<AnimeSummary> onOpenAnime;
  final VoidCallback? onRetry;
  final bool isMedium;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLargeText = DetailLayout.isLargeText(context);
    final gap = isMedium ? 24.0 : 14.0;

    return SingleChildScrollView(
      key: const Key('character_scroll'),
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
                      child: CharacterPortrait(posterUrl: head.posterUrl),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: DetailHeroTitles(
                      title: characterName(l10n, head),
                      subtitle: otherCharacterName(l10n, head),
                      maxSize: isMedium ? 44 : 40,
                      minSize: 16,
                      maxHeight: posterWidth / PosterImage.aspectRatio,
                    ),
                  ),
                ],
              );
            },
          ),
          DitherSwitcher(
            resizeDuration: const Duration(milliseconds: 200),
            collapse: true,
            duration: const Duration(milliseconds: 220),
            child: onRetry == null
                ? const SizedBox.shrink(key: ValueKey('no_retry'))
                : Padding(
                    key: const ValueKey('retry'),
                    padding: const EdgeInsets.only(top: 16),
                    child: DetailRetryBanner(
                      message: l10n.characterLoadError,
                      onRetry: onRetry!,
                    ),
                  ),
          ),
          CharacterNamesCard(details: details, topSpacing: 16),
          DitherSwitcher(
            resizeDuration: const Duration(milliseconds: 200),
            collapse: true,
            duration: const Duration(milliseconds: 220),
            child: onRetry == null
                ? CharacterDescriptionSection(
                    key: const ValueKey('description'),
                    description: details?.description,
                  )
                : const SizedBox.shrink(key: ValueKey('no_description')),
          ),
          CharacterAppearancesSection(
            appearances: details?.appearances ?? const [],
            onOpenAnime: onOpenAnime,
          ),
        ],
      ),
    );
  }
}
