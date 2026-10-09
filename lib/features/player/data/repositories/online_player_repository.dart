import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_source_link.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

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

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    final release = await _release(magnet);
    return PreparedPlayerSource(
      sessionId: magnet,
      files: [
        for (final (index, episode) in release.episodes.indexed)
          PlayerVideoFile(
            index: index,
            name: _episodeName(episode.number, episode.title),
            size: 0,
            extension: '',
            episodeNumber: episode.number % 1 == 0
                ? episode.number.toInt()
                : null,
            title: episode.title,
            duration: episode.duration,
          ),
      ],
    );
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    final PlayerSession session;
    try {
      final release = await _release(sessionId);
      if (fileIndex < 0 || fileIndex >= release.episodes.length) {
        throw RangeError.index(fileIndex, release.episodes, 'fileIndex');
      }
      final streams = await _repository.resolveStreams(
        provider: release.provider,
        episodeId: release.episodes[fileIndex].id,
      );
      if (streams.isEmpty) throw StateError('The episode has no streams.');
      final stream = streams.first;
      session = PlayerSession(
        sessionId: sessionId,
        streamUrl: stream.url,
        httpHeaders: stream.httpHeaders,
      );
    } on Object catch (error) {
      developer.log(
        'Online episode $fileIndex of $sessionId did not start: $error',
        name: 'iris.player.online',
      );
      yield const PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart);
      return;
    }
    yield PlayerLaunchReadyUpdate(session);
  }

  /// No peers or pieces to count: mpv's own buffering is the whole story.
  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    _releases.remove(sessionId);
  }

  Future<OnlineRelease> _release(String link) async {
    final known = _releases[link];
    if (known != null) return known;
    final parsed = OnlineSourceLink.tryParse(link);
    if (parsed == null) throw ArgumentError.value(link, 'link');
    final release = await _repository.fetchRelease(
      provider: parsed.provider,
      id: parsed.releaseId,
    );
    return _releases[link] = release;
  }
}

/// What watch history keeps as the "file name": `04 «Пристанище душ»`.
String _episodeName(num number, String title) {
  final digits = number % 1 == 0
      ? number.toInt().toString().padLeft(2, '0')
      : '$number';
  return title.isEmpty ? digits : '$digits $title';
}
