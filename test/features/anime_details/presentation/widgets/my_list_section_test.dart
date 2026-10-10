import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  late MockUserRateRepository repository;
  late UserRateCubit cubit;

  setUp(() {
    repository = MockUserRateRepository();
    cubit = UserRateCubit(repository: repository, animeId: '1');
  });

  tearDown(() => cubit.close());

  Future<void> pumpSection(WidgetTester tester, {int total = 12}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: MyListSection(totalEpisodes: total),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('signed out, there is no section', (tester) async {
    await pumpSection(tester);

    expect(find.text('MY LIST'), findsNothing);
  });

  testWidgets('adds the anime with a status from the menu', (tester) async {
    await cubit.accountChanged('42');
    await pumpSection(tester);

    expect(find.text('MY LIST'), findsOneWidget);
    expect(find.text('Add to list'), findsOneWidget);
    expect(find.byKey(MyListSection.episodeMoreKey), findsNothing);

    await tester.tap(find.byKey(MyListSection.statusButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(MyListSection.statusButtonKey),
        matching: find.text('Watching'),
      ),
      findsOneWidget,
    );
    expect(find.text('0 / 12'), findsOneWidget);
    expect((await repository.fetch('1'))?.status, UserRateStatus.watching);
  });

  testWidgets('steps the episodes watched within the total', (tester) async {
    await repository.save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 1,
      score: 0,
    );
    await cubit.accountChanged('42');
    await pumpSection(tester, total: 2);

    await tester.tap(find.byKey(MyListSection.episodeMoreKey));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(MyListSection.episodeMoreKey))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(MyListSection.episodeLessKey));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Episodes watched: 1 / 2'), findsOneWidget);
  });

  testWidgets('takes the anime out of the list', (tester) async {
    await repository.save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.planned,
      episodes: 0,
      score: 0,
    );
    await cubit.accountChanged('42');
    await pumpSection(tester);

    await tester.tap(find.byKey(MyListSection.statusButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from list'));
    await tester.pumpAndSettle();

    expect(find.text('Add to list'), findsOneWidget);
    expect(await repository.fetch('1'), isNull);
  });

  testWidgets('scores from the menu', (tester) async {
    await cubit.accountChanged('42');
    await pumpSection(tester);

    await tester.tap(find.byKey(MyListSection.scoreButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.pumpAndSettle();

    expect(find.text('Score: 9'), findsOneWidget);
    expect((await repository.fetch('1'))?.score, 9);
  });
}
