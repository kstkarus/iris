import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';

sealed class SaveTorrentResult {
  const SaveTorrentResult();
}

final class SaveTorrentAdded extends SaveTorrentResult {
  const SaveTorrentAdded(this.torrent);

  final SavedTorrent torrent;
}

/// The same info-hash is already saved; nothing was changed.
final class SaveTorrentDuplicate extends SaveTorrentResult {
  const SaveTorrentDuplicate(this.existing);

  final SavedTorrent existing;
}

/// The text is not a magnet link with a BitTorrent info-hash.
final class SaveTorrentInvalidMagnet extends SaveTorrentResult {
  const SaveTorrentInvalidMagnet();
}

abstract interface class SavedTorrentsRepository {
  /// Emits the current list (most recently used first) and every change.
  Stream<List<SavedTorrent>> watchTorrents();

  /// Saves [magnet]; a blank [title] falls back to the link's `dn` or hash.
  Future<SaveTorrentResult> add({required String magnet, String? title});

  Future<void> rename({required String infoHash, required String title});

  Future<void> markOpened({required String infoHash});

  Future<void> delete({required String infoHash});
}
