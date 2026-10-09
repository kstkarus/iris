import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';

/// One playable video of a source: a file of a torrent, or an episode of an
/// online release.
class PlayerVideoFile {
  const PlayerVideoFile({
    required this.index,
    required this.name,
    required this.size,
    required this.extension,
    this.episodeNumber,
    this.title = '',
    this.duration,
  });

  final int index;
  final String name;

  /// Bytes; 0 for an online episode, which has no file.
  final int size;
  final String extension;

  /// Given by an online release; a torrent file's number is read from its
  /// name instead.
  final int? episodeNumber;

  /// The episode's own name when the source gives one; empty for torrents.
  final String title;
  final Duration? duration;

  /// The source's own number, else the one the file name carries.
  int? get number => episodeNumber ?? episodeNumberFromFileName(name);

  /// The episode's own name, else the file name without folders and
  /// extension.
  String get displayName => title.isNotEmpty ? title : fileDisplayName(name);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerVideoFile &&
        other.index == index &&
        other.name == name &&
        other.size == size &&
        other.extension == extension &&
        other.episodeNumber == episodeNumber &&
        other.title == title &&
        other.duration == duration;
  }

  @override
  int get hashCode =>
      Object.hash(index, name, size, extension, episodeNumber, title, duration);
}
