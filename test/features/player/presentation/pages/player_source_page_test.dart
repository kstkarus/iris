import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';

import '../../../../helpers/test_app.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets('opens player immediately when only one file is available', (
    tester,
  ) async {
    final cubit = await _pumpFilesPage(tester, withPlayerRoute: true);

    cubit.push(const PlayerSourceReady(_singleFileSource));
    await tester.pumpAndSettle();

    expect(find.text('Player Route'), findsOneWidget);
    expect(cubit.didTransferOwnership, isTrue);
  });

  testWidgets('reclaims session ownership when navigation throws', (
    tester,
  ) async {
    final cubit = await _pumpFilesPage(tester, withPlayerRoute: false);

    cubit.push(const PlayerSourceReady(_singleFileSource));
    await tester.pump();

    expect(cubit.didTransferOwnership, isTrue);
    expect(cubit.didReclaimOwnership, isTrue);
    expect(find.byType(PlayerSourcePage), findsOneWidget);
  });
}

/// Without the player route, opening the player throws.
Future<FakePlayerSourceCubit> _pumpFilesPage(
  WidgetTester tester, {
  required bool withPlayerRoute,
}) async {
  late FakePlayerSourceCubit cubit;
  final router = GoRouter(
    initialLocation: '/files',
    routes: [
      GoRoute(
        path: '/files',
        builder: (context, state) {
          cubit = FakePlayerSourceCubit();
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
      if (withPlayerRoute)
        GoRoute(
          path: '/player',
          name: 'player',
          builder: (context, state) {
            return const Scaffold(body: Text('Player Route'));
          },
        ),
    ],
  );

  await tester.pumpWidget(testRouterApp(router));
  return cubit;
}

const _singleFileSource = PreparedPlayerSource(
  sessionId: '42',
  files: [
    PlayerVideoFile(
      index: 1,
      name: 'episode-01.mkv',
      size: 734003200,
      extension: 'mkv',
    ),
  ],
);
