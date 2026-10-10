import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/router/app_router.dart';
import 'package:iris/entities/friend/data/mock_friends_repository.dart';
import 'package:iris/entities/friend/data/remote_friends_repository.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';
import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/data/remote_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/watch_progress/data/shared_preferences_watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/features/anime_details/data/datasources/mock_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/datasources/remote_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/repositories/mock_anime_details_repository.dart';
import 'package:iris/features/anime_details/data/repositories/remote_anime_details_repository.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_genres_repository.dart';
import 'package:iris/features/anime_list/data/repositories/remote_anime_genres_repository.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';
import 'package:iris/features/anime_list/data/datasources/mock_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/mappers/shikimori_anime_mapper.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_list_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/profile/data/repositories/mock_user_list_repository.dart';
import 'package:iris/features/profile/data/repositories/remote_user_list_repository.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';
import 'package:iris/features/anime_list/data/repositories/remote_anime_list_repository.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/auth/data/datasources/shikimori_account_data_source.dart';
import 'package:iris/features/auth/data/datasources/web_authenticator.dart';
import 'package:iris/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:iris/features/auth/data/repositories/shikimori_auth_repository.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/data/repositories/downloads_repository_impl.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/repositories/aniskip_skip_times_repository.dart';
import 'package:iris/features/player/data/repositories/mock_player_repository.dart';
import 'package:iris/features/player/data/repositories/mock_player_skip_times_repository.dart';
import 'package:iris/features/player/data/repositories/local_player_repository.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/data/repositories/player_decoding_preferences_repository_impl.dart';
import 'package:iris/features/player/data/repositories/shared_preferences_subtitle_preferences_repository.dart';
import 'package:iris/features/player/data/repositories/shared_preferences_track_preferences_repository.dart';
import 'package:iris/features/player/data/repositories/streaming_or_local_player_repository.dart';
import 'package:iris/features/player/data/repositories/torrent_player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/widgets/media_kit_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/mock_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/online_sources/data/datasources/aksor_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/anilibria_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/kodik_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/yummy_anime_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/anilibria_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/combined_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/yummy_anime_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/data/repositories/mock_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/watch_sources/data/datasources/mock_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/repositories/mock_watch_sources_repository.dart';
import 'package:iris/features/watch_sources/data/repositories/remote_watch_sources_repository.dart';
import 'package:iris/features/watch_sources/data/repositories/shared_preferences_watch_sources_tab_repository.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_tab_repository.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/anilibria_dio_factory.dart';
import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/aniskip_api_client.dart';
import 'package:iris/shared/network/aniskip_dio_factory.dart';
import 'package:iris/shared/network/nyaa_api_client.dart';
import 'package:iris/shared/network/nyaa_dio_factory.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/network/yummy_anime_api_client.dart';
import 'package:iris/shared/network/yummy_anime_dio_factory.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/window/windows_fullscreen.dart';

final serviceLocator = GetIt.instance;

