import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_genres_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_genres_cubit.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_list_preview_cubit.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../anime_list_test_doubles.dart';

void main() {
  late RecordingAnimeListRepository repository;
  late AnimeListBloc bloc;
  late AnimeGenresCubit genres;

  setUp(() {
    repository = RecordingAnimeListRepository();
    bloc = AnimeListBloc(repository: repository);
    genres = AnimeGenresCubit(repository: const MockAnimeGenresRepository());
  });

  tearDown(() async {
    await bloc.close();
    await genres.close();
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required bool signedIn,
    AnimeListPreviewCubit? preview,
    String? search,
  }) async {
    setTestWindowSize(tester, const Size(1200, 2400));
    bloc
      ..add(AnimeListAccountChanged(signedIn: signedIn, reload: false))
      ..add(const AnimeListStarted());
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: genres),
            if (preview != null) BlocProvider.value(value: preview),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showAnimeListCriteriaSheet(context, search: search),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the user list is not offered', (tester) async {
    await openSheet(tester, signedIn: false);

    expect(find.text('NOT COMPLETED'), findsNothing);
    expect(find.text('Not completed'), findsNothing);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Military'), findsOneWidget);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('applies the list, genre, season, rating and length', (
    tester,
  ) async {
    await openSheet(tester, signedIn: true);

    await tester.tap(find.text('Watching'));
    await tester.tap(find.text('Not completed'));
    await tester.tap(find.text('Fantasy'));
    await tester.tap(find.text('Military'));
    await tester.tap(find.text('2010s'));
    await tester.tap(find.text('PG-13'));
    await tester.tap(find.text('Over 30 min'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    final filters = repository.queries.last.filters;
    expect(filters.myList, {UserRateStatus.watching});
    expect(filters.hideCompleted, isTrue);
    expect(filters.genres.map((genre) => genre.name), {'Fantasy', 'Military'});
    expect(filters.seasons.single, const SeasonFilter.decade(2010));
    expect(filters.ratings, {AnimeRatingFilter.pg13});
    expect(filters.durations, {AnimeDurationFilter.long});
  });
  testWidgets('preview uses the field query before search debounce completes', (
    tester,
  ) async {
    final preview = AnimeListPreviewCubit(repository: repository);
    addTearDown(preview.close);
    await openSheet(
      tester,
      signedIn: false,
      preview: preview,
      search: 'pending query',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'pending query');
    expect(repository.queries.last.limit, 50);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('count reveal keeps its animation when the result is capped', (
    tester,
  ) async {
    final preview = _ControlledPreview();
    addTearDown(preview.close);
    await openSheet(tester, signedIn: false, preview: preview);
    final skeleton = find.descendant(
      of: find.byType(AppSkeleton),
      matching: find.byWidgetPredicate((widget) => widget is Skeletonizer),
    );
    for (final count in [1, 42, 50]) {
      preview.show((loading: true, count: null, hasMore: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final before = tester.state(skeleton);
      preview.show((loading: false, count: count, hasMore: count == 50));
      await tester.pump();
      expect(
        identical(tester.state(skeleton), before),
        isTrue,
        reason: '$count',
      );
      final label = find.descendant(
        of: find.byType(AppSkeleton),
        matching: find.text('$count${count == 50 ? '+' : ''}'),
      );
      final mask = find.ancestor(of: label, matching: find.byType(BayerMasked));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<BayerMasked>(mask.first).open,
        inExclusiveRange(0, 16),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'genres fold after ten, selected tags stay, audience is separate',
    (tester) async {
      await genres.close();
      genres = AnimeGenresCubit(repository: _ManyGenres());
      await openSheet(tester, signedIn: false);
      expect(find.text('AUDIENCE'), findsOneWidget);
      expect(find.text('Shounen'), findsOneWidget);
      expect(find.text('Genre 9'), findsOneWidget);
      expect(find.text('Genre 10'), findsNothing);
      await tester.tap(find.text('More (4)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Genre 13'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Genre 13'), findsOneWidget);
      expect(find.text('Genre 10'), findsNothing);
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();
      expect(bloc.state.filters.genres.single.name, 'Genre 13');
    },
  );

  testWidgets('selected tags invert without shifting their hit targets', (
    tester,
  ) async {
    await openSheet(tester, signedIn: false);
    final tag = find.widgetWithText(OutlinedButton, 'TV');
    final before = tester.getRect(tag);
    for (final label in ['TV', 'G']) {
      final button = find.widgetWithText(OutlinedButton, label);
      final surface = find
          .descendant(of: button, matching: find.byType(Material))
          .first;
      expect(tester.getRect(surface).left, tester.getRect(button).left);
    }
    await tester.tap(tag);
    await tester.pumpAndSettle();
    expect(tester.getRect(tag), before);
    expect(before.height, greaterThanOrEqualTo(44));
    final style = tester.widget<OutlinedButton>(tag).style!;
    final scheme = Theme.of(tester.element(tag)).colorScheme;
    expect(style.backgroundColor!.resolve({}), scheme.onSurface);
    expect(style.foregroundColor!.resolve({}), scheme.surface);
  });

  testWidgets('dismissing a draft leaves the catalog criteria untouched', (
    tester,
  ) async {
    await openSheet(tester, signedIn: false);
    await tester.tap(find.text('Score'));
    await tester.tap(find.text('Movie'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(bloc.state.sort, AnimeListSortOption.popularity);
    expect(bloc.state.filters.hasAny, isFalse);
  });
}

class _ControlledPreview extends AnimeListPreviewCubit {
  _ControlledPreview() : super(repository: RecordingAnimeListRepository());

  void show(AnimeListPreview state) => emit(state);
}

class _ManyGenres implements AnimeGenresRepository {
  @override
  Future<List<AnimeGenre>> genres() async => [
    for (var i = 0; i < 14; i++)
      AnimeGenre(
        id: '$i',
        name: 'Genre $i',
        russian: '',
        kind: AnimeGenreKind.genre,
      ),
    const AnimeGenre(
      id: '99',
      name: 'Shounen',
      russian: '',
      kind: AnimeGenreKind.demographic,
    ),
  ];
}
