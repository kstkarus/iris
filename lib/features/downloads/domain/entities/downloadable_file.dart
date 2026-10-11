class DownloadableFile {
  const DownloadableFile({
    required this.index,
    required this.name,
    required this.relativePath,
    required this.size,
  });

  final int index;
  final String name;
  final String relativePath;
  final int size;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadableFile &&
        other.index == index &&
        other.name == name &&
        other.relativePath == relativePath &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(index, name, relativePath, size);
}
