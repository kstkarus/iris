import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';

abstract interface class DownloadsRepository {
  /// [cancelled] completes when the caller no longer wants the source; the
  /// preparation then stops and releases what it holds.
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  });

  Future<void> disposePreparedSource({required String sourceToken});

  /// [quality] caps the picture height of an online episode (null: the
  /// best); a torrent file ignores it. The source stays prepared, so more
  /// of its files can be queued until it is disposed.
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    int? quality,
  });

  Stream<List<DownloadItem>> watchDownloads();

  /// The downloads of the torrent or online release [magnet], by file
  /// index, now and on every change.
  Stream<Map<int, DownloadItem>> watchSourceDownloads({required String magnet});

  Future<void> pause({required String id});

  Future<void> resume({required String id});

  Future<void> retry({required String id});

  /// Returns false when the files could not be removed; the record is then
  /// kept, stopped if it was loading.
  Future<bool> delete({required String id});

  Future<DownloadItem?> findCompletedById({required String id});

  Future<DownloadStorageUsage> calculateStorageUsage();

  /// Removes temporary streaming data. Returns false when nothing could be
  /// cleared because a torrent is being streamed right now.
  Future<bool> clearCache();
}
