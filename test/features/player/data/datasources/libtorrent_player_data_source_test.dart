import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/data/exceptions/torrent_metadata_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/data/utils/playback_stream_probe.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';

void main() {
  test(
    'prepares source and returns raw torrent files for later filtering',
    () async {
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [
          TorrentFileDescriptor(
            index: 3,
            name: 'episode-02.mkv',
            size: 900,
            isStreamable: true,
          ),
          TorrentFileDescriptor(
            index: 1,
            name: 'cover.png',
            size: 200,
            isStreamable: false,
          ),
        ],
        streamUrl: 'http://127.0.0.1:8080/stream/3',
      );

      final probe = _FakePlaybackStreamProbe();
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );

      final preparedSource = await dataSource.prepareSource(
        magnet: 'magnet:?xt=urn:btih:test-player',
      );

      expect(engine.initialized, isTrue);
      expect(engine.lastMagnet, 'magnet:?xt=urn:btih:test-player');
      expect(engine.waitedForMetadataTorrentId, 42);
      expect(preparedSource.sessionId, '42');
      expect(preparedSource.files.length, 2);
      expect(preparedSource.files.first.name, 'episode-02.mkv');
    },
  );

  test(
    'throws player-level error when torrent has no streamable files at all',
    () async {
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [
          TorrentFileDescriptor(
            index: 0,
            name: 'readme.txt',
            size: 40,
            isStreamable: false,
          ),
        ],
        streamUrl: 'http://127.0.0.1:8080/stream/0',
      );

      final dataSource = LibtorrentPlayerDataSource(engine: engine);

      await expectLater(
        () => dataSource.prepareSource(magnet: 'magnet:?xt=urn:btih:no-video'),
        throwsA(isA<NoPlayableVideoException>()),
      );
      expect(engine.disposedTorrentIds, [42]);
    },
  );

  test('marks the torrent as streaming before adding it and releases it on '
      'dispose', () async {
    final registry = TorrentActivityRegistry();
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [
        TorrentFileDescriptor(
          index: 0,
          name: 'episode-01.mkv',
          size: 900,
          isStreamable: true,
        ),
      ],
      streamUrl: 'http://127.0.0.1:8080/stream/0',
    );
    final streamingAtAdd = <bool>[];
    registry.streamingStarted.listen(
      (_) => streamingAtAdd.add(engine.lastMagnet == null),
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      activityRegistry: registry,
    );

    final prepared = await dataSource.prepareSource(
      magnet: 'magnet:?xt=urn:btih:ABCDEF',
    );

    expect(streamingAtAdd, [true]);
    expect(registry.isStreaming('abcdef'), isTrue);

    await dataSource.disposePlayback(sessionId: prepared.sessionId);
    expect(registry.isStreaming('abcdef'), isFalse);
  });

  test('releases the streaming mark when metadata fails', () async {
    final registry = TorrentActivityRegistry();
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/0',
      waitForMetadataError: StateError('engine failure'),
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      activityRegistry: registry,
    );

    await expectLater(
      () => dataSource.prepareSource(magnet: 'magnet:?xt=urn:btih:ABCDEF'),
      throwsA(isA<StateError>()),
    );
    expect(registry.isStreaming('abcdef'), isFalse);
    expect(engine.disposedTorrentIds, hasLength(1));
  });

  test('disposes torrent session when metadata loading times out', () async {
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/0',
      waitForMetadataError: const TorrentMetadataUnavailableException(
        torrentId: 42,
        timeout: Duration(seconds: 90),
      ),
    );

    final dataSource = LibtorrentPlayerDataSource(engine: engine);

    await expectLater(
      () => dataSource.prepareSource(magnet: 'magnet:?xt=urn:btih:no-meta'),
      throwsA(isA<TorrentMetadataUnavailableException>()),
    );
    expect(engine.disposedTorrentIds, [42]);
  });

  test(
    'starts playback for selected file index instead of auto-choosing a file',
    () async {
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [],
        streamUrl: 'http://127.0.0.1:8080/stream/8',
      );
      final probe = _FakePlaybackStreamProbe();

      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );

      final updates = await dataSource
          .startPlayback(sessionId: '42', fileIndex: 8)
          .toList();

      expect(engine.startedStreamTorrentId, 42);
      expect(engine.startedStreamFileIndex, 8);
      expect(engine.startedStreamMaxCacheBytes, 256 * 1024 * 1024);
      expect(engine.waitedForStreamReadyId, isNull);
      expect(probe.probedUrls, ['http://127.0.0.1:8080/stream/8']);
      expect(updates, [
        const PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
    },
  );

  test(
    'does not fail startup when HTTP probe cannot confirm a playable stream',
    () async {
      final probe = _FakePlaybackStreamProbe(
        result: const PlaybackProbeResult(
          statusCode: 206,
          contentType: null,
          contentLength: 64,
          acceptRanges: 'bytes',
          firstBytes: [0x00],
        ),
      );
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [],
        streamUrl: 'http://127.0.0.1:8080/stream/8',
      );
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );

      final updates = await dataSource
          .startPlayback(sessionId: '42', fileIndex: 8)
          .toList();

      expect(updates, [
        const PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
    },
  );

  test('emits ready before a blocking HTTP probe completes', () async {
    final probe = _BlockingPlaybackStreamProbe();
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/8',
    );
    final dataSource = LibtorrentPlayerDataSource(engine: engine, probe: probe);

    final updates = await dataSource
        .startPlayback(sessionId: '42', fileIndex: 8)
        .toList();

    expect(updates, [
      const PlaybackLaunchReadyUpdateModel(
        PreparedPlaybackModel(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/8',
        ),
      ),
    ]);
    expect(probe.probedUrls, ['http://127.0.0.1:8080/stream/8']);

    probe.release(
      const PlaybackProbeResult(
        statusCode: 206,
        contentType: null,
        contentLength: 64,
        acceptRanges: 'bytes',
        firstBytes: [0x1A, 0x45, 0xDF, 0xA3],
      ),
    );
  });

  test('disposes torrent session by torrent id', () async {
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/0',
    );
    final dataSource = LibtorrentPlayerDataSource(engine: engine);

    await dataSource.disposePlayback(sessionId: '17');

    expect(engine.disposedTorrentIds, [17]);
  });

  test('watches playback stats for an active playback session', () async {
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/8',
      runtimeStats: const PlaybackRuntimeStatsModel(
        downloadRateBytesPerSecond: 3145728,
        appMemoryBytes: null,
        activePeers: 24,
        bufferSeconds: 14,
        bufferPieces: 20,
        readaheadWindow: 30,
      ),
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      memoryAdapter: const _FakePlayerRuntimeMemoryAdapter(134217728),
      probe: _FakePlaybackStreamProbe(),
      statsPollInterval: Duration.zero,
    );

    await dataSource.startPlayback(sessionId: '42', fileIndex: 8).last;
    final stats = await dataSource.watchPlaybackStats(sessionId: '42').first;

    expect(engine.runtimeStatsStreamId, 77);
    expect(
      stats,
      const PlaybackRuntimeStatsModel(
        downloadRateBytesPerSecond: 3145728,
        appMemoryBytes: 134217728,
        activePeers: 24,
        bufferSeconds: 14,
        bufferPieces: 20,
        readaheadWindow: 30,
      ),
    );
  });

  test('stops the stream but keeps the torrent for the next file', () async {
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/8',
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      probe: _FakePlaybackStreamProbe(),
    );

    await dataSource.startPlayback(sessionId: '42', fileIndex: 8).last;
    await dataSource.stopPlayback(sessionId: '42');
    final next = await dataSource
        .startPlayback(sessionId: '42', fileIndex: 9)
        .last;

    expect(engine.stoppedStreamIds, [77]);
    expect(engine.disposedTorrentIds, isEmpty);
    expect(engine.startedStreamFileIndex, 9);
    expect(next, isA<PlaybackLaunchReadyUpdateModel>());
  });

  test('does not start a second stream for the same active session', () async {
    final engine = _FakeLibtorrentEngineAdapter(
      files: const [],
      streamUrl: 'http://127.0.0.1:8080/stream/8',
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      probe: _FakePlaybackStreamProbe(),
    );

    await dataSource.startPlayback(sessionId: '42', fileIndex: 8).last;
    final secondAttempt = await dataSource
        .startPlayback(sessionId: '42', fileIndex: 8)
        .toList();

    expect(engine.startStreamCallCount, 1);
    expect(secondAttempt, const [
      PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      ),
    ]);
  });

  test(
    'stops HTTP probing quietly when playback is disposed mid-probe',
    () async {
      final probe = _BlockingPlaybackStreamProbe();
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [],
        streamUrl: 'http://127.0.0.1:8080/stream/8',
      );
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );

      final updates = <PlaybackLaunchUpdateModel>[];
      final done = Completer<void>();
      final subscription = dataSource
          .startPlayback(sessionId: '42', fileIndex: 8)
          .listen(
            updates.add,
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
          );

      await probe.started.future;
      await dataSource.disposePlayback(sessionId: '42');
      probe.release(
        const PlaybackProbeResult(
          statusCode: 206,
          contentType: null,
          contentLength: 64,
          acceptRanges: 'bytes',
          firstBytes: [0x00],
        ),
      );
      await done.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(updates, [
        const PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
      expect(probe.probedUrls.length, 1);
    },
  );

  test(
    'ignores probe errors that arrive after playback was disposed',
    () async {
      final probe = _BlockingPlaybackStreamProbe();
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [],
        streamUrl: 'http://127.0.0.1:8080/stream/8',
      );
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );

      final updates = <PlaybackLaunchUpdateModel>[];
      final done = Completer<void>();
      final subscription = dataSource
          .startPlayback(sessionId: '42', fileIndex: 8)
          .listen(
            updates.add,
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
          );

      await probe.started.future;
      await dataSource.disposePlayback(sessionId: '42');
      probe.releaseError(StateError('probe failed'));
      await done.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(updates, [
        const PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
    },
  );
}

