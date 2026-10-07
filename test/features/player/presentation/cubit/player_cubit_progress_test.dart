import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

import '../../../../helpers/fake_player_engine.dart';

const _hash = '065c4691de84f964e143103b3bd0de17be5bfd0a';
const _magnet = 'magnet:?xt=urn:btih:$_hash';
const _files = [
  PlayerVideoFile(index: 0, name: 'ep-01.mkv', size: 1, extension: 'mkv'),
  PlayerVideoFile(index: 3, name: 'ep-02.mkv', size: 1, extension: 'mkv'),
];
const _source = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist',
  sourceTitle: '[Group] FMA',
  sessionId: '42',
  fileIndex: 0,
  fileName: 'ep-01.mkv',
  magnet: _magnet,
  files: _files,
);

void main() {
  late _RecordingPlayerRepository repository;
  late _MemoryWatchProgressRepository progress;
  late _MemoryTrackPreferencesRepository tracks;
  late DateTime now;
  late FakePlayerEngine engine;
  late _RecordingSkipTimesRepository skipTimes;

  setUp(() {
    engine = FakePlayerEngine();
    skipTimes = _RecordingSkipTimesRepository();
    repository = _RecordingPlayerRepository();
    progress = _MemoryWatchProgressRepository();
    tracks = _MemoryTrackPreferencesRepository();
    now = DateTime.utc(2026, 10, 4, 12);
  });

  PlayerCubit createCubit({AnimePlayerSource source = _source}) {
    return PlayerCubit(
      source: source,
      repository: repository,
      engine: engine,
      progressRepository: progress,
      trackPreferencesRepository: tracks,
      skipTimesRepository: skipTimes,
      now: () => now,
      engineReleaseTimeout: const Duration(milliseconds: 50),
    );
  }

  WatchProgress saved({int fileIndex = 0, int seconds = 600}) {
    return WatchProgress(
      torrentKey: torrentKeyFromMagnet(_magnet),
      fileIndex: fileIndex,
      fileName: 'ep-01.mkv',
      magnet: _magnet,
      sourceTitle: '[Group] FMA',
      position: Duration(seconds: seconds),
      duration: const Duration(minutes: 24),
      updatedAt: DateTime.utc(2026, 10, 3),
      animeId: '5114',
      animeTitle: 'Fullmetal Alchemist',
    );
  }

  test('resumes from the saved position and offers to start over', () async {
    progress.seed(saved());
    final cubit = createCubit();
    addTearDown(cubit.close);

    await cubit.loadPlayback();

    final state = cubit.state as PlayerReady;
    expect(state.startPosition, const Duration(seconds: 600));
    expect(state.showResumeNotice, isTrue);

    cubit.restartFromBeginning();
    await Future<void>.delayed(Duration.zero);

    expect(engine.calls.last, 'seek ${Duration.zero}');
    final restarted = cubit.state as PlayerReady;
    expect(restarted.startsOver, isTrue);
    // Chosen while the file starts: the notice stays so it can be undone.
    expect(restarted.showResumeNotice, isTrue);

    cubit.resumeSavedPosition();
    await Future<void>.delayed(Duration.zero);

    expect(engine.calls.last, 'seek ${const Duration(seconds: 600)}');
    expect((cubit.state as PlayerReady).startsOver, isFalse);
    expect((cubit.state as PlayerReady).showResumeNotice, isTrue);
  });

  test('marks the file started on its first frame', () async {
    progress.seed(saved());
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    expect((cubit.state as PlayerReady).started, isFalse);

    engine.emit(const PlayerEnginePlaybackStarted());
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as PlayerReady).started, isTrue);
  });

  test('starting over once the file plays closes the notice', () async {
    progress.seed(saved());
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    engine.emit(const PlayerEnginePlaybackStarted());
    await Future<void>.delayed(Duration.zero);

    cubit.restartFromBeginning();
    await Future<void>.delayed(Duration.zero);

    expect(engine.calls.last, 'seek ${Duration.zero}');
    expect((cubit.state as PlayerReady).showResumeNotice, isFalse);
  });

  test('starts from zero when the file was already watched', () async {
    progress.seed(saved(seconds: 1400));
    final cubit = createCubit();
    addTearDown(cubit.close);

    await cubit.loadPlayback();

    expect((cubit.state as PlayerReady).startPosition, isNull);
  });

  test('saves progress periodically, on flush and on close', () async {
    final cubit = createCubit();
    await cubit.loadPlayback();

    cubit.reportProgress(
      const Duration(seconds: 30),
      const Duration(minutes: 24),
    );
    await Future<void>.delayed(Duration.zero);
    expect(progress.saves, isEmpty, reason: 'first report starts the clock');

    now = now.add(const Duration(seconds: 11));
    cubit.reportProgress(
      const Duration(seconds: 41),
      const Duration(minutes: 24),
    );
    await Future<void>.delayed(Duration.zero);
    expect(progress.saves.single.position, const Duration(seconds: 41));
    expect(progress.saves.single.animeId, '5114');

    cubit.reportProgress(
      const Duration(seconds: 45),
      const Duration(minutes: 24),
      flush: true,
    );
    cubit.reportProgress(
      const Duration(seconds: 47),
      const Duration(minutes: 24),
    );
    await cubit.close();

    expect(progress.saves.map((item) => item.position.inSeconds), [41, 45, 47]);
    expect(repository.events.last, 'dispose 42');
  });

  test('does not record a file opened only for a moment', () async {
    final cubit = createCubit();
    await cubit.loadPlayback();
    cubit.reportProgress(
      const Duration(seconds: 3),
      const Duration(minutes: 24),
      flush: true,
    );
    await cubit.close();

    expect(progress.saves, isEmpty);
  });

  test('keeps the anime link when reopened from saved torrents', () async {
    progress.seed(saved());
    final cubit = createCubit(
      source: const AnimePlayerSource(
        animeId: '',
        animeTitle: 'My torrent',
        sourceTitle: 'My torrent',
        sessionId: '42',
        fileIndex: 0,
        fileName: 'ep-01.mkv',
        magnet: _magnet,
      ),
    );
    await cubit.loadPlayback();
    cubit.reportProgress(
      const Duration(seconds: 700),
      const Duration(minutes: 24),
      flush: true,
    );
    await cubit.close();

    expect(progress.saves.last.animeId, '5114');
    expect(progress.saves.last.animeTitle, 'Fullmetal Alchemist');
  });

  test('marks the end of the file as watched', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    cubit.reportProgress(
      const Duration(minutes: 23),
      const Duration(minutes: 24),
    );

    cubit.markCompleted();
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as PlayerReady).completed, isTrue);
    expect(progress.saves.last.isFinished, isTrue);
  });

  test('plays the next file in the same player once it released the '
      'previous stream', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    cubit.reportProgress(
      const Duration(minutes: 23),
      const Duration(minutes: 24),
    );
    engine.stopGate = Completer<void>();

    final switching = cubit.playFile(cubit.source.nextFile!);
    await Future<void>.delayed(Duration.zero);
    expect(
      cubit.state,
      isA<PlayerPreparing>().having(
        (state) => state.keepsPlayer,
        'keepsPlayer',
        isTrue,
      ),
      reason: 'the player stays on screen, also in full screen',
    );
    expect(repository.events, isNot(contains('stop 42')));

    engine.stopGate!.complete();
    await switching;

    expect(repository.events, ['start 42:0', 'stop 42', 'start 42:3']);
    expect(engine.calls, [
      'open http://127.0.0.1/stream/0',
      'stop',
      'stopped',
      'open http://127.0.0.1/stream/3',
    ]);
    expect(cubit.source.fileIndex, 3);
    expect(cubit.source.nextFile, isNull);
    expect(cubit.state, isA<PlayerReady>());
    expect(progress.saves.single.fileIndex, 0);
  });

  test('looks up skip times once the episode length is known', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();

    engine.emit(
      const PlayerEngineProgress(Duration(seconds: 5), Duration(minutes: 24)),
    );
    engine.emit(
      const PlayerEngineProgress(Duration(seconds: 6), Duration(minutes: 24)),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(skipTimes.requests, ['5114 1 ${const Duration(minutes: 24)}']);
    expect(engine.lastSkipTimes, [_opening]);
  });

  test('uses the anime from the history and drops a late answer for the '
      'previous file', () async {
    progress.seed(saved(seconds: 5));
    final answer = Completer<List<PlayerSkipSegment>>();
    skipTimes.answer = answer.future;
    final cubit = createCubit(
      source: const AnimePlayerSource(
        animeId: '',
        animeTitle: '',
        sourceTitle: '[Group] FMA',
        sessionId: '42',
        fileIndex: 0,
        fileName: 'ep-01.mkv',
        magnet: _magnet,
        files: _files,
      ),
    );
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    engine.emit(
      const PlayerEngineProgress(Duration(seconds: 5), Duration(minutes: 24)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(skipTimes.requests.single, startsWith('5114 1 '));

    await cubit.playFile(cubit.source.nextFile!);
    answer.complete([_opening]);
    await Future<void>.delayed(Duration.zero);

    expect(engine.lastSkipTimes, isNull);
  });

  test('records progress, completion and track choices reported by the '
      'player', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();

    engine.emit(
      const PlayerEngineProgress(
        Duration(minutes: 23),
        Duration(minutes: 24),
        flush: true,
      ),
    );
    engine.emit(const PlayerEngineCompleted());
    engine.emit(
      const PlayerEngineTracksChosen(
        PlayerTrackPreferences(audio: PreferredTrack(language: 'jpn')),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(progress.saves.last.isFinished, isTrue);
    expect((cubit.state as PlayerReady).completed, isTrue);
    expect(
      cubit.trackPreferences,
      const PlayerTrackPreferences(audio: PreferredTrack(language: 'jpn')),
    );
  });

  test(
    'opens the player at the resume position with remembered tracks',
    () async {
      progress.seed(saved());
      tracks.seed(const PlayerTrackPreferences(subtitle: PreferredTrack.off()));
      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.loadPlayback();

      expect(engine.lastStartPosition, const Duration(seconds: 600));
      expect(
        engine.lastPreferredTracks,
        const PlayerTrackPreferences(subtitle: PreferredTrack.off()),
      );
    },
  );

  test('remembers track choices per release', () async {
    final cubit = createCubit();
    await cubit.loadPlayback();

    cubit.saveTrackPreferences(
      const PlayerTrackPreferences(audio: PreferredTrack(language: 'jpn')),
    );
    cubit.saveTrackPreferences(
      const PlayerTrackPreferences(subtitle: PreferredTrack.off()),
    );
    await cubit.close();

    final reopened = createCubit();
    addTearDown(reopened.close);
    await reopened.loadPlayback();

    expect(
      reopened.trackPreferences,
      const PlayerTrackPreferences(
        audio: PreferredTrack(language: 'jpn'),
        subtitle: PreferredTrack.off(),
      ),
    );
  });
}

const _opening = PlayerSkipSegment(
  kind: PlayerSkipKind.opening,
  start: Duration(seconds: 30),
  end: Duration(minutes: 2),
);

class _RecordingSkipTimesRepository implements PlayerSkipTimesRepository {
  final requests = <String>[];
  Future<List<PlayerSkipSegment>>? answer;

  @override
  Future<List<PlayerSkipSegment>> find({
    required String animeId,
    required int episode,
    required Duration duration,
  }) {
    requests.add('$animeId $episode $duration');
    return answer ?? Future.value(const [_opening]);
  }
}

class _RecordingPlayerRepository implements PlayerRepository {
  final List<String> events = [];

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    events.add('start $sessionId:$fileIndex');
    yield PlayerLaunchReadyUpdate(
      PlayerSession(
        sessionId: sessionId,
        streamUrl: 'http://127.0.0.1/stream/$fileIndex',
      ),
    );
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {
    events.add('stop $sessionId');
  }

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    events.add('dispose $sessionId');
  }
}

class _MemoryWatchProgressRepository implements WatchProgressRepository {
  final Map<String, WatchProgress> _items = {};
  final List<WatchProgress> saves = [];

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async {
    return _items[watchProgressId(
      torrentKey: torrentKey,
      fileIndex: fileIndex,
    )];
  }

  /// Stores a record without counting it as a save by the cubit.
  void seed(WatchProgress progress) => _items[progress.id] = progress;

  @override
  Future<void> save(WatchProgress progress) async {
    saves.add(progress);
    _items[progress.id] = progress;
  }

  @override
  Future<void> removeTorrent({required String torrentKey}) async {
    _items.removeWhere((_, item) => item.torrentKey == torrentKey);
  }

  @override
  Stream<List<WatchProgress>> watchAll() async* {
    yield _items.values.toList();
  }
}

class _MemoryTrackPreferencesRepository
    implements PlayerTrackPreferencesRepository {
  final Map<String, PlayerTrackPreferences> _items = {};

  void seed(PlayerTrackPreferences preferences) {
    _items[torrentKeyFromMagnet(_magnet)] = preferences;
  }

  @override
  Future<PlayerTrackPreferences?> load({required String torrentKey}) async {
    return _items[torrentKey];
  }

  @override
  Future<void> save({
    required String torrentKey,
    required PlayerTrackPreferences preferences,
  }) async {
    _items[torrentKey] = preferences;
  }
}
