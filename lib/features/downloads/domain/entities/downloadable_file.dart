class DownloadableFile {
  const DownloadableFile({
    required this.index,
    required this.name,
    required this.relativePath,
    required this.size,
    required this.extension,
  });

  final int index;
  final String name;
  final String relativePath;
  final int size;
  final String extension;

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
        other.extension == extension;
  }

  @override
  int get hashCode => Object.hash(index, name, relativePath, size, extension);
}
