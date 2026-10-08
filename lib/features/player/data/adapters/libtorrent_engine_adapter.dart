import 'dart:async';
import 'dart:developer' as developer;

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/features/player/data/exceptions/torrent_metadata_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/torrent_metadata_wait.dart';
import 'package:iris/shared/utils/playback_runtime_initializer.dart';

const torrentStreamCacheBytes = 256 * 1024 * 1024;
const _torrentSessionCacheBytes = 256 * 1024 * 1024;
const _torrentSessionReadAheadPercent = 95;
const _torrentSessionPreloadPercent = 60;

abstract interface class LibtorrentEngineAdapter {
  Future<void> initialize();

  int addMagnet(String magnet);

  Future<void> waitForMetadata(int torrentId);

  List<TorrentFileDescriptor> getFiles(int torrentId);

  PlaybackStreamDescriptor startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = torrentStreamCacheBytes,
  });

  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId);

  void stopStream(int streamId);

  Future<void> disposeTorrent(int torrentId);
}

abstract interface class LibtorrentEngineClient {
  int addMagnet(String magnet, {String? savePath});

  bool disposeTorrent(int torrentId);

  List<FileInfo> getFiles(int torrentId);

  StreamInfo startStream(
    int torrentId, {
    int fileIndex = -1,
    int maxCacheBytes = 0,
  });

  StreamInfo? getStreamInfo(int streamId);

  void stopStream(int streamId);

  Map<int, TorrentInfo> get torrents;

  Stream<Map<int, TorrentInfo>> get torrentUpdates;

  void configureSession(BtConfig config);
}

class LibtorrentEngineAdapterImpl implements LibtorrentEngineAdapter {
  LibtorrentEngineAdapterImpl({
    Duration metadataWaitTimeout = const Duration(seconds: 90),
    LibtorrentEngineClient? engineClient,
    Future<void> Function()? runtimeInitializer,
    StreamCacheStorage? streamCache,
  }) : _metadataWaitTimeout = metadataWaitTimeout,
       _streamCache = streamCache,
       _engineClient = engineClient ?? const _DefaultLibtorrentEngineClient(),
       _runtimeInitializer =
           runtimeInitializer ?? PlaybackRuntimeInitializer.ensureInitialized;

  final Duration _metadataWaitTimeout;
  final LibtorrentEngineClient _engineClient;
  final Future<void> Function() _runtimeInitializer;

  /// Where streamed pieces are written; the engine default (system temp)
  /// when null.
  final StreamCacheStorage? _streamCache;
  bool _sessionConfigured = false;

  @override
  int addMagnet(String magnet) {
    final torrentId = _engineClient.addMagnet(
      magnet,
      savePath: _streamCache?.directory.path,
    );
    developer.log(
      'Magnet added to libtorrent. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    return torrentId;
  }

  @override
  void stopStream(int streamId) {
    developer.log(
      'Stopping torrent stream. streamId=$streamId',
      name: 'iris.player.libtorrent',
    );
    _engineClient.stopStream(streamId);
  }

  @override
  Future<void> disposeTorrent(int torrentId) {
    developer.log(
      'Disposing torrent session. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    _engineClient.disposeTorrent(torrentId);
    return Future<void>.value();
  }

  @override
  List<TorrentFileDescriptor> getFiles(int torrentId) {
    final files = _engineClient.getFiles(torrentId).map((file) {
      return TorrentFileDescriptor(
        index: file.index,
        name: file.name,
        size: file.size,
        isStreamable: file.isStreamable,
      );
    }).toList();
    developer.log(
      'Loaded torrent files. torrentId=$torrentId count=${files.length}',
      name: 'iris.player.libtorrent',
    );
    return files;
  }

  @override
  Future<void> initialize() async {
    developer.log(
      'Ensuring libtorrent runtime is initialized.',
      name: 'iris.player.libtorrent',
    );
    await _runtimeInitializer();
    await _streamCache?.prepare();
    if (_sessionConfigured) {
      return;
    }

    _engineClient.configureSession(
      const BtConfig(
        cacheSize: _torrentSessionCacheBytes,
        readerReadAhead: _torrentSessionReadAheadPercent,
        preloadCache: _torrentSessionPreloadPercent,
        responsiveMode: true,
        // With IPv6 disabled the native bridge rebinds the session to
        // 0.0.0.0:6881, overriding torrentListenInterfaces.
        enableIpv6: true,
      ),
    );
    _sessionConfigured = true;
  }

  @override
  PlaybackStreamDescriptor startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = torrentStreamCacheBytes,
  }) {
    final stream = _engineClient.startStream(
      torrentId,
      fileIndex: fileIndex,
      maxCacheBytes: maxCacheBytes,
    );
    developer.log(
      'Started local torrent stream. torrentId=$torrentId fileIndex=$fileIndex streamId=${stream.id} url=${stream.url} state=${stream.streamState} bufferPct=${stream.bufferPct} bufferSeconds=${stream.bufferSeconds}',
      name: 'iris.player.libtorrent',
    );
    return PlaybackStreamDescriptor(streamId: stream.id, url: stream.url);
  }

