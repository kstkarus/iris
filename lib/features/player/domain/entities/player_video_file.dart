class PlayerVideoFile {
  const PlayerVideoFile({
    required this.index,
    required this.name,
    required this.size,
    required this.extension,
  });

  final int index;
  final String name;
  final int size;
  final String extension;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerVideoFile &&
        other.index == index &&
        other.name == name &&
        other.size == size &&
        other.extension == extension;
  }

  @override
  int get hashCode => Object.hash(index, name, size, extension);
}
