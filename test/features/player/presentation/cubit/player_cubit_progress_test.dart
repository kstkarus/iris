import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/bootstrap/windows_update_restart.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

import '../../../../helpers/fake_player_engine.dart';
import '../../../../helpers/fake_player_repository.dart';

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

  PlayerCubit createCubit({
    AnimePlayerSource source = _source,
    FakePlayerEngine? playerEngine,
  }) {
    return PlayerCubit(
      source: source,
      repository: repository,
      engine: playerEngine ?? engine,
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

  test('the ending counts the file watched', () async {
    final cubit = createCubit();
    addTearDown(cubit.close);
    await cubit.loadPlayback();
    expect((cubit.state as PlayerReady).watched, isFalse);

    engine.emit(const PlayerEngineWatched());
    await Future<void>.delayed(Duration.zero);

    expect((cubit.state as PlayerReady).watched, isTrue);
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

  test(
    'restart preparation waits for every active or closing player',
    () async {
      final oldEngine = FakePlayerEngine()..closeGate = Completer<void>();
      final oldPlayer = createCubit(playerEngine: oldEngine);
      final latestEngine = FakePlayerEngine();
      final latestPlayer = createCubit(playerEngine: latestEngine);
      addTearDown(() async {
        if (!(oldEngine.closeGate?.isCompleted ?? true)) {
          oldEngine.closeGate!.complete();
        }
        if (!(progress.saveGate?.isCompleted ?? true)) {
          progress.saveGate!.complete();
        }
        await oldPlayer.close();
        await latestPlayer.close();
      });
      progress.saveGate = Completer<void>();
      oldPlayer.reportProgress(
        const Duration(minutes: 10),
        const Duration(minutes: 24),
        flush: true,
      );
      await Future<void>.delayed(Duration.zero);
      final closingOldPlayer = oldPlayer.close();
      await Future<void>.delayed(Duration.zero);

      latestPlayer.reportProgress(
        const Duration(minutes: 12),
        const Duration(minutes: 24),
        flush: true,
      );
      await Future<void>.delayed(Duration.zero);

      final downloadWrite = Completer<void>();
      final downloadWriteStarted = Completer<void>();
      var watchProgressFlushed = false;
      final restart = WindowsUpdateRestart(
        flushWatchProgress: () async => watchProgressFlushed = true,
        flushDownloads: () async {
          downloadWriteStarted.complete();
          await downloadWrite.future;
        },
      );
      restart
        ..trackPlayer(oldPlayer)
        ..trackPlayer(latestPlayer);

      var finished = false;
      final preparing = restart.prepareForRestart().then(
        (_) => finished = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(downloadWriteStarted.isCompleted, isFalse);

      oldEngine.closeGate!.complete();
      progress.saveGate!.complete();
      await downloadWriteStarted.future.timeout(const Duration(seconds: 5));
      expect(finished, isFalse);
      expect(
        progress.saves.map((item) => item.position.inMinutes),
        containsAll([10, 12]),
      );
      expect(watchProgressFlushed, isTrue);

      downloadWrite.complete();
      await preparing;
      await closingOldPlayer;
      expect(oldPlayer.isClosed, isTrue);
      expect(latestPlayer.isClosed, isFalse);
      await latestPlayer.close();
    },
  );

  test('restart storage failure propagates and can be retried', () async {
    final cubit = createCubit();
    progress.failSaves = true;
    cubit.reportProgress(
      const Duration(minutes: 10),
      const Duration(minutes: 24),
      flush: true,
    );
    await Future<void>.delayed(Duration.zero);

    var watchProgressFlushed = false;
    var downloadsFlushed = false;
    final restart = WindowsUpdateRestart(
      flushWatchProgress: () async => watchProgressFlushed = true,
      flushDownloads: () async => downloadsFlushed = true,
    )..trackPlayer(cubit);

    await expectLater(restart.prepareForRestart(), throwsA(isA<StateError>()));
    expect(watchProgressFlushed, isFalse);
    expect(downloadsFlushed, isFalse);
    expect(cubit.isClosed, isFalse);

    progress.failSaves = false;
    await restart.prepareForRestart();
    expect(watchProgressFlushed, isTrue);
    expect(downloadsFlushed, isTrue);
    expect(cubit.isClosed, isFalse);
    await cubit.close();
  });

  test(
    'restart does not recreate history removed after a successful close',
    () async {
      final cubit = createCubit();
      final restart = WindowsUpdateRestart(
        flushWatchProgress: progress.flushForRestart,
        flushDownloads: () async {},
      )..trackPlayer(cubit);
      cubit.reportProgress(
        const Duration(minutes: 10),
        const Duration(minutes: 24),
        flush: true,
      );
      await cubit.close();

      await progress.removeTorrent(torrentKey: torrentKeyFromMagnet(_magnet));
      await restart.prepareForRestart();

      expect(
        await progress.find(
          torrentKey: torrentKeyFromMagnet(_magnet),
          fileIndex: 0,
        ),
        isNull,
      );
      expect(progress.persisted, isEmpty);
    },
  );

  test(
    'restart preserves a removal from cache after a failed close write',
    () async {
      final cubit = createCubit();
      final restart = WindowsUpdateRestart(
        flushWatchProgress: progress.flushForRestart,
        flushDownloads: () async {},
      )..trackPlayer(cubit);
      progress.failSaves = true;
      cubit.reportProgress(
        const Duration(minutes: 10),
        const Duration(minutes: 24),
        flush: true,
      );
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      expect(cubit.isClosed, isTrue);
      expect(progress.saves, isEmpty);
      progress.failSaves = false;
      await progress.removeTorrent(torrentKey: torrentKeyFromMagnet(_magnet));
      expect(progress.persisted, isEmpty);

      await restart.prepareForRestart();

      expect(progress.persisted, isEmpty);
      expect(progress.findInPersisted(torrentKeyFromMagnet(_magnet)), isNull);
    },
  );

  test('restart retries a failed closed player save from the cache', () async {
    final cubit = createCubit();
    final restart = WindowsUpdateRestart(
      flushWatchProgress: progress.flushForRestart,
      flushDownloads: () async {},
    )..trackPlayer(cubit);
    progress.failSaves = true;
    cubit.reportProgress(
      const Duration(minutes: 10),
      const Duration(minutes: 24),
      flush: true,
    );
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    expect(cubit.isClosed, isTrue);
    expect(progress.persisted, isEmpty);

    progress.failSaves = false;
    await restart.prepareForRestart();

    expect(progress.persisted.single.position, const Duration(minutes: 10));
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

    expect((cubit.state as PlayerReady).showResumeNotice, isFalse);
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

  test(
    'holds the fixed skip until the lookup answers, even with nothing',
    () async {
      final answer = Completer<List<PlayerSkipSegment>>();
      skipTimes.answer = answer.future;
      final cubit = createCubit();
      addTearDown(cubit.close);
      await cubit.loadPlayback();
      expect(engine.skipTimesExpected, isTrue);

      engine.emit(
        const PlayerEngineProgress(Duration(seconds: 5), Duration(minutes: 24)),
      );
      await Future<void>.delayed(Duration.zero);
      answer.complete(const []);
      await Future<void>.delayed(Duration.zero);

      expect(engine.lastSkipTimes, isEmpty);
      expect(engine.skipTimesExpected, isFalse);
    },
  );

  test('does not hold the fixed skip when nothing can be looked up', () async {
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

    expect(engine.skipTimesExpected, isFalse);
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
    expect((cubit.state as PlayerReady).showResumeNotice, isFalse);
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

class _RecordingPlayerRepository extends StubPlayerRepository {
  final List<String> events = [];

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
  final Map<String, WatchProgress> _persisted = {};
  final List<WatchProgress> saves = [];
  Completer<void>? saveGate;
  bool failSaves = false;
  bool _cacheLoaded = false;

  List<WatchProgress> get persisted => List.unmodifiable(_persisted.values);

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async {
    _cacheLoaded = true;
    return _items[watchProgressId(
      torrentKey: torrentKey,
      fileIndex: fileIndex,
    )];
  }

  /// Stores a record without counting it as a save by the cubit.
  void seed(WatchProgress progress) {
    _cacheLoaded = true;
    _items[progress.id] = progress;
    _persisted[progress.id] = progress;
  }

  @override
  Future<void> save(WatchProgress progress) async {
    _cacheLoaded = true;
    _items[progress.id] = progress;
    await saveGate?.future;
    if (failSaves) throw StateError('watch progress storage failed');
    saves.add(progress);
    _persisted[progress.id] = progress;
  }

  @override
  Future<void> removeTorrent({required String torrentKey}) async {
    _cacheLoaded = true;
    _items.removeWhere((_, item) => item.torrentKey == torrentKey);
    await saveGate?.future;
    if (failSaves) throw StateError('watch progress storage failed');
    _persisted
      ..clear()
      ..addAll(_items);
  }

  Future<void> flushForRestart() async {
    if (!_cacheLoaded) return;
    await saveGate?.future;
    if (failSaves) throw StateError('watch progress storage failed');
    _persisted
      ..clear()
      ..addAll(_items);
  }

  WatchProgress? findInPersisted(String torrentKey) {
    for (final item in _persisted.values) {
      if (item.torrentKey == torrentKey) return item;
    }
    return null;
  }

  @override
  Stream<List<WatchProgress>> watchAll() async* {
    _cacheLoaded = true;
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
