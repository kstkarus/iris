class TorrentMetadataUnavailableException implements Exception {
  const TorrentMetadataUnavailableException({
    required this.torrentId,
    required this.timeout,
  });

  final int torrentId;
  final Duration timeout;
}
