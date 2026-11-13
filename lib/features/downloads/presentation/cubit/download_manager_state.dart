import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

class DownloadManagerState {
  const DownloadManagerState({
    this.isLoading = false,
    this.downloads = const [],
    this.storageUsage,
    this.hasError = false,
    this.deletingIds = const {},
  });

  final bool isLoading;
  final List<DownloadItem> downloads;
  final DownloadStorageUsage? storageUsage;
  final bool hasError;
  final Set<String> deletingIds;

  List<DownloadItem> get queue => [
    ...downloads.where((item) => item.status == DownloadStatus.downloading),
    ...downloads.where((item) => item.status == DownloadStatus.queued),
  ];

  DownloadManagerState copyWith({
    bool? isLoading,
    List<DownloadItem>? downloads,
    DownloadStorageUsage? storageUsage,
    bool? hasError,
    Set<String>? deletingIds,
  }) {
    return DownloadManagerState(
      isLoading: isLoading ?? this.isLoading,
      downloads: downloads ?? this.downloads,
      storageUsage: storageUsage ?? this.storageUsage,
      hasError: hasError ?? this.hasError,
      deletingIds: deletingIds ?? this.deletingIds,
    );
  }
}
