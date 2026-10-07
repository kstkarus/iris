import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/di/service_locator.dart';
import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/pages/anime_details_page.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/pages/anime_list_page.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/pages/saved_torrents_page.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

abstract final class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShellPage(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  name: 'anime-list',
                  builder: (context, state) {
                    return MultiBlocProvider(
                      providers: [
                        BlocProvider(
                          create: (_) =>
                              serviceLocator<AnimeListBloc>()
                                ..add(const AnimeListStarted()),
                        ),
                        BlocProvider(
                          create: (_) => serviceLocator<AnimeSearchBloc>(),
                        ),
                      ],
                      child: const AnimeListPage(),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/torrents',
                  name: 'saved-torrents',
                  builder: (context, state) {
                    // Saved torrents are not catalog titles: the player and
                    // downloads get the torrent's own name and no anime id.
                    return BlocProvider(
                      create: (_) => SavedTorrentsCubit(
                        repository: serviceLocator<SavedTorrentsRepository>(),
                      )..load(),
                      child: SavedTorrentsPage(
                        onWatch: (torrent, {autoOpenFileIndex}) =>
                            context.pushNamed(
                              'torrent-stream-files',
                              extra: AnimePlayerSourceArgs(
                                animeId: '',
                                animeTitle: torrent.title,
                                sourceTitle: torrent.title,
                                magnet: torrent.magnet,
                                autoOpenFileIndex: autoOpenFileIndex,
                              ),
                            ),
                        onDownload: (torrent) => context.pushNamed(
                          'torrent-download-files',
                          extra: DownloadSelectionArgs(
                            animeId: '',
                            animeTitle: torrent.title,
                            sourceTitle: torrent.title,
                            magnet: torrent.magnet,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/downloads',
                  name: 'downloads',
                  builder: (context, state) {
                    return BlocProvider(
                      create: (_) => DownloadManagerCubit(
                        repository: serviceLocator<DownloadsRepository>(),
                      )..load(),
                      child: DownloadManagerPage(
                        onWatch: (item) {
                          context.pushNamed(
                            'player',
                            extra: AnimePlayerArgs(
                              animeId: item.animeId,
                              animeTitle: item.animeTitle,
                              sourceTitle: item.sourceTitle,
                              sessionId: item.id,
                              fileIndex: item.fileIndex,
                              fileName: item.fileName,
                              magnet: item.magnet,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/anime/:id',
          name: 'anime-details',
          builder: (context, state) {
            final animeId = state.pathParameters['id'] ?? '';
            // Optional: a deep link opens the page without a preview.
            final preview = switch (state.extra) {
              final AnimeDetailsPreview preview when preview.id == animeId =>
                preview,
              _ => null,
            };

            return BlocProvider(
              create: (_) => AnimeDetailsCubit(
                animeId: animeId,
                repository: serviceLocator<AnimeDetailsRepository>(),
              )..loadAnime(),
              child: AnimeDetailsPage(preview: preview),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id/download',
          name: 'anime-watch-sources',
          builder: (context, state) {
            final args = state.extra;
            if (args is! AnimeWatchSourcesArgs ||
                args.animeId.trim().isEmpty ||
                state.pathParameters['id']?.trim().isEmpty != false) {
              _reportInvalidRouteArgs(
                routeName: 'anime-watch-sources',
                extra: state.extra,
              );
              return const _InvalidRoutePage();
            }

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
        // Torrent routes take a magnet, not a catalog title: they serve both
        // catalog sources and the user's saved torrents.
        GoRoute(
          path: '/torrent/download',
          name: 'torrent-download-files',
          builder: (context, state) {
            final args = state.extra;
            if (args is! DownloadSelectionArgs || args.magnet.trim().isEmpty) {
              _reportInvalidRouteArgs(
                routeName: 'torrent-download-files',
                extra: state.extra,
              );
              return const _InvalidRoutePage();
            }

            return BlocProvider(
              create: (_) => DownloadSelectionCubit(
                args: args,
                repository: serviceLocator<DownloadsRepository>(),
              )..load(),
              child: DownloadSelectionPage(
                args: args,
                onQueued: (_) => context.goNamed('downloads'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/torrent/watch',
          name: 'torrent-stream-files',
          builder: (context, state) {
            final args = state.extra;
            if (args is! AnimePlayerSourceArgs || args.magnet.trim().isEmpty) {
              _reportInvalidRouteArgs(
                routeName: 'torrent-stream-files',
                extra: state.extra,
              );
              return const _InvalidRoutePage();
            }

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
          path: '/player',
          name: 'player',
          builder: (context, state) {
            final args = state.extra;
            if (args is! AnimePlayerArgs || args.sessionId.trim().isEmpty) {
              _reportInvalidRouteArgs(routeName: 'player', extra: state.extra);
              return const _InvalidRoutePage();
            }

            final viewportFactory = serviceLocator<PlayerViewportFactory>();
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => PlayerSubtitlePreferencesCubit(
                    repository: serviceLocator<SubtitlePreferencesRepository>(),
                  )..loadPreferences(),
                ),
                BlocProvider(
                  create: (_) => PlayerDecodingPreferencesCubit(
                    repository:
                        serviceLocator<PlayerDecodingPreferencesRepository>(),
                  )..loadPreferences(),
                ),
                // Below the preference cubits: the media player reads them.
                BlocProvider(
                  create: (context) => PlayerCubit(
                    source: AnimePlayerSource(
                      animeId: args.animeId,
                      animeTitle: args.animeTitle,
                      sourceTitle: args.sourceTitle,
                      sessionId: args.sessionId,
                      fileIndex: args.fileIndex,
                      fileName: args.fileName,
                      magnet: args.magnet,
                      files: args.files,
                    ),
                    repository: serviceLocator<PlayerRepository>(),
                    engine: viewportFactory.createEngine(
                      subtitlePreferences: context
                          .read<PlayerSubtitlePreferencesCubit>(),
                      decodingPreferences: context
                          .read<PlayerDecodingPreferencesCubit>(),
                    ),
                    progressRepository:
                        serviceLocator<WatchProgressRepository>(),
                    trackPreferencesRepository:
                        serviceLocator<PlayerTrackPreferencesRepository>(),
                    skipTimesRepository:
                        serviceLocator<PlayerSkipTimesRepository>(),
                  )..loadPlayback(),
                ),
              ],
              child: PlayerPage(viewportFactory: viewportFactory),
            );
          },
        ),
      ],
    );
  }
}

void _reportInvalidRouteArgs({
  required String routeName,
  required Object? extra,
}) {
  developer.log(
    'Route $routeName received invalid navigation data: $extra',
    name: 'iris.app_router',
  );
}

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.invalidRouteArgumentsMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                    return;
                  }
                  context.goNamed('anime-list');
                },
                child: Text(materialL10n.backButtonTooltip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
