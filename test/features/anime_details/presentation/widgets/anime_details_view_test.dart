import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/shared/models/details_description.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../anime_details_test_doubles.dart';

void main() {
  testWidgets('announces loading without a preview', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: PendingAnimeDetailsRepository(),
    );

    await tester.pumpWidget(_app(cubit..loadAnime()));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading anime details'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a preview and source button remain available while loading', (
    tester,
  ) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: PendingAnimeDetailsRepository(),
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pump();

    expect(find.text(fmaDetails.anime.name), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Choose source');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('shows anime details when loading succeeds', (tester) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: const FixedAnimeDetailsRepository(),
    );

    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit..loadAnime(),
          child: const Scaffold(body: AnimeDetailsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Choose source'), findsOneWidget);
    for (final fact in [
      'Type',
      'TV',
      'Released',
      'Episodes',
      '64',
      'Score',
      '9.12',
      'Apr 5, 2009',
    ]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
    expect(
      find.text(
        'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('synopsis links open their character and Back returns', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: FixedAnimeDetailsRepository(
        AnimeDetails(
          anime: fmaDetails.anime,
          description: const DetailsDescription(
            'The cast includes Яхве and Ичиго Куросаки.',
            characterLinks: [
              (start: 18, end: 22, characterId: '68537'),
              (start: 27, end: 41, characterId: '5'),
            ],
          ),
        ),
      ),
    )..loadAnime();
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const AnimeDetailsView(),
            ),
          ),
        ),
        GoRoute(
          path: '/character/:id',
          name: 'character',
          builder: (_, state) =>
              Scaffold(body: Text('Character ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(testRouterApp(router));
    for (final (label, id, size) in [
      ('Яхве', '68537', TestWindowSizes.phone),
      ('Ичиго Куросаки', '5', TestWindowSizes.desktop),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final link = find.text(label);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(link),
        isSemantics(label: label, isLink: true, hasTapAction: true),
      );
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('Character $id'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(link, findsOneWidget);
    }
  });

  testWidgets('the details add the next episode, studio, genres and rating', (
    tester,
  ) async {
    final airing = AnimeDetails(
      anime: AnimeSummary(
        id: '5114',
        name: 'Airing',
        russian: 'Выходит',
        kind: 'tv',
        score: 8,
        status: 'ongoing',
        episodes: 12,
        episodesAired: 6,
        airedOn: '2026-07',
        posterUrl: '',
        nextEpisodeAt: DateTime.now().add(const Duration(days: 3)),
      ),
      description: const DetailsDescription('About it.'),
      rating: 'pg_13',
      studios: const ['Bones', 'MAPPA'],
      genres: const [
        AnimeGenreName(name: 'Action', russian: 'Экшен'),
        AnimeGenreName(name: 'Drama', russian: ''),
      ],
    );
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: FixedAnimeDetailsRepository(airing),
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), locale: 'ru'));
    await tester.pumpAndSettle();

    for (final fact in [
      'Следующая',
      '7 серия через 3 дня',
      'Студия',
      'Bones, MAPPA',
      'Жанры',
      'Экшен, Drama',
      'Рейтинг',
      'PG-13',
    ]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
  });

  testWidgets('a released title has no next episode', (tester) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: FixedAnimeDetailsRepository(
        AnimeDetails(
          anime: AnimeSummary(
            id: '5114',
            name: 'Done',
            russian: '',
            kind: 'tv',
            score: 8,
            status: 'released',
            episodes: 12,
            episodesAired: 12,
            airedOn: '2020',
            posterUrl: '',
            nextEpisodeAt: DateTime.now().add(const Duration(days: 3)),
          ),
          description: const DetailsDescription('About it.'),
        ),
      ),
    );

    await tester.pumpWidget(_app(cubit..loadAnime()));
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsNothing);
  });

  testWidgets('shows localized details metadata for Russian locale', (
    tester,
  ) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: const FixedAnimeDetailsRepository(),
    );

    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit..loadAnime(),
          child: const Scaffold(body: AnimeDetailsView()),
        ),
        locale: const Locale('ru'),
      ),
    );

    await tester.pumpAndSettle();

    for (final fact in [
      'Статус',
      'Вышло',
      'Оценка',
      '9,12',
      '5 апр. 2009\u00A0г.',
    ]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
  });

  testWidgets('shows error state and retries loading', (tester) async {
    final repository = _ToggleAnimeDetailsRepository();
    final cubit = AnimeDetailsCubit(animeId: '5114', repository: repository);

    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit..loadAnime(),
          child: const Scaffold(body: AnimeDetailsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unable to load anime details.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
  });

  testWidgets('a failure keeps what the preview knew and the way to sources', (
    tester,
  ) async {
    final repository = _ToggleAnimeDetailsRepository();
    final cubit = AnimeDetailsCubit(animeId: '5114', repository: repository);

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pumpAndSettle();

    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Choose source'), findsOneWidget);
    expect(find.text('Unable to load anime details.'), findsOneWidget);

    repository.shouldFail = false;
    await tester.ensureVisible(find.text('Try Again'));
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load anime details.'), findsNothing);
    expect(find.text(fmaDetails.description.text), findsOneWidget);
  });

  testWidgets('screen readers hear the name once', (tester) async {
    final semantics = tester.ensureSemantics();
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpPage(tester);
    // The heading, and the cover named after the anime.
    final before = find
        .bySemanticsLabel(_longDetails.anime.name)
        .evaluate()
        .length;
    await _scrollBy(tester, _nameBelowBar(tester) + 4);

    expect(_barTitle, findsOneWidget);
    expect(
      find.bySemanticsLabel(_longDetails.anime.name),
      findsNWidgets(before),
    );
    semantics.dispose();
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('adapts the details layout on ${entry.key}', (tester) async {
      setTestWindowSize(tester, entry.value);
      final cubit = AnimeDetailsCubit(
        animeId: '5114',
        repository: FixedAnimeDetailsRepository(_longDetails),
      );

      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: cubit..loadAnime(),
            child: const AnimeDetailsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_longDetails.anime.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the overflowing desktop rail passes excess wheel scroll on', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1280, 420));
    await _pumpPage(tester);

    final rail = find.byType(ListView);
    final railPosition = tester.widget<ListView>(rail).controller!.position;
    final mainPosition = tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('anime_details_scroll')),
        )
        .controller!
        .position;
    final bottom = railPosition.maxScrollExtent;
    expect(bottom, greaterThan(12));

    Future<void> wheel(double delta) async {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: tester.getCenter(rail),
          scrollDelta: Offset(0, delta),
        ),
      );
      await tester.pump();
    }

    await wheel(bottom - 12);
    expect(railPosition.pixels, closeTo(bottom - 12, 0.01));
    expect(mainPosition.pixels, 0);

    await wheel(36);
    expect(railPosition.pixels, bottom);
    expect(mainPosition.pixels, closeTo(24, 0.01));
    await wheel(16);
    expect(railPosition.pixels, bottom);
    expect(mainPosition.pixels, closeTo(40, 0.01));

    await wheel(-bottom);
    expect(railPosition.pixels, 0);
    expect(mainPosition.pixels, closeTo(40, 0.01));
    await wheel(-16);
    expect(railPosition.pixels, 0);
    expect(mainPosition.pixels, closeTo(24, 0.01));
  });

  testWidgets('collapses empty description smoothly without layout error', (
    tester,
  ) async {
    final gate = Completer<AnimeDetails>();
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _FutureAnimeDetailsRepository(gate.future),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pump();
    expect(find.text('Synopsis'), findsOneWidget);

    gate.complete(
      AnimeDetails(
        anime: fmaDetails.anime,
        description: const DetailsDescription(''),
      ),
    );
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle();

    expect(find.text('Synopsis'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  final cubit = AnimeDetailsCubit(
    animeId: '5114',
    repository: FixedAnimeDetailsRepository(_longDetails),
  );
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit..loadAnime(),
        child: const AnimeDetailsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The anime name in the bar, not on the page.
Finder get _barTitle => find.descendant(
  of: find.byType(AppBar),
  matching: find.text(_longDetails.anime.name),
);

/// Scrolls the page by [dy] and waits for the bar to settle.
Future<void> _scrollBy(WidgetTester tester, double dy) async {
  final page = find.byType(SingleChildScrollView).first;
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: page, matching: find.byType(Scrollable)).first,
      )
      .position;
  position.jumpTo(position.pixels + dy);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// How far the page name's lower edge is below the bar.
double _nameBelowBar(WidgetTester tester) {
  final name = tester.getRect(
    find.descendant(
      of: find.byType(SingleChildScrollView).first,
      matching: find.text(_longDetails.anime.name),
    ),
  );
  return name.bottom - tester.getRect(find.byType(AppBar)).bottom;
}

Widget _app(
  AnimeDetailsCubit cubit, {
  AnimeDetailsPreview? preview,
  String locale = 'en',
}) {
  return testApp(
    BlocProvider.value(
      value: cubit,
      child: Scaffold(body: AnimeDetailsView(preview: preview)),
    ),
    locale: Locale(locale),
  );
}

class _ToggleAnimeDetailsRepository implements AnimeDetailsRepository {
  bool shouldFail = true;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async {
    if (shouldFail) {
      throw Exception('First call fails');
    }

    return fmaDetails;
  }
}

class _FutureAnimeDetailsRepository implements AnimeDetailsRepository {
  _FutureAnimeDetailsRepository(this.future);

  final Future<AnimeDetails> future;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) => future;
}

final _preview = AnimeDetailsPreview.fromSummary(
  AnimeSummary(
    id: fmaDetails.anime.id,
    name: fmaDetails.anime.name,
    russian: fmaDetails.anime.russian,
    kind: fmaDetails.anime.kind,
    score: fmaDetails.anime.score,
    status: fmaDetails.anime.status,
    episodes: fmaDetails.anime.episodes,
    episodesAired: fmaDetails.anime.episodesAired,
    airedOn: fmaDetails.anime.airedOn,
    posterUrl: 'https://shikimori.one/posters/5114/main.jpg',
  ),
);

final _longDetails = AnimeDetails(
  anime: fmaDetails.anime,
  description: DetailsDescription(
    List.filled(40, fmaDetails.description.text).join(' '),
  ),
);
