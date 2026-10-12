import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_cubit.dart';
import 'package:iris/features/characters/presentation/pages/anime_characters_page.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';
import '../characters_test_doubles.dart';

void main() {
  Future<AnimeCharactersCubit> pumpPage(
    WidgetTester tester,
    FakeCharactersRepository repository,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    final cubit = AnimeCharactersCubit(animeId: '1', repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const AnimeCharactersPage(animeName: 'Sousou no Frieren'),
        ),
      ),
    );
    await tester.runAsync(cubit.load);
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('lists the main characters, then the rest', (tester) async {
    await pumpPage(
      tester,
      FakeCharactersRepository(
        characters: [
          testCharacter('3', name: 'Aura'),
          testCharacter('1', role: CharacterRole.main, name: 'Frieren'),
          testCharacter('2', name: 'Heiter'),
        ],
      ),
    );

    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Sousou no Frieren'), findsOneWidget);
    final main = tester.getTopLeft(find.text('MAIN'));
    final frieren = tester.getTopLeft(find.text('Frieren'));
    final supporting = tester.getTopLeft(find.text('SUPPORTING'));
    final aura = tester.getTopLeft(find.text('Aura'));
    final heiter = tester.getTopLeft(find.text('Heiter'));
    expect(main.dy, lessThan(frieren.dy));
    expect(frieren.dy, lessThan(supporting.dy));
    expect(supporting.dy, lessThan(aura.dy));
    expect(aura.dy, heiter.dy);
    expect(aura.dx, lessThan(heiter.dx));
  });

  testWidgets('a failure offers to try again', (tester) async {
    final repository = FakeCharactersRepository(
      characters: [testCharacter('1', name: 'Aura')],
    )..failing = true;
    await pumpPage(tester, repository);

    expect(find.text('Unable to load the characters.'), findsOneWidget);

    repository.failing = false;
    await tester.tap(find.text('Try Again'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Aura'), findsOneWidget);
  });
}
