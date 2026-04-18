class TorrentFileDescriptor {
  const TorrentFileDescriptor({
    required this.index,
    required this.name,
    required this.size,
    required this.isStreamable,
  });

  final int index;
  final String name;
  final int size;
  final bool isStreamable;
}
