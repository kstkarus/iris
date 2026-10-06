import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';
import 'package:iris/features/watch_sources/data/repositories/remote_watch_sources_repository.dart';

void main() {
  test('keeps anime episodes and drops other Nyaa sections and AMVs', () async {
    final repository = RemoteWatchSourcesRepository(
      dataSource: _FakeDataSource([
        _dto('Anime - English-translated', 'Subbed'),
        _dto('Anime - Non-English-translated', 'Dubbed'),
        _dto('Anime - Raw', 'Raw'),
        _dto('', 'Unknown section'),
        _dto('Anime - Anime Music Video', 'AMV'),
        _dto('Literature - English-translated', 'Manga'),
        _dto('Audio - Lossless', 'Soundtrack'),
      ]),
    );

    final items = await repository.fetchSources('Frieren');

    expect(items.map((item) => item.title), [
      'Subbed',
      'Dubbed',
      'Raw',
      'Unknown section',
    ]);
  });
}

NyaaWatchSourceDto _dto(String category, String title) {
  return NyaaWatchSourceDto(
    category: category,
    title: title,
    link: 'https://nyaa.si/view/1',
    torrent: 'https://nyaa.si/download/1.torrent',
    magnet: 'magnet:?xt=urn:btih:test',
    size: '1.0 GiB',
    time: '2026-04-14 17:09',
    seeders: 1,
    leechers: 0,
    downloads: 1,
  );
}

class _FakeDataSource implements RemoteWatchSourcesDataSource {
  const _FakeDataSource(this.items);

  final List<NyaaWatchSourceDto> items;

  @override
  Future<List<NyaaWatchSourceDto>> fetchSources(
    String animeEnglishTitle,
  ) async {
    return items;
  }
}
