import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

void main() {
  late MockUserRateRepository repository;
  late MarkEpisodeWatched mark;

  setUp(() {
    repository = MockUserRateRepository();
    mark = MarkEpisodeWatched(repository);
  });

  Future<UserRate> keep(UserRateStatus status, int episodes, {int score = 0}) =>
      repository.save(
        userId: '42',
        animeId: '1',
        rateId: null,
        status: status,
        episodes: episodes,
        score: score,
      );

  Future<EpisodeMarkResult> watch(int episode) =>
      mark(userId: '42', animeId: '1', episode: episode);

  test('an anime not in the list is added as watching', () async {
    final result = await watch(1);

    expect(result, isA<EpisodeMarked>());
    expect(
      repository.rates['1'],
      const UserRate(id: '1', status: UserRateStatus.watching, episodes: 1),
    );
  });

  test('the count only grows', () async {
    await keep(UserRateStatus.watching, 5);

    expect(await watch(3), isA<EpisodeAlreadyMarked>());
    expect(await watch(5), isA<EpisodeAlreadyMarked>());
    expect(repository.rates['1']?.episodes, 5);
  });

  test('planned, on hold and dropped become watching', () async {
    for (final status in [
      UserRateStatus.planned,
      UserRateStatus.onHold,
      UserRateStatus.dropped,
    ]) {
      await keep(status, 0);
      await watch(1);
      expect(repository.rates['1']?.status, UserRateStatus.watching);
    }
  });

  test('a rewatch keeps its status and the score stays', () async {
    await keep(UserRateStatus.rewatching, 2, score: 9);

    await watch(3);

    expect(
      repository.rates['1'],
      const UserRate(
        id: '1',
        status: UserRateStatus.rewatching,
        episodes: 3,
        score: 9,
      ),
    );
  });

  test('the last episode completes an anime that was not being '
      'watched', () async {
    repository.totalEpisodes['1'] = 1;

    await watch(1);
    expect(repository.rates['1']?.status, UserRateStatus.completed);

    repository.totalEpisodes['1'] = 12;
    await keep(UserRateStatus.planned, 3);
    await watch(12);
    expect(repository.rates['1']?.status, UserRateStatus.completed);
  });

  test('the last episode of an anime being watched completes it', () async {
    repository.totalEpisodes['1'] = 12;
    await keep(UserRateStatus.watching, 10);

    await watch(11);
    expect(repository.rates['1']?.status, UserRateStatus.watching);
    await watch(12);
    expect(repository.rates['1']?.status, UserRateStatus.completed);
  });

  test('a rewatch is left for Shikimori to end and count', () async {
    repository.totalEpisodes['1'] = 12;
    await keep(UserRateStatus.rewatching, 11);

    await watch(12);

    expect(repository.rates['1']?.status, UserRateStatus.rewatching);
  });

  test('an anime with no known count stays watching', () async {
    await watch(24);

    expect(repository.rates['1']?.status, UserRateStatus.watching);
  });

  test('undo takes a new entry out of the list', () async {
    final result = await watch(1) as EpisodeMarked;

    await mark.undo(userId: '42', animeId: '1', mark: result);

    expect(repository.rates, isEmpty);
  });

  test('undo puts an entry back as it was', () async {
    await keep(UserRateStatus.planned, 0, score: 7);
    final result = await watch(1) as EpisodeMarked;

    await mark.undo(userId: '42', animeId: '1', mark: result);

    expect(
      repository.rates['1'],
      const UserRate(
        id: '1',
        status: UserRateStatus.planned,
        episodes: 0,
        score: 7,
      ),
    );
  });
}
