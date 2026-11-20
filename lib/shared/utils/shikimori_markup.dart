import 'package:html/dom.dart' show Element, Node, Text;
import 'package:html/parser.dart' show parseFragment;

import 'package:iris/shared/models/details_description.dart';
import 'package:iris/shared/network/shikimori_api.dart';

/// Shikimori resolves abbreviated BBCode references in the rendered markup.
DetailsDescription parseShikimoriDescription(String input, {String html = ''}) {
  if (html.isNotEmpty) {
    final description = _parseDescriptionHtml(html);
    if (description.text.isNotEmpty) return description;
  }
  return DetailsDescription(_normalizeWhitespace(_plainBbCode(input)).trim());
}

DetailsDescription _parseDescriptionHtml(String input) {
  final fragment = parseFragment(input);
  for (final element in fragment.querySelectorAll(
    'script, style, .b-spoiler_block > span, .b-spoiler > label',
  )) {
    element.remove();
  }
  for (final lineBreak in fragment.querySelectorAll('br')) {
    lineBreak.replaceWith(Text('\n'));
  }
  for (final block in fragment.querySelectorAll(
    'div, p, blockquote, li, h1, h2, h3, h4, h5, h6',
  )) {
    block.nodes.insert(0, Text('\n\n'));
    block.append(Text(block.localName!.startsWith('h') ? '\n' : '\n\n'));
  }

  final description = StringBuffer();
  final plain = StringBuffer();
  final links = <DescriptionCharacterLink>[];

  void flushText() {
    final text = _normalizeWhitespace(plain.toString());
    description.write(description.isEmpty ? text.trimLeft() : text);
    plain.clear();
  }

  void visit(Node node) {
    if (node is Text) {
      plain.write(node.data);
      return;
    }
    if (node is Element && node.localName == 'a') {
      final characterId = _characterId(node.attributes['href']);
      final content = node.text;
      final label = content.trim();
      if (characterId != null && label.isNotEmpty) {
        // Keep the surrounding whitespace in the paragraph text.
        plain.write(
          content.substring(0, content.length - content.trimLeft().length),
        );
        flushText();
        final start = description.length;
        description.write(_normalizeWhitespace(label));
        links.add((
          start: start,
          end: description.length,
          characterId: characterId,
        ));
        plain.write(content.substring(content.trimRight().length));
        return;
      }
    }
    for (final child in node.nodes) {
      visit(child);
    }
  }

  visit(fragment);
  flushText();
  return DetailsDescription(
    description.toString().trimRight(),
    characterLinks: List.unmodifiable(links),
  );
}

final _shikimoriOrigin = Uri.parse(ShikimoriApi.baseUrl);
final _characterPath = RegExp(r'^/characters/z?([1-9]\d*)(?:-[^/]+)?/?$');

String? _characterId(String? href) {
  final uri = Uri.tryParse(href ?? '');
  if (uri == null) return null;
  final target = _shikimoriOrigin.resolveUri(uri);
  if ((target.scheme != 'https' && target.scheme != 'http') ||
      (target.host != _shikimoriOrigin.host &&
          target.host != 'shikimori.one')) {
    return null;
  }
  return _characterPath.firstMatch(target.path)?.group(1);
}

String _normalizeWhitespace(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n');

String _plainBbCode(String input) {
  // Headings: a line of their own, after a blank one.
  final headingPattern = RegExp(r'\[(h\d)\](.*?)\[/\1\]', dotAll: true);
  // Wiki links: [[Page]] or [[Page|shown text]].
  final wikiLinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');
  final linkedTagPattern = RegExp(
    r'\[(\w+)(=[^\]]+)?\](.*?)\[/\1\]',
    dotAll: true,
  );
  final remainingTagPattern = RegExp(r'\[/?[^\]]+\]');

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
  return withoutLinkedTags.replaceAll(remainingTagPattern, '');
}
