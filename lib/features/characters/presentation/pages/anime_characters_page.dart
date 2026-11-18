import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/character_names.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_cubit.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_state.dart';
import 'package:iris/features/characters/presentation/widgets/character_tile.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Every character of an anime as portraits, main ones first: it needs an
/// [AnimeCharactersCubit] for the anime.
class AnimeCharactersPage extends StatelessWidget {
  const AnimeCharactersPage({required this.animeName, super.key});

  /// Empty when the page was opened by a link.
  final String animeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: FramedAppBar(
        title: PageTitle(
          title: l10n.charactersTitle,
          subtitle: animeName.isEmpty ? null : animeName,
        ),
      ),
      body: SafeArea(
        top: false,
        child: PageFrame.subPage(
          child: BlocBuilder<AnimeCharactersCubit, AnimeCharactersState>(
            builder: (context, state) => DitherSwitcher(
              expand: true,
              duration: const Duration(milliseconds: 240),
              child: switch (state) {
                AnimeCharactersLoading() => const _Grid(
                  key: ValueKey('grid'),
                  characters: null,
                ),
                AnimeCharactersLoaded(:final characters)
                    when characters.isEmpty =>
                  MessageView(
                    key: const ValueKey('empty'),
                    message: l10n.charactersEmpty,
                  ),
                AnimeCharactersLoaded(:final characters) => _Grid(
                  key: const ValueKey('grid'),
                  characters: characters,
                ),
                AnimeCharactersFailure() => RetryView(
                  key: const ValueKey('failure'),
                  message: l10n.charactersLoadError,
                  onRetry: () => context.read<AnimeCharactersCubit>().load(),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in portrait used to give skeleton noise the shape of a row.
const _standInCharacter = CharacterSummary(
  id: '',
  name: 'A name',
  russian: '',
  posterUrl: '',
);

/// The characters under a label per role, built row by row as they
/// scroll in; null [characters] are noise while they load.
class _Grid extends StatelessWidget {
  const _Grid({required this.characters, super.key});

  final List<AnimeCharacter>? characters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = characters == null;
    final ordered = loading
        ? const <AnimeCharacter>[]
        : charactersInOrder(l10n, characters!);
    return AppSkeleton(
      enabled: loading,
      semanticLabel: l10n.charactersLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = adaptiveColumnCount(
            availableWidth: constraints.maxWidth,
            minItemWidth: WindowSizeClass.of(context).isCompact
                ? CharacterTileSizes.compactMinWidth
                : CharacterTileSizes.minWidth,
            spacing: CharacterTileSizes.gap,
            maxColumns: 1 << 20,
          );
          final items = <_Item>[];
          if (loading) {
            items
              ..add(const _Label(CharacterRole.main))
              ..add(_Row(List.filled(columns, _standInCharacter)))
              ..add(const _Label(CharacterRole.supporting))
              ..add(_Row(List.filled(columns, _standInCharacter)))
              ..add(_Row(List.filled(columns, _standInCharacter)));
          } else {
            for (final role in CharacterRole.values) {
              final group = [
                for (final item in ordered)
                  if (item.role == role) item.character,
              ];
              if (group.isEmpty) continue;
              items.add(_Label(role));
              for (var start = 0; start < group.length; start += columns) {
                items.add(_Row(group.skip(start).take(columns).toList()));
              }
            }
          }
          return ListView.builder(
            key: const Key('anime_characters_grid'),
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: items.length,
            itemBuilder: (context, index) => switch (items[index]) {
              _Label(:final role) => Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 12),
                child: SectionLabel(
                  switch (role) {
                    CharacterRole.main => l10n.charactersMainTitle,
                    CharacterRole.supporting => l10n.charactersSupportingTitle,
                  },
                  style: DetailLayout.sectionTitleStyle(Theme.of(context)),
                  uppercase: false,
                ),
              ),
              _Row(:final characters) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: CharacterTileRow(
                  characters: characters,
                  columns: columns,
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

sealed class _Item {
  const _Item();
}

final class _Label extends _Item {
  const _Label(this.role);

  final CharacterRole role;
}

final class _Row extends _Item {
  const _Row(this.characters);

  final List<CharacterSummary> characters;
}
