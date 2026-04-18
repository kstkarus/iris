import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/router/app_router.dart';
import 'package:iris/features/anime_details/data/datasources/mock_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/datasources/remote_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/repositories/mock_anime_details_repository.dart';
import 'package:iris/features/anime_details/data/repositories/remote_anime_details_repository.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/data/datasources/mock_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_list_repository.dart';
import 'package:iris/features/anime_list/data/repositories/remote_anime_list_repository.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/repositories/mock_player_repository.dart';
import 'package:iris/features/player/data/repositories/shared_preferences_subtitle_preferences_repository.dart';
import 'package:iris/features/player/data/repositories/torrent_player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/widgets/media_kit_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/mock_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/watch_sources/data/datasources/mock_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/repositories/mock_watch_sources_repository.dart';
import 'package:iris/features/watch_sources/data/repositories/remote_watch_sources_repository.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/nyaa_api_client.dart';
import 'package:iris/shared/network/nyaa_dio_factory.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

final serviceLocator = GetIt.instance;

Future<void> configureDependencies({
  bool useMocks = false,
  bool reset = false,
}) async {
  if (reset) {
    await serviceLocator.reset();
  }

  if (!serviceLocator.isRegistered<Dio>()) {
    serviceLocator.registerLazySingleton<Dio>(createDio);
  }

  if (!serviceLocator.isRegistered<ShikimoriGraphQlClient>()) {
    serviceLocator.registerLazySingleton<ShikimoriGraphQlClient>(
      () => ShikimoriGraphQlClient(dio: serviceLocator<Dio>()),
    );
  }

  if (!serviceLocator.isRegistered<NyaaApiClient>()) {
    serviceLocator.registerLazySingleton<NyaaApiClient>(
      () => NyaaApiClient(dio: createNyaaDio()),
    );
  }

  if (!serviceLocator.isRegistered<GoRouter>()) {
    serviceLocator.registerLazySingleton<GoRouter>(AppRouter.createRouter);
  }

  if (!serviceLocator.isRegistered<SharedPreferences>()) {
    serviceLocator.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
  }

  if (useMocks) {
    if (!serviceLocator.isRegistered<MockAnimeListDataSource>()) {
      serviceLocator.registerLazySingleton<MockAnimeListDataSource>(
        MockAnimeListDataSource.new,
      );
    }

    if (!serviceLocator.isRegistered<MockAnimeDetailsDataSource>()) {
      serviceLocator.registerLazySingleton<MockAnimeDetailsDataSource>(
        MockAnimeDetailsDataSource.new,
      );
    }

    if (!serviceLocator.isRegistered<MockWatchSourcesDataSource>()) {
      serviceLocator.registerLazySingleton<MockWatchSourcesDataSource>(
        MockWatchSourcesDataSource.new,
      );
    }

    if (!serviceLocator.isRegistered<AnimeListRepository>()) {
      serviceLocator.registerLazySingleton<AnimeListRepository>(
        () => MockAnimeListRepository(
          dataSource: serviceLocator<MockAnimeListDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<AnimeDetailsRepository>()) {
      serviceLocator.registerLazySingleton<AnimeDetailsRepository>(
        () => MockAnimeDetailsRepository(
          dataSource: serviceLocator<MockAnimeDetailsDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<WatchSourcesRepository>()) {
      serviceLocator.registerLazySingleton<WatchSourcesRepository>(
        () => MockWatchSourcesRepository(
          dataSource: serviceLocator<MockWatchSourcesDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerRepository>()) {
      serviceLocator.registerLazySingleton<PlayerRepository>(
        MockPlayerRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<PlayerViewportFactory>()) {
      serviceLocator.registerLazySingleton<PlayerViewportFactory>(
        MockPlayerViewportFactory.new,
      );
    }

    if (!serviceLocator.isRegistered<SubtitlePreferencesRepository>()) {
      serviceLocator.registerLazySingleton<SubtitlePreferencesRepository>(
        () => SharedPreferencesSubtitlePreferencesRepository(
          serviceLocator<SharedPreferences>(),
        ),
      );
    }
  } else {
    if (!serviceLocator.isRegistered<RemoteAnimeListDataSource>()) {
      serviceLocator.registerLazySingleton<RemoteAnimeListDataSource>(
        () => RemoteAnimeListDataSource(
          client: serviceLocator<ShikimoriGraphQlClient>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<RemoteAnimeDetailsDataSource>()) {
      serviceLocator.registerLazySingleton<RemoteAnimeDetailsDataSource>(
        () => RemoteAnimeDetailsDataSource(
          client: serviceLocator<ShikimoriGraphQlClient>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<RemoteWatchSourcesDataSource>()) {
      serviceLocator.registerLazySingleton<RemoteWatchSourcesDataSource>(
        () => RemoteWatchSourcesDataSource(
          client: serviceLocator<NyaaApiClient>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<LibtorrentEngineAdapter>()) {
      serviceLocator.registerLazySingleton<LibtorrentEngineAdapter>(
        LibtorrentEngineAdapterImpl.new,
      );
    }

    if (!serviceLocator.isRegistered<LibtorrentPlayerDataSource>()) {
      serviceLocator.registerLazySingleton<LibtorrentPlayerDataSource>(
        () => LibtorrentPlayerDataSource(
          engine: serviceLocator<LibtorrentEngineAdapter>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<AnimeListRepository>()) {
      serviceLocator.registerLazySingleton<AnimeListRepository>(
        () => RemoteAnimeListRepository(
          dataSource: serviceLocator<RemoteAnimeListDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<AnimeDetailsRepository>()) {
      serviceLocator.registerLazySingleton<AnimeDetailsRepository>(
        () => RemoteAnimeDetailsRepository(
          dataSource: serviceLocator<RemoteAnimeDetailsDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<WatchSourcesRepository>()) {
      serviceLocator.registerLazySingleton<WatchSourcesRepository>(
        () => RemoteWatchSourcesRepository(
          dataSource: serviceLocator<RemoteWatchSourcesDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerRepository>()) {
      serviceLocator.registerLazySingleton<PlayerRepository>(
        () => TorrentPlayerRepository(
          dataSource: serviceLocator<LibtorrentPlayerDataSource>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerViewportFactory>()) {
      serviceLocator.registerLazySingleton<PlayerViewportFactory>(
        MediaKitPlayerViewportFactory.new,
      );
    }

    if (!serviceLocator.isRegistered<SubtitlePreferencesRepository>()) {
      serviceLocator.registerLazySingleton<SubtitlePreferencesRepository>(
        () => SharedPreferencesSubtitlePreferencesRepository(
          serviceLocator<SharedPreferences>(),
        ),
      );
    }
  }

  if (!serviceLocator.isRegistered<AnimeListBloc>()) {
    serviceLocator.registerFactory<AnimeListBloc>(
      () => AnimeListBloc(repository: serviceLocator<AnimeListRepository>()),
    );
  }
}
