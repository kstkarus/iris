import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/poster_image.dart';

import '../../../../helpers/test_app.dart';

void main() {
  AnimeListItem item({
    UserRate? userRate,
    String name = 'Frieren',
    String russian = '',
  }) => AnimeListItem(
    anime: AnimeSummary(
      id: '1',
      name: name,
      russian: russian,
      kind: 'tv',
      score: 9.1,
      status: 'released',
      episodes: 28,
      episodesAired: 28,
      airedOn: '2023-09-29',
      posterUrl: '',
    ),
    userRate: userRate,
  );

  Future<void> pumpCard(
    WidgetTester tester,
    AnimeListItem item, {
    UserRateBookCubit? book,
  }) async {
    final card = SizedBox(width: 200, child: AnimeCard(item: item));
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: book == null
              ? card
              : BlocProvider.value(value: book, child: card),
        ),
      ),
    );
  }

  testWidgets('a title not in the list has no plate', (tester) async {
    await pumpCard(tester, item());

    expect(find.textContaining('WATCHING'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('card facts align across title lengths at text scale $scale', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(800, 1500)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 700,
                  child: AdaptiveGridRow(
                    columns: 3,
                    children: [
                      AnimeCard(item: item(russian: 'Фрирен')),
                      AnimeCard(
                        item: item(
                          name: 'Fullmetal Alchemist: Brotherhood',
                          russian: 'Стальной алхимик: Братство',
                        ),
                      ),
                      AnimeCard(item: item(name: 'Death Note')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          theme: buildAppTheme(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byType(PosterImage).first).dx, 32);
      final facts = find.descendant(
        of: find.byType(AnimeCard),
        matching: find.byType(Row),
      );
      expect(facts, findsNWidgets(3));
      final top = tester.getTopLeft(facts.first).dy;
      for (var index = 1; index < 3; index++) {
        expect(tester.getTopLeft(facts.at(index)).dy, closeTo(top, 0.01));
      }
    });
  }

  testWidgets('a title being watched shows its status and progress', (
    tester,
  ) async {
    await pumpCard(
      tester,
      item(
        userRate: const UserRate(
          id: '7',
          status: UserRateStatus.watching,
          episodes: 5,
        ),
      ),
    );

    expect(find.text('WATCHING 5/28'), findsOneWidget);
  });

  testWidgets('a change made elsewhere shows over the loaded page', (
    tester,
  ) async {
    final repository = MockUserRateRepository();
    final book = UserRateBookCubit(repository: repository);
    addTearDown(book.close);
    await pumpCard(
      tester,
      item(
        userRate: const UserRate(
          id: '7',
          status: UserRateStatus.planned,
          episodes: 0,
        ),
      ),
      book: book,
    );
    expect(find.text('PLANNED'), findsOneWidget);

    await tester.runAsync(
      () => repository.save(
        userId: '42',
        animeId: '1',
        rateId: '7',
        status: UserRateStatus.completed,
        episodes: 28,
        score: 0,
      ),
    );
    await tester.pump();

    expect(find.text('COMPLETED'), findsOneWidget);
  });
}
