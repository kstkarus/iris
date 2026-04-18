import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';

void main() {
  test('emits loading then success when source files are prepared', () async {
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: _PreparedSourceRepository(
        const PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 700,
              extension: 'mkv',
            ),
            PlayerVideoFile(
              index: 2,
              name: 'episode-02.mkv',
              size: 800,
              extension: 'mkv',
            ),
          ],
        ),
      ),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([
        const PlayerSourceLoading(),
        const PlayerSourceReady(
          PreparedPlayerSource(
            sessionId: '42',
            files: [
              PlayerVideoFile(
                index: 1,
                name: 'episode-01.mkv',
                size: 700,
                extension: 'mkv',
              ),
              PlayerVideoFile(
                index: 2,
                name: 'episode-02.mkv',
                size: 800,
                extension: 'mkv',
              ),
            ],
          ),
        ),
      ]),
    );

    await cubit.loadSource();
  });

  test(
    'emits unsupported-source failure when repository finds no video files',
    () async {
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: _UnsupportedSourceRepository(),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          const PlayerSourceLoading(),
          const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
        ]),
      );

      await cubit.loadSource();
    },
  );

  test(
    'disposes prepared source on close when ownership was not transferred',
    () async {
      final repository = _PreparedSourceRepository(
        const PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 700,
              extension: 'mkv',
            ),
          ],
        ),
      );
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: repository,
      );

      await cubit.loadSource();
      await cubit.close();

      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test('does not dispose prepared source after ownership transfer', () async {
    final repository = _PreparedSourceRepository(
      const PreparedPlayerSource(
        sessionId: '42',
        files: [
          PlayerVideoFile(
            index: 1,
            name: 'episode-01.mkv',
            size: 700,
            extension: 'mkv',
          ),
        ],
      ),
    );
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: repository,
    );

    await cubit.loadSource();
    cubit.transferSessionOwnership();
    await cubit.close();

    expect(repository.disposedSessionIds, isEmpty);
  });
}

class _PreparedSourceRepository implements PlayerRepository {
  _PreparedSourceRepository(this.preparedSource);

  final PreparedPlayerSource preparedSource;
  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) async {
    return preparedSource;
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }
}

class _UnsupportedSourceRepository implements PlayerRepository {
  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) async {
    throw const NoPlayableVideoException();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }
}
