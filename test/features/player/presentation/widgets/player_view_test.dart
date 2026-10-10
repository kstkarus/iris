import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import '../../../../helpers/fake_player_engine.dart';

void main() {
  testWidgets('shows the preparation state', (tester) async {
    final cubit = _FakePlayerCubit(const PlayerPreparing(), source: _source);

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Preparing video'), findsOneWidget);
    expect(find.text('0% ready for playback'), findsOneWidget);
  });

  testWidgets('shows player viewport when playback is ready', (tester) async {
    final cubit = _FakePlayerCubit(
      const PlayerReady(
        PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/2',
        ),
      ),
      source: _source,
    );

    await tester.pumpWidget(
      _wrap(cubit: cubit, factory: const _FakeViewportFactory()),
    );

    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
  });

  testWidgets('keeps the player on screen while the next file starts', (
    tester,
  ) async {
    final cubit = _FakePlayerCubit(
      const PlayerPreparing(keepsPlayer: true),
      source: _source,
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
    expect(find.text('Preparing video'), findsNothing);
  });

  testWidgets('shows retry action on generic failure', (tester) async {
    final cubit = _FakePlayerCubit(const PlayerFailure(), source: _source);

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Unable to start playback.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    expect(cubit.loadCalls, 1);
  });
}

Widget _wrap({
  required _FakePlayerCubit cubit,
  PlayerViewportFactory factory = const _FakeViewportFactory(),
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<PlayerCubit>.value(
      value: cubit,
      child: Scaffold(body: PlayerView(viewportFactory: factory)),
    ),
  );
}

class _FakePlayerCubit extends PlayerCubit {
  _FakePlayerCubit(PlayerState initialState, {required super.source})
    : super(repository: _UnusedPlayerRepository(), engine: FakePlayerEngine()) {
    emit(initialState);
  }

  int loadCalls = 0;

  @override
  Future<void> loadPlayback() async {
    loadCalls++;
  }
}

class _UnusedPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
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

class _FakeViewportFactory implements PlayerViewportFactory {
  const _FakeViewportFactory();

  @override
  PlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return FakePlayerEngine();
  }

  @override
  Widget build({
    required PlayerEngine engine,
    PlayerNextFile? next,
    PlayerChrome? chrome,
  }) {
    return const ColoredBox(
      key: Key('player_video_surface'),
      color: Colors.black,
      child: SizedBox.expand(),
    );
  }
}

const _source = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
  sessionId: '42',
  fileIndex: 2,
  fileName: 'episode-02.mkv',
);
