import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('opens player immediately when only one file is available', (
    tester,
  ) async {
    late _TestPlayerSourceCubit cubit;
    final router = GoRouter(
      initialLocation: '/files',
      routes: [
        GoRoute(
          path: '/files',
          builder: (context, state) {
            cubit = _TestPlayerSourceCubit();
            return BlocProvider<PlayerSourceCubit>.value(
              value: cubit,
              child: const PlayerSourcePage(
                args: AnimePlayerSourceArgs(
                  animeId: '5114',
                  animeTitle: 'Fullmetal Alchemist: Brotherhood',
                  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
                  magnet: 'magnet:?xt=urn:btih:test-source',
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/anime/:id/watch/player',
          name: 'anime-player',
          builder: (context, state) {
            return const Scaffold(body: Text('Player Route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

    cubit.emitReady(
      const PreparedPlayerSource(
        sessionId: '42',
        files: [
          PlayerVideoFile(
            index: 1,
            name: 'episode-01.mkv',
            size: 734003200,
            extension: 'mkv',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player Route'), findsOneWidget);
    expect(cubit.didTransferOwnership, isTrue);
  });

  testWidgets('reclaims session ownership when navigation throws', (
    tester,
  ) async {
    late _TestPlayerSourceCubit cubit;
    final router = GoRouter(
      initialLocation: '/files',
      routes: [
        GoRoute(
          path: '/files',
          builder: (context, state) {
            cubit = _TestPlayerSourceCubit();
            return BlocProvider<PlayerSourceCubit>.value(
              value: cubit,
              child: const PlayerSourcePage(
                args: AnimePlayerSourceArgs(
                  animeId: '5114',
                  animeTitle: 'Fullmetal Alchemist: Brotherhood',
                  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
                  magnet: 'magnet:?xt=urn:btih:test-source',
                ),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

    cubit.emitReady(
      const PreparedPlayerSource(
        sessionId: '42',
        files: [
          PlayerVideoFile(
            index: 1,
            name: 'episode-01.mkv',
            size: 734003200,
            extension: 'mkv',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(cubit.didTransferOwnership, isTrue);
    expect(cubit.didReclaimOwnership, isTrue);
    expect(find.byType(PlayerSourcePage), findsOneWidget);
  });
}

class _TestPlayerSourceCubit extends PlayerSourceCubit {
  _TestPlayerSourceCubit()
    : super(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: _UnusedPlayerRepository(),
      );

  bool didTransferOwnership = false;
  bool didReclaimOwnership = false;

  void emitReady(PreparedPlayerSource source) {
    emit(PlayerSourceReady(source));
  }

  @override
  void transferSessionOwnership() {
    didTransferOwnership = true;
    super.transferSessionOwnership();
  }

  @override
  void reclaimSessionOwnership() {
    didReclaimOwnership = true;
    super.reclaimSessionOwnership();
  }
}

class _UnusedPlayerRepository implements PlayerRepository {
  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}
