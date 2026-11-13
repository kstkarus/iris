class DownloadStorageUsage {
  const DownloadStorageUsage({this.cacheBytes, this.cacheInUse = false});

  /// The streaming cache: what clearing the cache removes.
  final int? cacheBytes;
  final bool cacheInUse;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadStorageUsage &&
        other.cacheBytes == cacheBytes &&
        other.cacheInUse == cacheInUse;
  }

  @override
  int get hashCode => Object.hash(cacheBytes, cacheInUse);
}
