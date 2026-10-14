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
    expect(marks.state, isA<EpisodeMarkIdle>());
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
      isA<EpisodeMarkDone>().having((s) => s.undoFailed, 'undoFailed', true),
    );
    expect(rates.rates['1']?.episodes, 5);

    failing.refuse = false;
    await marks.undo();
    expect(rates.rates['1'], isNull);
    expect(marks.state, isA<EpisodeMarkIdle>());
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
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) {
    saveCalls++;
    return super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
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
    required UserRateStatus status,
    required int episodes,
    required int score,
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
