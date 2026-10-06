class DownloadStorageUsage {
  const DownloadStorageUsage({
    required this.downloadsBytes,
    this.cacheBytes,
    this.totalBytes,
  });

  final int downloadsBytes;

  /// Temporary data: the streaming cache plus, on Android, the rest of the
  /// app cache reported by the system.
  final int? cacheBytes;
  final int? totalBytes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadStorageUsage &&
        other.downloadsBytes == downloadsBytes &&
        other.cacheBytes == cacheBytes &&
        other.totalBytes == totalBytes;
  }

  @override
  int get hashCode => Object.hash(downloadsBytes, cacheBytes, totalBytes);
}
