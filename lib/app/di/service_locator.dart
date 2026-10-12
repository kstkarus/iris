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
import 'package:iris/features/characters/data/mock_characters_repository.dart';
import 'package:iris/features/characters/data/remote_characters_repository.dart';
import 'package:iris/features/characters/domain/repositories/characters_repository.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_genres_repository.dart';
import 'package:iris/features/anime_list/data/repositories/remote_anime_genres_repository.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';
import 'package:iris/features/anime_list/data/datasources/mock_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/repositories/mock_anime_list_repository.dart';
import 'package:iris/features/profile/data/repositories/mock_user_list_repository.dart';
import 'package:iris/features/profile/data/repositories/remote_user_list_repository.dart';
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
import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/online_sources/data/repositories/shared_preferences_online_quality_preferences.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
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
import 'package:iris/shared/network/anilibria_api.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/aniskip_api_client.dart';
import 'package:iris/shared/network/aniskip_dio_factory.dart';
import 'package:iris/shared/network/nyaa_api.dart';
import 'package:iris/shared/network/nyaa_api_client.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/network/yummy_anime_api.dart';
import 'package:iris/shared/network/yummy_anime_api_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/window/player_screen_mode.dart';
import 'package:iris/shared/window/screen_brightness_control.dart';
import 'package:iris/shared/window/windows_fullscreen.dart';

final serviceLocator = GetIt.instance;

Future<void> configureDependencies({
  bool useMocks = false,
  bool reset = false,
}) async {
  if (reset) {
    await serviceLocator.reset();
  }

  _registerNetwork();
  serviceLocator
    ..registerLazySingleton<GoRouter>(AppRouter.createRouter)
    ..registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );

  if (useMocks) {
    _registerMocks();
  } else {
    await _registerReal();
  }

  _registerCommon();
}

