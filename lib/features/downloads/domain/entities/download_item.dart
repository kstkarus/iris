import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/shared/online/online_source_link.dart';

const _notProvided = Object();

class DownloadItem {
  const DownloadItem({
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
    this.posterUrl = '',
    this.errorMessage,
    this.completedAt,
    this.quality,
  });

  final String id;
  final String animeId;
  final String animeTitle;
  final String sourceTitle;

  /// The torrent, or an online release's [OnlineSourceLink], whose file
  /// [fileIndex] (an episode, for a release) this is.
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
  final String posterUrl;

  /// How tall a picture an online episode loads in at most; null for the
  /// best, and for a torrent file.
  final int? quality;

  /// The loaded share of the file, from 0 to 1; 0 while its size is unknown.
  double get progress => totalBytes <= 0
      ? 0
      : (downloadedBytes / totalBytes).clamp(0.0, 1.0).toDouble();

  /// An episode loaded from a video server rather than a torrent: it has
  /// no peers, and its size is an estimate until it is done.
  bool get isOnline => OnlineSourceLink.tryParse(magnet) != null;

  /// Why a failed download stopped; null for any other status.
  DownloadFailure? get failure => status == DownloadStatus.failed
      ? downloadFailureFrom(errorMessage)
      : null;

  DownloadItem copyWith({
    String? id,
    String? animeId,
    String? animeTitle,
    String? sourceTitle,
    String? magnet,
    int? fileIndex,
    String? fileName,
    String? relativePath,
    String? localPath,
    int? totalBytes,
    int? downloadedBytes,
    int? downloadRateBytesPerSecond,
    int? peers,
    DownloadStatus? status,
    Object? errorMessage = _notProvided,
    DateTime? createdAt,
    Object? completedAt = _notProvided,
    String? posterUrl,
    int? quality,
  }) {
    assert(
      identical(errorMessage, _notProvided) || errorMessage is String?,
      'errorMessage must be a String or null',
    );
    assert(
      identical(completedAt, _notProvided) || completedAt is DateTime?,
      'completedAt must be a DateTime or null',
    );

    return DownloadItem(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      magnet: magnet ?? this.magnet,
      fileIndex: fileIndex ?? this.fileIndex,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      localPath: localPath ?? this.localPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      downloadRateBytesPerSecond:
          downloadRateBytesPerSecond ?? this.downloadRateBytesPerSecond,
      peers: peers ?? this.peers,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _notProvided)
          ? this.completedAt
          : completedAt as DateTime?,
      posterUrl: posterUrl ?? this.posterUrl,
      quality: quality ?? this.quality,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadItem &&
        other.id == id &&
        other.animeId == animeId &&
        other.animeTitle == animeTitle &&
        other.sourceTitle == sourceTitle &&
        other.magnet == magnet &&
        other.fileIndex == fileIndex &&
        other.fileName == fileName &&
        other.relativePath == relativePath &&
        other.localPath == localPath &&
        other.totalBytes == totalBytes &&
        other.downloadedBytes == downloadedBytes &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.peers == peers &&
        other.status == status &&
        other.errorMessage == errorMessage &&
        other.createdAt == createdAt &&
        other.completedAt == completedAt &&
        other.posterUrl == posterUrl &&
        other.quality == quality;
  }

  @override
  int get hashCode => Object.hash(
    id,
    animeId,
    animeTitle,
    sourceTitle,
    magnet,
    fileIndex,
    fileName,
    relativePath,
    localPath,
    totalBytes,
    downloadedBytes,
    downloadRateBytesPerSecond,
    peers,
    status,
    errorMessage,
    createdAt,
    completedAt,
    posterUrl,
    quality,
  );
}
