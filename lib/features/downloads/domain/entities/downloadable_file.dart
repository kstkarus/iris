class DownloadableFile {
  const DownloadableFile({
    required this.index,
    required this.name,
    required this.relativePath,
    required this.size,
    this.episodeNumber,
    this.title = '',
    this.duration,
  });

  final int index;
  final String name;
  final String relativePath;
  final int size;
  final num? episodeNumber;
  final String title;
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadableFile &&
        other.index == index &&
        other.name == name &&
        other.relativePath == relativePath &&
        other.size == size &&
        other.episodeNumber == episodeNumber &&
        other.title == title &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(
    index,
    name,
    relativePath,
    size,
    episodeNumber,
    title,
    duration,
  );
}
