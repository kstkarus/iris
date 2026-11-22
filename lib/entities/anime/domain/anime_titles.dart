final class AnimeTitles {
  const AnimeTitles({required this.name, this.russian = '', this.english = ''});

  /// Shikimori's main title, usually in romaji.
  final String name;
  final String russian;
  final String english;

  @override
  bool operator ==(Object other) =>
      other is AnimeTitles &&
      other.name == name &&
      other.russian == russian &&
      other.english == english;

  @override
  int get hashCode => Object.hash(name, russian, english);
}
