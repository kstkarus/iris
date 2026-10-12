/// A torrent the user added to an anime by hand: a magnet link, or a
/// `.torrent` file kept as one.
///
/// It belongs to the anime it was added to, never to one guessed from its
/// name; the same torrent may be added to several.
class SavedTorrent {
  const SavedTorrent({
    required this.animeId,
    required this.infoHash,
    required this.magnet,
    required this.title,
    required this.addedAt,
    this.lastOpenedAt,
  });

  final String animeId;

  /// Lower-case info-hash; unique among one anime's torrents.
  final String infoHash;
  final String magnet;
  final String title;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// When the user last used or added this torrent; drives "recent first".
  DateTime get lastUsedAt => lastOpenedAt ?? addedAt;

  SavedTorrent copyWith({String? title, DateTime? lastOpenedAt}) {
    return SavedTorrent(
      animeId: animeId,
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
        other.animeId == animeId &&
        other.infoHash == infoHash &&
        other.magnet == magnet &&
        other.title == title &&
        other.addedAt == addedAt &&
        other.lastOpenedAt == lastOpenedAt;
  }

  @override
  int get hashCode =>
      Object.hash(animeId, infoHash, magnet, title, addedAt, lastOpenedAt);
}
