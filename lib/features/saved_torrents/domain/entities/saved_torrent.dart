/// A magnet link the user saved to stream or download later.
///
/// Deliberately independent from the anime catalog: the title is the user's
/// (or the torrent's own `dn`), never a guessed catalog entry.
class SavedTorrent {
  const SavedTorrent({
    required this.infoHash,
    required this.magnet,
    required this.title,
    required this.addedAt,
    this.lastOpenedAt,
  });

  /// Lower-case info-hash; unique per saved torrent.
  final String infoHash;
  final String magnet;
  final String title;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// When the user last used or added this torrent; drives "recent first".
  DateTime get lastUsedAt => lastOpenedAt ?? addedAt;

  SavedTorrent copyWith({String? title, DateTime? lastOpenedAt}) {
    return SavedTorrent(
      infoHash: infoHash,
      magnet: magnet,
      title: title ?? this.title,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedTorrent &&
        other.infoHash == infoHash &&
        other.magnet == magnet &&
        other.title == title &&
        other.addedAt == addedAt &&
        other.lastOpenedAt == lastOpenedAt;
  }

  @override
  int get hashCode =>
      Object.hash(infoHash, magnet, title, addedAt, lastOpenedAt);
}
