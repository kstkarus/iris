class WatchSourceItem {
  const WatchSourceItem({
    required this.title,
    required this.magnet,
    required this.size,
    required this.time,
    required this.seeders,
    required this.downloads,
  });

  final String title;
  final String magnet;
  final String size;
  final String time;
  final int seeders;
  final int downloads;

  static final _sizePattern = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*([a-z]+)$',
    caseSensitive: false,
  );
  static const _bytesPerUnit = {
    'b': 1,
    'kb': 1000,
    'mb': 1000000,
    'gb': 1000000000,
    'tb': 1000000000000,
    'pb': 1000000000000000,
    'kib': 1 << 10,
    'mib': 1 << 20,
    'gib': 1 << 30,
    'tib': 1 << 40,
    'pib': 1 << 50,
  };

  /// The reported size in bytes, or null when the source gave no usable size.
  double? get sizeInBytes {
    final match = _sizePattern.firstMatch(size.trim());
    if (match == null) return null;
    final multiplier = _bytesPerUnit[match[2]!.toLowerCase()];
    if (multiplier == null) return null;
    final bytes = double.parse(match[1]!.replaceFirst(',', '.')) * multiplier;
    return bytes.isFinite ? bytes : null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WatchSourceItem &&
        other.title == title &&
        other.magnet == magnet &&
        other.size == size &&
        other.time == time &&
        other.seeders == seeders &&
        other.downloads == downloads;
  }

  @override
  int get hashCode =>
      Object.hash(title, magnet, size, time, seeders, downloads);
}
