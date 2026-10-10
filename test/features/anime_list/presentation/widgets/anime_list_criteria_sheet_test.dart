import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_genres_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_genres_cubit.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import '../../../../helpers/test_window.dart';

void main() {
  late List<AnimeListQuery> queries;
  late AnimeListBloc bloc;
  late AnimeGenresCubit genres;

  setUp(() {
    queries = [];
    bloc = AnimeListBloc(repository: _Repository(queries));
    genres = AnimeGenresCubit(repository: const MockAnimeGenresRepository());
  });

  tearDown(() async {
    await bloc.close();
    await genres.close();
  });

  Future<void> openSheet(WidgetTester tester, {required bool signedIn}) async {
    setTestWindowSize(tester, const Size(1200, 2400));
    bloc
      ..add(AnimeListAccountChanged(signedIn: signedIn, reload: false))
      ..add(const AnimeListStarted());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bloc),
            BlocProvider.value(value: genres),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAnimeListCriteriaSheet(context),
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
  });

  testWidgets('applies the list, genre, season, rating and length', (
    tester,
  ) async {
    await openSheet(tester, signedIn: true);

    await tester.tap(find.text('Watching'));
    await tester.tap(find.text('Not completed'));
    await tester.tap(find.text('Fantasy'));
    await tester.tap(find.text('Themes (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Military'));
    await tester.tap(find.text('2010s'));
    await tester.tap(find.text('PG-13'));
    await tester.tap(find.text('Over 30 min'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filters = queries.last.filters;
    expect(filters.myList, {UserRateStatus.watching});
    expect(filters.hideCompleted, isTrue);
    expect(filters.genres.map((genre) => genre.name), {'Fantasy', 'Military'});
    expect(filters.seasons.single.apiValue, '2010_2019');
    expect(filters.ratings, {AnimeRatingFilter.pg13});
    expect(filters.durations, {AnimeDurationFilter.long});
  });
}

class _Repository implements AnimeListRepository {
  _Repository(this.queries);

  final List<AnimeListQuery> queries;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    queries.add(query);
    return AnimeListPageResult(
      items: const [],
      page: query.page,
      hasMore: false,
      query: query.search,
    );
  }
}
