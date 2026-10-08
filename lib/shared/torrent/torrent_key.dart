import 'package:iris/shared/torrent/info_hash.dart';
import 'package:iris/shared/torrent/magnet_link.dart';

/// Stable per-torrent key: the canonical BitTorrent info-hash of a magnet
/// link, or a hash of the whole link when it carries no `btih`.
///
/// Hex and base32 spellings of one info-hash give the same key. libtorrent
/// maps every add of the same info-hash onto one native torrent, so features
/// that add magnets must coordinate by this key.
String torrentKeyFromMagnet(String magnet) {
  for (final parameter in magnetQueryParameters(magnet)) {
    final value = parameter.value;
    if (parameter.key != 'xt' || value == null) continue;
    final key = _btihKey(value);
    if (key != null) return key;
  }
  return _fnv1a(magnet);
}

/// The key for an `urn:btih:` value, or null for any other value.
String? _btihKey(String xt) {
  const prefix = 'urn:btih:';
  if (!xt.toLowerCase().startsWith(prefix)) return null;
  final btih = xt.substring(prefix.length);
  final canonical = canonicalInfoHash(btih);
  if (canonical != null) return canonical;
  // Other values keep the historical normalization so existing keys stay valid.
  final hash = btih.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return hash.isEmpty ? null : hash;
}

String _fnv1a(String value) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16);
}
