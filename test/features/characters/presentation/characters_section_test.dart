import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_cubit.dart';
import 'package:iris/features/characters/presentation/widgets/characters_section.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';
import '../characters_test_doubles.dart';

void main() {
  late FakeCharactersRepository repository;
  final opened = <String, Object?>{};

  Future<void> pumpSection(
    WidgetTester tester,
    List<AnimeCharacter> characters, {
    Locale locale = const Locale('en'),
  }) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    repository = FakeCharactersRepository(characters: characters);
    final cubit = AnimeCharactersCubit(
      animeId: '52991',
      repository: repository,
    );
    addTearDown(cubit.close);
    opened.clear();
    GoRoute opens(String path, String name) => GoRoute(
      path: path,
      name: name,
      builder: (_, state) {
        opened[name] = state.extra;
        return const SizedBox.shrink();
      },
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SingleChildScrollView(
                child: CharactersSection(
                  animeId: '52991',
                  animeName: 'Sousou no Frieren',
                ),
              ),
            ),
          ),
        ),
        opens('/anime/:id/characters', 'anime-characters'),
        opens('/character/:id', 'character'),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(testRouterApp(router, locale: locale));
    await tester.runAsync(cubit.load);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the main characters and opens the rest on a page', (
    tester,
  ) async {
    await pumpSection(tester, [
      for (var index = 0; index < 5; index++) testCharacter('s$index'),
      testCharacter('2', role: CharacterRole.main, name: 'Stark'),
      testCharacter('1', role: CharacterRole.main, name: 'Frieren'),
    ]);

    expect(find.text('CHARACTERS'), findsOneWidget);
    expect(_tiles, findsNWidgets(2));
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Stark'), findsOneWidget);
    expect(find.text('Character s0'), findsNothing);
    expect(find.text('All 7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('characters_all')));
    await tester.pumpAndSettle();
    expect(opened['anime-characters'], 'Sousou no Frieren');
  });

  testWidgets('a portrait opens the character', (tester) async {
    await pumpSection(tester, [
      testCharacter('184947', role: CharacterRole.main, name: 'Frieren'),
    ]);

    expect(find.byKey(const Key('characters_all')), findsNothing);

    await tester.tap(find.text('Frieren'));
    await tester.pumpAndSettle();
    expect(
      opened['character'],
      isA<CharacterSummary>().having((it) => it.id, 'id', '184947'),
    );
  });

  testWidgets('with no main characters, the first of the rest by name', (
    tester,
  ) async {
    await pumpSection(tester, [
      for (final name in [
        'Fern',
        'Aura',
        'Eisen',
        'Denken',
        'Heiter',
        'Bakery',
      ])
        testCharacter(name, name: name),
    ]);

    expect(_tiles, findsNWidgets(4));
    for (final name in ['Aura', 'Bakery', 'Denken', 'Eisen']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('All 6'), findsOneWidget);
  });

  testWidgets('names are Russian in Russian', (tester) async {
    await pumpSection(locale: const Locale('ru'), tester, [
      testCharacter(
        '1',
        role: CharacterRole.main,
        name: 'Frieren',
        russian: 'Фрирен',
      ),
    ]);

    expect(find.text('Фрирен'), findsOneWidget);
    expect(find.text('Frieren'), findsNothing);
  });

  testWidgets('no characters, no section', (tester) async {
    await pumpSection(tester, const []);

    expect(find.text('CHARACTERS'), findsNothing);
  });
}

final _tiles = find.byWidgetPredicate(
  (widget) =>
      widget is InkWell &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('character_'),
);
