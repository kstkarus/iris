import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/di/service_locator.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/pages/anime_list_page.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';

abstract final class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'anime-list',
          builder: (context, state) {
            return BlocProvider(
              create: (_) =>
                  serviceLocator<AnimeListBloc>()
                    ..add(const AnimeListStarted()),
              child: const AnimeListPage(),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id',
          name: 'anime-details',
          builder: (context, state) {
            final animeId = state.pathParameters['id'] ?? '';

            return BlocProvider(
              create: (_) => AnimeDetailsCubit(
                animeId: animeId,
                repository: serviceLocator<AnimeDetailsRepository>(),
              )..loadAnime(),
              child: const AnimeDetailsPage(),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id/watch',
          name: 'anime-watch-sources',
          builder: (context, state) {
            final extra = state.extra;
            final args = extra is AnimeWatchSourcesArgs
                ? extra
                : AnimeWatchSourcesArgs(
                    animeId: state.pathParameters['id'] ?? '',
                    animeEnglishTitle: '',
                  );

            return BlocProvider(
              create: (_) => WatchSourcesCubit(
                animeId: args.animeId,
                animeEnglishTitle: args.animeEnglishTitle,
                repository: serviceLocator<WatchSourcesRepository>(),
              )..loadSources(),
              child: WatchSourcesPage(args: args),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id/watch/files',
          name: 'anime-player-files',
          builder: (context, state) {
            final extra = state.extra;
            final args = extra is AnimePlayerSourceArgs
                ? extra
                : AnimePlayerSourceArgs(
                    animeId: state.pathParameters['id'] ?? '',
                    animeTitle: '',
                    sourceTitle: '',
                    magnet: '',
                  );

            return BlocProvider(
              create: (_) => PlayerSourceCubit(
                magnet: args.magnet,
                repository: serviceLocator<PlayerRepository>(),
              )..loadSource(),
              child: PlayerSourcePage(args: args),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id/watch/player',
          name: 'anime-player',
          builder: (context, state) {
            final extra = state.extra;
            final args = extra is AnimePlayerArgs
                ? extra
                : AnimePlayerArgs(
                    animeId: state.pathParameters['id'] ?? '',
                    animeTitle: '',
                    sourceTitle: '',
                    sessionId: '',
                    fileIndex: 0,
                    fileName: '',
                  );

            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => PlayerCubit(
                    source: AnimePlayerSource(
                      animeId: args.animeId,
                      animeTitle: args.animeTitle,
                      sourceTitle: args.sourceTitle,
                      sessionId: args.sessionId,
                      fileIndex: args.fileIndex,
                      fileName: args.fileName,
                    ),
                    repository: serviceLocator<PlayerRepository>(),
                  )..loadPlayback(),
                ),
                BlocProvider(
                  create: (_) => PlayerSubtitlePreferencesCubit(
                    repository: serviceLocator<SubtitlePreferencesRepository>(),
                  )..loadPreferences(),
                ),
              ],
              child: PlayerPage(
                viewportFactory: serviceLocator<PlayerViewportFactory>(),
              ),
            );
          },
        ),
      ],
    );
  }
}
