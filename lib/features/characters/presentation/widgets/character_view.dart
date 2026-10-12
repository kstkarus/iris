import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_kind.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/cubit/character_cubit.dart';
import 'package:iris/features/characters/presentation/cubit/character_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

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
        return switch (state) {
          CharacterLoading() => _Content(
            head: preview,
            onOpenAnime: onOpenAnime,
          ),
          CharacterLoaded(:final details) => _Content(
            head: _head(details.character),
            details: details,
            onOpenAnime: onOpenAnime,
          ),
          // What the list already knew stays.
          CharacterFailure() when preview != null => _Content(
            head: preview,
            onOpenAnime: onOpenAnime,
            onRetry: retry,
          ),
          CharacterFailure() => RetryView(
            message: AppLocalizations.of(context).characterLoadError,
            onRetry: retry,
          ),
        };
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
final _standInDescription = List.filled(
  4,
  'A few sentences about who the character is and what they do.',
).join(' ');

/// The page from what is known so far: a null [head] or [details] is
/// still loading, unless [onRetry] says the details failed to load.
class _Content extends StatelessWidget {
  const _Content({
    required this.head,
    required this.onOpenAnime,
    this.details,
    this.onRetry,
  });

  final CharacterSummary? head;
  final CharacterDetails? details;
  final ValueChanged<AnimeSummary> onOpenAnime;
  final VoidCallback? onRetry;

  static const _gap = 40.0;

  @override
  Widget build(BuildContext context) {
    final head = this.head ?? _standInHead;
    return AppSkeleton(
      enabled: this.head == null,
      semanticLabel: AppLocalizations.of(context).characterLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
          if (sizeClass == WindowSizeClass.compact) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompactHead(head: head, details: details),
                  ..._sections(labelWidth: null),
                ],
              ),
            );
          }
          final posterWidth = sizeClass.isAtLeast(WindowSizeClass.large)
              ? 260.0
              : 200.0;
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
                      child: PosterImage(url: head.posterUrl),
                    ),
                    const SizedBox(width: _gap),
                    Expanded(
                      child: _Names(
                        head: head,
                        details: details,
                        maxSize: sizeClass.isAtLeast(WindowSizeClass.large)
                            ? 96
                            : 64,
                        minSize: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._sections(labelWidth: posterWidth + _gap),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections({required double? labelWidth}) => [
    _Description(
      description: details?.description,
      labelWidth: labelWidth,
      onRetry: onRetry,
    ),
    _Appearances(
      appearances: details?.appearances ?? const [],
      labelWidth: labelWidth,
      onOpenAnime: onOpenAnime,
    ),
  ];
}

/// Phones: the portrait, small, with the name beside it.
class _CompactHead extends StatelessWidget {
  const _CompactHead({required this.head, required this.details});

  final CharacterSummary head;
  final CharacterDetails? details;

  static const _posterShare = 0.36;
  static const _minPosterWidth = 112.0;
  static const _maxPosterWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: (constraints.maxWidth * _posterShare).clamp(
              _minPosterWidth,
              _maxPosterWidth,
            ),
            child: PosterImage(url: head.posterUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Names(
              head: head,
              details: details,
              maxSize: 36,
              minSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// The name as the page's headline; under it the name in the other
/// script, then the Japanese one and any other names.
class _Names extends StatelessWidget {
  const _Names({
    required this.head,
    required this.details,
    required this.maxSize,
    required this.minSize,
  });

  final CharacterSummary head;
  final CharacterDetails? details;
  final double maxSize;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final other = otherCharacterName(l10n, head);
    final more = [
      details?.japanese.trim() ?? '',
      details?.altName.trim() ?? '',
    ].where((name) => name.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeadlineAnchor(
          child: Semantics(
            header: true,
            child: DisplayTitle(
              characterName(l10n, head),
              maxSize: maxSize,
              minSize: minSize,
              maxLines: 4,
            ),
          ),
        ),
        if (other != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              other,
              style: theme.textTheme.titleMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        for (final name in more)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// Who the character is, as noise while it loads; with [onRetry], the
/// failure to load it in its place. Nothing when there is no description.
class _Description extends StatelessWidget {
  const _Description({
    required this.description,
    required this.labelWidth,
    required this.onRetry,
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
    final style = Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: l10n.characterDescriptionTitle,
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
                    semanticLabel: l10n.characterLoading,
                    child: Text(
                      description ?? _standInDescription,
                      style: style,
                    ),
                  )
                : InlineRetry(
                    message: l10n.characterLoadError,
                    onRetry: onRetry,
                    style: style,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The anime the character is in, oldest first, each a row that opens
/// its page; promos aside, as there is nothing to watch.
class _Appearances extends StatelessWidget {
  const _Appearances({
    required this.appearances,
    required this.labelWidth,
    required this.onOpenAnime,
  });

  /// Rows shown before the rest folds away: a long series' hero is in
  /// dozens of films and specials.
  static const _visibleRows = 5;
  static const _minFolded = 2;

  final List<CharacterAppearance> appearances;
  final double? labelWidth;
  final ValueChanged<AnimeSummary> onOpenAnime;

  @override
  Widget build(BuildContext context) {
    final shown = appearancesToShow(appearances);
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: AppLocalizations.of(context).characterAnimeTitle,
        labelWidth: labelWidth,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdaptiveContentWidth.reading,
            ),
            child: FoldingList(
              key: const Key('character_anime'),
              items: shown,
              visible: _visibleRows,
              minFolded: _minFolded,
              toggleKey: const Key('character_anime_more'),
              builder: (context, rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, item) in rows.indexed) ...[
                    if (index > 0) const SegmentedRule(),
                    _AppearanceRow(
                      appearance: item,
                      first: index == 0,
                      onOpen: () => onOpenAnime(item.anime),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The anime worth listing, by air date, undated last.
List<CharacterAppearance> appearancesToShow(
  List<CharacterAppearance> appearances,
) {
  final shown = appearances.where((item) => !isPromoAnimeKind(item.anime.kind));
  return shown.toList()..sort((a, b) {
    final aAiredOn = a.anime.airedOn;
    final bAiredOn = b.anime.airedOn;
    if (aAiredOn.isEmpty != bAiredOn.isEmpty) {
      return aAiredOn.isEmpty ? 1 : -1;
    }
    return aAiredOn.compareTo(bAiredOn);
  });
}

/// Kind, year and role over the title, the Russian title under it when
/// it says something else.
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.appearance,
    required this.first,
    required this.onOpen,
  });

  final CharacterAppearance appearance;

  /// The first row starts level with the section label.
  final bool first;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final anime = appearance.anime;
    final year = yearOfIsoDate(anime.airedOn)?.toString() ?? '';
    final caption = [
      if (anime.kind.isNotEmpty) formatAnimeKind(l10n, anime.kind),
      if (year.isNotEmpty) year,
      formatCharacterRole(l10n, appearance.role),
    ].join(' · ');
    final russian = anime.russian.trim();
    return TapRow(
      inkKey: ValueKey('character_anime_${anime.id}'),
      onTap: onOpen,
      child: Padding(
        padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (russian.isNotEmpty &&
                      russian.toLowerCase() != anime.name.toLowerCase()) ...[
                    const SizedBox(height: 2),
                    Text(
                      russian,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: PixelIcon(PixelGlyph.arrowRight, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
