import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/shared/utils/playback_runtime_initializer.dart';

class DownloadEngineFile {
  const DownloadEngineFile({
    required this.index,
    required this.name,
    required this.relativePath,
    required this.size,
    required this.isStreamable,
  });

  final int index;
  final String name;
  final String relativePath;
  final int size;
  final bool isStreamable;
}

class DownloadEngineTorrent {
  const DownloadEngineTorrent({
    required this.id,
    required this.progress,
    required this.downloadRateBytesPerSecond,
    required this.downloadedBytes,
    required this.wantedBytes,
    required this.peers,
    required this.hasMetadata,
    required this.isPaused,
    required this.isFinished,
    required this.hasError,
    required this.errorMessage,
  });

  final int id;
  final double progress;
  final int downloadRateBytesPerSecond;
  final int downloadedBytes;
  final int wantedBytes;
  final int peers;
  final bool hasMetadata;
  final bool isPaused;
  final bool isFinished;
  final bool hasError;
  final String errorMessage;
}

abstract interface class LibtorrentDownloadEngineAdapter {
  Future<void> initialize();

  int addMagnet({
    required String magnet,
    required String savePath,
    required bool metadataOnly,
  });

  Future<void> waitForMetadata(
    int torrentId, {
    Duration timeout = const Duration(seconds: 90),
  });

  List<DownloadEngineFile> getFiles(int torrentId);

  void setFilePriorities(int torrentId, List<int> priorities);

  void pause(int torrentId);

  void resume(int torrentId);

  void remove(int torrentId, {required bool deleteFiles});

  DownloadEngineTorrent? getTorrent(int torrentId);

  Stream<Map<int, DownloadEngineTorrent>> get torrentUpdates;
}

class LibtorrentDownloadEngineAdapterImpl
    implements LibtorrentDownloadEngineAdapter {
  const LibtorrentDownloadEngineAdapterImpl();

  LibtorrentFlutter get _engine => LibtorrentFlutter.instance;

  @override
  Future<void> initialize() => PlaybackRuntimeInitializer.ensureInitialized();

  @override
  int addMagnet({
    required String magnet,
    required String savePath,
    required bool metadataOnly,
  }) {
    return _engine.addMagnet(magnet, savePath, metadataOnly);
  }

  @override
  DownloadEngineTorrent? getTorrent(int torrentId) {
    final torrent = _engine.torrents[torrentId];
    return torrent == null ? null : _mapTorrent(torrent);
  }

  @override
  List<DownloadEngineFile> getFiles(int torrentId) {
    return _engine
        .getFiles(torrentId)
        .map(
          (file) => DownloadEngineFile(
            index: file.index,
            name: file.name,
            relativePath: file.path,
            size: file.size,
            isStreamable: file.isStreamable,
          ),
        )
        .toList(growable: false);
  }

  @override
  void pause(int torrentId) => _engine.pauseTorrent(torrentId);

  @override
  void remove(int torrentId, {required bool deleteFiles}) {
    _engine.removeTorrent(torrentId, deleteFiles: deleteFiles);
  }

  @override
  void resume(int torrentId) => _engine.resumeTorrent(torrentId);

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {
    _engine.setFilePriorities(torrentId, priorities);
  }

  @override
  Stream<Map<int, DownloadEngineTorrent>> get torrentUpdates {
    return _engine.torrentUpdates.map(
      (torrents) =>
          torrents.map((id, torrent) => MapEntry(id, _mapTorrent(torrent))),
    );
  }

  @override
  Future<void> waitForMetadata(
    int torrentId, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final current = _engine.torrents[torrentId];
    if (current?.hasMetadata == true) {
      return;
    }

    await _engine.torrentUpdates
        .firstWhere((torrents) => torrents[torrentId]?.hasMetadata == true)
        .timeout(timeout);
  }
}

DownloadEngineTorrent _mapTorrent(TorrentInfo torrent) {
  return DownloadEngineTorrent(
    id: torrent.id,
    progress: torrent.progress,
    downloadRateBytesPerSecond: torrent.downloadRate,
    downloadedBytes: torrent.totalDone,
    wantedBytes: torrent.totalWanted,
    peers: torrent.numPeers,
    hasMetadata: torrent.hasMetadata,
    isPaused: torrent.isPaused,
    // Not `state.isDone`: the native bridge passes libtorrent 2.x states
    // (1-based) through 0-based constants, so `downloading` decodes as
    // `finished`. The native finished flag is computed from progress.
    isFinished: torrent.isFinished,
    hasError: torrent.state == TorrentState.error,
    errorMessage: torrent.errorMsg,
  );
}
