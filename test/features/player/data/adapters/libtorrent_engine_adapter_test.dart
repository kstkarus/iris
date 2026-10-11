import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';

void main() {
  test(
    'configures libtorrent session only once across repeated initialize calls',
    () async {
      final engine = _FakeEngineClient();
      final adapter = LibtorrentEngineAdapterImpl(
        engineClient: engine,
        runtimeInitializer: () async {},
      );

      await adapter.initialize();
      await adapter.initialize();

      expect(engine.configureSessionCallCount, 1);
      expect(engine.lastConfig, isNotNull);
      expect(engine.lastConfig!.cacheSize, 256 * 1024 * 1024);
      expect(engine.lastConfig!.readerReadAhead, 95);
      expect(engine.lastConfig!.preloadCache, 60);
      expect(engine.lastConfig!.responsiveMode, isTrue);
    },
  );

  test('adds magnets into the prepared stream cache folder', () async {
    final root = await Directory.systemTemp.createTemp('iris_engine_test_');
    addTearDown(() => root.delete(recursive: true));
    final cacheDirectory = Directory('${root.path}/stream');
    final leftover = File('${cacheDirectory.path}/old.mkv');
    await leftover.create(recursive: true);
    final engine = _FakeEngineClient();
    final adapter = LibtorrentEngineAdapterImpl(
      engineClient: engine,
      runtimeInitializer: () async {},
      streamCache: StreamCacheStorage(directory: cacheDirectory),
    );

    await adapter.initialize();
    adapter.addMagnet('magnet:?xt=urn:btih:abc');

    expect(await leftover.exists(), isFalse);
    expect(engine.lastSavePath, cacheDirectory.path);
  });

  test('starts stream with explicit cache size override', () {
    final engine = _FakeEngineClient();
    final adapter = LibtorrentEngineAdapterImpl(engineClient: engine);

    adapter.startStream(
      42,
      fileIndex: 7,
      maxCacheBytes: torrentStreamCacheBytes,
    );

    expect(engine.startStreamTorrentId, 42);
    expect(engine.startStreamFileIndex, 7);
    expect(engine.startStreamMaxCacheBytes, 256 * 1024 * 1024);
  });

  test('maps runtime stats with buffer metrics from stream info', () {
    final engine = _FakeEngineClient(
      streamInfo: const StreamInfo(
        id: 77,
        torrentId: 42,
        fileIndex: 7,
        url: 'http://127.0.0.1:8080/stream/7',
        fileSize: 4096,
        readHead: 1024,
        streamState: StreamState.buffering,
        bufferSeconds: 12,
        bufferPieces: 20,
        readaheadWindow: 30,
        activePeers: 18,
        downloadRate: 3145728,
      ),
    );
    final adapter = LibtorrentEngineAdapterImpl(engineClient: engine);

    final stats = adapter.getPlaybackRuntimeStats(77);

    expect(
      stats,
      const PlaybackRuntimeStatsModel(
        downloadRateBytesPerSecond: 3145728,
        appMemoryBytes: null,
        activePeers: 18,
        bufferSeconds: 12,
        bufferPieces: 20,
        readaheadWindow: 30,
      ),
    );
  });
}

class _FakeEngineClient implements LibtorrentEngineClient {
  @override
  void stopStream(int streamId) {}

  BtConfig? lastConfig;
  String? lastSavePath;
  int configureSessionCallCount = 0;
  int? startStreamTorrentId;
  int? startStreamFileIndex;
  int? startStreamMaxCacheBytes;
  final StreamInfo? streamInfo;

  _FakeEngineClient({this.streamInfo});

  @override
  int addMagnet(String magnet, {String? savePath}) {
    lastSavePath = savePath;
    return 42;
  }

  @override
  void configureSession(BtConfig config) {
    configureSessionCallCount++;
    lastConfig = config;
  }

  @override
  StreamInfo startStream(
    int torrentId, {
    int fileIndex = -1,
    int maxCacheBytes = 0,
  }) {
    startStreamTorrentId = torrentId;
    startStreamFileIndex = fileIndex;
    startStreamMaxCacheBytes = maxCacheBytes;
    return StreamInfo(
      id: 77,
      torrentId: torrentId,
      fileIndex: fileIndex,
      url: 'http://127.0.0.1:8080/stream/$fileIndex',
      fileSize: 4096,
      readHead: 0,
      streamState: StreamState.buffering,
      bufferSeconds: 0,
      bufferPieces: 0,
      readaheadWindow: 0,
      activePeers: 0,
      downloadRate: 0,
    );
  }

  @override
  bool disposeTorrent(int torrentId) => true;

  @override
  List<FileInfo> getFiles(int torrentId) => const [];

  @override
  StreamInfo? getStreamInfo(int streamId) => streamInfo;

  @override
  Map<int, TorrentInfo> get torrents => const {};

  @override
  Stream<Map<int, TorrentInfo>> get torrentUpdates => const Stream.empty();
}
