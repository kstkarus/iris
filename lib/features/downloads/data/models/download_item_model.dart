import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

class DownloadItemModel {
  const DownloadItemModel({
    required this.id,
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.magnet,
    required this.fileIndex,
    required this.fileName,
    required this.relativePath,
    required this.localPath,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.downloadRateBytesPerSecond,
    required this.peers,
    required this.status,
    required this.createdAt,
    this.errorMessage,
    this.completedAt,
  });

  factory DownloadItemModel.fromDomain(DownloadItem item) {
    return DownloadItemModel(
      id: item.id,
      animeId: item.animeId,
      animeTitle: item.animeTitle,
      sourceTitle: item.sourceTitle,
      magnet: item.magnet,
      fileIndex: item.fileIndex,
      fileName: item.fileName,
      relativePath: item.relativePath,
      localPath: item.localPath,
      totalBytes: item.totalBytes,
      downloadedBytes: item.downloadedBytes,
      downloadRateBytesPerSecond: item.downloadRateBytesPerSecond,
      peers: item.peers,
      status: item.status,
      errorMessage: item.errorMessage,
      createdAt: item.createdAt,
      completedAt: item.completedAt,
    );
  }

  factory DownloadItemModel.fromJson(Map<String, Object?> json) {
    return DownloadItemModel(
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
    );
  }

  final String id;
  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String magnet;
  final int fileIndex;
  final String fileName;
  final String relativePath;
  final String localPath;
  final int totalBytes;
  final int downloadedBytes;
  final int downloadRateBytesPerSecond;
  final int peers;
  final DownloadStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'animeId': animeId,
      'animeTitle': animeTitle,
      'sourceTitle': sourceTitle,
      'magnet': magnet,
      'fileIndex': fileIndex,
      'fileName': fileName,
      'relativePath': relativePath,
      'localPath': localPath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'downloadRateBytesPerSecond': downloadRateBytesPerSecond,
      'peers': peers,
      'status': status.name,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  DownloadItem toDomain() {
    return DownloadItem(
      id: id,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      magnet: magnet,
      fileIndex: fileIndex,
      fileName: fileName,
      relativePath: relativePath,
      localPath: localPath,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      downloadRateBytesPerSecond: downloadRateBytesPerSecond,
      peers: peers,
      status: status,
      errorMessage: errorMessage,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }
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
