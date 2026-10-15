import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/utils/json_read.dart';

class ShikimoriDownloadPosterDataSource {
  const ShikimoriDownloadPosterDataSource({required this.client});

  final ShikimoriGraphQlClient client;

  Future<Map<String, String>> fetch(Set<String> animeIds) async {
    final result = <String, String>{};
    if (animeIds.isEmpty) return result;
    final items = await client.queryList(
      'animes',
      document: _query,
      variables: {'ids': animeIds.join(','), 'limit': animeIds.length},
    );
    for (final item in items) {
      if (item is! Map) continue;
      final rawId = item['id'];
      if (rawId == null) continue;
      final poster = jsonString(jsonMap(item['poster'])['mainUrl']);
      if (poster.isNotEmpty) {
        result[rawId.toString()] = poster;
      }
    }
    return result;
  }
}

const _query = r'''
query DownloadPosters($ids: String!, $limit: Int!) {
  animes(ids: $ids, limit: $limit, censored: true) {
    id
    poster { mainUrl }
  }
}
''';
