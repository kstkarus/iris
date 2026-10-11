import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/shared/utils/json_read.dart';

/// `currentUser` from Shikimori's GraphQL API, also the cached copy.
class ShikimoriAccountDto {
  const ShikimoriAccountDto({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
  });

  /// Null when [json] is not an account.
  static ShikimoriAccountDto? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final nickname = json['nickname'];
    if (id == null || nickname is! String) return null;
    return ShikimoriAccountDto(
      id: '$id',
      nickname: nickname,
      avatarUrl: jsonString(json['avatarUrl']),
    );
  }

  final String id;
  final String nickname;
  final String avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
  };

  ShikimoriAccount toEntity() =>
      ShikimoriAccount(id: id, nickname: nickname, avatarUrl: avatarUrl);
}
