import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/repositories/streaming_or_local_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

void main() {
  late _RecordingPlayerRepository streaming;
  late _RecordingPlayerRepository online;
  late _RecordingPlayerRepository local;
  late StreamingOrLocalPlayerRepository repository;

  setUp(() {
    streaming = _RecordingPlayerRepository('streaming');
    online = _RecordingPlayerRepository('online');
    local = _RecordingPlayerRepository('local');
    repository = StreamingOrLocalPlayerRepository(
      streaming: streaming,
      online: online,
      local: local,
    );
  });

  test('prepares sources by streaming', () async {
    await repository.prepareSource(magnet: 'magnet:?xt=urn:btih:abc');

    expect(streaming.calls, ['prepare']);
    expect(local.calls, isEmpty);
  });

  test('passes the cancellation of a preparation on to streaming', () async {
    final cancelled = Completer<void>();

    await repository.prepareSource(
      magnet: 'magnet:?xt=urn:btih:abc',
      cancelled: cancelled.future,
    );

    expect(streaming.cancellations.single, same(cancelled.future));
  });

  test('routes numeric torrent sessions to streaming', () async {
    await repository.startPlayback(sessionId: '7', fileIndex: 2).drain<void>();
    await repository.watchPlaybackStats(sessionId: '7').drain<void>();
    await repository.disposePlayback(sessionId: '7');

    expect(streaming.calls, ['start:7', 'stats:7', 'dispose:7']);
    expect(local.calls, isEmpty);
  });

  test('prepares and plays an online release online', () async {
    const link = 'online:anilibria/9542';
    await repository.prepareSource(magnet: link);
    await repository.startPlayback(sessionId: link, fileIndex: 3).drain<void>();
    await repository.watchPlaybackStats(sessionId: link).drain<void>();
    await repository.disposePlayback(sessionId: link);

    expect(online.calls, [
      'prepare',
      'start:$link',
      'stats:$link',
      'dispose:$link',
    ]);
    expect(streaming.calls, isEmpty);
    expect(local.calls, isEmpty);
  });

  test('routes download ids to local playback', () async {
    const downloadId = 'abcdef0123-4';
    await repository
        .startPlayback(sessionId: downloadId, fileIndex: 4)
        .drain<void>();
    await repository.disposePlayback(sessionId: downloadId);

    expect(local.calls, ['start:$downloadId', 'dispose:$downloadId']);
    expect(streaming.calls, isEmpty);
  });
}

class _RecordingPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  _RecordingPlayerRepository(this.name);

  final String name;
  final List<String> calls = [];
  final List<Future<void>?> cancellations = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    calls.add('dispose:$sessionId');
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    calls.add('prepare');
    cancellations.add(cancelled);
    return const PreparedPlayerSource(sessionId: '1', files: []);
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    calls.add('start:$sessionId');
    return const Stream.empty();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    calls.add('stats:$sessionId');
    return const Stream.empty();
  }
}
