import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/data/models/user_list_entry_dto.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

/// Reads `userRates` through GraphQL. Shikimori gives no total, so a full
/// page means there may be more.
class RemoteUserListRepository implements UserListRepository {
  RemoteUserListRepository({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;

  @override
  Future<UserListPage> page({
    required String userId,
    required UserRateStatus status,
    required int page,
  }) async {
    final data = await _client.query(
      document: _userListQuery,
      variables: {
        'userId': userId,
        'status': UserRateDto.statusToApi(status),
        'page': page,
        'limit': UserListRepository.pageSize,
      },
    );
    final items = data['userRates'];
    if (items is! List) {
      throw const RemoteResponseException('User rates response is not a list.');
    }
    return UserListPage(
      entries: [for (final item in items) ?UserListEntryDto.tryParse(item)],
      hasMore: items.length >= UserListRepository.pageSize,
    );
  }
}

const _userListQuery = r'''
query UserList(
  $userId: ID!
  $status: UserRateStatusEnum
  $page: PositiveInt
  $limit: PositiveInt
) {
  userRates(
    userId: $userId
    targetType: Anime
    status: $status
    order: { field: updated_at, order: desc }
    page: $page
    limit: $limit
  ) {
    id
    status
    episodes
    score
    anime {
      id
      name
      russian
      kind
      score
      status
      episodes
      episodesAired
      nextEpisodeAt
      airedOn {
        year
        month
        day
        date
      }
      poster {
        mainUrl
      }
    }
  }
}
''';
