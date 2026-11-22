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
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';

import '../../../../helpers/test_app.dart';
import '../../../settings/settings_test_doubles.dart';

void main() {
  AnimeListItem item({
    UserRate? userRate,
    String name = 'Frieren',
    String russian = '',
    String english = '',
  }) => AnimeListItem(
    anime: AnimeSummary(
      id: '1',
      name: name,
      russian: russian,
      english: english,
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

  testWidgets('the catalog reorders titles when the preference changes', (
    tester,
  ) async {
    final settings = AppSettingsCubit(
      repository: MemoryAppSettingsRepository(const AppSettings()),
    );
    addTearDown(settings.close);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: settings,
            child: SizedBox(
              width: 200,
              child: AnimeCard(
                item: item(
                  name: 'Sousou no Frieren',
                  russian: 'Фрирен',
                  english: 'Frieren Beyond Journey’s End',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    double top(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(
      top('Frieren Beyond Journey’s End'),
      lessThan(top('Sousou no Frieren')),
    );

    await settings.setAnimeTitleLanguage(AnimeTitleLanguage.russian);
    await tester.pump();
    expect(top('Фрирен'), lessThan(top('Sousou no Frieren')));

    await settings.setAnimeTitleLanguage(AnimeTitleLanguage.romaji);
    await tester.pump();
    expect(
      top('Sousou no Frieren'),
      lessThan(top('Frieren Beyond Journey’s End')),
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('cards with long titles fit at text scale $scale', (
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

    expect(find.text('Watching 5/28'), findsOneWidget);
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
    expect(find.text('Planned'), findsOneWidget);

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

    expect(find.text('Completed'), findsOneWidget);
  });
}
