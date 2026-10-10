import 'package:iris/features/auth/data/models/shikimori_account_dto.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

class ShikimoriAccountDataSource {
  const ShikimoriAccountDataSource({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;

  /// The account the request is signed in as; null when it is anonymous.
  Future<ShikimoriAccountDto?> fetchCurrent() async {
    final data = await _client.query(document: _currentUserQuery);
    return ShikimoriAccountDto.tryParse(data['currentUser']);
  }
}

const _currentUserQuery = '''
query CurrentUser {
  currentUser {
    id
    nickname
    avatarUrl
  }
}
''';
