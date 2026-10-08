class PlayerPlaybackStats {
  const PlayerPlaybackStats({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
    required this.activePeers,
    required this.bufferSeconds,
    required this.bufferPieces,
    required this.readaheadWindow,
    this.isTorrent = false,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;
  final int activePeers;
  final double bufferSeconds;
  final int bufferPieces;
  final int readaheadWindow;

  /// The numbers describe a torrent stream; a local file reports zeros.
  final bool isTorrent;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPlaybackStats &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.appMemoryBytes == appMemoryBytes &&
        other.activePeers == activePeers &&
        other.bufferSeconds == bufferSeconds &&
        other.bufferPieces == bufferPieces &&
        other.readaheadWindow == readaheadWindow &&
        other.isTorrent == isTorrent;
  }

  @override
  int get hashCode => Object.hash(
    downloadRateBytesPerSecond,
    appMemoryBytes,
    activePeers,
    bufferSeconds,
    bufferPieces,
    readaheadWindow,
    isTorrent,
  );
}
