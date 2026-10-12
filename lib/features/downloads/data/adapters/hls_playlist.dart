/// One piece of an HLS episode to load: a media segment, or the init
/// segment of fragmented MP4.
class HlsPiece {
  const HlsPiece(this.uri, {this.seconds = 0});

  final Uri uri;

  /// Play time the playlist gives the segment; 0 for the init segment.
  final double seconds;
}

/// The pieces of an HLS episode, in order.
class HlsPlan {
  const HlsPlan({required this.segments, this.init});

  /// The init segment of fragmented MP4; null for MPEG-TS.
  final HlsPiece? init;
  final List<HlsPiece> segments;

  bool get fragmentedMp4 => init != null;
}

/// Reads the HLS playlists of video servers, as far as loading them takes:
/// variants, segments and the fMP4 init segment. Encrypted and byte-range
/// playlists are not loaded.
abstract final class HlsPlaylist {
  static const _variantTag = '#EXT-X-STREAM-INF:';

  /// The variant of a master playlist to load: the one [quality] high, or
  /// the best. Null for a media playlist.
  static Uri? pickVariant(String text, Uri base, {required int quality}) {
    final lines = _lines(text);
    final variants = <({Uri uri, int height, int bandwidth})>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (!line.startsWith(_variantTag)) continue;
      final uri = lines
          .skip(index + 1)
          .firstWhere(
            (next) => next.isNotEmpty && !next.startsWith('#'),
            orElse: () => '',
          );
      if (uri.isEmpty) continue;
      final attributes = line.substring(_variantTag.length);
      final resolution = _attribute(attributes, 'RESOLUTION');
      final height = int.tryParse(resolution?.split('x').last ?? '') ?? 0;
      final bandwidth = int.tryParse(_attribute(attributes, 'BANDWIDTH') ?? '');
      variants.add((
        uri: resolveHlsUri(base, uri),
        height: height,
        bandwidth: bandwidth ?? 0,
      ));
    }
    if (variants.isEmpty) return null;
    for (final variant in variants) {
      if (variant.height == quality) return variant.uri;
    }
    variants.sort((left, right) {
      final height = right.height.compareTo(left.height);
      return height != 0 ? height : right.bandwidth.compareTo(left.bandwidth);
    });
    return variants.first.uri;
  }

  /// The pieces of a media playlist; null when it cannot be loaded as
  /// plain pieces (encrypted, byte ranges) or has none.
  static HlsPlan? parseMedia(String text, Uri base) {
    HlsPiece? init;
    final segments = <HlsPiece>[];
    var seconds = 0.0;
    for (final line in _lines(text)) {
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final value = line.substring('#EXTINF:'.length).split(',').first;
        seconds = double.tryParse(value.trim()) ?? 0;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        final method = _attribute(line.substring(11), 'METHOD');
        if (method != null && method != 'NONE') return null;
      } else if (line.startsWith('#EXT-X-BYTERANGE')) {
        return null;
      } else if (line.startsWith('#EXT-X-MAP:')) {
        final attributes = line.substring('#EXT-X-MAP:'.length);
        if (_attribute(attributes, 'BYTERANGE') != null) return null;
        final uri = _attribute(attributes, 'URI');
        if (uri == null || init != null) return null;
        init = HlsPiece(resolveHlsUri(base, uri));
      } else if (!line.startsWith('#')) {
        segments.add(HlsPiece(resolveHlsUri(base, line), seconds: seconds));
        seconds = 0;
      }
    }
    if (segments.isEmpty) return null;
    return HlsPlan(init: init, segments: List.unmodifiable(segments));
  }

  static List<String> _lines(String text) => [
    for (final line in text.split('\n')) line.trim(),
  ];

  /// An attribute of a tag's list: `METHOD=AES-128,URI="key.bin"`.
  static String? _attribute(String attributes, String name) {
    final match = RegExp('(?:^|,)$name=("[^"]*"|[^,]*)').firstMatch(attributes);
    final value = match?.group(1);
    if (value == null) return null;
    return value.startsWith('"') && value.endsWith('"') && value.length >= 2
        ? value.substring(1, value.length - 1)
        : value;
  }
}

/// [reference] from a playlist at [base]. Kodik names segments like
/// `720.mp4:hls:seg-1-v1-a1.ts`, which would read as a scheme: anything
/// but http(s) is a path.
Uri resolveHlsUri(Uri base, String reference) {
  if (reference.startsWith('//')) return Uri.parse('${base.scheme}:$reference');
  final parsed = Uri.tryParse(reference);
  if (parsed != null && (parsed.isScheme('http') || parsed.isScheme('https'))) {
    return parsed;
  }
  if (parsed != null && !parsed.hasScheme) return base.resolveUri(parsed);
  return base.resolve('./$reference');
}
