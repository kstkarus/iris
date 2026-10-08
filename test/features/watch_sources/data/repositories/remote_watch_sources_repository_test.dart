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

    final items = await repository.fetchSources(['Frieren']);

    expect(items.map((item) => item.title), [
      'Subbed',
      'Dubbed',
      'Raw',
      'Unknown section',
    ]);
  });

  test('searches every name and lists each release once', () async {
    final dataSource = _PerTitleDataSource({
      'Sousou no Frieren': [_dto(_subbed, 'SubsPlease'), _dto(_subbed, 'Both')],
      "Frieren: Beyond Journey's End": [
        _dto(_subbed, 'Both'),
        _dto(_subbed, 'Judas'),
      ],
    });
    final repository = RemoteWatchSourcesRepository(dataSource: dataSource);

    final items = await repository.fetchSources([
      'Sousou no Frieren',
      "Frieren: Beyond Journey's End",
    ]);

    expect(dataSource.asked, hasLength(2));
    expect(items.map((item) => item.title), ['SubsPlease', 'Both', 'Judas']);
  });

  test('shows what one name found when the other search fails', () async {
    final repository = RemoteWatchSourcesRepository(
      dataSource: _PerTitleDataSource({
        'Sousou no Frieren': [_dto(_subbed, 'SubsPlease')],
      }),
    );

    final items = await repository.fetchSources([
      'Sousou no Frieren',
      'Unreachable',
    ]);

    expect(items.map((item) => item.title), ['SubsPlease']);
  });

  test('fails when every search fails', () async {
    final repository = RemoteWatchSourcesRepository(
      dataSource: _PerTitleDataSource({}),
    );

    await expectLater(repository.fetchSources(['One', 'Two']), throwsException);
  });
}

const _subbed = 'Anime - English-translated';

NyaaWatchSourceDto _dto(String category, String title) {
  return NyaaWatchSourceDto(
    category: category,
    title: title,
    link: 'https://nyaa.si/view/$title',
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
  Future<List<NyaaWatchSourceDto>> fetchSources(String title) async {
    return items;
  }
}

/// Answers each title with its own releases; a title without an entry
/// fails like an unreachable service.
class _PerTitleDataSource implements RemoteWatchSourcesDataSource {
  _PerTitleDataSource(this.byTitle);

  final Map<String, List<NyaaWatchSourceDto>> byTitle;
  final asked = <String>[];

  @override
  Future<List<NyaaWatchSourceDto>> fetchSources(String title) async {
    asked.add(title);
    final items = byTitle[title];
    if (items == null) throw Exception('unreachable');
    return items;
  }
}
