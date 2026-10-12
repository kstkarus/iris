/// Shikimori's BBCode and wiki markup as plain text: links and tags
/// keep their text, headings get a line of their own, and blank lines
/// between paragraphs are one at most.
String sanitizeShikimoriDescription(String input) {
  // Headings: a line of their own, after a blank one.
  final headingPattern = RegExp(r'\[(h\d)\](.*?)\[/\1\]', dotAll: true);
  // Wiki links: [[Page]] or [[Page|shown text]].
  final wikiLinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');
  final linkedTagPattern = RegExp(
    r'\[(\w+)(=[^\]]+)?\](.*?)\[/\1\]',
    dotAll: true,
  );
  final remainingTagPattern = RegExp(r'\[/?[^\]]+\]');
  final extraSpacesBeforeNewlinePattern = RegExp(r'[ \t]+\n');
  final excessiveNewLinesPattern = RegExp(r'\n{3,}');
  final repeatedSpacesPattern = RegExp(r'[ \t]{2,}');

  final withHeadingLines = input.replaceAllMapped(
    headingPattern,
    (match) => '\n\n${match.group(2)}\n',
  );
  final withoutWikiLinks = withHeadingLines.replaceAllMapped(
    wikiLinkPattern,
    (match) => match.group(2) ?? match.group(1) ?? '',
  );
  final withoutLinkedTags = withoutWikiLinks.replaceAllMapped(
    linkedTagPattern,
    (match) => match.group(3) ?? '',
  );
  final withoutRemainingTags = withoutLinkedTags.replaceAll(
    remainingTagPattern,
    '',
  );
  final normalizedLineEndings = withoutRemainingTags.replaceAll('\r\n', '\n');
  final withoutTrailingSpaces = normalizedLineEndings
      .replaceAll(repeatedSpacesPattern, ' ')
      .replaceAll(extraSpacesBeforeNewlinePattern, '\n');

  return withoutTrailingSpaces
      .replaceAll(excessiveNewLinesPattern, '\n\n')
      .trim();
}
