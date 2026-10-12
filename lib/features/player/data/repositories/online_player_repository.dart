import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';

/// Plays an online release as a torrent is played: its episodes are the
/// files, and the release's [OnlineSourceLink] is both the "magnet" and the
/// session id.
///
/// Stream links expire, so each episode's link is asked for right before it
/// plays; mpv does the buffering.
class OnlinePlayerRepository implements PlayerRepository {
  OnlinePlayerRepository({required OnlineSourcesRepository repository})
    : _repository = repository;

  final OnlineSourcesRepository _repository;

  /// The releases of the sessions in use: "next episode" needs no request.
  final _releases = <String, OnlineRelease>{};

  /// The episode each session plays now, to renew its link.
  final _playing = <String, int>{};

  /// Stops waiting when [cancelled] completes; a slow server's late answer
  /// is dropped.
  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    final release = await unlessCancelled(_release(magnet), cancelled);
    return PreparedPlayerSource(
      sessionId: magnet,
      files: [
        for (final (index, episode) in onlineEpisodeFileIndices(
          release,
        ).indexed)
          PlayerVideoFile(
            index: episode,
            name: onlineEpisodeFileName(
              release.episodes[index].number,
              release.episodes[index].title,
            ),
            size: 0,
            extension: '',
            episodeNumber: release.episodes[index].number,
            title: release.episodes[index].title,
            duration: release.episodes[index].duration,
          ),
      ],
    );
  }

  /// One update, ready or failed. Cancelling does not wait for the server:
  /// switching episodes or leaving the player stays immediate, and an
  /// answer that comes after is dropped.
  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    var cancelled = false;
    late final StreamController<PlayerLaunchUpdate> controller;
    controller = StreamController<PlayerLaunchUpdate>(
      onListen: () async {
        final update = await _launch(
          sessionId: sessionId,
          fileIndex: fileIndex,
        );
        if (cancelled) return;
        controller.add(update);
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }

  Future<PlayerLaunchUpdate> _launch({
    required String sessionId,
    required int fileIndex,
  }) async {
    try {
      final session = await _resolve(sessionId, fileIndex);
      _playing[sessionId] = fileIndex;
      return PlayerLaunchReadyUpdate(session);
    } on Object catch (error) {
      developer.log(
        'Online episode $fileIndex of $sessionId did not start: $error',
        name: 'iris.player.online',
      );
      return const PlayerLaunchFailureUpdate();
    }
  }

  /// Asks for the playing episode's link again: the one mpv holds may have
  /// expired while it played or waited on pause.
  @override
  Future<PlayerSession?> renewSession(PlayerSession session) async {
    final fileIndex = _playing[session.sessionId];
    if (fileIndex == null) return null;
    final renewed = await _resolve(session.sessionId, fileIndex);
    developer.log(
      'Renewed the link of online episode $fileIndex of ${session.sessionId}.',
      name: 'iris.player.online',
    );
    return renewed;
  }

  /// A fresh link to episode [fileIndex] of the release [sessionId] names.
  Future<PlayerSession> _resolve(String sessionId, int fileIndex) async {
    final release = await _release(sessionId);
    final position = onlineEpisodeFileIndices(release).indexOf(fileIndex);
    if (position < 0) {
      throw RangeError.value(fileIndex, 'fileIndex', 'No such episode');
    }
    final streams = await _repository.resolveStreams(
      provider: release.provider,
      episodeId: release.episodes[position].id,
    );
    if (streams.isEmpty) throw StateError('The episode has no streams.');
    return PlayerSession(sessionId: sessionId, streamUrl: streams.first.url);
  }

  /// No peers or pieces to count: mpv's own buffering is the whole story.
  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {
    _playing.remove(sessionId);
  }

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    _releases.remove(sessionId);
    _playing.remove(sessionId);
  }

  Future<OnlineRelease> _release(String link) async {
    final known = _releases[link];
    if (known != null) return known;
    final parsed = OnlineSourceLink.tryParse(link);
    final provider = parsed == null
        ? null
        : OnlineProvider.named(parsed.provider);
    if (parsed == null || provider == null) {
      throw ArgumentError.value(link, 'link');
    }
    final release = await _repository.fetchRelease(
      provider: provider,
      id: parsed.releaseId,
    );
    return _releases[link] = release;
  }
}
