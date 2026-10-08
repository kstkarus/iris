import 'package:iris/shared/torrent/info_hash.dart';

/// A validated BitTorrent magnet link.
class MagnetLink {
  const MagnetLink._({
    required this.uri,
    required this.infoHash,
    required this.displayName,
  });

  /// The trimmed link as entered by the user.
  final String uri;

  /// Lower-case 40-character hex info-hash. A base32 info-hash is converted,
  /// so both spellings of one torrent give the same value.
  final String infoHash;

  /// The `dn` parameter, if the link carries one.
  final String? displayName;

  static const _btihPrefix = 'urn:btih:';

  /// Parses [input] or returns null when it is not a magnet link with a
  /// BitTorrent v1 info-hash (`xt=urn:btih:...`), or when any parameter has
  /// malformed percent-encoding.
  static MagnetLink? tryParse(String input) {
    final text = input.trim();
    String? infoHash;
    String? displayName;
    for (final parameter in magnetQueryParameters(text)) {
      final value = parameter.value;
      if (value == null) return null;
      if (parameter.key == 'xt' && infoHash == null) {
        infoHash = _infoHashFrom(value);
      } else if (parameter.key == 'dn' && value.trim().isNotEmpty) {
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
    return canonicalInfoHash(xt.substring(_btihPrefix.length));
  }
}

/// A `key=value` parameter of a magnet query. The key is lower-case and is
/// not percent-decoded; [value] is null when its percent-encoding is malformed.
typedef MagnetQueryParameter = ({String key, String? value});

const _magnetScheme = 'magnet:?';

/// The parameters of [magnet] in order, or none when it does not start with
/// `magnet:?`. Parts without a key or without `=` are skipped.
List<MagnetQueryParameter> magnetQueryParameters(String magnet) {
  if (!magnet.toLowerCase().startsWith(_magnetScheme)) return const [];
  final parameters = <MagnetQueryParameter>[];
  for (final part in magnet.substring(_magnetScheme.length).split('&')) {
    final separator = part.indexOf('=');
    if (separator <= 0) continue;
    parameters.add((
      key: part.substring(0, separator).toLowerCase(),
      value: _decodeOrNull(part.substring(separator + 1)),
    ));
  }
  return parameters;
}

String? _decodeOrNull(String encoded) {
  try {
    return Uri.decodeQueryComponent(encoded);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}
