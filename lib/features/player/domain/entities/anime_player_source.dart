import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/utils/episode_number.dart';

class AnimePlayerSource {
  const AnimePlayerSource({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.sessionId,
    required this.fileIndex,
    required this.fileName,
    this.magnet = '',
    this.files = const [],
  });

  /// Empty when playback was not started from an anime page.
  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String sessionId;
  final int fileIndex;
  final String fileName;

  /// The torrent being played; empty when unknown (no progress is kept).
  final String magnet;

  /// Video files of a streamed torrent, in playback order. Empty for local
  /// downloads, which play a single file.
  final List<PlayerVideoFile> files;

  /// Identity of the torrent for watch progress; null without a magnet.
  String? get torrentKey =>
      magnet.trim().isEmpty ? null : torrentKeyFromMagnet(magnet);

  /// The playing episode's number, when the source or the name gives one.
  int? get episodeNumber {
    for (final file in files) {
      if (file.index == fileIndex) return file.number;
    }
    return episodeNumberFromFileName(fileName);
  }

  /// The file after the current one, if any.
  PlayerVideoFile? get nextFile {
    final position = files.indexWhere((file) => file.index == fileIndex);
    if (position < 0 || position + 1 >= files.length) return null;
    return files[position + 1];
  }

  AnimePlayerSource withFile(PlayerVideoFile file) {
    return AnimePlayerSource(
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      sessionId: sessionId,
      fileIndex: file.index,
      fileName: file.name,
      magnet: magnet,
      files: files,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimePlayerSource &&
        other.animeId == animeId &&
        other.animeTitle == animeTitle &&
        other.sourceTitle == sourceTitle &&
        other.sessionId == sessionId &&
        other.fileIndex == fileIndex &&
        other.fileName == fileName &&
        other.magnet == magnet &&
        _sameFiles(other.files, files);
  }

  @override
  int get hashCode => Object.hash(
    animeId,
    animeTitle,
    sourceTitle,
    sessionId,
    fileIndex,
    fileName,
    magnet,
    Object.hashAll(files),
  );
}

bool _sameFiles(List<PlayerVideoFile> left, List<PlayerVideoFile> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
