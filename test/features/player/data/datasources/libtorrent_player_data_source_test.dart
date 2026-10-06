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

const _magnet = 'magnet:?xt=urn:btih:ABCDEF';
const _otherMagnet = 'magnet:?xt=urn:btih:123456';

const _videoFiles = [
  TorrentFileDescriptor(
    index: 8,
    name: 'episode-08.mkv',
    size: 900,
    isStreamable: true,
  ),
  TorrentFileDescriptor(
    index: 9,
    name: 'episode-09.mkv',
    size: 900,
    isStreamable: true,
  ),
];

_FakeLibtorrentEngineAdapter _videoEngine({
  PlaybackRuntimeStatsModel? runtimeStats,
  Object? waitForMetadataError,
  Completer<void>? metadataGate,
}) {
  return _FakeLibtorrentEngineAdapter(
    files: _videoFiles,
    streamUrl: 'http://127.0.0.1:8080/stream/8',
    runtimeStats: runtimeStats,
    waitForMetadataError: waitForMetadataError,
    metadataGate: metadataGate,
  );
}

Future<String> _prepare(
  LibtorrentPlayerDataSource dataSource, [
  String magnet = _magnet,
]) async {
  final prepared = await dataSource.prepareSource(magnet: magnet);
  return prepared.sessionId;
}

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
      expect(int.tryParse(preparedSource.sessionId), isNotNull);
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
    final engine = _videoEngine();
    final streamingAtAdd = <bool>[];
    registry.streamingStarted.listen(
      (_) => streamingAtAdd.add(engine.lastMagnet == null),
    );
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      activityRegistry: registry,
    );

    final sessionId = await _prepare(dataSource);

    expect(streamingAtAdd, [true]);
    expect(registry.isStreaming('abcdef'), isTrue);

    await dataSource.disposePlayback(sessionId: sessionId);
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
      () => dataSource.prepareSource(magnet: _magnet),
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
      final engine = _videoEngine();
      final probe = _FakePlaybackStreamProbe();
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: probe,
      );
      final sessionId = await _prepare(dataSource);

      final updates = await dataSource
          .startPlayback(sessionId: sessionId, fileIndex: 8)
          .toList();

      expect(engine.startedStreamTorrentId, 42);
      expect(engine.startedStreamFileIndex, 8);
      expect(engine.startedStreamMaxCacheBytes, 256 * 1024 * 1024);
      expect(engine.waitedForStreamReadyId, isNull);
      expect(probe.probedUrls, ['http://127.0.0.1:8080/stream/8']);
      expect(updates, [
        PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: sessionId,
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
      final dataSource = LibtorrentPlayerDataSource(
        engine: _videoEngine(),
        probe: probe,
      );
      final sessionId = await _prepare(dataSource);

      final updates = await dataSource
          .startPlayback(sessionId: sessionId, fileIndex: 8)
          .toList();

      expect(updates, [
        PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: sessionId,
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
    },
  );

  test('emits ready before a blocking HTTP probe completes', () async {
    final probe = _BlockingPlaybackStreamProbe();
    final dataSource = LibtorrentPlayerDataSource(
      engine: _videoEngine(),
      probe: probe,
    );
    final sessionId = await _prepare(dataSource);

    final updates = await dataSource
        .startPlayback(sessionId: sessionId, fileIndex: 8)
        .toList();

    expect(updates, [
      PlaybackLaunchReadyUpdateModel(
        PreparedPlaybackModel(
          sessionId: sessionId,
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

  test('watches playback stats for an active playback session', () async {
    final engine = _videoEngine(
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
    final sessionId = await _prepare(dataSource);

    await dataSource.startPlayback(sessionId: sessionId, fileIndex: 8).last;
    final stats = await dataSource
        .watchPlaybackStats(sessionId: sessionId)
        .first;

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
    final engine = _videoEngine();
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      probe: _FakePlaybackStreamProbe(),
    );
    final sessionId = await _prepare(dataSource);

    await dataSource.startPlayback(sessionId: sessionId, fileIndex: 8).last;
    await dataSource.stopPlayback(sessionId: sessionId);
    final next = await dataSource
        .startPlayback(sessionId: sessionId, fileIndex: 9)
        .last;

    expect(engine.stoppedStreamIds, [77]);
    expect(engine.disposedTorrentIds, isEmpty);
    expect(engine.startedStreamFileIndex, 9);
    expect(next, isA<PlaybackLaunchReadyUpdateModel>());
  });

  test('does not start a second stream for the same active session', () async {
    final engine = _videoEngine();
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      probe: _FakePlaybackStreamProbe(),
    );
    final sessionId = await _prepare(dataSource);

    await dataSource.startPlayback(sessionId: sessionId, fileIndex: 8).last;
    final secondAttempt = await dataSource
        .startPlayback(sessionId: sessionId, fileIndex: 8)
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
      final dataSource = LibtorrentPlayerDataSource(
        engine: _videoEngine(),
        probe: probe,
      );
      final sessionId = await _prepare(dataSource);

      final updates = <PlaybackLaunchUpdateModel>[];
      final done = Completer<void>();
      final subscription = dataSource
          .startPlayback(sessionId: sessionId, fileIndex: 8)
          .listen(
            updates.add,
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
          );

      await probe.started.future;
      await dataSource.disposePlayback(sessionId: sessionId);
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
        PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: sessionId,
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
      final dataSource = LibtorrentPlayerDataSource(
        engine: _videoEngine(),
        probe: probe,
      );
      final sessionId = await _prepare(dataSource);

      final updates = <PlaybackLaunchUpdateModel>[];
      final done = Completer<void>();
      final subscription = dataSource
          .startPlayback(sessionId: sessionId, fileIndex: 8)
          .listen(
            updates.add,
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
          );

      await probe.started.future;
      await dataSource.disposePlayback(sessionId: sessionId);
      probe.releaseError(StateError('probe failed'));
      await done.future.timeout(const Duration(seconds: 2));
      await subscription.cancel();

      expect(updates, [
        PlaybackLaunchReadyUpdateModel(
          PreparedPlaybackModel(
            sessionId: sessionId,
            streamUrl: 'http://127.0.0.1:8080/stream/8',
          ),
        ),
      ]);
    },
  );

  group('sessions of one torrent', () {
    test(
      'share it and it goes, with its files, with the last of them',
      () async {
        final registry = TorrentActivityRegistry();
        final engine = _videoEngine();
        final dataSource = LibtorrentPlayerDataSource(
          engine: engine,
          probe: _FakePlaybackStreamProbe(),
          activityRegistry: registry,
        );

        final older = await _prepare(dataSource);
        final newer = await _prepare(dataSource);

        expect(newer, isNot(older));
        expect(engine.calls.where((call) => call.startsWith('add')), [
          'add:42',
        ]);

        await dataSource.disposePlayback(sessionId: older);
        expect(engine.disposedTorrentIds, isEmpty);
        expect(registry.isStreaming('abcdef'), isTrue);
        final update = await dataSource
            .startPlayback(sessionId: newer, fileIndex: 8)
            .last;
        expect(update, isA<PlaybackLaunchReadyUpdateModel>());

        await dataSource.disposePlayback(sessionId: newer);
        expect(engine.disposedTorrentIds, [42]);
        expect(registry.isStreaming('abcdef'), isFalse);
      },
    );

    test('closing the older session after the newer one started keeps the '
        'newer stream', () async {
      final engine = _videoEngine();
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        probe: _FakePlaybackStreamProbe(),
      );
      final older = await _prepare(dataSource);
      await dataSource.startPlayback(sessionId: older, fileIndex: 8).last;

      final newer = await _prepare(dataSource);
      await dataSource.startPlayback(sessionId: newer, fileIndex: 8).last;
      await dataSource.disposePlayback(sessionId: older);

      expect(
        engine.calls,
        ['add:42', 'start:77', 'stop:77', 'start:78'],
        reason:
            'the older stream ends before the newer starts, so its end '
            'cannot reset the newer stream\'s priorities',
      );
      expect(engine.disposedTorrentIds, isEmpty);
    });

    test('a newer stream ends the stats of the older session', () async {
      final engine = _videoEngine(
        runtimeStats: const PlaybackRuntimeStatsModel(
          downloadRateBytesPerSecond: 1,
          appMemoryBytes: null,
          activePeers: 1,
          bufferSeconds: 1,
          bufferPieces: 1,
          readaheadWindow: 1,
        ),
      );
      final dataSource = LibtorrentPlayerDataSource(
        engine: engine,
        memoryAdapter: const _FakePlayerRuntimeMemoryAdapter(null),
        probe: _FakePlaybackStreamProbe(),
        statsPollInterval: Duration.zero,
      );
      final older = await _prepare(dataSource);
      await dataSource.startPlayback(sessionId: older, fileIndex: 8).last;
      final olderStats = dataSource
          .watchPlaybackStats(sessionId: older)
          .toList();

      final newer = await _prepare(dataSource);
      await dataSource.startPlayback(sessionId: newer, fileIndex: 8).last;

      await expectLater(
        olderStats.timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    test('a session still preparing keeps the torrent when the older one '
        'goes', () async {
      final gate = Completer<void>();
      final engine = _videoEngine(metadataGate: gate);
      final dataSource = LibtorrentPlayerDataSource(engine: engine);

      final olderPrepared = dataSource.prepareSource(magnet: _magnet);
      final newerPrepared = dataSource.prepareSource(magnet: _magnet);
      gate.complete();
      final older = (await olderPrepared).sessionId;

      await dataSource.disposePlayback(sessionId: older);
      final newer = (await newerPrepared).sessionId;

      expect(engine.disposedTorrentIds, isEmpty);
      expect(
        engine.calls.where((call) => call.startsWith('add')),
        hasLength(1),
      );
      await dataSource.disposePlayback(sessionId: newer);
      expect(engine.disposedTorrentIds, [42]);
    });

    test(
      'all fail and the torrent goes once when its metadata fails',
      () async {
        final registry = TorrentActivityRegistry();
        final gate = Completer<void>();
        final engine = _videoEngine(
          metadataGate: gate,
          waitForMetadataError: StateError('no metadata'),
        );
        final dataSource = LibtorrentPlayerDataSource(
          engine: engine,
          activityRegistry: registry,
        );

        final first = dataSource.prepareSource(magnet: _magnet);
        final second = dataSource.prepareSource(magnet: _magnet);
        gate.complete();

        await expectLater(first, throwsA(isA<StateError>()));
        await expectLater(second, throwsA(isA<StateError>()));
        expect(engine.disposedTorrentIds, [42]);
        expect(registry.isStreaming('abcdef'), isFalse);
      },
    );

    test('get a fresh torrent once the last session is gone', () async {
      final engine = _videoEngine();
      final dataSource = LibtorrentPlayerDataSource(engine: engine);

      final first = await _prepare(dataSource);
      await dataSource.disposePlayback(sessionId: first);
      final second = await _prepare(dataSource);

      expect(engine.calls, ['add:42', 'dispose:42', 'add:43']);
      expect(second, isNot(first));
    });
  });

  test('keeps the torrents of different magnets apart', () async {
    final engine = _videoEngine();
    final dataSource = LibtorrentPlayerDataSource(engine: engine);

    final first = await _prepare(dataSource);
    final second = await _prepare(dataSource, _otherMagnet);
    await dataSource.disposePlayback(sessionId: first);

    expect(engine.disposedTorrentIds, [42]);
    final update = await dataSource
        .startPlayback(sessionId: second, fileIndex: 8)
        .last;
    expect(update, isA<PlaybackLaunchReadyUpdateModel>());
    expect(engine.startedStreamTorrentId, 43);
  });

  test('ignores disposing an unknown or already disposed session', () async {
    final registry = TorrentActivityRegistry();
    final engine = _videoEngine();
    final dataSource = LibtorrentPlayerDataSource(
      engine: engine,
      activityRegistry: registry,
    );
    final kept = await _prepare(dataSource);
    final disposed = await _prepare(dataSource);

    await dataSource.disposePlayback(sessionId: disposed);
    await dataSource.disposePlayback(sessionId: disposed);
    await dataSource.disposePlayback(sessionId: '999');

    expect(engine.disposedTorrentIds, isEmpty);
    expect(registry.isStreaming('abcdef'), isTrue);
    await dataSource.disposePlayback(sessionId: kept);
    expect(engine.disposedTorrentIds, [42]);
  });

  test('does not start a disposed session', () async {
    final engine = _videoEngine();
    final dataSource = LibtorrentPlayerDataSource(engine: engine);
    final sessionId = await _prepare(dataSource);
    await dataSource.disposePlayback(sessionId: sessionId);

    final updates = await dataSource
        .startPlayback(sessionId: sessionId, fileIndex: 8)
        .toList();

    expect(updates, const [
      PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      ),
    ]);
    expect(engine.startStreamCallCount, 0);
  });
}

class _FakeLibtorrentEngineAdapter implements LibtorrentEngineAdapter {
  _FakeLibtorrentEngineAdapter({
    required this.files,
    required this.streamUrl,
    this.runtimeStats,
    this.waitForMetadataError,
    this.metadataGate,
  });

  final List<TorrentFileDescriptor> files;
  final String streamUrl;
  final PlaybackRuntimeStatsModel? runtimeStats;
  final Object? waitForMetadataError;

  /// Holds metadata back until completed, when set.
  final Completer<void>? metadataGate;

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

  /// Native calls in order: `add:42`, `start:77`, `stop:77`, `dispose:42`.
  final List<String> calls = [];
  int _nextTorrentId = 42;
  int _nextStreamId = 77;

  @override
  int addMagnet(String magnet) {
    lastMagnet = magnet;
    final torrentId = _nextTorrentId++;
    calls.add('add:$torrentId');
    return torrentId;
  }

  @override
  Future<void> disposeTorrent(int torrentId) async {
    calls.add('dispose:$torrentId');
    disposedTorrentIds.add(torrentId);
  }

  @override
  void stopStream(int streamId) {
    calls.add('stop:$streamId');
    stoppedStreamIds.add(streamId);
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
    final streamId = _nextStreamId++;
    calls.add('start:$streamId');
    return PlaybackStreamDescriptor(streamId: streamId, url: streamUrl);
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    await metadataGate?.future;
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
