import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';
import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';
import 'package:iris/shared/utils/json_read.dart';

/// Reads friends and their entries through REST: GraphQL has neither.
///
/// Both are kept for the session, as every anime page asks for them
/// again; a failed request is asked again next time.
class RemoteFriendsRepository implements FriendsRepository {
  RemoteFriendsRepository({required ShikimoriRestClient client})
    : _client = client;

  /// Shikimori's largest page.
  static const _friendsLimit = 100;

  final ShikimoriRestClient _client;
  final _friends = <String, Future<List<Friend>>>{};
  final _rates = <String, Future<UserRate?>>{};

  @override
  Future<List<Friend>> friends(String userId) =>
      _kept(_friends, userId, () => _fetchFriends(userId));

  @override
  Future<UserRate?> rateOf({
    required String friendId,
    required String animeId,
  }) =>
      _kept(_rates, '$friendId/$animeId', () => _fetchRate(friendId, animeId));

  Future<List<Friend>> _fetchFriends(String userId) async {
    final data = await _client.get(
      '/api/users/$userId/friends',
      query: {'limit': _friendsLimit},
    );
    if (data is! List) {
      throw const RemoteResponseException('Friends response is not a list.');
    }
    return [for (final item in data) ?_parseFriend(item)];
  }

  /// Without `user_id` Shikimori does not answer at all, so the entries
  /// are read one friend at a time.
  Future<UserRate?> _fetchRate(String friendId, String animeId) async {
    final data = await _client.get(
      '/api/v2/user_rates',
      query: {
        'user_id': friendId,
        'target_id': animeId,
        'target_type': 'Anime',
      },
    );
    if (data is! List) {
      throw const RemoteResponseException('User rates response is not a list.');
    }
    return data.isEmpty ? null : UserRateDto.tryParse(data.first)?.toEntity();
  }

  static Friend? _parseFriend(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final nickname = json['nickname'];
    if (id == null || nickname is! String) return null;
    final image = json['image'];
    final avatar = image is Map ? image['x160'] : json['avatar'];
    return Friend(id: '$id', nickname: nickname, avatarUrl: jsonString(avatar));
  }

  static Future<T> _kept<T>(
    Map<String, Future<T>> cache,
    String key,
    Future<T> Function() fetch,
  ) {
    final kept = cache[key];
    if (kept != null) return kept;
    final future = fetch();
    cache[key] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        cache.remove(key);
      },
    );
    return future;
  }
}
