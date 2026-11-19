import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
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
/// files, and each prepared player gets its own session id backed by the
/// release's [OnlineSourceLink].
///
/// Stream links expire, so each episode's link is asked for right before it
/// plays; mpv does the buffering. The quality is the one chosen for
/// watching, the best when none is.
class OnlinePlayerRepository implements PlayerRepository {
  OnlinePlayerRepository({
    required OnlineSourcesRepository repository,
    OnlineQualityPreferences? qualityPreferences,
    AnimejoyAccountRepository? animejoyAccount,
  }) : _repository = repository,
       _qualityPreferences = qualityPreferences,
       _animejoyAccount = animejoyAccount;

  static const _sessionPrefix = 'online-session:';

  /// Whether [sessionId] belongs to an online playback session (either a
  /// per-player session id or a raw [OnlineSourceLink]).
  static bool isOnlineSessionId(String sessionId) =>
      sessionId.startsWith(_sessionPrefix) ||
      OnlineSourceLink.tryParse(sessionId) != null;

  final OnlineSourcesRepository _repository;
  final OnlineQualityPreferences? _qualityPreferences;
  final AnimejoyAccountRepository? _animejoyAccount;

  int _nextSessionId = 0;

  /// Active online sessions, each isolated by its own id so a closing player
  /// never clears a replacement player for the same release.
  final _sessions = <String, _OnlineSession>{};

  /// Stops waiting when [cancelled] completes; a slow server's late answer
  /// is dropped.
  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    final sessionId = '$_sessionPrefix${++_nextSessionId}';
    final session = _OnlineSession(link: magnet);
    _sessions[sessionId] = session;
    final OnlineRelease release;
    try {
      release = await _release(session, cancelled: cancelled);
    } on Object {
      if (identical(_sessions[sessionId], session)) {
        _sessions.remove(sessionId);
      }
      rethrow;
    }
    return PreparedPlayerSource(
      sessionId: sessionId,
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
    final cancelled = Completer<void>();
    late final StreamController<PlayerLaunchUpdate> controller;
    controller = StreamController<PlayerLaunchUpdate>(
      onListen: () async {
        final session = _sessionFor(sessionId);
        if (session == null) {
          controller.add(const PlayerLaunchFailureUpdate());
          await controller.close();
          return;
        }
        final update = await _launch(
          session: session,
          sessionId: sessionId,
          fileIndex: fileIndex,
          cancelled: cancelled.future,
        );
        if (cancelled.isCompleted ||
            !identical(_sessions[sessionId], session)) {
          return;
        }
        if (update is PlayerLaunchReadyUpdate) {
          session.playingFileIndex = fileIndex;
        }
        controller.add(update);
        await controller.close();
      },
      onCancel: cancelled.complete,
    );
    return controller.stream;
  }

  Future<PlayerLaunchUpdate> _launch({
    required _OnlineSession session,
    required String sessionId,
    required int fileIndex,
    required Future<void> cancelled,
  }) async {
    try {
      final resolved = await _resolve(
        session,
        sessionId,
        fileIndex,
        cancelled: cancelled,
      );
      return PlayerLaunchReadyUpdate(resolved);
    } on PreparationCancelledException {
      return const PlayerLaunchFailureUpdate();
    } on Object catch (error) {
      developer.log(
        'Online episode $fileIndex of $sessionId did not start: $error',
        name: 'iris.player.online',
      );
      return const PlayerLaunchFailureUpdate();
    }
  }

  /// Asks for the playing episode's link again: the one mpv holds may have
  /// expired while it played or waited on pause, or another quality was
  /// chosen.
  @override
  Future<PlayerSession?> renewSession(PlayerSession session) async {
    final state = _sessions[session.sessionId];
    final fileIndex = state?.playingFileIndex;
    if (state == null || fileIndex == null) return null;
    final renewed = await _resolve(state, session.sessionId, fileIndex);
    if (!identical(_sessions[session.sessionId], state) ||
        state.playingFileIndex != fileIndex) {
      return null;
    }
    developer.log(
      'Renewed the link of online episode $fileIndex of ${session.sessionId}.',
      name: 'iris.player.online',
    );
    return renewed;
  }

  /// A fresh link to episode [fileIndex] of [session].
  Future<PlayerSession> _resolve(
    _OnlineSession session,
    String sessionId,
    int fileIndex, {
    Future<void>? cancelled,
  }) async {
    final release = await _release(session, cancelled: cancelled);
    final position = onlineEpisodeFileIndices(release).indexOf(fileIndex);
    if (position < 0) {
      throw RangeError.value(fileIndex, 'fileIndex', 'No such episode');
    }
    final streams = await unlessCancelled(
      _repository.resolveStreams(
        provider: release.provider,
        episodeId: release.episodes[position].id,
      ),
      cancelled,
    );
    final stream = chooseOnlineStream(
      streams,
      maxQuality: _qualityPreferences?.watching,
    );
    if (stream == null) throw StateError('The episode has no streams.');
    return PlayerSession(
      sessionId: sessionId,
      streamUrl: stream.url,
      subtitleUrl: stream.subtitleUrl,
      qualities: onlineQualities(streams),
      quality: stream.quality,
    );
  }

  /// No peers or pieces to count: mpv's own buffering is the whole story.
  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {
    _sessions[sessionId]?.playingFileIndex = null;
  }

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    final removed = _sessions.remove(sessionId);
    if (removed != null) {
      removed.releaseLoad = null;
      removed.release = null;
      removed.playingFileIndex = null;
    }
  }

  _OnlineSession? _sessionFor(String sessionId) {
    final existing = _sessions[sessionId];
    if (existing != null) return existing;
    if (OnlineSourceLink.tryParse(sessionId) == null) return null;
    return _sessions[sessionId] = _OnlineSession(link: sessionId);
  }

  Future<OnlineRelease> _release(
    _OnlineSession session, {
    Future<void>? cancelled,
  }) async {
    final known = session.release;
    if (known != null) {
      if (known.generation == _sessionGeneration(known.release.provider)) {
        return known.release;
      }
      session.release = null;
    }
    final parsed = OnlineSourceLink.tryParse(session.link);
    final provider = parsed == null
        ? null
        : OnlineProvider.named(parsed.provider);
    if (parsed == null || provider == null) {
      throw ArgumentError.value(session.link, 'link');
    }
    final load = Object();
    final generation = _sessionGeneration(provider);
    session.releaseLoad = load;
    try {
      final release = await unlessCancelled(
        _repository.fetchRelease(provider: provider, id: parsed.releaseId),
        cancelled,
      );
      if (generation != _sessionGeneration(provider)) {
        throw const AnimejoySessionChanged();
      }
      if (identical(session.releaseLoad, load)) {
        session.release = (release: release, generation: generation);
      }
      return release;
    } finally {
      if (identical(session.releaseLoad, load)) session.releaseLoad = null;
    }
  }

  int? _sessionGeneration(OnlineProvider provider) =>
      provider == OnlineProvider.animejoy ? _animejoyAccount?.generation : null;
}

class _OnlineSession {
  _OnlineSession({required this.link});

  final String link;
  ({OnlineRelease release, int? generation})? release;
  Object? releaseLoad;
  int? playingFileIndex;
}
