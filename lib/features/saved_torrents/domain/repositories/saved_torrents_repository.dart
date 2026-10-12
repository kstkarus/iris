import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';

sealed class SaveTorrentResult {
  const SaveTorrentResult();
}

final class SaveTorrentAdded extends SaveTorrentResult {
  const SaveTorrentAdded(this.torrent);

  final SavedTorrent torrent;
}

/// The anime already has the same info-hash; nothing was changed.
final class SaveTorrentDuplicate extends SaveTorrentResult {
  const SaveTorrentDuplicate(this.existing);

  final SavedTorrent existing;
}

/// The text is not a magnet link with a BitTorrent info-hash.
final class SaveTorrentInvalidMagnet extends SaveTorrentResult {
  const SaveTorrentInvalidMagnet();
}

/// The torrents the user added by hand, kept per anime.
abstract interface class SavedTorrentsRepository {
  /// Emits [animeId]'s torrents (most recently used first) and every
  /// change to them.
  Stream<List<SavedTorrent>> watchTorrents(String animeId);

  /// Adds [magnet] to [animeId], named by the link's `dn` or its hash.
  Future<SaveTorrentResult> add({
    required String animeId,
    required String magnet,
  });

  Future<void> rename(SavedTorrent torrent, String title);

  Future<void> markOpened(SavedTorrent torrent);

  Future<void> delete(SavedTorrent torrent);

  /// Puts back a torrent [delete] removed, as it was (its place in the list
  /// included); nothing when the same info-hash is saved again meanwhile.
  Future<void> restore(SavedTorrent torrent);
}