class _FakeLibtorrentEngineAdapter implements LibtorrentEngineAdapter {
  @override
  void stopStream(int streamId) => stoppedStreamIds.add(streamId);

  _FakeLibtorrentEngineAdapter({
    required this.files,
    required this.streamUrl,
    this.runtimeStats,
    this.waitForMetadataError,
  });

  final List<TorrentFileDescriptor> files;
  final String streamUrl;
  final PlaybackRuntimeStatsModel? runtimeStats;
  final Object? waitForMetadataError;

  bool initialized = false;
  String? lastMagnet;
  int? waitedForMetadataTorrentId;
  int? startedStreamTorrentId;
  int? startedStreamFileIndex;
  int? startedStreamMaxCacheBytes;
  int? waitedForStreamReadyId;
  int? runtimeStatsStreamId;
  int startStreamCallCount = 0;
  bool waitForStreamReadyWasCancelled = false;
  final List<int> disposedTorrentIds = [];
  final List<int> stoppedStreamIds = [];

  @override
  int addMagnet(String magnet) {
    lastMagnet = magnet;
    return 42;
  }

  @override
  Future<void> disposeTorrent(int torrentId) async {
    disposedTorrentIds.add(torrentId);
  }

  @override
  List<TorrentFileDescriptor> getFiles(int torrentId) => files;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  PlaybackStreamDescriptor startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 0,
  }) {
    startStreamCallCount++;
    startedStreamTorrentId = torrentId;
    startedStreamFileIndex = fileIndex;
    startedStreamMaxCacheBytes = maxCacheBytes;
    return PlaybackStreamDescriptor(streamId: 77, url: streamUrl);
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    if (waitForMetadataError != null) {
      throw waitForMetadataError!;
    }
    waitedForMetadataTorrentId = torrentId;
  }

  @override
  Stream<PlaybackLaunchProgressModel> waitForStreamReady(
    int streamId, {
    required bool Function() isCancelled,
  }) async* {
    waitedForStreamReadyId = streamId;
    waitForStreamReadyWasCancelled = isCancelled();
    yield const PlaybackLaunchProgressModel(
      bufferProgress: 0.25,
      downloadRateBytesPerSecond: 2048,
      stage: PlaybackLaunchStageModel.buffering,
    );
  }

  @override
  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId) {
    runtimeStatsStreamId = streamId;
    return runtimeStats;
  }
}

