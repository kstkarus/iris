import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../../../helpers/fake_secure_storage.dart';

void main() {
  late MockUserRateRepository rates;

  setUp(() => rates = MockUserRateRepository());

  EpisodeMarkCubit cubit({String? userId = '42'}) {
    final cubit = EpisodeMarkCubit(
      markEpisode: MarkEpisodeWatched(rates),
      userId: userId,
      sessionGeneration: () => 0,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  AnimePlayerSource online({String animeId = '1', num? number = 5}) =>
      AnimePlayerSource(
        animeId: animeId,
        animeTitle: 'Anime',
        sourceTitle: 'AniLibria',
        sessionId: 's',
        fileIndex: 0,
        fileName: 'Episode',
        files: [
          PlayerVideoFile(
            index: 0,
            name: 'Episode',
            size: 0,
            extension: '',
            episodeNumber: number,
          ),
        ],
      );

  AnimePlayerSource torrent({String fileName = '[Group] Anime - 05.mkv'}) =>
      AnimePlayerSource(
        animeId: '1',
        animeTitle: 'Anime',
        sourceTitle: 'Release',
        sessionId: 's',
        fileIndex: 0,
        fileName: fileName,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('an online episode is marked at once, and undone', () async {
    final marks = cubit();

    marks.watched(online());
    expect(marks.state, isA<EpisodeMarkSaving>());
    await settle();

    expect(marks.state, isA<EpisodeMarkDone>());
    expect(
      rates.rates['1'],
      const UserRate(id: '1', status: UserRateStatus.watching, episodes: 5),
    );

    await marks.undo();
    expect(rates.rates['1'], isNull);
    expect(marks.state, isA<EpisodeMarkUndone>());
    marks.confirm();
    await settle();
    expect(rates.rates['1']?.episodes, 5);
    expect(marks.state, isA<EpisodeMarkDone>());
  });

  test('a refused undo keeps the mark and can be tried again', () async {
    final failing = _RefusingRemoval();
    rates = failing;
    final marks = cubit();
    marks.watched(online());
    await settle();

    await marks.undo();
    expect(
      marks.state,
      isA<EpisodeMarkFailed>().having(
        (s) => s.action,
        'action',
        EpisodeMarkAction.undo,
      ),
    );
    expect(rates.rates['1']?.episodes, 5);

    failing.refuse = false;
    await marks.undo();
    expect(rates.rates['1'], isNull);
    expect(marks.state, isA<EpisodeMarkUndone>());
  });

  test('a torrent episode is offered first', () async {
    final marks = cubit();

    marks.watched(torrent());
    expect(
      marks.state,
      isA<EpisodeMarkOffered>().having((s) => s.episode, 'episode', 5),
    );
    expect(rates.rates, isEmpty);

    marks.confirm();
    await settle();
    expect(rates.rates['1']?.episodes, 5);
  });

  test(
    'an ended session cannot offer a torrent mark before the account listener',
    () {
      var generation = 0;
      final marks = EpisodeMarkCubit(
        markEpisode: MarkEpisodeWatched(rates),
        userId: '42',
        sessionGeneration: () => generation,
      );
      addTearDown(marks.close);
      generation++;
      marks.watched(torrent());
      expect(marks.state, isA<EpisodeMarkIdle>());
      expect(rates.rates, isEmpty);
    },
  );

  test('an offer put away marks nothing', () async {
    final marks = cubit()..watched(torrent());

    marks.dismiss();
    await settle();

    expect(marks.state, isA<EpisodeMarkIdle>());
    expect(rates.rates, isEmpty);
  });

  test('an episode the list already counts says nothing', () async {
    await rates.save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 7,
      score: 0,
    );
    final marks = cubit()..watched(online());
    await settle();

    expect(marks.state, isA<EpisodeMarkIdle>());
    expect(rates.rates['1']?.episodes, 7);
  });

  test('an already-counted torrent leaves no empty mark to select', () async {
    await rates.save(userId: '42', animeId: '1', rateId: null, episodes: 5);
    final marks = cubit()..watched(torrent());
    marks.confirm();
    await settle();

    expect(marks.state, isA<EpisodeMarkIdle>());
    expect(marks.pendingCount, 0);
    expect(marks.pendingIndex, -1);

    marks.watched(online(number: 6));
    await settle();
    expect(marks.pendingCount, 1);
    expect(marks.pendingIndex, 0);
    marks.showNextPending();
    expect(
      marks.state,
      isA<EpisodeMarkDone>().having((state) => state.episode, 'episode', 6),
    );
    await marks.undo();
    expect(rates.rates['1']?.episodes, 5);
    expect(marks.state, isA<EpisodeMarkUndone>());
  });

  test('an already-counted torrent returns to a retained mark', () async {
    await rates.save(userId: '42', animeId: '1', rateId: null, episodes: 5);
    final marks = cubit()..watched(online(number: 6));
    await settle();
    await marks.undo();

    marks.watched(torrent());
    marks.confirm();
    await settle();

    expect(marks.pendingCount, 1);
    expect(marks.pendingIndex, 0);
    expect(
      marks.state,
      isA<EpisodeMarkUndone>().having((state) => state.episode, 'episode', 6),
    );
    marks.confirm();
    await settle();
    expect(marks.state, isA<EpisodeMarkDone>());
    expect(rates.rates['1']?.episodes, 6);
  });

  test('without an account, an anime or a number nothing happens', () {
    final signedOut = cubit(userId: null)..watched(online());
    final savedTorrent = cubit()..watched(online(animeId: ''));
    final special = cubit()..watched(online(number: 12.5));
    final unnumbered = cubit()..watched(torrent(fileName: 'movie.mkv'));

    for (final marks in [signedOut, savedTorrent, special, unnumbered]) {
      expect(marks.state, isA<EpisodeMarkIdle>());
    }
  });

  test('a failed mark can be tried again', () async {
    final failing = _FailingOnceRepository();
    final marks = EpisodeMarkCubit(
      markEpisode: MarkEpisodeWatched(failing),
      userId: '42',
      sessionGeneration: () => 0,
    );
    addTearDown(marks.close);

    marks.watched(online());
    await settle();
    expect(marks.state, isA<EpisodeMarkFailed>());

    marks.confirm();
    await settle();
    expect(marks.state, isA<EpisodeMarkDone>());
  });

  test('a failed restore remains unmarked and can be retried', () async {
    final failing = _ToggleSaveRepository();
    rates = failing;
    final marks = cubit()..watched(online());
    await settle();
    await marks.undo();
    failing.fail = true;
    marks.confirm();
    await settle();
    expect(
      marks.state,
      isA<EpisodeMarkFailed>().having(
        (state) => state.action,
        'action',
        EpisodeMarkAction.restore,
      ),
    );
    expect(rates.rates['1'], isNull);
    failing.fail = false;
    marks.confirm();
    await settle();
    expect(marks.state, isA<EpisodeMarkDone>());
    expect(rates.rates['1']?.episodes, 5);
  });

  test('undo does not overwrite progress changed elsewhere', () async {
    final marks = cubit()..watched(online());
    await settle();
    await rates.save(
      userId: '42',
      animeId: '1',
      rateId: rates.rates['1']!.id,
      episodes: 6,
    );
    await marks.undo();
    expect(marks.state, isA<EpisodeMarkConflict>());
    expect(rates.rates['1']?.episodes, 6);
  });

  test(
    'a pending earlier failure survives the next episode finishing',
    () async {
      final marker = _ConcurrentMarker();
      final marks = EpisodeMarkCubit(
        markEpisode: marker,
        userId: '42',
        sessionGeneration: () => 0,
      );
      addTearDown(marks.close);
      marks.watched(online(number: 5));
      marks.watched(online(number: 6));
      marker.replies[5]!.completeError(StateError('first failed'));
      await settle();
      expect(
        marks.state,
        isA<EpisodeMarkFailed>().having((s) => s.episode, 'episode', 5),
      );
      marker.replies[6]!.complete(const EpisodeAlreadyMarked());
      await settle();
      expect(
        marks.state,
        isA<EpisodeMarkFailed>().having((s) => s.episode, 'episode', 5),
      );
    },
  );

  test(
    'multiple failures can be selected and a retry keeps its undo',
    () async {
      final marker = _ConcurrentMarker();
      final marks = EpisodeMarkCubit(
        markEpisode: marker,
        userId: '42',
        sessionGeneration: () => 0,
      );
      addTearDown(marks.close);
      marks.watched(online(number: 5));
      marks.watched(online(number: 6));
      marker.replies[5]!.completeError(StateError('first failed'));
      marker.replies[6]!.completeError(StateError('second failed'));
      await settle();
      expect(marks.pendingCount, 2);
      marks.showNextPending();
      expect(
        marks.state,
        isA<EpisodeMarkFailed>().having((s) => s.episode, 'episode', 6),
      );
      marks.confirm();
      marker.replies[6]!.complete(
        const EpisodeMarked(
          previous: null,
          saved: UserRate(
            id: '1',
            status: UserRateStatus.watching,
            episodes: 6,
          ),
        ),
      );
      await settle();
      expect(
        marks.state,
        isA<EpisodeMarkFailed>().having((s) => s.episode, 'episode', 5),
      );
      expect(marks.pendingCount, 2);
      marks.showNextPending();
      expect(
        marks.state,
        isA<EpisodeMarkDone>().having((s) => s.episode, 'episode', 6),
      );
    },
  );

  test(
    'an undone mark stays reachable after a later episode is marked',
    () async {
      final marks = cubit()..watched(online(number: 5));
      await settle();
      await marks.undo();
      expect(marks.state, isA<EpisodeMarkUndone>());
      marks.watched(online(number: 6));
      await settle();
      expect(
        marks.state,
        isA<EpisodeMarkDone>().having((s) => s.episode, 'episode', 6),
      );
      expect(marks.pendingCount, 2);
      marks.showNextPending();
      expect(
        marks.state,
        isA<EpisodeMarkUndone>().having((s) => s.episode, 'episode', 5),
      );
    },
  );

  test('a mark finishing after account expiration changes nothing', () async {
    final gated = _GatedFetchRepository();
    final marks = EpisodeMarkCubit(
      markEpisode: MarkEpisodeWatched(gated),
      userId: '42',
      sessionGeneration: () => 0,
    );
    addTearDown(marks.close);

    marks.watched(online());
    expect(marks.state, isA<EpisodeMarkSaving>());
    marks.accountChanged(null);
    gated.fetchGate.complete();
    await settle();

    expect(marks.state, isA<EpisodeMarkIdle>());
    expect(gated.rates, isEmpty);
  });

  test(
    'an update from a previous sign-in of the same account is ignored',
    () async {
      var generation = 0;
      final marker = _SyncMarker();
      final marks = EpisodeMarkCubit(
        markEpisode: marker,
        userId: '42',
        sessionGeneration: () => generation,
      );
      addTearDown(marks.close);
      addTearDown(marker.updates.close);
      marks.watched(online());
      await settle();
      generation++;
      marks.accountChanged('42');
      marks.watched(online());
      await settle();
      marker.updates.add(
        const EpisodeMarkUpdate(
          userId: '42',
          animeId: '1',
          episode: 5,
          generation: 0,
          result: EpisodeMarked(
            previous: null,
            saved: UserRate(
              id: '1',
              status: UserRateStatus.watching,
              episodes: 5,
            ),
          ),
        ),
      );
      await settle();
      expect(marks.state, isA<EpisodeMarkQueued>());
      marker.updates.add(
        const EpisodeMarkUpdate(
          userId: '42',
          animeId: '1',
          episode: 5,
          generation: 1,
          result: EpisodeMarked(
            previous: null,
            saved: UserRate(
              id: '1',
              status: UserRateStatus.watching,
              episodes: 5,
            ),
          ),
        ),
      );
      await settle();
      expect(marks.state, isA<EpisodeMarkDone>());
    },
  );

  test('a pending undo failure after account expiration is ignored', () async {
    final gated = _GatedRemoveRepository();
    final marks = EpisodeMarkCubit(
      markEpisode: MarkEpisodeWatched(gated),
      userId: '42',
      sessionGeneration: () => 0,
    );
    addTearDown(marks.close);

    marks.watched(online());
    await settle();
    gated.fail = true;
    final undo = marks.undo();
    await settle();
    marks.accountChanged(null);
    gated.removeGate.complete();
    await undo;

    expect(marks.state, isA<EpisodeMarkIdle>());
  });

  test(
    'a cleared session blocks a mark before account listener delivery',
    () async {
      final storage = _DelayedDeleteStorage();
      final session = ShikimoriSessionStore(storage);
      await session.write(
        ShikimoriTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.utc(2026, 10, 15),
        ),
      );
      final gated = _GatedFetchRepository();
      final marks = EpisodeMarkCubit(
        markEpisode: MarkEpisodeWatched(gated),
        userId: '42',
        sessionGeneration: () => session.generation,
      );
      addTearDown(marks.close);

      marks.watched(online());
      final expiring = session.expire();
      await storage.deleteStarted.future;
      gated.fetchGate.complete();
      await pumpEventQueue();

      expect(gated.saveCalls, 0);
      storage.allowDelete.complete();
      await expiring;
    },
  );
}

class _ConcurrentMarker implements EpisodeMarker {
  final replies = <int, Completer<EpisodeMarkResult>>{};

  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) => (replies[episode] = Completer<EpisodeMarkResult>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SyncMarker implements EpisodeMarker, EpisodeMarkSync {
  final updates = StreamController<EpisodeMarkUpdate>.broadcast();

  @override
  Stream<EpisodeMarkUpdate> get markUpdates => updates.stream;

  @override
  List<EpisodeMarkUpdate> pendingMarks({
    required String userId,
    required String animeId,
  }) => [];

  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) async => const EpisodeMarkDeferred();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ToggleSaveRepository extends MockUserRateRepository {
  bool fail = false;

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    required int episodes,
    int? score,
    int? rewatches,
  }) {
    if (fail) throw StateError('save failed');
    return super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
      rewatches: rewatches,
    );
  }
}

