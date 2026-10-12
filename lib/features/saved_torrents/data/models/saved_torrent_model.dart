import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

/// JSON shape of a saved torrent in local storage.
abstract final class SavedTorrentModel {
  static Map<String, Object?> toJson(SavedTorrent torrent) {
    return {
      'animeId': torrent.animeId,
      'infoHash': torrent.infoHash,
      'magnet': torrent.magnet,
      'title': torrent.title,
      'addedAt': torrent.addedAt.toUtc().toIso8601String(),
      'lastOpenedAt': torrent.lastOpenedAt?.toUtc().toIso8601String(),
    };
  }

  /// Returns null for malformed entries so one bad record does not wipe the
  /// whole list, and for torrents saved before they belonged to an anime,
  /// which are let go.
  static SavedTorrent? fromJson(Object? json) {
    if (json is! Map) return null;
    final animeId = json['animeId'];
    final infoHash = json['infoHash'];
    final magnet = json['magnet'];
    final title = json['title'];
    final addedAt = DateTime.tryParse('${json['addedAt']}');
    if (animeId is! String ||
        animeId.isEmpty ||
        infoHash is! String ||
        infoHash.isEmpty ||
        magnet is! String ||
        magnet.isEmpty ||
        title is! String ||
        addedAt == null) {
      return null;
    }
    final lastOpenedRaw = json['lastOpenedAt'];
    return SavedTorrent(
      animeId: animeId,
      infoHash: canonicalTorrentKey(infoHash),
      magnet: magnet,
      title: title,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedRaw is String
          ? DateTime.tryParse(lastOpenedRaw)
          : null,
    );
  }
}