void _registerNetwork() {
  // Desktop has no app links: the default browser comes back to a
  // server the app runs on its own machine.
  final loopback =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  serviceLocator
    ..registerLazySingleton<ShikimoriSessionStore>(
      () => ShikimoriSessionStore(const FlutterSecureStorage()),
    )
    ..registerSingleton<ShikimoriOAuthConfig>(
      ShikimoriOAuthConfig.fromEnvironment(
        redirectUri: loopback
            ? ShikimoriOAuthConfig.loopbackRedirectUri
            : ShikimoriOAuthConfig.appRedirectUri,
      ),
    )
    ..registerLazySingleton<ShikimoriOAuthClient>(
      () => ShikimoriOAuthClient(
        dio: createShikimoriOAuthDio(),
        config: serviceLocator<ShikimoriOAuthConfig>(),
      ),
    )
    ..registerLazySingleton<Dio>(
      () => createShikimoriDio(
        session: serviceLocator<ShikimoriSessionStore>(),
        oauth: serviceLocator<ShikimoriOAuthClient>(),
      ),
    )
    ..registerLazySingleton<ShikimoriGraphQlClient>(
      () => ShikimoriGraphQlClient(dio: serviceLocator<Dio>()),
    )
    ..registerLazySingleton<ShikimoriRestClient>(
      () => ShikimoriRestClient(dio: serviceLocator<Dio>()),
    )
    ..registerLazySingleton<NyaaApiClient>(
      () => NyaaApiClient(dio: createJsonApiDio(baseUrl: NyaaApi.baseUrl)),
    )
    ..registerLazySingleton<AnilibriaApiClient>(
      () => AnilibriaApiClient(
        dio: createJsonApiDio(baseUrl: AnilibriaApi.baseUrl),
      ),
    )
    ..registerLazySingleton<YummyAnimeApiClient>(
      () => YummyAnimeApiClient(
        dio: createJsonApiDio(
          baseUrl: YummyAnimeApi.baseUrl,
          // A long-running anime lists thousands of videos.
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
    )
    ..registerLazySingleton<AniSkipApiClient>(
      () => AniSkipApiClient(dio: createAniSkipDio()),
    );
}

void _registerMocks() {
  serviceLocator
    ..registerLazySingleton<AuthRepository>(MockAuthRepository.new)
    ..registerLazySingleton<UserRateRepository>(MockUserRateRepository.new)
    ..registerLazySingleton<MockAnimeListDataSource>(
      MockAnimeListDataSource.new,
    )
    ..registerLazySingleton<MockAnimeDetailsDataSource>(
      MockAnimeDetailsDataSource.new,
    )
    ..registerLazySingleton<MockWatchSourcesDataSource>(
      MockWatchSourcesDataSource.new,
    )
    ..registerLazySingleton<AnimeListRepository>(
      () => MockAnimeListRepository(
        dataSource: serviceLocator<MockAnimeListDataSource>(),
        userRates: _mockUserRates(),
      ),
    )
    ..registerLazySingleton<FriendsRepository>(MockFriendsRepository.new)
    ..registerLazySingleton<CharactersRepository>(MockCharactersRepository.new)
    ..registerLazySingleton<UserListRepository>(
      () => MockUserListRepository(
        rates: _mockUserRates(),
        titles: () async => [
          for (final dto
              in await serviceLocator<MockAnimeListDataSource>()
                  .fetchPopularAnime())
            dto.anime,
        ],
      ),
    )
    ..registerLazySingleton<AnimeGenresRepository>(
      MockAnimeGenresRepository.new,
    )
    ..registerLazySingleton<AnimeDetailsRepository>(
      () => MockAnimeDetailsRepository(
        dataSource: serviceLocator<MockAnimeDetailsDataSource>(),
      ),
    )
    ..registerLazySingleton<WatchSourcesRepository>(
      () => MockWatchSourcesRepository(
        dataSource: serviceLocator<MockWatchSourcesDataSource>(),
      ),
    )
    ..registerLazySingleton<DownloadsRepository>(MockDownloadsRepository.new)
    ..registerLazySingleton<OnlineSourcesRepository>(
      MockOnlineSourcesRepository.new,
    )
    ..registerLazySingleton<OnlineReleasesSearch>(
      MockOnlineSourcesRepository.new,
    )
    ..registerLazySingleton<PlayerRepository>(MockPlayerRepository.new)
    ..registerLazySingleton<PlayerSkipTimesRepository>(
      MockPlayerSkipTimesRepository.new,
    )
    ..registerLazySingleton<PlayerViewportFactory>(
      MockPlayerViewportFactory.new,
    );
}

/// The mock user rates, which the mock catalog and lists read directly.
MockUserRateRepository _mockUserRates() =>
    serviceLocator<UserRateRepository>() as MockUserRateRepository;

Future<void> _registerReal() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final temporaryDirectory = await getTemporaryDirectory();

  final streamCache = StreamCacheStorage(
    directory: Directory(path.join(temporaryDirectory.path, 'iris', 'stream')),
  );
  serviceLocator.registerSingleton<StreamCacheStorage>(streamCache);
  // Leftovers of a crashed or killed session are useless after restart.
  unawaited(streamCache.prepare());

  serviceLocator
    ..registerLazySingleton<TorrentActivityRegistry>(
      TorrentActivityRegistry.new,
    )
    ..registerLazySingleton<AuthRepository>(
      () => ShikimoriAuthRepository(
        oauth: serviceLocator<ShikimoriOAuthClient>(),
        session: serviceLocator<ShikimoriSessionStore>(),
        accounts: ShikimoriAccountDataSource(
          client: serviceLocator<ShikimoriGraphQlClient>(),
        ),
        authenticator: FlutterWebAuthenticator(
          callbackUrlScheme:
              serviceLocator<ShikimoriOAuthConfig>().callbackUrlScheme,
        ),
        preferences: serviceLocator<SharedPreferences>(),
        // flutter_web_auth_2's web flow needs a callback page iris lacks.
        platformSupported: !kIsWeb,
      ),
    )
    ..registerLazySingleton<UserRateRepository>(
      () => RemoteUserRateRepository(
        graphQl: serviceLocator<ShikimoriGraphQlClient>(),
        rest: serviceLocator<ShikimoriRestClient>(),
      ),
    )
    ..registerLazySingleton<FriendsRepository>(
      () => RemoteFriendsRepository(
        client: serviceLocator<ShikimoriRestClient>(),
      ),
    )
    ..registerLazySingleton<CharactersRepository>(
      () => RemoteCharactersRepository(
        graphQl: serviceLocator<ShikimoriGraphQlClient>(),
        rest: serviceLocator<ShikimoriRestClient>(),
      ),
    )
    ..registerLazySingleton<UserListRepository>(
      () => RemoteUserListRepository(
        client: serviceLocator<ShikimoriGraphQlClient>(),
      ),
    )
    ..registerLazySingleton<AnimeGenresRepository>(
      () => RemoteAnimeGenresRepository(
        client: serviceLocator<ShikimoriGraphQlClient>(),
      ),
    )
    ..registerLazySingleton<RemoteAnimeListDataSource>(
      () => RemoteAnimeListDataSource(
        client: serviceLocator<ShikimoriGraphQlClient>(),
      ),
    )
    ..registerLazySingleton<RemoteAnimeDetailsDataSource>(
      () => RemoteAnimeDetailsDataSource(
        client: serviceLocator<ShikimoriGraphQlClient>(),
      ),
    )
    ..registerLazySingleton<RemoteWatchSourcesDataSource>(
      () =>
          RemoteWatchSourcesDataSource(client: serviceLocator<NyaaApiClient>()),
    )
    ..registerLazySingleton<LibtorrentEngineAdapter>(
      () => LibtorrentEngineAdapterImpl(
        streamCache: serviceLocator<StreamCacheStorage>(),
      ),
    )
    ..registerLazySingleton<PlayerRuntimeMemoryAdapter>(
      MethodChannelPlayerRuntimeMemoryAdapter.new,
    )
    ..registerLazySingleton<LibtorrentPlayerDataSource>(
      () => LibtorrentPlayerDataSource(
        engine: serviceLocator<LibtorrentEngineAdapter>(),
        memoryAdapter: serviceLocator<PlayerRuntimeMemoryAdapter>(),
        activityRegistry: serviceLocator<TorrentActivityRegistry>(),
      ),
    )
    ..registerLazySingleton<AnimeListRepository>(
      () => RemoteAnimeListRepository(
        dataSource: serviceLocator<RemoteAnimeListDataSource>(),
      ),
    )
    ..registerLazySingleton<AnimeDetailsRepository>(
      () => RemoteAnimeDetailsRepository(
        dataSource: serviceLocator<RemoteAnimeDetailsDataSource>(),
      ),
    )
    ..registerLazySingleton<WatchSourcesRepository>(
      () => RemoteWatchSourcesRepository(
        dataSource: serviceLocator<RemoteWatchSourcesDataSource>(),
      ),
    )
    ..registerLazySingleton<CombinedOnlineSourcesRepository>(() {
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
    })
    // One repository behind both: the search shows sites as they answer,
    // the player opens what it found.
    ..registerLazySingleton<OnlineSourcesRepository>(
      () => serviceLocator<CombinedOnlineSourcesRepository>(),
    )
    ..registerLazySingleton<OnlineReleasesSearch>(
      () => serviceLocator<CombinedOnlineSourcesRepository>(),
    )
    ..registerLazySingleton<PlayerRepository>(
      () => StreamingOrLocalPlayerRepository(
        streaming: TorrentPlayerRepository(
          dataSource: serviceLocator<LibtorrentPlayerDataSource>(),
        ),
        online: OnlinePlayerRepository(
          repository: serviceLocator<OnlineSourcesRepository>(),
          qualityPreferences: serviceLocator<OnlineQualityPreferences>(),
        ),
        local: LocalPlayerRepository(
          downloadsRepository: serviceLocator<DownloadsRepository>(),
          memoryAdapter: serviceLocator<PlayerRuntimeMemoryAdapter>(),
        ),
      ),
    )
    ..registerLazySingleton<PlayerSkipTimesRepository>(
      () => AniSkipSkipTimesRepository(
        client: serviceLocator<AniSkipApiClient>(),
      ),
    )
    ..registerLazySingleton<PlayerViewportFactory>(
      () => defaultTargetPlatform == TargetPlatform.windows && !kIsWeb
          ? MediaKitPlayerViewportFactory(
              repository: serviceLocator<PlayerRepository>(),
              onlineQuality: serviceLocator<OnlineQualityPreferences>(),
              enterNativeFullscreen: WindowsFullscreen.enter,
              exitNativeFullscreen: WindowsFullscreen.exit,
            )
          : MediaKitPlayerViewportFactory(
              repository: serviceLocator<PlayerRepository>(),
              onlineQuality: serviceLocator<OnlineQualityPreferences>(),
              // Phones and tablets only; see _registerCommon.
              brightness: serviceLocator.isRegistered<ScreenBrightnessControl>()
                  ? serviceLocator<ScreenBrightnessControl>()
                  : null,
            ),
    );

  // Last: the downloads restore at once, and load online episodes through
  // the online sources registered above.
  await _registerDownloads(supportDirectory);
}

Future<void> _registerDownloads(Directory supportDirectory) async {
  serviceLocator
    ..registerLazySingleton<LibtorrentDownloadEngineAdapter>(
      LibtorrentDownloadEngineAdapterImpl.new,
    )
    ..registerLazySingleton<DownloadForegroundServiceAdapter>(
      () => defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? const MethodChannelDownloadForegroundServiceAdapter()
          : const NoopDownloadForegroundServiceAdapter(),
    )
    ..registerLazySingleton<AppStorageUsageAdapter>(
      MethodChannelAppStorageUsageAdapter.new,
    )
    ..registerLazySingleton<DownloadRegistryDataSource>(
      () => DownloadRegistryDataSource(
        registryFile: File(
          path.join(supportDirectory.path, 'downloads_registry.json'),
        ),
      ),
    );

  final repository = DownloadsRepositoryImpl(
    engine: serviceLocator<LibtorrentDownloadEngineAdapter>(),
    registry: serviceLocator<DownloadRegistryDataSource>(),
    downloadsDirectory: Directory(
      path.join(supportDirectory.path, 'offline_downloads'),
    ),
    foregroundService: serviceLocator<DownloadForegroundServiceAdapter>(),
    storageUsageAdapter: serviceLocator<AppStorageUsageAdapter>(),
    streamCache: serviceLocator<StreamCacheStorage>(),
    activityRegistry: serviceLocator<TorrentActivityRegistry>(),
    onlineDownloader: OnlineEpisodeDownloader(
      repository: serviceLocator<OnlineSourcesRepository>(),
      dio: createVideoServerDio(),
    ),
  );
  serviceLocator.registerSingleton<DownloadsRepository>(
    repository,
    dispose: (_) => repository.close(),
  );
  await repository.restore();
}

/// Registrations that are the same with and without mocks.
void _registerCommon() {
  final phone =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (phone) {
    serviceLocator.registerLazySingleton<ScreenBrightnessControl>(
      () => const PluginScreenBrightnessControl(),
    );
  }
  serviceLocator
    ..registerLazySingleton<PlayerScreenMode>(
      () => phone ? const PhonePlayerScreenMode() : const NoPlayerScreenMode(),
    )
    ..registerLazySingleton<MarkEpisodeWatched>(
      () => MarkEpisodeWatched(serviceLocator<UserRateRepository>()),
    )
    ..registerLazySingleton<SubtitlePreferencesRepository>(
      () => SharedPreferencesSubtitlePreferencesRepository(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<PlayerDecodingPreferencesRepository>(
      () => PlayerDecodingPreferencesRepositoryImpl(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<OnlineQualityPreferences>(
      () => SharedPreferencesOnlineQualityPreferences(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<WatchProgressRepository>(
      () => SharedPreferencesWatchProgressRepository(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<PlayerTrackPreferencesRepository>(
      () => SharedPreferencesTrackPreferencesRepository(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<WatchSourcesTabRepository>(
      () => SharedPreferencesWatchSourcesTabRepository(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<SavedTorrentsRepository>(
      () => SharedPreferencesSavedTorrentsRepository(
        serviceLocator<SharedPreferences>(),
      ),
    )
    ..registerFactory<AnimeListBloc>(
      () => AnimeListBloc(repository: serviceLocator<AnimeListRepository>()),
    )
    ..registerFactory<AnimeSearchBloc>(
      () => AnimeSearchBloc(repository: serviceLocator<AnimeListRepository>()),
    );
}
