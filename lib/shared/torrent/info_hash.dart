/// The canonical form of a BitTorrent v1 info-hash: 40 lower-case hex digits.
///
/// Accepts 40 hex digits, or the 32-character RFC 4648 base32 spelling of the
/// same 20 bytes. Returns null for any other value. libtorrent treats both
/// spellings as one torrent, so callers must compare the canonical form.
String? canonicalInfoHash(String value) {
  if (_hexInfoHash.hasMatch(value)) return value.toLowerCase();
  if (_base32InfoHash.hasMatch(value)) return _hexFromBase32(value);
  return null;
}

final _hexInfoHash = RegExp(r'^[0-9a-fA-F]{40}$');
final _base32InfoHash = RegExp(r'^[A-Za-z2-7]{32}$');
const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Converts 32 base32 characters (160 bits) into 40 lower-case hex digits.
String _hexFromBase32(String value) {
  final hex = StringBuffer();
  var buffer = 0;
  var bitCount = 0;
  for (final character in value.toUpperCase().split('')) {
    buffer = (buffer << 5) | _base32Alphabet.indexOf(character);
    bitCount += 5;
    if (bitCount >= 8) {
      bitCount -= 8;
      final byte = (buffer >> bitCount) & 0xff;
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
      buffer &= (1 << bitCount) - 1;
    }
  }
  return hex.toString();
}
