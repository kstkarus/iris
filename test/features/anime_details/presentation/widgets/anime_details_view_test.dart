import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/dithered_image.dart';
import 'package:iris/shared/widgets/spec_table.dart';

import '../../../../helpers/test_window.dart';

void main() {
  testWidgets('without a preview the whole page is noise while loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _PendingAnimeDetailsRepository(),
    );

    await tester.pumpWidget(_app(cubit..loadAnime()));
    await tester.pump();

    expect(_skeletonAround(tester, find.text('Choose source')).enabled, isTrue);
    expect(find.bySemanticsLabel('Loading anime details...'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('anime title')), findsNothing);
    semantics.dispose();
  });

  testWidgets('a preview shows at once; only the description waits', (
    tester,
  ) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _PendingAnimeDetailsRepository(),
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pump();

    expect(find.text(_details.name), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(_skeletonAround(tester, find.text(_details.name)).enabled, isFalse);
    final button = find.widgetWithText(FilledButton, 'Choose source');
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(_skeletonAround(tester, _standIn).enabled, isTrue);
  });

  testWidgets('a long title sets smaller to keep the facts beside the cover', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1536, 800));
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _PendingAnimeDetailsRepository(),
    );
    final preview = AnimeDetailsPreview(
      id: _preview.id,
      name: 'Re:Zero kara Hajimeru Isekai Seikatsu 4th Season',
      russian: _preview.russian,
      kind: _preview.kind,
      score: _preview.score,
      status: _preview.status,
      episodes: _preview.episodes,
      episodesAired: _preview.episodesAired,
      airedOn: _preview.airedOn,
      posterUrl: _preview.posterUrl,
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: preview));
    await tester.pump();

    final poster = tester.getRect(find.byType(DitheredImage).first);
    // The facts beside the cover; the details' own rows wait below it.
    final facts = tester.getRect(find.byType(SpecTable).first);
    expect(facts.bottom, lessThanOrEqualTo(poster.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rows the details bring hold their place as noise', (
    tester,
  ) async {
    final details = Completer<AnimeDetails>();
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _CompleterAnimeDetailsRepository(details),
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pump();

    final moreFacts = find.byKey(const Key('anime_details_more_facts'));
    expect(moreFacts, findsOneWidget);
    expect(_skeletonAround(tester, moreFacts).enabled, isTrue);
    // The labels are known already: only the values are noise.
    expect(find.text('Studio'), findsOneWidget);
    final top = tester.getTopLeft(moreFacts).dy;

    details.complete(
      AnimeDetails(
        id: _details.id,
        name: _details.name,
        russian: _details.russian,
        description: _details.description,
        kind: _details.kind,
        score: _details.score,
        status: _details.status,
        episodes: _details.episodes,
        episodesAired: _details.episodesAired,
        airedOn: _details.airedOn,
        posterOriginalUrl: _details.posterOriginalUrl,
        studios: const ['Bones'],
        rating: 'r',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bones'), findsOneWidget);
    expect(_skeletonAround(tester, moreFacts).enabled, isFalse);
    expect(tester.getTopLeft(moreFacts).dy, top);
  });

  testWidgets('the description develops out of the noise', (tester) async {
    final details = Completer<AnimeDetails>();
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _CompleterAnimeDetailsRepository(details),
    );

    await tester.pumpWidget(_app(cubit..loadAnime(), preview: _preview));
    await tester.pump();

    details.complete(_details);
    await tester.pump();
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(find.text(_details.description), findsOneWidget);
    expect(_standIn, findsOneWidget, reason: 'still leaving');

    await tester.pump(DitherTransition.duration);
    expect(_standIn, findsNothing);
    expect(find.text(_details.name), findsOneWidget);
  });

  testWidgets('shows anime details when loading succeeds', (tester) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _SuccessAnimeDetailsRepository(_details),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
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

  testWidgets('the details add the next episode, studio, genres and rating', (
    tester,
  ) async {
    final airing = AnimeDetails(
      id: '5114',
      name: 'Airing',
      russian: 'Выходит',
      description: 'About it.',
      kind: 'tv',
      score: 8,
      status: 'ongoing',
      episodes: 12,
      episodesAired: 6,
      airedOn: '2026-07',
      posterOriginalUrl: '',
      nextEpisodeAt: DateTime.now().add(const Duration(days: 3)),
      rating: 'pg_13',
      studios: const ['Bones', 'MAPPA'],
      genres: const [
        AnimeGenreName(name: 'Action', russian: 'Экшен'),
        AnimeGenreName(name: 'Drama', russian: ''),
      ],
    );
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _SuccessAnimeDetailsRepository(airing),
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

  testWidgets('a released title has no next episode; the dubs fold', (
    tester,
  ) async {
    final dubs = [for (var i = 1; i <= 16; i++) 'Team $i'];
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _SuccessAnimeDetailsRepository(
        AnimeDetails(
          id: '5114',
          name: 'Done',
          russian: '',
          description: 'About it.',
          kind: 'tv',
          score: 8,
          status: 'released',
          episodes: 12,
          episodesAired: 12,
          airedOn: '2020',
          posterOriginalUrl: '',
          nextEpisodeAt: DateTime.now().add(const Duration(days: 3)),
          fandubbers: dubs,
        ),
      ),
    );

    await tester.pumpWidget(_app(cubit..loadAnime()));
    await tester.pumpAndSettle();

    expect(find.text('Next'), findsNothing);
    expect(find.byKey(const Key('anime_details_more_facts')), findsNothing);
    final names = find.byKey(const Key('dubs_section_names'));
    await tester.ensureVisible(names);
    expect(tester.widget<Text>(names).data, dubs.take(12).join(' · '));

    final more = find.byKey(const Key('dubs_section_more'));
    await tester.ensureVisible(more);
    expect(find.text('4 more'), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(names).data, dubs.join(' · '));
  });

  testWidgets('shows localized details metadata for Russian locale', (
    tester,
  ) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _SuccessAnimeDetailsRepository(_details),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit..loadAnime(),
          child: const Scaffold(body: AnimeDetailsView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    for (final fact in [
      'Статус',
      'Вышло',
      'Оценка',
      '9,12',
      '5 апр. 2009 г.',
    ]) {
      expect(find.text(fact), findsOneWidget, reason: fact);
    }
  });

  testWidgets('shows error state and retries loading', (tester) async {
    final repository = _ToggleAnimeDetailsRepository();
    final cubit = AnimeDetailsCubit(animeId: '5114', repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
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
    expect(_standIn, findsNothing);

    repository.shouldFail = false;
    await tester.ensureVisible(find.text('Try Again'));
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load anime details.'), findsNothing);
    expect(find.text(_details.description), findsOneWidget);
  });

  for (final entry in {
    'phone': TestWindowSizes.phone,
    'desktop': TestWindowSizes.desktop,
  }.entries) {
    testWidgets('the bar takes the name over once it is gone on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      await _pumpPage(tester);
      expect(_barTitle, findsNothing);

      // A sliver of the name still shows: the page still has it.
      await _scrollBy(tester, _nameBelowBar(tester) - 4);
      expect(_barTitle, findsNothing);

      await _scrollBy(tester, 8);
      expect(_barTitle, findsOneWidget);

      await _scrollBy(tester, -200);
      expect(_barTitle, findsNothing);
    });
  }

  testWidgets('the name develops in the bar rather than appearing', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpPage(tester);
    final page = find.byType(SingleChildScrollView).first;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: page, matching: find.byType(Scrollable)).first,
        )
        .position;

    position.jumpTo(position.pixels + _nameBelowBar(tester) + 4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final masked = find.ancestor(
      of: _barTitle,
      matching: find.byType(BayerMasked),
    );
    expect(tester.widget<BayerMasked>(masked.first).open, greaterThan(0));
    expect(
      tester.widget<BayerMasked>(masked.first).open,
      lessThan(BayerMask.steps),
    );
  });

  testWidgets('screen readers hear the name once', (tester) async {
    final semantics = tester.ensureSemantics();
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpPage(tester);
    // The heading, and the cover named after the anime.
    final before = find.bySemanticsLabel(_longDetails.name).evaluate().length;
    await _scrollBy(tester, _nameBelowBar(tester) + 4);

    expect(_barTitle, findsOneWidget);
    expect(find.bySemanticsLabel(_longDetails.name), findsNWidgets(before));
    semantics.dispose();
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('adapts the details layout on ${entry.key}', (tester) async {
      setTestWindowSize(tester, entry.value);
      final cubit = AnimeDetailsCubit(
        animeId: '5114',
        repository: _SuccessAnimeDetailsRepository(_longDetails),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit..loadAnime(),
            child: const AnimeDetailsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text(_longDetails.name));
      final poster = tester.getRect(find.byType(DitheredImage).first);
      final description = tester.getRect(find.text(_longDetails.description));
      if (entry.value.width < 840) {
        expect(description.left, title.left);
      } else {
        expect(description.left, greaterThan(poster.right));
        expect(description.width, lessThanOrEqualTo(720));
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpPage(WidgetTester tester) async {
  final cubit = AnimeDetailsCubit(
    animeId: '5114',
    repository: _SuccessAnimeDetailsRepository(_longDetails),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
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
  matching: find.text(_longDetails.name),
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
      matching: find.text(_longDetails.name),
    ),
  );
  return name.bottom - tester.getRect(find.byType(AppBar)).bottom;
}

Widget _app(
  AnimeDetailsCubit cubit, {
  AnimeDetailsPreview? preview,
  String locale = 'en',
}) {
  return MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(
      value: cubit,
      child: Scaffold(body: AnimeDetailsView(preview: preview)),
    ),
  );
}

/// The closest skeleton holding [finder].
AppSkeleton _skeletonAround(WidgetTester tester, Finder finder) =>
    tester.widget<AppSkeleton>(
      find.ancestor(of: finder, matching: find.byType(AppSkeleton)).first,
    );

/// How the stand-in description begins.
final _standIn = find.textContaining('A few sentences');

class _CompleterAnimeDetailsRepository implements AnimeDetailsRepository {
  const _CompleterAnimeDetailsRepository(this.details);

  final Completer<AnimeDetails> details;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) => details.future;
}

class _PendingAnimeDetailsRepository implements AnimeDetailsRepository {
  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) {
    return Completer<AnimeDetails>().future;
  }
}

class _SuccessAnimeDetailsRepository implements AnimeDetailsRepository {
  const _SuccessAnimeDetailsRepository(this.details);

  final AnimeDetails details;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async => details;
}

class _ToggleAnimeDetailsRepository implements AnimeDetailsRepository {
  bool shouldFail = true;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async {
    if (shouldFail) {
      throw Exception('First call fails');
    }

    return _details;
  }
}

const _details = AnimeDetails(
  id: '5114',
  name: 'Fullmetal Alchemist: Brotherhood',
  russian: 'Fullmetal Alchemist: Brotherhood RU',
  description:
      'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
  kind: 'tv',
  score: 9.12,
  status: 'released',
  episodes: 64,
  episodesAired: 64,
  airedOn: '2009-04-05',
  posterOriginalUrl: 'https://shikimori.one/posters/5114/original.jpg',
);

final _preview = AnimeDetailsPreview(
  id: _details.id,
  name: _details.name,
  russian: _details.russian,
  kind: _details.kind,
  score: _details.score,
  status: _details.status,
  episodes: _details.episodes,
  episodesAired: _details.episodesAired,
  airedOn: _details.airedOn,
  posterUrl: 'https://shikimori.one/posters/5114/main.jpg',
);

final _longDetails = AnimeDetails(
  id: _details.id,
  name: _details.name,
  russian: _details.russian,
  description: List.filled(40, _details.description).join(' '),
  kind: _details.kind,
  score: _details.score,
  status: _details.status,
  episodes: _details.episodes,
  episodesAired: _details.episodesAired,
  airedOn: _details.airedOn,
  posterOriginalUrl: _details.posterOriginalUrl,
);
