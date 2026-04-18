import 'dart:developer' as developer;

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/features/player/data/adapters/stream_startup_monitor.dart';
import 'package:iris/features/player/data/exceptions/startup_buffer_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/shared/utils/playback_runtime_initializer.dart';

abstract interface class LibtorrentEngineAdapter {
  Future<void> initialize();

  int addMagnet(String magnet);

  Future<void> waitForMetadata(int torrentId);

  List<TorrentFileDescriptor> getFiles(int torrentId);

  PlaybackStreamDescriptor startStream(int torrentId, {required int fileIndex});

  Stream<PlaybackLaunchProgressModel> waitForStreamReady(int streamId);

  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId);

  Future<void> disposeTorrent(int torrentId);
}

class LibtorrentEngineAdapterImpl implements LibtorrentEngineAdapter {
  LibtorrentEngineAdapterImpl();

  LibtorrentFlutter get _engine => LibtorrentFlutter.instance;

  @override
  int addMagnet(String magnet) {
    final torrentId = _engine.addMagnet(magnet);
    developer.log(
      'Magnet added to libtorrent. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    return torrentId;
  }

  @override
  Future<void> disposeTorrent(int torrentId) async {
    developer.log(
      'Disposing torrent session. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    _engine.disposeTorrent(torrentId);
  }

  @override
  List<TorrentFileDescriptor> getFiles(int torrentId) {
    final files = _engine.getFiles(torrentId).map((file) {
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
    await PlaybackRuntimeInitializer.ensureInitialized();
  }

  @override
  PlaybackStreamDescriptor startStream(
    int torrentId, {
    required int fileIndex,
  }) {
    final stream = _engine.startStream(torrentId, fileIndex: fileIndex);
    developer.log(
      'Started local torrent stream. torrentId=$torrentId fileIndex=$fileIndex streamId=${stream.id} url=${stream.url} state=${stream.streamState} bufferPct=${stream.bufferPct}',
      name: 'iris.player.libtorrent',
    );
    return PlaybackStreamDescriptor(streamId: stream.id, url: stream.url);
  }

  @override
  Stream<PlaybackLaunchProgressModel> waitForStreamReady(int streamId) async* {
    developer.log(
      'Waiting for torrent stream readiness. streamId=$streamId',
      name: 'iris.player.libtorrent',
    );
    final monitor = StreamStartupMonitor();
    final stopwatch = Stopwatch()..start();
    PlaybackLaunchProgressModel? lastReportedProgress;

    while (true) {
      final current = _engine.getStreamInfo(streamId);
      if (current != null) {
        developer.log(
          'Observed stream status. streamId=$streamId state=${current.streamState} bufferPct=${current.bufferPct} activePeers=${current.activePeers} downloadRate=${current.downloadRate} readHead=${current.readHead}',
          name: 'iris.player.libtorrent',
        );
        if (current.streamState == StreamState.error) {
          throw StateError(
            'Stream entered error state while waiting for readiness.',
          );
        }

        final decision = monitor.evaluate(
          bufferProgress: current.bufferPct,
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
            'Torrent stream became ready for local probing. streamId=$streamId isReady=${current.isReady} bufferPct=${current.bufferPct}',
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
    final current = _engine.getStreamInfo(streamId);
    if (current == null) {
      return null;
    }

    return PlaybackRuntimeStatsModel(
      downloadRateBytesPerSecond: current.downloadRate,
      appMemoryBytes: null,
      activePeers: current.activePeers,
    );
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    developer.log(
      'Waiting for torrent metadata. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
    final current = _engine.torrents[torrentId];
    if (current != null && current.hasMetadata) {
      developer.log(
        'Torrent metadata already available. torrentId=$torrentId',
        name: 'iris.player.libtorrent',
      );
      return;
    }

    await _engine.torrentUpdates.firstWhere((torrents) {
      final torrent = torrents[torrentId];
      return torrent != null && torrent.hasMetadata;
    });
    developer.log(
      'Torrent metadata received. torrentId=$torrentId',
      name: 'iris.player.libtorrent',
    );
  }
}
