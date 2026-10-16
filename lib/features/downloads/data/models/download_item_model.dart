import 'package:path/path.dart' as path;

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
      'totalBytes': item.totalBytes,
      'downloadedBytes': item.downloadedBytes,
      'downloadRateBytesPerSecond': item.downloadRateBytesPerSecond,
      'peers': item.peers,
      'status': item.status.name,
      'errorMessage': item.errorMessage,
      'createdAt': item.createdAt.toIso8601String(),
      'completedAt': item.completedAt?.toIso8601String(),
      if (item.quality != null) 'quality': item.quality,
      if (item.videoHeight != null) 'videoHeight': item.videoHeight,
    };
  }

  static DownloadItem fromJson(Map<String, Object?> json) {
    final id = _readString(json, 'id');
    final relativePath = _readString(json, 'relativePath');
    final drivePrefix = RegExp(r'^[a-zA-Z]:');
    final invalidId =
        id.isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains('/') ||
        id.contains('\\') ||
        id.contains('\u0000') ||
        drivePrefix.hasMatch(id) ||
        path.windows.rootPrefix(id).isNotEmpty;
    final invalidRelativePath =
        relativePath.contains('\u0000') ||
        drivePrefix.hasMatch(relativePath) ||
        [path.posix, path.windows].any(
          (context) =>
              context.rootPrefix(relativePath).isNotEmpty ||
              context.split(context.normalize(relativePath)).firstOrNull ==
                  '..',
        );
    if (invalidId || invalidRelativePath) {
      throw const FormatException('Download path leaves its directory.');
    }
    return DownloadItem(
      id: id,
      animeId: _readString(json, 'animeId'),
      animeTitle: _readString(json, 'animeTitle'),
      sourceTitle: _readString(json, 'sourceTitle'),
      magnet: _readString(json, 'magnet'),
      fileIndex: _readInt(json, 'fileIndex'),
      fileName: _readString(json, 'fileName'),
      relativePath: relativePath,
      // Older registries contain this field. Restore rebuilds it from the
      // current support directory before exposing the download.
      localPath: _readOptionalString(json, 'localPath'),
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
      videoHeight: _readPositiveNullableInt(json, 'videoHeight'),
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

int? _readPositiveNullableInt(Map<String, Object?> json, String key) {
  final value = _readNullableInt(json, key);
  return value != null && value > 0 ? value : null;
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
