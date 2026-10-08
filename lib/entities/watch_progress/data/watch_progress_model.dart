import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

abstract final class WatchProgressModel {
  static Map<String, Object?> toJson(WatchProgress progress) => {
    'torrentKey': progress.torrentKey,
    'fileIndex': progress.fileIndex,
    'fileName': progress.fileName,
    'magnet': progress.magnet,
    'sourceTitle': progress.sourceTitle,
    'positionMs': progress.position.inMilliseconds,
    'durationMs': progress.duration.inMilliseconds,
    'updatedAt': progress.updatedAt.toUtc().toIso8601String(),
    'animeId': progress.animeId,
    'animeTitle': progress.animeTitle,
  };

  /// Returns null for malformed entries instead of failing the whole list.
  static WatchProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final torrentKey = json['torrentKey'];
    final fileIndex = json['fileIndex'];
    final positionMs = json['positionMs'];
    final durationMs = json['durationMs'];
    final updatedAt = DateTime.tryParse('${json['updatedAt']}');
    if (torrentKey is! String ||
        torrentKey.isEmpty ||
        fileIndex is! int ||
        positionMs is! int ||
        durationMs is! int ||
        updatedAt == null) {
      return null;
    }
    return WatchProgress(
      torrentKey: canonicalTorrentKey(torrentKey),
      fileIndex: fileIndex,
      fileName: _string(json['fileName']),
      magnet: _string(json['magnet']),
      sourceTitle: _string(json['sourceTitle']),
      position: Duration(milliseconds: positionMs),
      duration: Duration(milliseconds: durationMs),
      updatedAt: updatedAt,
      animeId: _string(json['animeId']),
      animeTitle: _string(json['animeTitle']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';