class _FakePlaybackStreamProbe implements PlaybackStreamProbe {
  _FakePlaybackStreamProbe({
    this.result = const PlaybackProbeResult(
      statusCode: 206,
      contentType: null,
      contentLength: 64,
      acceptRanges: 'bytes',
      firstBytes: [0x1A, 0x45, 0xDF, 0xA3],
    ),
  });

  final PlaybackProbeResult result;
  final List<String> probedUrls = [];

  @override
  Future<PlaybackProbeResult> probe(String url) async {
    probedUrls.add(url);
    return result;
  }
}

class _BlockingPlaybackStreamProbe implements PlaybackStreamProbe {
  final List<String> probedUrls = [];
  final Completer<void> started = Completer<void>();
  final Completer<PlaybackProbeResult> _result =
      Completer<PlaybackProbeResult>();

  void release(PlaybackProbeResult result) {
    if (!_result.isCompleted) {
      _result.complete(result);
    }
  }

  void releaseError(Object error) {
    if (!_result.isCompleted) {
      _result.completeError(error);
    }
  }

  @override
  Future<PlaybackProbeResult> probe(String url) async {
    probedUrls.add(url);
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }
}

class _FakePlayerRuntimeMemoryAdapter implements PlayerRuntimeMemoryAdapter {
  const _FakePlayerRuntimeMemoryAdapter(this.appMemoryBytes);

  final int? appMemoryBytes;

  @override
  Future<int?> getAppMemoryBytes() async => appMemoryBytes;
}
