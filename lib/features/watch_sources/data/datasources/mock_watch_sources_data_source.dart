import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';

class MockWatchSourcesDataSource {
  Future<List<NyaaWatchSourceDto>> fetchSources(String title) async {
    final normalizedTitle = title.trim().toLowerCase();
    return _mockSources[normalizedTitle] ?? const [];
  }
}

const _mockSources = {
  'fullmetal alchemist: brotherhood': [
    NyaaWatchSourceDto(
      title: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
      category: 'Anime - English-translated',
      link: 'https://nyaa.si/view/mock-fmab',
      torrent: 'https://nyaa.si/download/mock-fmab.torrent',
      magnet: 'magnet:?xt=urn:btih:mock-fmab',
      size: '12.4 GiB',
      time: '2026-04-14 17:09',
      seeders: 120,
      leechers: 6,
      downloads: 1402,
    ),
  ],
  'frieren: beyond journey\'s end': [
    NyaaWatchSourceDto(
      title: '[Mock] Frieren Season Pack',
      category: 'Anime - English-translated',
      link: 'https://nyaa.si/view/mock-frieren',
      torrent: 'https://nyaa.si/download/mock-frieren.torrent',
      magnet: 'magnet:?xt=urn:btih:mock-frieren',
      size: '9.7 GiB',
      time: '2026-04-12 10:30',
      seeders: 88,
      leechers: 3,
      downloads: 854,
    ),
  ],
};
