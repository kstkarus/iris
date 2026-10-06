import 'package:iris/features/player/domain/entities/player_video_file.dart';

class AnimePlayerArgs {
  const AnimePlayerArgs({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.sessionId,
    required this.fileIndex,
    required this.fileName,
    this.magnet = '',
    this.files = const [],
  });

  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String sessionId;
  final int fileIndex;
  final String fileName;
  final String magnet;
  final List<PlayerVideoFile> files;
}
