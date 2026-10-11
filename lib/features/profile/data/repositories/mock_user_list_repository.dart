import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';

/// The mock app's list: whatever [rates] holds, for any user, with the
/// anime looked up in [titles].
class MockUserListRepository implements UserListRepository {
  const MockUserListRepository({required this.rates, required this.titles});

  final MockUserRateRepository rates;
  final Future<List<AnimeSummary>> Function() titles;

  @override
  Future<UserListPage> page({
    required String userId,
    required UserRateStatus status,
    required int page,
  }) async {
    final anime = {for (final title in await titles()) title.id: title};
    final entries = [
      for (final MapEntry(key: id, value: rate) in rates.rates.entries)
        if (rate.status == status && anime[id] != null)
          UserListEntry(rate: rate, anime: anime[id]!),
    ];
    const size = UserListRepository.pageSize;
    final start = (page - 1) * size;
    return UserListPage(
      entries: entries.skip(start).take(size).toList(),
      hasMore: entries.length > start + size,
    );
  }
}
