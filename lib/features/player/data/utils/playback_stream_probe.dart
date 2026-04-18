import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

abstract interface class PlaybackStreamProbe {
  Future<PlaybackProbeResult> probe(String url);
}

class PlaybackProbeResult {
  const PlaybackProbeResult({
    required this.statusCode,
    required this.contentType,
    required this.contentLength,
    required this.acceptRanges,
    required this.firstBytes,
    this.error,
  });

  final int? statusCode;
  final ContentType? contentType;
  final int? contentLength;
  final String? acceptRanges;
  final List<int> firstBytes;
  final Object? error;

  bool get hasSuccessfulStatus =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  bool get hasBodyBytes => firstBytes.isNotEmpty;

  bool get looksLikePlayableMedia {
    if (!hasSuccessfulStatus || !hasBodyBytes) {
      return false;
    }

    if (_startsWith(firstBytes, const [0x1A, 0x45, 0xDF, 0xA3])) {
      return true;
    }

    if (firstBytes.length >= 8 &&
        ascii.decode(firstBytes.skip(4).take(4).toList(), allowInvalid: true) ==
            'ftyp') {
      return true;
    }

    if (firstBytes.length >= 12 &&
        ascii.decode(firstBytes.take(4).toList(), allowInvalid: true) ==
            'RIFF' &&
        ascii.decode(firstBytes.skip(8).take(3).toList(), allowInvalid: true) ==
            'AVI') {
      return true;
    }

    if (firstBytes.first == 0x47) {
      return true;
    }

    final mediaType = contentType?.mimeType.toLowerCase();
    if (mediaType != null &&
        (mediaType.startsWith('video/') ||
            mediaType == 'application/octet-stream')) {
      return true;
    }

    return false;
  }
}

class HttpPlaybackStreamProbe implements PlaybackStreamProbe {
  const HttpPlaybackStreamProbe({this.timeout = const Duration(seconds: 5)});

  final Duration timeout;

  @override
  Future<PlaybackProbeResult> probe(String url) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final result = await () async {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-63');
        final response = await request.close();
        final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
          if (buffer.length >= 64) {
            return buffer;
          }

          final remaining = 64 - buffer.length;
          buffer.addAll(chunk.take(remaining));
          return buffer;
        });

        return PlaybackProbeResult(
          statusCode: response.statusCode,
          contentType: response.headers.contentType,
          contentLength: response.contentLength,
          acceptRanges: response.headers.value(HttpHeaders.acceptRangesHeader),
          firstBytes: bytes,
        );
      }().timeout(timeout);

      developer.log(
        'HTTP probe completed. status=${result.statusCode} contentType=${result.contentType} contentLength=${result.contentLength} acceptRanges=${result.acceptRanges} firstBytesHex=${_toHex(result.firstBytes)} firstBytesText=${_toAscii(result.firstBytes)} looksLikePlayableMedia=${result.looksLikePlayableMedia}',
        name: 'iris.player.http_probe',
      );
      return result;
    } catch (error, stackTrace) {
      developer.log(
        'HTTP probe failed.',
        name: 'iris.player.http_probe',
        error: error,
        stackTrace: stackTrace,
      );
      return PlaybackProbeResult(
        statusCode: null,
        contentType: null,
        contentLength: null,
        acceptRanges: null,
        firstBytes: const [],
        error: error,
      );
    } finally {
      client.close(force: true);
    }
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }

  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }

  return true;
}

String _toHex(List<int> bytes) {
  if (bytes.isEmpty) {
    return 'empty';
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}

String _toAscii(List<int> bytes) {
  if (bytes.isEmpty) {
    return 'empty';
  }

  final decoded = latin1.decode(bytes, allowInvalid: true);
  return decoded.replaceAll(RegExp(r'[^\x20-\x7E]'), '.');
}
