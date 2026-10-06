/// A validated BitTorrent magnet link.
class MagnetLink {
  const MagnetLink._({
    required this.uri,
    required this.infoHash,
    required this.displayName,
  });

  /// The trimmed link as entered by the user.
  final String uri;

  /// Lower-case info-hash (40 hex or 32 base32 characters).
  final String infoHash;

  /// The `dn` parameter, if the link carries one.
  final String? displayName;

  static const _scheme = 'magnet:?';
  static const _btihPrefix = 'urn:btih:';
  static final _hexHash = RegExp(r'^[0-9a-fA-F]{40}$');
  static final _base32Hash = RegExp(r'^[A-Za-z2-7]{32}$');

  /// Parses [input] or returns null when it is not a magnet link with a
  /// BitTorrent v1 info-hash (`xt=urn:btih:...`).
  static MagnetLink? tryParse(String input) {
    final text = input.trim();
    if (!text.toLowerCase().startsWith(_scheme)) return null;

    String? infoHash;
    String? displayName;
    for (final part in text.substring(_scheme.length).split('&')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final key = part.substring(0, separator).toLowerCase();
      final String value;
      try {
        value = Uri.decodeQueryComponent(part.substring(separator + 1));
      } on ArgumentError {
        continue;
      }
      if (key == 'xt' && infoHash == null) {
        infoHash = _infoHashFrom(value);
      } else if (key == 'dn' && value.trim().isNotEmpty) {
        displayName ??= value.trim();
      }
    }
    if (infoHash == null) return null;

    return MagnetLink._(
      uri: text,
      infoHash: infoHash,
      displayName: displayName,
    );
  }

  static String? _infoHashFrom(String xt) {
    if (!xt.toLowerCase().startsWith(_btihPrefix)) return null;
    final hash = xt.substring(_btihPrefix.length);
    if (_hexHash.hasMatch(hash) || _base32Hash.hasMatch(hash)) {
      return hash.toLowerCase();
    }
    return null;
  }
}