  @override
  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId) {
    final current = _engineClient.getStreamInfo(streamId);
    if (current == null) {
      return null;
    }

    return PlaybackRuntimeStatsModel(
      downloadRateBytesPerSecond: current.downloadRate,
      appMemoryBytes: null,
      activePeers: current.activePeers,
      bufferSeconds: current.bufferSeconds,
      bufferPieces: current.bufferPieces,
      readaheadWindow: current.readaheadWindow,
    );
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    developer.log(
      'Waiting for torrent metadata. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    final current = _engineClient.torrents[torrentId];
    if (current != null && current.hasMetadata) {
      developer.log(
        'Torrent metadata already available. torrentId=$torrentId',
        name: 'iris.player.libtorrent',
      );
      return;
    }

    try {
      await waitForTorrentMetadata(
        torrentId: torrentId,
        current: _engineClient.torrents,
        updates: _engineClient.torrentUpdates,
        timeout: _metadataWaitTimeout,
      );
    } on TimeoutException {
      developer.log(
        'Timed out while waiting for torrent metadata. torrentId=$torrentId timeout=${_metadataWaitTimeout.inSeconds}s',
        name: 'iris.player.libtorrent',
      );
      throw TorrentMetadataUnavailableException(
        torrentId: torrentId,
        timeout: _metadataWaitTimeout,
      );
    } on TorrentMetadataFailedException catch (error) {
      developer.log(
        'Torrent failed before its metadata arrived. torrentId=$torrentId',
        name: 'iris.player.libtorrent',
        error: error,
      );
      rethrow;
    }
    developer.log(
      'Torrent metadata received. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
  }
}

class _DefaultLibtorrentEngineClient implements LibtorrentEngineClient {
  const _DefaultLibtorrentEngineClient();

  LibtorrentFlutter get _engine => LibtorrentFlutter.instance;

  @override
  int addMagnet(String magnet, {String? savePath}) =>
      _engine.addMagnet(magnet, savePath);

  @override
  void configureSession(BtConfig config) {
    _engine.configureSession(config);
  }

  @override
  bool disposeTorrent(int torrentId) => _engine.disposeTorrent(torrentId);

  @override
  List<FileInfo> getFiles(int torrentId) => _engine.getFiles(torrentId);

  @override
  StreamInfo? getStreamInfo(int streamId) => _engine.getStreamInfo(streamId);

  @override
  void stopStream(int streamId) => _engine.stopStream(streamId);

  @override
  Stream<Map<int, TorrentInfo>> get torrentUpdates => _engine.torrentUpdates;

  @override
  Map<int, TorrentInfo> get torrents => _engine.torrents;

  @override
  StreamInfo startStream(
    int torrentId, {
    int fileIndex = -1,
    int maxCacheBytes = 0,
  }) {
    return _engine.startStream(
      torrentId,
      fileIndex: fileIndex,
      maxCacheBytes: maxCacheBytes,
    );
  }
}
