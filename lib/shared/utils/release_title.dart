final _leadingTags = RegExp(r'^(\s*\[[^\]]*\]\s*)+');
final _technicalTail = RegExp(r'\s*[\[(|].*$');

/// A torrent's name without its tags, as a title for viewers:
/// `[SubsPlease] Sousou no Frieren (1080p)` -> `Sousou no Frieren`,
/// `Тетрадь смерти / Death Note [S01] (2006) BDRip | СВ-дубль` ->
/// `Тетрадь смерти / Death Note`. Returns the name unchanged when nothing
/// would be left.
String releaseDisplayTitle(String releaseName) {
  final name = releaseName.trim();
  final title = name
      .replaceFirst(_leadingTags, '')
      .replaceFirst(_technicalTail, '')
      .trim();
  return title.isEmpty ? name : title;
}