class _GatedFetchRepository extends MockUserRateRepository {
  final fetchGate = Completer<void>();
  var saveCalls = 0;

  @override
  Future<UserRate?> fetch(String animeId) async {
    await fetchGate.future;
    return super.fetch(animeId);
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    required int episodes,
    int? score,
    int? rewatches,
  }) {
    saveCalls++;
    return super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
      rewatches: rewatches,
    );
  }
}

class _DelayedDeleteStorage extends FakeSecureStorage {
  final deleteStarted = Completer<void>();
  final allowDelete = Completer<void>();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #delete) {
      if (!deleteStarted.isCompleted) deleteStarted.complete();
      final key = invocation.namedArguments[#key] as String?;
      return allowDelete.future.then((_) {
        if (key != null) values.remove(key);
      });
    }
    return super.noSuchMethod(invocation);
  }
}

class _GatedRemoveRepository extends MockUserRateRepository {
  final removeGate = Completer<void>();
  bool fail = false;

  @override
  Future<void> remove({required String animeId, required String rateId}) async {
    await removeGate.future;
    if (fail) throw Exception('offline');
    return super.remove(animeId: animeId, rateId: rateId);
  }
}

class _FailingOnceRepository extends MockUserRateRepository {
  var _failed = false;

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    required int episodes,
    int? score,
    int? rewatches,
  }) {
    if (!_failed) {
      _failed = true;
      throw Exception('offline');
    }
    return super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
      rewatches: rewatches,
    );
  }
}

class _RefusingRemoval extends MockUserRateRepository {
  bool refuse = true;

  @override
  Future<void> remove({required String animeId, required String rateId}) {
    if (refuse) throw Exception('offline');
    return super.remove(animeId: animeId, rateId: rateId);
  }
}
