import 'dart:async';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';

const testReleaseMagnet =
    'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';
const testReleaseLink = 'online:anilibria/9542?anime=52991';
const testReleasePoster = 'https://example.test/frieren.png';

AnimePlayerSourceArgs testReleaseArgs({
  bool online = false,
  bool selectDownloads = false,
  bool preferDownloads = false,
  int? autoOpenFileIndex,
}) => AnimePlayerSourceArgs(
  animeId: '52991',
  animeTitles: const AnimeTitles(name: 'Frieren'),
  sourceTitle: online ? 'AniLibria' : 'Some Release',
  posterUrl: testReleasePoster,
  magnet: online ? testReleaseLink : testReleaseMagnet,
  initialDownloadMode: selectDownloads,
  preferDownloads: preferDownloads,
  autoOpenFileIndex: autoOpenFileIndex,
);

List<DownloadableFile> testReleaseFiles(int count, {bool named = false}) => [
  for (var index = 1; index <= count; index++)
    DownloadableFile(
      index: index,
      name: 'episode-${index.toString().padLeft(2, '0')}.mkv',
      relativePath: 'episode-$index.mkv',
      size: 0,
      episodeNumber: index,
      title: named ? 'Story of episode $index' : '',
      duration: const Duration(minutes: 24),
    ),
];

DownloadItem testReleaseDownload(
  int index,
  DownloadStatus status, {
  int downloadedBytes = 48,
  int totalBytes = 100,
  int? videoHeight,
  String animeId = '52991',
  String magnet = testReleaseLink,
}) => DownloadItem(
  id: 'download-$index',
  animeId: animeId,
  animeTitle: 'Frieren',
  sourceTitle: 'Release',
  magnet: magnet,
  fileIndex: index,
  fileName: '0$index Story of episode $index',
  relativePath: 'episode-$index.mkv',
  localPath: 'local/episode-$index.mkv',
  totalBytes: totalBytes,
  downloadedBytes: downloadedBytes,
  downloadRateBytesPerSecond: 0,
  peers: 0,
  status: status,
  createdAt: DateTime(2026),
  videoHeight: videoHeight,
);

class ReleaseDownloadsFixture extends MockDownloadsRepository {
  ReleaseDownloadsFixture({
    required this.files,
    this.qualities = const [],
    List<DownloadItem> downloads = const [],
  }) : _downloads = {for (final item in downloads) item.fileIndex: item};

  final List<DownloadableFile> files;
  final List<int> qualities;
  final Map<int, DownloadItem> _downloads;
  final _changes = StreamController<Map<int, DownloadItem>>.broadcast();
  final enqueued = <({int index, int? quality, String posterUrl})>[];
  final disposed = <String>[];
  final reject = <int>{};
  final filesMissingOnDisk = <int>{};
  Future<void>? enqueueGate;
  int preparations = 0;
  int inventoryActions = 0;

  void update(DownloadItem item) {
    _downloads[item.fileIndex] = item;
    _changes.add(Map.of(_downloads));
  }

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    preparations++;
    return PreparedDownloadSource(
      sourceToken: 'release',
      files: files,
      qualities: qualities,
    );
  }

  @override
  Future<void> disposePreparedSource({required String sourceToken}) async =>
      disposed.add(sourceToken);

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    controller.add(Map.of(_downloads));
  });

  @override
  Stream<List<DownloadItem>> watchDownloads() => watchSourceDownloads(
    magnet: testReleaseLink,
  ).map((items) => items.values.toList());

  @override
  Future<DownloadItem?> findCompletedById({required String id}) async {
    return _downloads.values
        .where(
          (item) =>
              item.id == id &&
              item.status == DownloadStatus.completed &&
              !filesMissingOnDisk.contains(item.fileIndex),
        )
        .firstOrNull;
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    String animeRussian = '',
    String animeEnglish = '',
    String posterUrl = '',
    int? quality,
  }) async {
    await enqueueGate;
    if (disposed.contains(source.sourceToken)) {
      throw StateError('Source disposed');
    }
    final index = file.index;
    if (reject.contains(index)) throw StateError('Cannot add $index');
    enqueued.add((index: index, quality: quality, posterUrl: posterUrl));
    final item = testReleaseDownload(index, DownloadStatus.queued);
    update(item);
    return item;
  }

  @override
  Future<void> resume({required String id}) async => inventoryActions++;

  @override
  Future<void> retry({required String id}) async => inventoryActions++;

  Future<void> closeFixture() => _changes.close();
}
