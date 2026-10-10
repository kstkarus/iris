import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';

/// Anyone's Shikimori list, one status at a time. Lists are public, so
/// this needs no session.
abstract interface class UserListRepository {
  static const pageSize = 30;

  /// [page] counts from 1.
  Future<UserListPage> page({
    required String userId,
    required UserRateStatus status,
    required int page,
  });
}
