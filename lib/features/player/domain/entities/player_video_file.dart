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

  /// Given by an online release, specials included (12.5); a torrent
  /// file's number is read from its name instead.
  final num? episodeNumber;

  /// The episode's own name when the source gives one; empty for torrents.
  final String title;
  final Duration? duration;

  /// The episode's whole number: the source's own (none for a special),
  /// else the one the file name carries.
  int? get number {
    final given = episodeNumber;
    if (given == null) return episodeNumberFromFileName(name);
    return given % 1 == 0 ? given.toInt() : null;
  }

  /// The number as a list shows it, "04" or "12.5"; null when none is
  /// known.
  String? get numberLabel {
    final given = episodeNumber;
    if (given != null && given % 1 != 0) return '$given';
    return number?.toString().padLeft(2, '0');
  }

  /// The episode's own name, else the file name without folders and
  /// extension (an online episode's name is not a file's).
  String get displayName {
    if (title.isNotEmpty) return title;
    return episodeNumber == null ? fileDisplayName(name) : name;
  }

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
