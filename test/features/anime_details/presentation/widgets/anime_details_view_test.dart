import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
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
    final facts = tester.getRect(find.byType(SpecTable));
    expect(facts.bottom, lessThanOrEqualTo(poster.bottom));
    expect(tester.takeException(), isNull);
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

Widget _app(AnimeDetailsCubit cubit, {AnimeDetailsPreview? preview}) {
  return MaterialApp(
    locale: const Locale('en'),
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
