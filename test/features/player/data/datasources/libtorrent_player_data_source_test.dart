import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/data/exceptions/startup_buffer_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/data/utils/playback_stream_probe.dart';

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
      expect(engine.waitedForStreamReadyId, 77);
      expect(probe.probedUrls, ['http://127.0.0.1:8080/stream/8']);
      expect(updates, [
        const PlaybackLaunchProgressUpdateModel(
          PlaybackLaunchProgressModel(
            bufferProgress: 0.25,
            downloadRateBytesPerSecond: 2048,
            stage: PlaybackLaunchStageModel.buffering,
          ),
        ),
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
    'emits startup buffer failure when engine cannot prepare the buffer',
    () async {
      final engine = _FakeLibtorrentEngineAdapter(
        files: const [],
        streamUrl: 'http://127.0.0.1:8080/stream/8',
        waitForStreamReadyError: const StartupBufferUnavailableException(
          progress: PlaybackLaunchProgressModel(
            bufferProgress: 0.125,
            downloadRateBytesPerSecond: 4096,
            stage: PlaybackLaunchStageModel.extendedBuffering,
          ),
        ),
      );
      final dataSource = LibtorrentPlayerDataSource(engine: engine);

      final updates = await dataSource
          .startPlayback(sessionId: '42', fileIndex: 8)
          .toList();

      expect(updates, [
        const PlaybackLaunchProgressUpdateModel(
          PlaybackLaunchProgressModel(
            bufferProgress: 0.125,
            downloadRateBytesPerSecond: 4096,
            stage: PlaybackLaunchStageModel.extendedBuffering,
          ),
        ),
        const PlaybackLaunchFailureUpdateModel(
          PlaybackLaunchFailureModel.unableToPrepareStartupBuffer,
        ),
      ]);
    },
  );

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
      ),
    );
  });
}

class _FakeLibtorrentEngineAdapter implements LibtorrentEngineAdapter {
  _FakeLibtorrentEngineAdapter({
    required this.files,
    required this.streamUrl,
    this.waitForStreamReadyError,
    this.runtimeStats,
  });

  final List<TorrentFileDescriptor> files;
  final String streamUrl;
  final Object? waitForStreamReadyError;
  final PlaybackRuntimeStatsModel? runtimeStats;

  bool initialized = false;
  String? lastMagnet;
  int? waitedForMetadataTorrentId;
  int? startedStreamTorrentId;
  int? startedStreamFileIndex;
  int? waitedForStreamReadyId;
  int? runtimeStatsStreamId;
  final List<int> disposedTorrentIds = [];

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
  }) {
    startedStreamTorrentId = torrentId;
    startedStreamFileIndex = fileIndex;
    return PlaybackStreamDescriptor(streamId: 77, url: streamUrl);
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    waitedForMetadataTorrentId = torrentId;
  }

  @override
  Stream<PlaybackLaunchProgressModel> waitForStreamReady(int streamId) async* {
    waitedForStreamReadyId = streamId;
    if (waitForStreamReadyError != null) {
      throw waitForStreamReadyError!;
    }
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
  final List<String> probedUrls = [];

  @override
  Future<PlaybackProbeResult> probe(String url) async {
    probedUrls.add(url);
    return const PlaybackProbeResult(
      statusCode: 206,
      contentType: null,
      contentLength: 64,
      acceptRanges: 'bytes',
      firstBytes: [0x1A, 0x45, 0xDF, 0xA3],
    );
  }
}

class _FakePlayerRuntimeMemoryAdapter implements PlayerRuntimeMemoryAdapter {
  const _FakePlayerRuntimeMemoryAdapter(this.appMemoryBytes);

  final int? appMemoryBytes;

  @override
  Future<int?> getAppMemoryBytes() async => appMemoryBytes;
}
