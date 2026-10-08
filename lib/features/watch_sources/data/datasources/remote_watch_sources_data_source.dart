import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/nyaa_api_client.dart';

class RemoteWatchSourcesDataSource {
  const RemoteWatchSourcesDataSource({required NyaaApiClient client})
    : _client = client;

  final NyaaApiClient _client;

  Future<List<NyaaWatchSourceDto>> fetchSources(String title) async {
    final response = await _client.fetchSources(query: title);
    final items = response['data'];

    if (items is! List) {
      throw const RemoteResponseException(
        'Watch sources response does not contain a valid item list.',
      );
    }

    return items.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Watch sources response contains an invalid item.',
        );
      }

      return NyaaWatchSourceDto.fromJson(item);
    }).toList();
  }
}
