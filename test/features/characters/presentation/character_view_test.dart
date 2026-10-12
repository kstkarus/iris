import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/cubit/character_cubit.dart';
import 'package:iris/features/characters/presentation/widgets/character_view.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';
import '../characters_test_doubles.dart';

const _frieren = CharacterSummary(
  id: '184947',
  name: 'Frieren',
  russian: 'Фрирен',
  posterUrl: '',
);

void main() {
  late List<AnimeSummary> opened;

  Future<void> pumpView(
    WidgetTester tester,
    FakeCharactersRepository repository, {
    CharacterSummary? preview = _frieren,
    Size size = TestWindowSizes.phone,
    bool load = true,
  }) async {
    setTestWindowSize(tester, size);
    opened = [];
    final cubit = CharacterCubit(characterId: '184947', repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: CharacterView(preview: preview, onOpenAnime: opened.add),
          ),
        ),
      ),
    );
    if (!load) return;
    await tester.runAsync(cubit.load);
    await tester.pumpAndSettle();
  }

  CharacterDetails details({
    String description = 'An elf mage.',
    List<CharacterAppearance> appearances = const [],
  }) => CharacterDetails(
    character: _frieren,
    japanese: 'フリーレン',
    altName: 'Frieren the Slayer',
    description: description,
    appearances: appearances,
  );

  testWidgets('shows what the list knew while the rest loads', (tester) async {
    await pumpView(
      tester,
      FakeCharactersRepository(details: details()),
      load: false,
    );

    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Фрирен'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('An elf mage.'), findsNothing);
  });

  for (final MapEntry(key: name, value: size) in TestWindowSizes.all.entries) {
    testWidgets('names, description and anime on a $name', (tester) async {
      await pumpView(
        tester,
        FakeCharactersRepository(
          details: details(
            appearances: [
              testAppearance('late', airedOn: '2026-01-16'),
              testAppearance('clip', kind: 'music'),
              testAppearance(
                'early',
                airedOn: '2023-09-29',
                role: CharacterRole.supporting,
              ),
            ],
          ),
        ),
        size: size,
      );

      expect(find.text('フリーレン'), findsOneWidget);
      expect(find.text('Frieren the Slayer'), findsOneWidget);
      expect(find.text('An elf mage.'), findsOneWidget);
      expect(find.text('ANIME'), findsOneWidget);
      expect(find.text('Anime clip'), findsNothing);
      expect(find.text('TV · 2023 · SUPPORTING ROLE'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Anime early')).dy,
        lessThan(tester.getTopLeft(find.text('Anime late')).dy),
      );
    });
  }

  testWidgets('an anime row opens the anime', (tester) async {
    await pumpView(
      tester,
      FakeCharactersRepository(
        details: details(appearances: [testAppearance('5114')]),
      ),
    );

    await tester.tap(find.text('Anime 5114'));
    expect(opened.map((anime) => anime.id), ['5114']);
  });

  testWidgets('a long list of anime folds', (tester) async {
    await pumpView(
      tester,
      FakeCharactersRepository(
        details: details(
          appearances: [
            for (var index = 0; index < 8; index++)
              testAppearance('$index', airedOn: '20${10 + index}-01-01'),
          ],
        ),
      ),
    );

    expect(find.text('Anime 4'), findsOneWidget);
    expect(find.text('Anime 5'), findsNothing);
    expect(find.text('3 more'), findsOneWidget);
  });

  testWidgets('no description, no section for it', (tester) async {
    await pumpView(
      tester,
      FakeCharactersRepository(details: details(description: '')),
    );

    expect(find.text('ABOUT'), findsNothing);
  });

  testWidgets('a failure keeps what the list knew and offers to try again', (
    tester,
  ) async {
    final repository = FakeCharactersRepository(details: details())
      ..failing = true;
    await pumpView(tester, repository);

    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Unable to load the character.'), findsOneWidget);
  });

  testWidgets('a failure with nothing known is the whole page', (tester) async {
    await pumpView(
      tester,
      FakeCharactersRepository()..failing = true,
      preview: null,
    );

    expect(find.text('Unable to load the character.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}
