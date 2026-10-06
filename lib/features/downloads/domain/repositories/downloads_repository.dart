import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';

abstract interface class DownloadsRepository {
  Future<PreparedDownloadSource> prepareSource({required String magnet});

  Future<void> disposePreparedSource({required String sourceToken});

  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
  });

  Stream<List<DownloadItem>> watchDownloads();

  Future<List<DownloadItem>> currentDownloads();

  Future<void> pause({required String id});

  Future<void> resume({required String id});

  Future<void> retry({required String id});

  Future<void> delete({required String id});

  Future<DownloadItem?> findCompletedById({required String id});

  Future<DownloadStorageUsage> calculateStorageUsage();

  /// Removes temporary streaming data. Returns false when nothing could be
  /// cleared because a torrent is being streamed right now.
  Future<bool> clearCache();

  Future<void> restore();
}
