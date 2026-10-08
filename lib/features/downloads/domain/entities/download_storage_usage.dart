class DownloadStorageUsage {
  const DownloadStorageUsage({
    required this.downloadsBytes,
    this.cacheBytes,
    this.totalBytes,
  });

  final int downloadsBytes;

  /// The streaming cache: what clearing the cache removes.
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
