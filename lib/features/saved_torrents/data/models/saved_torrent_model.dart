import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';

/// JSON shape of a saved torrent in local storage.
abstract final class SavedTorrentModel {
  static Map<String, Object?> toJson(SavedTorrent torrent) {
    return {
      'infoHash': torrent.infoHash,
      'magnet': torrent.magnet,
      'title': torrent.title,
      'addedAt': torrent.addedAt.toUtc().toIso8601String(),
      'lastOpenedAt': torrent.lastOpenedAt?.toUtc().toIso8601String(),
    };
  }

  /// Returns null for malformed entries so one bad record does not wipe the
  /// whole list.
  static SavedTorrent? fromJson(Object? json) {
    if (json is! Map) return null;
    final infoHash = json['infoHash'];
    final magnet = json['magnet'];
    final title = json['title'];
    final addedAt = DateTime.tryParse('${json['addedAt']}');
    if (infoHash is! String ||
        infoHash.isEmpty ||
        magnet is! String ||
        magnet.isEmpty ||
        title is! String ||
        addedAt == null) {
      return null;
    }
    final lastOpenedRaw = json['lastOpenedAt'];
    return SavedTorrent(
      infoHash: infoHash,
      magnet: magnet,
      title: title,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedRaw is String
          ? DateTime.tryParse(lastOpenedRaw)
          : null,
    );
  }
}
