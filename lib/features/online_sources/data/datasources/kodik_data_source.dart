import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// Reads an episode's HLS links out of a Kodik player page, as
/// anicli-api 0.12.0's `player/kodik.py` does:
///
/// 1. GET the player page; it carries a signed request in `var` lines.
/// 2. Find the API path in the player's script (`atob("L2Z0b3I=")`). The
///    path changes now and then, so it is kept and read again on refusal.
/// 3. POST the request; the links come back ROT18 and base64 encoded.
class KodikDataSource {
  KodikDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// The API path last read from the player script.
  String? _apiPath;

  static final _variables = {
    'd': RegExp(r'''var\s*domain\s+=\s+['"](.*?)['"];'''),
    'd_sign': RegExp(r'''var\s*d_sign\s+=\s+['"](.*?)['"];'''),
    'pd': RegExp(r'''var\s*pd\s+=\s+['"](.*?)['"];'''),
    'pd_sign': RegExp(r'''var\s*pd_sign\s+=\s+['"](.*?)['"];'''),
    'ref': RegExp(r'''var\s*ref\s+=\s+['"](.*?)['"];'''),
    'ref_sign': RegExp(r'''var\s*ref_sign\s+=\s+['"](.*?)['"];'''),
    'type': RegExp(r'''vInfo\.type = ['"](.*?)['"];'''),
    'hash': RegExp(r'''vInfo\.hash = ['"](.*?)['"];'''),
    'id': RegExp(r'''vInfo\.id = ['"](.*?)['"];'''),
  };
  static final _scriptPath = RegExp(
    r'''<script[^>]+src=["']([^"']*assets/js[^"']*)["']''',
  );
  static final _apiPathInScript = RegExp(
    r'''\$\.ajax[^)]+atob\(["'](\w+=*)["']\)''',
  );

  Future<List<VideoLinkDto>> links(String playerUrl) async {
    final page = Uri.parse(playerUrl);
    final html = await _getText(page);
    final payload = _payload(html);
    if (payload == null) {
      // A deleted video's page has a message and no request in it.
      throw const ResourceNotFoundException('Kodik has no such video.');
    }
    _apiPath ??= await _readApiPath(page, html);
    var response = await _post(page, payload);
    if (!_isSuccess(response)) {
      _apiPath = await _readApiPath(page, html);
      response = await _post(page, payload);
    }
    if (!_isSuccess(response)) {
      throw RemoteResponseException('Kodik answered ${response.statusCode}.');
    }
    return parseKodikLinks(response.data ?? '');
  }

  Map<String, String>? _payload(String html) {
    final payload = <String, String>{};
    for (final MapEntry(:key, value: pattern) in _variables.entries) {
      final match = pattern.firstMatch(html);
      if (match == null) return null;
      payload[key] = match.group(1)!;
    }
    return {
      ...payload,
      'bad_user': 'false',
      'info': '{}',
      'cdn_is_working': 'true',
    };
  }

  Future<String> _readApiPath(Uri page, String html) async {
    final script = _scriptPath.firstMatch(html)?.group(1);
    if (script == null) {
      throw const RemoteResponseException('Kodik page has no player script.');
    }
    final source = await _getText(page.resolve(script));
    final encoded = _apiPathInScript.firstMatch(source)?.group(1);
    if (encoded == null) {
      throw const RemoteResponseException('Kodik script has no API path.');
    }
    return utf8.decode(base64.decode(encoded));
  }

  Future<Response<String>> _post(Uri page, Map<String, String> payload) {
    return _request(
      () => _dio.postUri<String>(
        Uri(scheme: page.scheme, host: page.host, path: _apiPath),
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Origin': '${page.scheme}://${page.host}',
            'Referer': page.toString(),
            'Accept': 'application/json, text/javascript, */*; q=0.01',
          },
        ),
      ),
    );
  }

  Future<String> _getText(Uri uri) async {
    final response = await _request(() => _dio.getUri<String>(uri));
    if (!_isSuccess(response)) {
      throw RemoteResponseException('Kodik answered ${response.statusCode}.');
    }
    return response.data ?? '';
  }

  Future<Response<String>> _request(
    Future<Response<String>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  bool _isSuccess(Response<String> response) {
    final status = response.statusCode ?? 0;
    return status >= 200 && status < 300;
  }
}

/// The links of a Kodik API answer, best first.
List<VideoLinkDto> parseKodikLinks(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const RemoteResponseException('Kodik answer is not JSON.');
  }
  final links = json is Map ? json['links'] : null;
  if (links is! Map) {
    throw const RemoteResponseException('Kodik answer has no links.');
  }
  final result = <VideoLinkDto>[];
  for (final MapEntry(:key, :value) in links.entries) {
    final quality = int.tryParse('$key');
    final first = value is List && value.isNotEmpty ? value.first : null;
    final source = first is Map ? first['src'] : null;
    if (quality == null || source is! String || source.isEmpty) continue;
    result.add(
      VideoLinkDto(
        url: _fixKodikQuality(decodeKodikLink(source), quality),
        quality: quality,
        kind: VideoLinkKind.hls,
      ),
    );
  }
  result.sort((left, right) => right.quality.compareTo(left.quality));
  return result;
}

/// Kodik has answered its 720 key with the 480 file; anicli-api swaps the
/// file name back, and so does this.
String _fixKodikQuality(String link, int quality) {
  if (quality != 720) return link;
  return link.replaceFirst('/480.mp4:', '/720.mp4:');
}

/// A link as Kodik hides it: ROT18 over base64, or plain since 2025 for
/// some; either may lack the scheme.
String decodeKodikLink(String encoded) {
  final String link;
  if (encoded.endsWith('.m3u8')) {
    link = encoded;
  } else {
    final rotated = String.fromCharCodes([
      for (final unit in encoded.codeUnits) _rot18(unit),
    ]);
    final padded = rotated.padRight((rotated.length + 3) ~/ 4 * 4, '=');
    link = utf8.decode(base64.decode(padded));
  }
  return link.startsWith('//') ? 'https:$link' : link;
}

int _rot18(int unit) {
  const upperA = 65, upperZ = 90, lowerA = 97, lowerZ = 122;
  if (unit >= upperA && unit <= upperZ) {
    return (unit - upperA + 18) % 26 + upperA;
  }
  if (unit >= lowerA && unit <= lowerZ) {
    return (unit - lowerA + 18) % 26 + lowerA;
  }
  return unit;
}
