/// Stable per-torrent key: the lower-case BitTorrent info-hash of a magnet
/// link, or a hash of the whole link when it carries no `btih`.
///
/// libtorrent maps every add of the same info-hash onto one native torrent, so
/// features that add magnets must coordinate by this key.
String torrentKeyFromMagnet(String magnet) {
  final uri = Uri.tryParse(magnet);
  final xtValues = uri?.queryParametersAll['xt'] ?? const <String>[];
  for (final value in xtValues) {
    const prefix = 'urn:btih:';
    if (value.toLowerCase().startsWith(prefix)) {
      final hash = value
          .substring(prefix.length)
          .toLowerCase()
          .replaceAll(RegExp('[^a-z0-9]'), '');
      if (hash.isNotEmpty) return hash;
    }
  }
  return _fnv1a(magnet);
}

String _fnv1a(String value) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16);
}
