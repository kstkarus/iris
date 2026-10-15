import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

/// A download as the registry file stores it. Reading throws a
/// [FormatException] on the first field that does not fit.
abstract final class DownloadItemModel {
  static Map<String, Object?> toJson(DownloadItem item) {
    return {
      'id': item.id,
      'animeId': item.animeId,
      'animeTitle': item.animeTitle,
      'posterUrl': item.posterUrl,
      'sourceTitle': item.sourceTitle,
      'magnet': item.magnet,
      'fileIndex': item.fileIndex,
      'fileName': item.fileName,
      'relativePath': item.relativePath,
      'localPath': item.localPath,
      'totalBytes': item.totalBytes,
      'downloadedBytes': item.downloadedBytes,
      'downloadRateBytesPerSecond': item.downloadRateBytesPerSecond,
      'peers': item.peers,
      'status': item.status.name,
      'errorMessage': item.errorMessage,
      'createdAt': item.createdAt.toIso8601String(),
      'completedAt': item.completedAt?.toIso8601String(),
      if (item.quality != null) 'quality': item.quality,
    };
  }

  static DownloadItem fromJson(Map<String, Object?> json) {
    return DownloadItem(
      id: _readString(json, 'id'),
      animeId: _readString(json, 'animeId'),
      animeTitle: _readString(json, 'animeTitle'),
      sourceTitle: _readString(json, 'sourceTitle'),
      magnet: _readString(json, 'magnet'),
      fileIndex: _readInt(json, 'fileIndex'),
      fileName: _readString(json, 'fileName'),
      relativePath: _readString(json, 'relativePath'),
      localPath: _readString(json, 'localPath'),
      totalBytes: _readInt(json, 'totalBytes'),
      downloadedBytes: _readInt(json, 'downloadedBytes'),
      downloadRateBytesPerSecond: _readInt(json, 'downloadRateBytesPerSecond'),
      peers: _readInt(json, 'peers'),
      status: _readStatus(json, 'status'),
      errorMessage: _readNullableString(json, 'errorMessage'),
      createdAt: _readDateTime(json, 'createdAt'),
      completedAt: _readNullableDateTime(json, 'completedAt'),
      posterUrl: _readOptionalString(json, 'posterUrl'),
      quality: _readNullableInt(json, 'quality'),
    );
  }
}

String _readOptionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String? ?? '';
  throw FormatException('Expected "$key" to be a string or null.');
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
}

String? _readNullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('Expected "$key" to be a string or null.');
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an integer.');
}

/// Absent in records written before online episodes had a quality.
int? _readNullableInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected "$key" to be an integer or null.');
}

DownloadStatus _readStatus(Map<String, Object?> json, String key) {
  final value = _readString(json, key);
  for (final status in DownloadStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  throw FormatException('Unknown download status "$value".');
}

DateTime _readDateTime(Map<String, Object?> json, String key) {
  return DateTime.parse(_readString(json, key));
}

DateTime? _readNullableDateTime(Map<String, Object?> json, String key) {
  final value = _readNullableString(json, key);
  return value == null ? null : DateTime.parse(value);
}
