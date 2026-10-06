import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';

class DownloadManagerState {
  const DownloadManagerState({
    this.isLoading = false,
    this.downloads = const [],
    this.storageUsage,
    this.hasError = false,
  });

  final bool isLoading;
  final List<DownloadItem> downloads;
  final DownloadStorageUsage? storageUsage;
  final bool hasError;

  DownloadManagerState copyWith({
    bool? isLoading,
    List<DownloadItem>? downloads,
    DownloadStorageUsage? storageUsage,
    bool? hasError,
  }) {
    return DownloadManagerState(
      isLoading: isLoading ?? this.isLoading,
      downloads: downloads ?? this.downloads,
      storageUsage: storageUsage ?? this.storageUsage,
      hasError: hasError ?? this.hasError,
    );
  }
}
