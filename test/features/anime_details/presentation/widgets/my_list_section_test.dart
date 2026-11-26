import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/my_list_section.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';

import '../../../../helpers/record_haptics.dart';
import '../../../../helpers/test_app.dart';

void main() {
  late MockUserRateRepository repository;
  late UserRateCubit cubit;

  setUp(() {
    repository = MockUserRateRepository();
    cubit = UserRateCubit(repository: repository, animeId: '1');
  });

  tearDown(() => cubit.close());

  Future<void> pumpSection(
    WidgetTester tester, {
    int total = 12,
    UserRateCubit? rateCubit,
  }) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: rateCubit ?? cubit,
            child: MyListSection(totalEpisodes: total),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('list controls follow sign-in and sign-out', (tester) async {
    await pumpSection(tester);

    expect(find.byKey(MyListSection.statusButtonKey), findsNothing);
    expect(find.byKey(MyListSection.scoreButtonKey), findsNothing);

    await tester.runAsync(() => cubit.accountChanged('42'));
    await tester.pump();
    expect(find.byKey(MyListSection.statusButtonKey), findsOneWidget);
    expect(find.byKey(MyListSection.scoreButtonKey), findsOneWidget);

    await tester.runAsync(() => cubit.accountChanged(null));
    await tester.pump();
    expect(find.byKey(MyListSection.statusButtonKey), findsNothing);
    expect(find.byKey(MyListSection.scoreButtonKey), findsNothing);
  });

  testWidgets('the entry cannot be edited until it loads', (tester) async {
    final gate = Completer<void>();
    final slow = UserRateCubit(
      repository: _SlowRates(repository, gate),
      animeId: '1',
    );
    addTearDown(slow.close);
    unawaited(slow.accountChanged('42'));
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: slow,
            child: const MyListSection(totalEpisodes: 12),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(MyListSection.statusButtonKey), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(MyListSection.statusButtonKey), findsOneWidget);
  });

  testWidgets('adds the anime with a status from the menu', (tester) async {
    await cubit.accountChanged('42');
    await pumpSection(tester);

    expect(find.text('My list'), findsOneWidget);
    expect(find.text('Add to list'), findsOneWidget);
    expect(find.byKey(MyListSection.episodeMoreKey), findsNothing);
    for (final key in [
      MyListSection.statusButtonKey,
      MyListSection.scoreButtonKey,
    ]) {
      expect(
        tester
            .getSemantics(find.byKey(key))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
      );
    }

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
    final effects = recordHaptics();
    await repository.save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 1180,
      score: 0,
    );
    await cubit.accountChanged('42');
    await pumpSection(tester, total: 1181);
    cubit.setScore(7);
    await tester.pumpAndSettle();
    expect(effects, isEmpty);

    await tester.tap(find.byKey(MyListSection.episodeMoreKey));
    await tester.pumpAndSettle();
    expect(find.text('1181 / 1181'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(MyListSection.episodeMoreKey))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(MyListSection.episodeMoreKey));
    await tester.pumpAndSettle();
    expect(effects, [HapticsType.selection]);

    await tester.tap(find.byKey(MyListSection.episodeLessKey));
    await tester.pumpAndSettle();
    expect(find.text('1180 / 1181'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Episodes watched: 1180 / 1181'),
      findsOneWidget,
    );
    expect(effects, [HapticsType.selection, HapticsType.selection]);
  });

  testWidgets('a rejected list edit rolls back with an error haptic', (
    tester,
  ) async {
    final effects = recordHaptics();
    final rejectingCubit = UserRateCubit(
      repository: _RejectingRates(),
      animeId: '1',
    );
    addTearDown(rejectingCubit.close);
    await rejectingCubit.accountChanged('42');
    await pumpSection(tester, rateCubit: rejectingCubit);
    expect(effects, isEmpty);

    await tester.tap(find.byKey(MyListSection.statusButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t save to Shikimori.'), findsOneWidget);
    expect(find.text('Add to list'), findsOneWidget);
    expect(effects, [HapticsType.selection, HapticsType.error]);
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

  testWidgets('keeps one AppSkeleton across loading to loaded transition', (
    tester,
  ) async {
    final gate = Completer<void>();
    final slow = UserRateCubit(
      repository: _SlowRates(repository, gate),
      animeId: '1',
    );
    addTearDown(slow.close);
    unawaited(slow.accountChanged('42'));
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: slow,
            child: const MyListSection(totalEpisodes: 12),
          ),
        ),
      ),
    );
    await tester.pump();

    final loadingSkeleton = tester.element(find.byType(AppSkeleton));
    expect(
      tester.widget<AppSkeleton>(find.byType(AppSkeleton)).enabled,
      isTrue,
    );

    gate.complete();
    await tester.pump();
    expect(tester.element(find.byType(AppSkeleton)), same(loadingSkeleton));
    expect(
      tester.widget<AppSkeleton>(find.byType(AppSkeleton)).enabled,
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(MyListSection.statusButtonKey), findsOneWidget);
  });

  testWidgets('honors disableAnimations when stepping and adding', (
    tester,
  ) async {
    await cubit.accountChanged('42');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: testApp(
          Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const MyListSection(totalEpisodes: 12),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(MyListSection.statusButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watching'));
    await tester.pump();
    await tester.pump();

    expect(find.text('0 / 12'), findsOneWidget);
    await tester.tap(find.byKey(MyListSection.episodeMoreKey));
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 12'), findsOneWidget);
  });
}

class _RejectingRates extends MockUserRateRepository {
  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    int? episodes,
    int? score,
    int? rewatches,
  }) async => throw Exception('save failed');
}

/// [inner], with the entry held back until [gate] opens.
class _SlowRates implements UserRateRepository {
  @override
  Future<T> editRate<T>(Future<T> Function(UserRateRepository) edit) =>
      edit(this);

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
  Future<({UserRate? rate, int totalEpisodes})> fetchWithTotal(
    String animeId,
  ) async {
    await gate.future;
    return inner.fetchWithTotal(animeId);
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    int? episodes,
    int? score,
    int? rewatches,
  }) => inner.save(
    userId: userId,
    animeId: animeId,
    rateId: rateId,
    status: status,
    episodes: episodes,
    score: score,
    rewatches: rewatches,
  );

  @override
  Future<void> remove({required String animeId, required String rateId}) =>
      inner.remove(animeId: animeId, rateId: rateId);
}