Future<void> configureDependencies({
  bool useMocks = false,
  bool reset = false,
}) async {
  if (reset) {
    await serviceLocator.reset();
  }

  if (!serviceLocator.isRegistered<ShikimoriSessionStore>()) {
    serviceLocator.registerLazySingleton<ShikimoriSessionStore>(
      () => ShikimoriSessionStore(const FlutterSecureStorage()),
    );
  }

  if (!serviceLocator.isRegistered<ShikimoriOAuthClient>()) {
    serviceLocator.registerLazySingleton<ShikimoriOAuthClient>(
      () => ShikimoriOAuthClient(
        dio: createShikimoriOAuthDio(),
        config: const ShikimoriOAuthConfig.fromEnvironment(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<Dio>()) {
    serviceLocator.registerLazySingleton<Dio>(
      () => createDio(
        session: serviceLocator<ShikimoriSessionStore>(),
        oauth: serviceLocator<ShikimoriOAuthClient>(),
      ),
    );
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

  if (!serviceLocator.isRegistered<AnilibriaApiClient>()) {
    serviceLocator.registerLazySingleton<AnilibriaApiClient>(
      () => AnilibriaApiClient(dio: createAnilibriaDio()),
    );
  }

  if (!serviceLocator.isRegistered<YummyAnimeApiClient>()) {
    serviceLocator.registerLazySingleton<YummyAnimeApiClient>(
      () => YummyAnimeApiClient(dio: createYummyAnimeDio()),
    );
  }

  if (!serviceLocator.isRegistered<AniSkipApiClient>()) {
    serviceLocator.registerLazySingleton<AniSkipApiClient>(
      () => AniSkipApiClient(dio: createAniSkipDio()),
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
    if (!serviceLocator.isRegistered<AuthRepository>()) {
      serviceLocator.registerLazySingleton<AuthRepository>(
        MockAuthRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<UserRateRepository>()) {
      serviceLocator.registerLazySingleton<UserRateRepository>(
        MockUserRateRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<MarkEpisodeWatched>()) {
      serviceLocator.registerLazySingleton<MarkEpisodeWatched>(
        () => MarkEpisodeWatched(serviceLocator<UserRateRepository>()),
      );
    }

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
          userRates: switch (serviceLocator<UserRateRepository>()) {
            final MockUserRateRepository mock => mock,
            _ => null,
          },
        ),
      );
    }

    if (!serviceLocator.isRegistered<FriendsRepository>()) {
      serviceLocator.registerLazySingleton<FriendsRepository>(
        MockFriendsRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<UserListRepository>()) {
      serviceLocator.registerLazySingleton<UserListRepository>(
        () => MockUserListRepository(
          rates: switch (serviceLocator<UserRateRepository>()) {
            final MockUserRateRepository mock => mock,
            _ => MockUserRateRepository(),
          },
          titles: () async => [
            for (final dto
                in await serviceLocator<MockAnimeListDataSource>()
                    .fetchPopularAnime())
              _listedAnime(mapShikimoriAnimeToDomain(dto)),
          ],
        ),
      );
    }

    if (!serviceLocator.isRegistered<AnimeGenresRepository>()) {
      serviceLocator.registerLazySingleton<AnimeGenresRepository>(
        MockAnimeGenresRepository.new,
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

    if (!serviceLocator.isRegistered<DownloadsRepository>()) {
      serviceLocator.registerLazySingleton<DownloadsRepository>(
        MockDownloadsRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<OnlineSourcesRepository>()) {
      serviceLocator
        ..registerLazySingleton<OnlineSourcesRepository>(
          MockOnlineSourcesRepository.new,
        )
        ..registerLazySingleton<OnlineReleasesSearch>(
          MockOnlineSourcesRepository.new,
        );
    }

    if (!serviceLocator.isRegistered<PlayerRepository>()) {
      serviceLocator.registerLazySingleton<PlayerRepository>(
        MockPlayerRepository.new,
      );
    }

    if (!serviceLocator.isRegistered<PlayerSkipTimesRepository>()) {
      serviceLocator.registerLazySingleton<PlayerSkipTimesRepository>(
        MockPlayerSkipTimesRepository.new,
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

    if (!serviceLocator.isRegistered<PlayerDecodingPreferencesRepository>()) {
      serviceLocator.registerLazySingleton<PlayerDecodingPreferencesRepository>(
        () => PlayerDecodingPreferencesRepositoryImpl(
          serviceLocator<SharedPreferences>(),
        ),
      );
    }
  } else {
    final supportDirectory = await getApplicationSupportDirectory();
    final downloadsDirectory = Directory(
      path.join(supportDirectory.path, 'offline_downloads'),
    );
    final temporaryDirectory = await getTemporaryDirectory();

    if (!serviceLocator.isRegistered<StreamCacheStorage>()) {
      final streamCache = StreamCacheStorage(
        directory: Directory(
          path.join(temporaryDirectory.path, 'iris', 'stream'),
        ),
      );
      serviceLocator.registerSingleton<StreamCacheStorage>(streamCache);
      // Leftovers of a crashed or killed session are useless after restart.
      unawaited(streamCache.prepare());
    }

    if (!serviceLocator.isRegistered<TorrentActivityRegistry>()) {
      serviceLocator.registerLazySingleton<TorrentActivityRegistry>(
        TorrentActivityRegistry.new,
      );
    }

    if (!serviceLocator.isRegistered<AuthRepository>()) {
      serviceLocator.registerLazySingleton<AuthRepository>(
        () => ShikimoriAuthRepository(
          oauth: serviceLocator<ShikimoriOAuthClient>(),
          session: serviceLocator<ShikimoriSessionStore>(),
          accounts: ShikimoriAccountDataSource(
            client: serviceLocator<ShikimoriGraphQlClient>(),
          ),
          authenticator: const FlutterWebAuthenticator(),
          preferences: serviceLocator<SharedPreferences>(),
          // flutter_web_auth_2's web flow needs a callback page iris lacks.
          platformSupported: !kIsWeb,
        ),
      );
    }

    if (!serviceLocator.isRegistered<UserRateRepository>()) {
      serviceLocator.registerLazySingleton<UserRateRepository>(
        () => RemoteUserRateRepository(
          graphQl: serviceLocator<ShikimoriGraphQlClient>(),
          dio: serviceLocator<Dio>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<MarkEpisodeWatched>()) {
      serviceLocator.registerLazySingleton<MarkEpisodeWatched>(
        () => MarkEpisodeWatched(serviceLocator<UserRateRepository>()),
      );
    }

    if (!serviceLocator.isRegistered<FriendsRepository>()) {
      serviceLocator.registerLazySingleton<FriendsRepository>(
        () => RemoteFriendsRepository(dio: serviceLocator<Dio>()),
      );
    }

    if (!serviceLocator.isRegistered<UserListRepository>()) {
      serviceLocator.registerLazySingleton<UserListRepository>(
        () => RemoteUserListRepository(
          client: serviceLocator<ShikimoriGraphQlClient>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<AnimeGenresRepository>()) {
      serviceLocator.registerLazySingleton<AnimeGenresRepository>(
        () => RemoteAnimeGenresRepository(
          client: serviceLocator<ShikimoriGraphQlClient>(),
        ),
      );
    }

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
        () => LibtorrentEngineAdapterImpl(
          streamCache: serviceLocator<StreamCacheStorage>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerRuntimeMemoryAdapter>()) {
      serviceLocator.registerLazySingleton<PlayerRuntimeMemoryAdapter>(
        MethodChannelPlayerRuntimeMemoryAdapter.new,
      );
    }

    if (!serviceLocator.isRegistered<LibtorrentDownloadEngineAdapter>()) {
      serviceLocator.registerLazySingleton<LibtorrentDownloadEngineAdapter>(
        LibtorrentDownloadEngineAdapterImpl.new,
      );
    }

    if (!serviceLocator.isRegistered<DownloadForegroundServiceAdapter>()) {
      serviceLocator.registerLazySingleton<DownloadForegroundServiceAdapter>(
        () => defaultTargetPlatform == TargetPlatform.android && !kIsWeb
            ? const MethodChannelDownloadForegroundServiceAdapter()
            : const NoopDownloadForegroundServiceAdapter(),
      );
    }

    if (!serviceLocator.isRegistered<AppStorageUsageAdapter>()) {
      serviceLocator.registerLazySingleton<AppStorageUsageAdapter>(
        MethodChannelAppStorageUsageAdapter.new,
      );
    }

    if (!serviceLocator.isRegistered<DownloadRegistryDataSource>()) {
      serviceLocator.registerLazySingleton<DownloadRegistryDataSource>(
        () => DownloadRegistryDataSource(
          registryFile: File(
            path.join(supportDirectory.path, 'downloads_registry.json'),
          ),
        ),
      );
    }

    if (!serviceLocator.isRegistered<DownloadsRepository>()) {
      final repository = DownloadsRepositoryImpl(
        engine: serviceLocator<LibtorrentDownloadEngineAdapter>(),
        registry: serviceLocator<DownloadRegistryDataSource>(),
        downloadsDirectory: downloadsDirectory,
        foregroundService: serviceLocator<DownloadForegroundServiceAdapter>(),
        storageUsageAdapter: serviceLocator<AppStorageUsageAdapter>(),
        streamCache: serviceLocator<StreamCacheStorage>(),
        activityRegistry: serviceLocator<TorrentActivityRegistry>(),
      );
      serviceLocator.registerSingleton<DownloadsRepository>(
        repository,
        dispose: (_) => repository.close(),
      );
      await repository.restore();
    }

    if (!serviceLocator.isRegistered<LibtorrentPlayerDataSource>()) {
      serviceLocator.registerLazySingleton<LibtorrentPlayerDataSource>(
        () => LibtorrentPlayerDataSource(
          engine: serviceLocator<LibtorrentEngineAdapter>(),
          memoryAdapter: serviceLocator<PlayerRuntimeMemoryAdapter>(),
          activityRegistry: serviceLocator<TorrentActivityRegistry>(),
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

    if (!serviceLocator.isRegistered<CombinedOnlineSourcesRepository>()) {
      serviceLocator.registerLazySingleton<CombinedOnlineSourcesRepository>(() {
        final videoServers = createVideoServerDio();
        return CombinedOnlineSourcesRepository(
          // AniLibria first: its own release is better than a copy.
          providers: {
            OnlineProvider.anilibria: AnilibriaOnlineSourcesRepository(
              dataSource: AnilibriaDataSource(
                client: serviceLocator<AnilibriaApiClient>(),
              ),
            ),
            OnlineProvider.yummyAnime: YummyAnimeOnlineSourcesRepository(
              dataSource: YummyAnimeDataSource(
                client: serviceLocator<YummyAnimeApiClient>(),
              ),
              kodik: KodikDataSource(dio: videoServers),
              aksor: AksorDataSource(dio: videoServers),
            ),
          },
        );
      });
    }
    // One repository behind both: the search shows sites as they answer,
    // the player opens what it found.
    if (!serviceLocator.isRegistered<OnlineSourcesRepository>()) {
      serviceLocator.registerLazySingleton<OnlineSourcesRepository>(
        () => serviceLocator<CombinedOnlineSourcesRepository>(),
      );
    }
    if (!serviceLocator.isRegistered<OnlineReleasesSearch>()) {
      serviceLocator.registerLazySingleton<OnlineReleasesSearch>(
        () => serviceLocator<CombinedOnlineSourcesRepository>(),
      );
    }

    if (!serviceLocator.isRegistered<PlayerRepository>()) {
      serviceLocator.registerLazySingleton<PlayerRepository>(
        () => StreamingOrLocalPlayerRepository(
          streaming: TorrentPlayerRepository(
            dataSource: serviceLocator<LibtorrentPlayerDataSource>(),
          ),
          online: OnlinePlayerRepository(
            repository: serviceLocator<OnlineSourcesRepository>(),
          ),
          local: LocalPlayerRepository(
            downloadsRepository: serviceLocator<DownloadsRepository>(),
            memoryAdapter: serviceLocator<PlayerRuntimeMemoryAdapter>(),
          ),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerSkipTimesRepository>()) {
      serviceLocator.registerLazySingleton<PlayerSkipTimesRepository>(
        () => AniSkipSkipTimesRepository(
          client: serviceLocator<AniSkipApiClient>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerViewportFactory>()) {
      serviceLocator.registerLazySingleton<PlayerViewportFactory>(
        () => defaultTargetPlatform == TargetPlatform.windows && !kIsWeb
            ? MediaKitPlayerViewportFactory(
                repository: serviceLocator<PlayerRepository>(),
                enterNativeFullscreen: WindowsFullscreen.enter,
                exitNativeFullscreen: WindowsFullscreen.exit,
              )
            : MediaKitPlayerViewportFactory(
                repository: serviceLocator<PlayerRepository>(),
              ),
      );
    }

    if (!serviceLocator.isRegistered<SubtitlePreferencesRepository>()) {
      serviceLocator.registerLazySingleton<SubtitlePreferencesRepository>(
        () => SharedPreferencesSubtitlePreferencesRepository(
          serviceLocator<SharedPreferences>(),
        ),
      );
    }

    if (!serviceLocator.isRegistered<PlayerDecodingPreferencesRepository>()) {
      serviceLocator.registerLazySingleton<PlayerDecodingPreferencesRepository>(
        () => PlayerDecodingPreferencesRepositoryImpl(
          serviceLocator<SharedPreferences>(),
        ),
      );
    }
  }

  if (!serviceLocator.isRegistered<WatchProgressRepository>()) {
    serviceLocator.registerLazySingleton<WatchProgressRepository>(
      () => SharedPreferencesWatchProgressRepository(
        serviceLocator<SharedPreferences>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<PlayerTrackPreferencesRepository>()) {
    serviceLocator.registerLazySingleton<PlayerTrackPreferencesRepository>(
      () => SharedPreferencesTrackPreferencesRepository(
        serviceLocator<SharedPreferences>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<WatchSourcesTabRepository>()) {
    serviceLocator.registerLazySingleton<WatchSourcesTabRepository>(
      () => SharedPreferencesWatchSourcesTabRepository(
        serviceLocator<SharedPreferences>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<SavedTorrentsRepository>()) {
    serviceLocator.registerLazySingleton<SavedTorrentsRepository>(
      () => SharedPreferencesSavedTorrentsRepository(
        serviceLocator<SharedPreferences>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<AnimeListBloc>()) {
    serviceLocator.registerFactory<AnimeListBloc>(
      () => AnimeListBloc(repository: serviceLocator<AnimeListRepository>()),
    );
  }

  if (!serviceLocator.isRegistered<AnimeSearchBloc>()) {
    serviceLocator.registerFactory<AnimeSearchBloc>(
      () => AnimeSearchBloc(repository: serviceLocator<AnimeListRepository>()),
    );
  }
}

/// A mock catalog title as the mock list shows it.
ListedAnime _listedAnime(AnimeListItem item) => ListedAnime(
  id: item.id,
  name: item.name,
  russian: item.russian,
  kind: item.kind,
  score: item.score,
  status: item.status,
  episodes: item.episodes,
  episodesAired: item.episodesAired,
  airedOn: item.airedOn,
  posterUrl: item.posterMainUrl,
);
