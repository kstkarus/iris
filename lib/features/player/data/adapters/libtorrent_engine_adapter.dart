import 'dart:async';
import 'dart:developer' as developer;

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/features/player/data/adapters/stream_startup_monitor.dart';
import 'package:iris/features/player/data/exceptions/startup_buffer_unavailable_exception.dart';
import 'package:iris/features/player/data/exceptions/torrent_metadata_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
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

  Stream<PlaybackLaunchProgressModel> waitForStreamReady(
    int streamId, {
    required bool Function() isCancelled,
  });

  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId);

  Future<void> disposeTorrent(int torrentId);
}

abstract interface class LibtorrentEngineClient {
  int addMagnet(String magnet);

  bool disposeTorrent(int torrentId);

  List<FileInfo> getFiles(int torrentId);

  StreamInfo startStream(
    int torrentId, {
    int fileIndex = -1,
    int maxCacheBytes = 0,
  });

  StreamInfo? getStreamInfo(int streamId);

  Map<int, TorrentInfo> get torrents;

  Stream<Map<int, TorrentInfo>> get torrentUpdates;

  void configureSession(BtConfig config);
}

class LibtorrentEngineAdapterImpl implements LibtorrentEngineAdapter {
  LibtorrentEngineAdapterImpl({
    Duration metadataWaitTimeout = const Duration(seconds: 90),
    LibtorrentEngineClient? engineClient,
    Future<void> Function()? runtimeInitializer,
  }) : _metadataWaitTimeout = metadataWaitTimeout,
       _engineClient = engineClient ?? const _DefaultLibtorrentEngineClient(),
       _runtimeInitializer =
           runtimeInitializer ?? PlaybackRuntimeInitializer.ensureInitialized;

  final Duration _metadataWaitTimeout;
  final LibtorrentEngineClient _engineClient;
  final Future<void> Function() _runtimeInitializer;
  bool _sessionConfigured = false;

  @override
  int addMagnet(String magnet) {
    final torrentId = _engineClient.addMagnet(magnet);
    developer.log(
      'Magnet added to libtorrent. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    return torrentId;
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
    if (_sessionConfigured) {
      return;
    }

    _engineClient.configureSession(
      const BtConfig(
        cacheSize: _torrentSessionCacheBytes,
        readerReadAhead: _torrentSessionReadAheadPercent,
        preloadCache: _torrentSessionPreloadPercent,
        responsiveMode: true,
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
  Stream<PlaybackLaunchProgressModel> waitForStreamReady(
    int streamId, {
    required bool Function() isCancelled,
  }) async* {
    developer.log(
      'Waiting for torrent stream readiness. streamId=$streamId',
      name: 'iris.player.libtorrent',
    );
    final monitor = StreamStartupMonitor();
    final stopwatch = Stopwatch()..start();
    PlaybackLaunchProgressModel? lastReportedProgress;

    while (true) {
      if (isCancelled()) {
        developer.log(
          'Stopping torrent stream readiness wait because launch was cancelled. streamId=$streamId',
          name: 'iris.player.libtorrent',
        );
        return;
      }

      final current = _engineClient.getStreamInfo(streamId);
      if (current != null) {
        developer.log(
          'Observed stream status. streamId=$streamId state=${current.streamState} bufferPct=${current.bufferPct} bufferSeconds=${current.bufferSeconds} activePeers=${current.activePeers} downloadRate=${current.downloadRate} readHead=${current.readHead}',
          name: 'iris.player.libtorrent',
        );
        if (current.streamState == StreamState.error) {
          throw StateError(
            'Stream entered error state while waiting for readiness.',
          );
        }

        final decision = monitor.evaluate(
          bufferProgress: current.bufferPct,
          bufferSeconds: current.bufferSeconds,
          downloadRateBytesPerSecond: current.downloadRate,
          activePeers: current.activePeers,
          isReady: current.isReady,
          elapsed: stopwatch.elapsed,
        );

        if (decision.progress != lastReportedProgress) {
          lastReportedProgress = decision.progress;
          yield decision.progress;
        }

        if (decision.stageChanged) {
          developer.log(
            'Torrent stream wait stage changed. streamId=$streamId from=${decision.previousStage} to=${decision.progress.stage} bufferPct=${decision.progress.bufferProgress} downloadRate=${decision.progress.downloadRateBytesPerSecond}',
            name: 'iris.player.libtorrent',
          );
        }

        if (decision.type == StreamStartupDecisionType.ready) {
          developer.log(
            'Torrent stream became ready for local probing. streamId=$streamId isReady=${current.isReady} bufferPct=${current.bufferPct} bufferSeconds=${current.bufferSeconds}',
            name: 'iris.player.libtorrent',
          );
          return;
        }

        if (decision.type == StreamStartupDecisionType.failed) {
          developer.log(
            'Torrent stream could not gather enough startup buffer. streamId=$streamId bufferPct=${decision.progress.bufferProgress} downloadRate=${decision.progress.downloadRateBytesPerSecond}',
            name: 'iris.player.libtorrent',
          );
          throw StartupBufferUnavailableException(progress: decision.progress);
        }
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }
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
      await _engineClient.torrentUpdates
          .firstWhere((torrents) {
            final torrent = torrents[torrentId];
            return torrent != null && torrent.hasMetadata;
          })
          .timeout(_metadataWaitTimeout);
    } on TimeoutException {
      developer.log(
        'Timed out while waiting for torrent metadata. torrentId=$torrentId timeout=${_metadataWaitTimeout.inSeconds}s',
        name: 'iris.player.libtorrent',
      );
      throw TorrentMetadataUnavailableException(
        torrentId: torrentId,
        timeout: _metadataWaitTimeout,
      );
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
  int addMagnet(String magnet) => _engine.addMagnet(magnet);

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
