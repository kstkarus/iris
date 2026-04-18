import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows loading state while source is being prepared', (
    tester,
  ) async {
    final cubit = _FakePlayerSourceCubit(const PlayerSourceLoading());

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Preparing torrent files...'), findsOneWidget);
  });

  testWidgets('shows file cards when source preparation succeeds', (
    tester,
  ) async {
    final cubit = _FakePlayerSourceCubit(
      const PlayerSourceReady(
        PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 734003200,
              extension: 'mkv',
            ),
            PlayerVideoFile(
              index: 2,
              name: 'episode-02.mp4',
              size: 524288000,
              extension: 'mp4',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('episode-01.mkv'), findsOneWidget);
    expect(find.text('episode-02.mp4'), findsOneWidget);
    expect(find.text('Watch File'), findsNWidgets(2));
  });

  testWidgets('shows unsupported-source failure state', (tester) async {
    final cubit = _FakePlayerSourceCubit(
      const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(
      find.text('This source is not suitable for playback.'),
      findsOneWidget,
    );
  });
}

Widget _wrap({required _FakePlayerSourceCubit cubit}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<PlayerSourceCubit>.value(
      value: cubit,
      child: Scaffold(body: PlayerSourceView(onFileSelected: (_) {})),
    ),
  );
}

class _FakePlayerSourceCubit extends PlayerSourceCubit {
  _FakePlayerSourceCubit(PlayerSourceState initialState)
    : super(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: _UnusedPlayerRepository(),
      ) {
    emit(initialState);
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
}
