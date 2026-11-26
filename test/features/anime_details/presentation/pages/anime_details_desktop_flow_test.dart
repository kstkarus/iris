import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/friend_rates_cubit.dart';
import 'package:iris/features/anime_details/presentation/models/anime_desktop_watch_host.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_desktop_layout.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_sections.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/domain/repositories/characters_repository.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/shared/models/details_description.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/memory_saved_torrents_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../../watch_sources/watch_sources_test_doubles.dart';

const _anime = AnimeSummary(
  id: '52991',
  name: 'Sousou no Frieren',
  russian: '',
  english: "Frieren: Beyond Journey's End",
  kind: 'tv',
  score: 9.3,
  status: 'released',
  episodes: 28,
  episodesAired: 28,
  airedOn: '2023-09-29',
  posterUrl: '',
);

const _dub = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  dub: 'AniLibria',
  episodes: [
    OnlineEpisode(id: 'e1', number: 1),
    OnlineEpisode(id: 'e2', number: 2),
  ],
  bestQuality: 1080,
);

void main() {
  testWidgets(
    'desktop switches inline Overview -> Sources -> Episodes and steps back on Escape',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);

      final detailsCubit = AnimeDetailsCubit(
        animeId: _anime.id,
        repository: _FixedDetailsRepo(),
      )..loadAnime();
      final charactersCubit = AnimeCharactersCubit(
        animeId: _anime.id,
        repository: _EmptyCharactersRepo(),
      )..load();
      final userRateCubit = UserRateCubit(
        animeId: _anime.id,
        repository: _StubUserRateRepo(),
      );
      final friendsCubit = FriendRatesCubit(
        animeId: _anime.id,
        repository: _EmptyFriendsRepo(),
      );
      final progressCubit = WatchProgressCubit(
        repository: const FixedWatchProgressRepository(),
      )..load();
      addTearDown(detailsCubit.close);
      addTearDown(charactersCubit.close);
      addTearDown(userRateCubit.close);
      addTearDown(friendsCubit.close);
      addTearDown(progressCubit.close);

      var sourceLoads = 0;

      final host = AnimeDesktopWatchHost(
        buildSourcesScope:
            (
              context, {
              required args,
              required active,
              required desktopSplit,
              required onOpenSource,
              required builder,
            }) {
              return MultiBlocProvider(
                key: ValueKey('sources_${args.animeId}'),
                providers: [
                  BlocProvider(
                    create: (_) {
                      sourceLoads++;
                      return WatchSourcesCubit(
                        animeId: args.animeId,
                        animeTitles: args.animeTitles,
                        searchTitles: args.searchTitles,
                        repository: FixedWatchSourcesRepository(),
                      )..loadSources();
                    },
                  ),
                  BlocProvider(
                    create: (_) => OnlineReleasesCubit(
                      shikimoriId: args.animeId,
                      titles: args.searchTitles,
                      search: _FixedOnlineSearch(),
                    )..load(),
                  ),
                  BlocProvider(
                    create: (_) => WatchSourcesTabCubit(
                      repository: MemoryWatchSourcesTabRepository(),
                    ),
                  ),
                  BlocProvider(
                    create: (_) => SavedTorrentsCubit(
                      animeId: args.animeId,
                      repository: MemorySavedTorrentsRepository(),
                    )..load(),
                  ),
                ],
                child: WatchSourcesHost(
                  args: args,
                  active: active,
                  desktopSplit: desktopSplit,
                  onOpenSource: onOpenSource,
                  builder: builder,
                ),
              );
            },
        buildEpisodesScope:
            (
              context, {
              required args,
              required active,
              required desktopSplit,
              required backAction,
              required onBackStep,
              required builder,
            }) {
              return BlocProvider<PlayerSourceCubit>(
                key: ValueKey('episodes_${args.magnet}'),
                create: (_) => _ReadyPlayerSourceCubit(args),
                child: PlayerSourceHost(
                  args: args,
                  active: active,
                  embeddedDesktop: desktopSplit,
                  backAction: backAction,
                  onBackStep: onBackStep,
                  builder:
                      (
                        context, {
                        required appBar,
                        required railDetails,
                        required pane,
                        required canCancelSelection,
                        required cancelSelection,
                        required selectAll,
                        required onEscape,
                      }) => builder(
                        context,
                        appBar: appBar,
                        railDetails: railDetails,
                        pane: pane,
                        onEscape: onEscape,
                      ),
                ),
              );
            },
      );

      await tester.pumpWidget(
        testApp(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: detailsCubit),
              BlocProvider.value(value: charactersCubit),
              BlocProvider.value(value: userRateCubit),
              BlocProvider.value(value: friendsCubit),
              BlocProvider.value(value: progressCubit),
            ],
            child: AnimeDetailsPage(
              preview: const AnimeDetailsPreview.fromSummary(_anime),
              desktopWatchHost: host,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Overview is shown, sources have not loaded yet, and the poster
      // fills the full left rail width aligned with the primary button.
      final chooseSourceButton = find.widgetWithText(
        FilledButton,
        'Choose source',
      );
      expect(chooseSourceButton, findsOneWidget);
      expect(
        find.text('A quiet journey after the defeat of the Demon King.'),
        findsOneWidget,
      );
      expect(sourceLoads, 0);

      final initialLayout = tester.element(
        find.byType(AnimeDetailsDesktopLayout),
      );
      final initialPoster = tester.element(
        find.byType(AnimeDetailsFramedPoster),
      );
      expect(
        tester.getSize(find.byType(AnimeDetailsFramedPoster)).width,
        closeTo(tester.getSize(chooseSourceButton).width, 0.5),
      );

      // Step 2: Clicking Choose source swaps inline to Sources without
      // remounting the desktop layout or poster.
      await tester.tap(chooseSourceButton);
      await tester.pumpAndSettle();
      expect(sourceLoads, 1);
      expect(find.text('AniLibria'), findsOneWidget);
      expect(find.byKey(AnimeDetailsPage.backToDescriptionKey), findsOneWidget);
      expect(find.byKey(WatchSourcesPage.addButtonKey), findsOneWidget);
      expect(
        tester.element(find.byType(AnimeDetailsDesktopLayout)),
        same(initialLayout),
      );
      expect(
        tester.element(find.byType(AnimeDetailsFramedPoster)),
        same(initialPoster),
      );

      // Step 3: Clicking AniLibria swaps inline to Episodes without remounting
      // the desktop layout or poster.
      await tester.tap(find.text('AniLibria'));
      await tester.pumpAndSettle();
      expect(find.text('The Journey Begins'), findsOneWidget);
      expect(find.byKey(AnimeDetailsPage.backFromEpisodesKey), findsOneWidget);
      expect(
        tester.element(find.byType(AnimeDetailsDesktopLayout)),
        same(initialLayout),
      );
      expect(
        tester.element(find.byType(AnimeDetailsFramedPoster)),
        same(initialPoster),
      );

      // First Escape: Episodes -> Sources (without reloading sources or
      // remounting the poster, even after the episode provider tears down).
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('AniLibria'), findsOneWidget);
      expect(sourceLoads, 1);
      expect(
        tester.element(find.byType(AnimeDetailsDesktopLayout)),
        same(initialLayout),
      );
      expect(
        tester.element(find.byType(AnimeDetailsFramedPoster)),
        same(initialPoster),
      );

      // Second Escape: Sources -> Overview.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Choose source'), findsOneWidget);
      expect(
        find.text('A quiet journey after the defeat of the Demon King.'),
        findsOneWidget,
      );
      expect(
        tester.element(find.byType(AnimeDetailsDesktopLayout)),
        same(initialLayout),
      );
      expect(
        tester.element(find.byType(AnimeDetailsFramedPoster)),
        same(initialPoster),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Escape cancels download selection in inline Episodes before stepping back',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);

      final detailsCubit = AnimeDetailsCubit(
        animeId: _anime.id,
        repository: _FixedDetailsRepo(),
      )..loadAnime();
      final charactersCubit = AnimeCharactersCubit(
        animeId: _anime.id,
        repository: _EmptyCharactersRepo(),
      )..load();
      final userRateCubit = UserRateCubit(
        animeId: _anime.id,
        repository: _StubUserRateRepo(),
      );
      final friendsCubit = FriendRatesCubit(
        animeId: _anime.id,
        repository: _EmptyFriendsRepo(),
      );
      final progressCubit = WatchProgressCubit(
        repository: const FixedWatchProgressRepository(),
      )..load();
      addTearDown(detailsCubit.close);
      addTearDown(charactersCubit.close);
      addTearDown(userRateCubit.close);
      addTearDown(friendsCubit.close);
      addTearDown(progressCubit.close);

      _ReadyPlayerSourceCubit? episodesCubit;

      final host = AnimeDesktopWatchHost(
        buildSourcesScope:
            (
              context, {
              required args,
              required active,
              required desktopSplit,
              required onOpenSource,
              required builder,
            }) {
              return MultiBlocProvider(
                key: ValueKey('sources_${args.animeId}'),
                providers: [
                  BlocProvider(
                    create: (_) => WatchSourcesCubit(
                      animeId: args.animeId,
                      animeTitles: args.animeTitles,
                      searchTitles: args.searchTitles,
                      repository: FixedWatchSourcesRepository(),
                    )..loadSources(),
                  ),
                  BlocProvider(
                    create: (_) => OnlineReleasesCubit(
                      shikimoriId: args.animeId,
                      titles: args.searchTitles,
                      search: _FixedOnlineSearch(),
                    )..load(),
                  ),
                  BlocProvider(
                    create: (_) => WatchSourcesTabCubit(
                      repository: MemoryWatchSourcesTabRepository(),
                    ),
                  ),
                  BlocProvider(
                    create: (_) => SavedTorrentsCubit(
                      animeId: args.animeId,
                      repository: MemorySavedTorrentsRepository(),
                    )..load(),
                  ),
                ],
                child: WatchSourcesHost(
                  args: args,
                  active: active,
                  desktopSplit: desktopSplit,
                  onOpenSource: onOpenSource,
                  builder: builder,
                ),
              );
            },
        buildEpisodesScope:
            (
              context, {
              required args,
              required active,
              required desktopSplit,
              required backAction,
              required onBackStep,
              required builder,
            }) {
              return BlocProvider<PlayerSourceCubit>(
                key: ValueKey('episodes_${args.magnet}'),
                create: (_) {
                  episodesCubit = _ReadyPlayerSourceCubit(args);
                  return episodesCubit!;
                },
                child: PlayerSourceHost(
                  args: args,
                  active: active,
                  embeddedDesktop: desktopSplit,
                  backAction: backAction,
                  onBackStep: onBackStep,
                  builder:
                      (
                        context, {
                        required appBar,
                        required railDetails,
                        required pane,
                        required canCancelSelection,
                        required cancelSelection,
                        required selectAll,
                        required onEscape,
                      }) => builder(
                        context,
                        appBar: appBar,
                        railDetails: railDetails,
                        pane: pane,
                        onEscape: onEscape,
                      ),
                ),
              );
            },
      );

      await tester.pumpWidget(
        testApp(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: detailsCubit),
              BlocProvider.value(value: charactersCubit),
              BlocProvider.value(value: userRateCubit),
              BlocProvider.value(value: friendsCubit),
              BlocProvider.value(value: progressCubit),
            ],
            child: AnimeDetailsPage(
              preview: const AnimeDetailsPreview.fromSummary(_anime),
              desktopWatchHost: host,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AniLibria'));
      await tester.pumpAndSettle();

      episodesCubit!.startSelection();
      await tester.pumpAndSettle();
      expect((episodesCubit!.state as PlayerSourceReady).selecting, isTrue);

      // First Escape cancels download selection, stays on Episodes.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect((episodesCubit!.state as PlayerSourceReady).selecting, isFalse);
      expect(find.text('The Journey Begins'), findsOneWidget);

      // Clicking Back to sources returns to Sources, then Back to details returns to Overview.
      await tester.tap(find.byKey(AnimeDetailsPage.backFromEpisodesKey));
      await tester.pumpAndSettle();
      expect(find.text('AniLibria'), findsOneWidget);

      await tester.tap(find.byKey(AnimeDetailsPage.backToDescriptionKey));
      await tester.pumpAndSettle();
      expect(find.text('Choose source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FixedDetailsRepo implements AnimeDetailsRepository {
  @override
  Future<AnimeDetails> fetchAnimeDetails(String animeId) async =>
      const AnimeDetails(
        anime: _anime,
        description: DetailsDescription(
          'A quiet journey after the defeat of the Demon King.',
        ),
      );
}

class _EmptyCharactersRepo implements CharactersRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const <CharacterSummary>[]);
}

class _EmptyFriendsRepo implements FriendsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubUserRateRepo implements UserRateRepository {
  @override
  Stream<UserRateChange> get changes => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedOnlineSearch implements OnlineReleasesSearch {
  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => Stream.value(const [_dub]);
}

class _ReadyPlayerSourceCubit extends Cubit<PlayerSourceState>
    implements PlayerSourceCubit {
  _ReadyPlayerSourceCubit(this.args)
    : super(
        const PlayerSourceReady([
          PlayerVideoFile(
            index: 1,
            name: '01 The Journey Begins',
            size: 0,
            extension: 'm3u8',
            episodeNumber: 1,
            title: 'The Journey Begins',
            duration: Duration(minutes: 24),
          ),
          PlayerVideoFile(
            index: 2,
            name: '02 Beyond the End',
            size: 0,
            extension: 'm3u8',
            episodeNumber: 2,
            title: 'Beyond the End',
            duration: Duration(minutes: 24),
          ),
        ]),
      );

  @override
  final AnimePlayerSourceArgs args;

  @override
  void startSelection({int? index}) {
    final current = state;
    if (current is PlayerSourceReady && !current.selecting) {
      emit(
        current.copyWith(
          selecting: true,
          selected: index == null ? const {} : {index},
        ),
      );
    }
  }

  @override
  void cancelSelection() {
    final current = state;
    if (current is PlayerSourceReady && current.selecting) {
      emit(current.copyWith(selecting: false, selected: const {}));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
