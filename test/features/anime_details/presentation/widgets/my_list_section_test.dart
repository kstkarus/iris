import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/status_views.dart';

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

  testWidgets('while the entry loads, its controls are noise', (tester) async {
    final gate = Completer<void>();
    final slow = UserRateCubit(
      repository: _SlowRates(repository, gate),
      animeId: '1',
    );
    addTearDown(slow.close);
    unawaited(slow.accountChanged('42'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: slow,
            child: const MyListSection(totalEpisodes: 12),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BlockSpinner), findsNothing);
    expect(
      tester
          .widget<AppSkeleton>(
            find.ancestor(
              of: find.text('Add to list'),
              matching: find.byType(AppSkeleton),
            ),
          )
          .enabled,
      isTrue,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(MyListSection.statusButtonKey), findsOneWidget);
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

/// [inner], with the entry held back until [gate] opens.
class _SlowRates implements UserRateRepository {
  _SlowRates(this.inner, this.gate);

  final UserRateRepository inner;
  final Completer<void> gate;

  @override
  Stream<UserRateChange> get changes => inner.changes;

  @override
  Future<UserRate?> fetch(String animeId) async {
    await gate.future;
    return inner.fetch(animeId);
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) => inner.save(
    userId: userId,
    animeId: animeId,
    rateId: rateId,
    status: status,
    episodes: episodes,
    score: score,
  );

  @override
  Future<void> remove({required String animeId, required String rateId}) =>
      inner.remove(animeId: animeId, rateId: rateId);
}
