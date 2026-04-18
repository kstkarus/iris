import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows a loader while details are loading', (tester) async {
    final cubit = AnimeDetailsCubit(
      animeId: '5114',
      repository: _PendingAnimeDetailsRepository(),
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

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

    expect(find.text('TV / Released'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(find.text('Score 9.12'), findsOneWidget);
    expect(find.text('64/64 episodes'), findsOneWidget);
    expect(find.text('Apr 5, 2009'), findsOneWidget);
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

    expect(find.text('ТВ / Вышло'), findsOneWidget);
    expect(find.text('Оценка 9,12'), findsOneWidget);
    expect(find.text('64/64 серии'), findsOneWidget);
    expect(find.text('5 апр. 2009 г.'), findsOneWidget);
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
