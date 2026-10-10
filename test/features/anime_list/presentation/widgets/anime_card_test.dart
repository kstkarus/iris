import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  AnimeListItem item({UserRate? userRate}) => AnimeListItem(
    id: '1',
    name: 'Frieren',
    russian: '',
    kind: 'tv',
    score: 9.1,
    status: 'released',
    episodes: 28,
    episodesAired: 28,
    airedOn: '2023-09-29',
    posterMainUrl: '',
    userRate: userRate,
  );

  Future<void> pumpCard(
    WidgetTester tester,
    AnimeListItem item, {
    UserRateBookCubit? book,
  }) async {
    final card = SizedBox(width: 200, child: AnimeCard(item: item));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
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
