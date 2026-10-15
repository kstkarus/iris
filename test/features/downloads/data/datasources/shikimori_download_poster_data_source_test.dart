import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/datasources/shikimori_download_poster_data_source.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  test('loads real poster URLs and skips malformed poster values', () async {
    late FakeHttpAdapter adapter;
    final dio = Dio()
      ..httpClientAdapter = adapter = FakeHttpAdapter((_) {
        return const FakeReply(200, {
          'data': {
            'animes': [
              {
                'id': '1',
                'poster': {'mainUrl': 'https://example.test/1.jpg'},
              },
              {'id': '2', 'poster': null},
              {'id': '3', 'poster': 'bad'},
            ],
          },
        });
      });
    final source = ShikimoriDownloadPosterDataSource(
      client: ShikimoriGraphQlClient(dio: dio),
    );

    final posters = await source.fetch({'1', '2', '3'});

    expect(adapter.requests, hasLength(1));
    expect(posters, {'1': 'https://example.test/1.jpg'});
  });
}
