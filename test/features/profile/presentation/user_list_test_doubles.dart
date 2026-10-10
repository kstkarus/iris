import 'dart:async';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';

UserListEntry listEntry(
  String id, {
  UserRateStatus status = UserRateStatus.watching,
  int episodes = 3,
  int score = 0,
  String animeStatus = 'released',
  DateTime? nextEpisodeAt,
}) => UserListEntry(
  rate: UserRate(id: 'r$id', status: status, episodes: episodes, score: score),
  anime: ListedAnime(
    id: id,
    name: 'Anime $id',
    russian: '',
    kind: 'tv',
    score: 8,
    status: animeStatus,
    episodes: 12,
    episodesAired: animeStatus == 'ongoing' ? 6 : 12,
    airedOn: '2026',
    posterUrl: '',
    nextEpisodeAt: nextEpisodeAt,
  ),
);

/// Pages of [lists] by status; [gate], while set, holds every answer.
class FakeUserListRepository implements UserListRepository {
  FakeUserListRepository(this.lists, {this.pageSize = 2});

  final Map<UserRateStatus, List<UserListEntry>> lists;
  final int pageSize;
  final requests = <({String userId, UserRateStatus status, int page})>[];
  Completer<void>? gate;
  Object? failure;

  @override
  Future<UserListPage> page({
    required String userId,
    required UserRateStatus status,
    required int page,
  }) async {
    requests.add((userId: userId, status: status, page: page));
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    final all = lists[status] ?? const [];
    final start = (page - 1) * pageSize;
    return UserListPage(
      entries: all.skip(start).take(pageSize).toList(),
      hasMore: all.length > start + pageSize,
    );
  }
}
