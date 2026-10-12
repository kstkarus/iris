import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a `.torrent` file describes, enough to stand in for it as a magnet
/// link: the app keeps links, not files, and libtorrent fetches the rest
/// from peers.
class TorrentFile {
  const TorrentFile({
    required this.infoHash,
    required this.name,
    required this.size,
    required this.fileCount,
    this.trackers = const [],
  });

  /// Lower-case 40-character hex v1 info-hash.
  final String infoHash;
  final String name;

  /// All files together, in bytes.
  final int size;
  final int fileCount;
  final List<String> trackers;

  /// The torrent as a magnet link, with its name, size and trackers.
  String get magnet => [
    'magnet:?xt=urn:btih:$infoHash',
    if (name.isNotEmpty) 'dn=${Uri.encodeQueryComponent(name)}',
    'xl=$size',
    for (final tracker in trackers) 'tr=${Uri.encodeQueryComponent(tracker)}',
  ].join('&');

  /// Reads [bytes] as a BitTorrent v1 (or hybrid) metainfo file; null when
  /// they are something else, or a v2-only torrent, which has no v1 hash.
  static TorrentFile? tryParse(Uint8List bytes) {
    final _Bencoded root;
    try {
      root = _Decoder(bytes).decodeRoot();
    } on FormatException {
      return null;
    }
    final top = root.value;
    if (top is! Map<String, _Bencoded>) return null;
    final info = top['info'];
    final fields = info?.value;
    if (info == null || fields is! Map<String, _Bencoded>) return null;
    if (fields['pieces']?.value is! Uint8List) return null;

    final files = fields['files']?.value;
    final int size;
    final int fileCount;
    if (files is List<_Bencoded>) {
      size = files.fold(0, (sum, file) {
        final length = file.value is Map<String, _Bencoded>
            ? (file.value as Map<String, _Bencoded>)['length']?.value
            : null;
        return sum + (length is int ? length : 0);
      });
      fileCount = files.length;
    } else {
      final length = fields['length']?.value;
      if (length is! int) return null;
      size = length;
      fileCount = 1;
    }

    final hash = sha1.convert(bytes.sublist(info.start, info.end));
    return TorrentFile(
      infoHash: hash.toString(),
      name: _text(fields['name.utf-8']) ?? _text(fields['name']) ?? '',
      size: size,
      fileCount: fileCount,
      trackers: _trackers(top),
    );
  }

  /// `announce-list` tiers in order, then `announce`, each once.
  static List<String> _trackers(Map<String, _Bencoded> top) {
    final seen = <String>{};
    final tiers = top['announce-list']?.value;
    return [
      if (tiers is List<_Bencoded>)
        for (final tier in tiers)
          if (tier.value case final List<_Bencoded> urls)
            for (final url in urls)
              if (_text(url) case final tracker? when seen.add(tracker))
                tracker,
      if (_text(top['announce']) case final tracker? when seen.add(tracker))
        tracker,
    ];
  }

  static String? _text(_Bencoded? value) {
    final bytes = value?.value;
    if (bytes is! Uint8List) return null;
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    return text.isEmpty ? null : text;
  }
}

/// A decoded value (int, byte string, list or dictionary) and where it
/// lies in the file: the info-hash is taken over the info dictionary's own
/// bytes.
class _Bencoded {
  const _Bencoded(this.value, this.start, this.end);

  final Object value;
  final int start;
  final int end;
}

class _Decoder {
  _Decoder(this._bytes);

  final Uint8List _bytes;
  var _at = 0;

  static const _maxDepth = 64;

  _Bencoded decodeRoot() {
    final value = _decode(0);
    if (_at != _bytes.length) throw const FormatException('Trailing bytes');
    return value;
  }

  _Bencoded _decode(int depth) {
    if (depth > _maxDepth) throw const FormatException('Too deep');
    final start = _at;
    final Object value = switch (_peek()) {
      0x69 => _integer(), // i
      0x6c => _list(depth), // l
      0x64 => _dictionary(depth), // d
      >= 0x30 && <= 0x39 => _string(), // 0-9
      _ => throw const FormatException('Not bencode'),
    };
    return _Bencoded(value, start, _at);
  }

  int _peek() {
    if (_at >= _bytes.length) throw const FormatException('Cut short');
    return _bytes[_at];
  }

  int _integer() {
    _at++;
    final end = _bytes.indexOf(0x65, _at); // e
    if (end < 0) throw const FormatException('Open integer');
    final value = int.parse(ascii.decode(_bytes.sublist(_at, end)));
    _at = end + 1;
    return value;
  }

  Uint8List _string() {
    final colon = _bytes.indexOf(0x3a, _at); // :
    if (colon < 0) throw const FormatException('Open string');
    final length = int.parse(ascii.decode(_bytes.sublist(_at, colon)));
    final start = colon + 1;
    if (length < 0 || start + length > _bytes.length) {
      throw const FormatException('String past the end');
    }
    _at = start + length;
    return Uint8List.sublistView(_bytes, start, _at);
  }

  List<_Bencoded> _list(int depth) {
    _at++;
    final items = <_Bencoded>[];
    while (_peek() != 0x65) {
      items.add(_decode(depth + 1));
    }
    _at++;
    return items;
  }

  Map<String, _Bencoded> _dictionary(int depth) {
    _at++;
    final entries = <String, _Bencoded>{};
    while (_peek() != 0x65) {
      final key = utf8.decode(_string(), allowMalformed: true);
      entries[key] = _decode(depth + 1);
    }
    _at++;
    return entries;
  }
}
