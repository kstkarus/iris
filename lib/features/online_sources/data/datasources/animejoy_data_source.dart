import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import 'package:iris/features/online_sources/data/models/animejoy_dto.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';

class AnimejoyDataSource {
  AnimejoyDataSource({
    required Dio dio,
    String baseUrl = 'https://animejoy.ru/',
  }) : _dio = dio,
       _baseUri = Uri.parse(baseUrl);

  final Dio _dio;
  final Uri _baseUri;

  Future<List<int>> search(String title) async {
    final html = await _getText(
      _baseUri.replace(
        path: '/index.php',
        queryParameters: {
          'story': title,
          'do': 'search',
          'subaction': 'search',
        },
      ),
    );
    final document = parse(html);
    final ids = <int>{};
    for (final anchor in document.querySelectorAll(
      '#dle-content article.shortstory h2 a[href]',
    )) {
      final href = anchor.attributes['href'];
      final uri = href == null ? null : _resolveHttpUri(href, _baseUri);
      if (uri == null || uri.host != _baseUri.host) continue;
      final slug = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final id = int.tryParse(
        RegExp(r'^(\d+)-[^/]+\.html$').firstMatch(slug)?.group(1) ?? '',
      );
      if (id != null && id > 0) ids.add(id);
    }
    return ids.toList();
  }

  Future<AnimejoyArticleDto> article(int id) async {
    if (id <= 0) {
      throw const ResourceNotFoundException('Invalid Animejoy article id.');
    }
    final html = await _getText(
      _baseUri.replace(path: '/index.php', queryParameters: {'newsid': '$id'}),
      notFoundMessage: 'Animejoy article $id was not found.',
    );
    final document = parse(html);
    int? shikimoriId;
    for (final anchor in document.querySelectorAll('.abasel a[href]')) {
      final href = anchor.attributes['href'];
      final uri = href == null ? null : _resolveHttpUri(href, _baseUri);
      if (uri == null || !_shikimoriHosts.contains(uri.host)) continue;
      final match = RegExp(
        r'^/animes/(\d+)(?:-[^/]*)?/?$',
      ).firstMatch(uri.path);
      final candidate = int.tryParse(match?.group(1) ?? '');
      if (candidate != null && candidate > 0) {
        shikimoriId = candidate;
        break;
      }
    }
    return AnimejoyArticleDto(id: id, shikimoriId: shikimoriId);
  }

  Future<List<AnimejoyEpisodeDto>> episodes(int articleId) async {
    if (articleId <= 0) {
      throw const ResourceNotFoundException('Invalid Animejoy article id.');
    }
    final response = await _getText(
      _baseUri.replace(
        path: '/engine/ajax/playlists.php',
        queryParameters: {'news_id': '$articleId', 'xfield': 'playlist'},
      ),
      notFoundMessage:
          'Animejoy playlists for article $articleId were not found.',
    );
    final Object? json;
    try {
      json = jsonDecode(response);
    } on FormatException {
      throw const RemoteResponseException(
        'Animejoy playlist response is not JSON.',
      );
    }
    if (json is! Map ||
        json['success'] != true ||
        json['response'] is! String) {
      throw const RemoteResponseException(
        'Animejoy playlist response is invalid.',
      );
    }
    return _parseEpisodes(json['response'] as String, _baseUri);
  }

  Future<List<VideoLinkDto>> links(String playerUrl) async {
    final player = _resolveHttpUri(playerUrl, _baseUri);
    if (player == null || !_playerHosts.contains(player.host)) {
      throw const ResourceNotFoundException('Unsupported Animejoy player URL.');
    }

    if (player.host == 'animejoya.ru' || player.host == 'www.animejoya.ru') {
      final file = _queryValueRaw(player, 'file');
      if (file == null || file.isEmpty) {
        throw const RemoteResponseException(
          'Animejoy player has no media file.',
        );
      }
      return _parseVideoLinks(file, player);
    }

    final html = await _getText(player, referer: player.toString());
    final fields = _playerFields(html);
    final file = fields?['file'];
    if (file == null || file.isEmpty) {
      throw const RemoteResponseException('AllVideo player has no media file.');
    }
    return _parseVideoLinks(
      file,
      player,
      defaultQuality: _quality(fields?['default_quality']),
    );
  }

  Future<String> _getText(
    Uri uri, {
    String? referer,
    String? notFoundMessage,
  }) async {
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: {
            'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8',
            'Referer': ?referer,
          },
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
    final status = response.statusCode ?? 0;
    if (status == 404 && notFoundMessage != null) {
      throw ResourceNotFoundException(notFoundMessage);
    }
    if (status < 200 || status >= 300) {
      throw RemoteResponseException('Animejoy answered $status.');
    }
    return response.data ?? '';
  }
}

const _shikimoriHosts = {'shikimori.io', 'shikimori.one', 'shikimori.me'};
const _playerHosts = {
  'animejoya.ru',
  'www.animejoya.ru',
  'fsst.online',
  'www.fsst.online',
  'video1.online',
  'www.video1.online',
  'incvideo1.online',
  'www.incvideo1.online',
};

Uri? _resolveHttpUri(String value, Uri base) {
  final Uri? uri;
  try {
    uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final resolved = base.resolveUri(uri);
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    return resolved;
  } on FormatException {
    return null;
  }
}

List<AnimejoyEpisodeDto> _parseEpisodes(String html, Uri baseUri) {
  final document = parse(html);
  final playerTypes = <String, _PlayerType>{};
  for (final item in document.querySelectorAll(
    '.playlists-lists .playlists-items li[data-id]',
  )) {
    final id = item.attributes['data-id'];
    final name = item.text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (id == null) continue;
    if (name == 'наш плеер') playerTypes[id] = _PlayerType.our;
    if (name == 'allvideo') playerTypes[id] = _PlayerType.allVideo;
  }

  final episodes = <num, _EpisodeBuilder>{};
  for (final item in document.querySelectorAll(
    '.playlists-videos .playlists-items li[data-id][data-file]',
  )) {
    final type = playerTypes[item.attributes['data-id']];
    final url = _resolvePlayerUrl(item.attributes['data-file'] ?? '', baseUri);
    final parsed = _episodeLabel(item.text);
    if (type == null || url == null || parsed == null) continue;
    (episodes[parsed.number] ??= _EpisodeBuilder(
      parsed.title,
    )).add(type, url.toString());
  }

  final numbers = episodes.keys.toList()..sort();
  return [
    for (final number in numbers)
      AnimejoyEpisodeDto(
        number: number,
        title: episodes[number]!.title,
        playerUrls: episodes[number]!.urls,
        bestQuality: _playlistQuality(episodes[number]!.urls),
      ),
  ];
}

int? _playlistQuality(List<String> playerUrls) {
  var best = 0;
  for (final url in playerUrls) {
    final player = Uri.parse(url);
    if (player.host != 'animejoya.ru' && player.host != 'www.animejoya.ru') {
      continue;
    }
    try {
      final file = _queryValueRaw(player, 'file');
      if (file == null) continue;
      for (final link in _parseVideoLinks(file, player)) {
        if (link.quality > best) best = link.quality;
      }
    } on RemoteResponseException {
      // Optional metadata must not hide an episode's other player.
      continue;
    }
  }
  return best > 0 ? best : null;
}

Uri? _resolvePlayerUrl(String value, Uri baseUri) {
  final uri = _resolveHttpUri(value, baseUri);
  return uri != null && _playerHosts.contains(uri.host) ? uri : null;
}

({num number, String title})? _episodeLabel(String text) {
  final label = text.trim();
  final match = RegExp(r'^(\d+(?:[.,]\d+)?)(?=$|\s|[-–—:])').firstMatch(label);
  if (match == null) return null;
  final number = num.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (number == null || !number.isFinite || number < 0) return null;
  final title = label
      .substring(match.end)
      .replaceFirst(
        RegExp(
          r'^\s*(?:серия|эпизод)(?=$|\s|[:.,()\-–—])',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(RegExp(r'^[\s:.,()\-–—]+'), '')
      .trim();
  return (number: number, title: title);
}

enum _PlayerType { our, allVideo }

class _EpisodeBuilder {
  _EpisodeBuilder(this.title);

  final String title;
  String? ourUrl;
  String? allVideoUrl;

  void add(_PlayerType type, String url) {
    switch (type) {
      case _PlayerType.our:
        ourUrl ??= url;
      case _PlayerType.allVideo:
        allVideoUrl ??= url;
    }
  }

  List<String> get urls => [?ourUrl, ?allVideoUrl];
}

String? _queryValueRaw(Uri uri, String name) {
  for (final part in uri.query.split('&')) {
    final equals = part.indexOf('=');
    if (equals >= 0 && part.substring(0, equals) == name) {
      final value = part.substring(equals + 1);
      if (RegExp(r'https?%3a%2f%2f', caseSensitive: false).hasMatch(value)) {
        try {
          return Uri.decodeComponent(value);
        } on FormatException {
          throw const RemoteResponseException(
            'Animejoy player query is malformed.',
          );
        }
      }
      // Dart escapes literal quality brackets but leave nested media escapes,
      // such as %2F, untouched.
      return value
          .replaceAll(RegExp(r'%5b', caseSensitive: false), '[')
          .replaceAll(RegExp(r'%5d', caseSensitive: false), ']');
    }
  }
  return null;
}

List<VideoLinkDto> _parseVideoLinks(
  String file,
  Uri player, {
  int? defaultQuality,
}) {
  final links = <VideoLinkDto>[];
  final labelled = RegExp(r'\[(\d{3,4})p\]([^,\[\]]+)', caseSensitive: false);
  for (final match in labelled.allMatches(file)) {
    final quality = int.tryParse(match.group(1)!);
    final link = _videoLink(match.group(2)!, quality, player);
    if (link != null) links.add(link);
  }
  if (links.isEmpty) {
    final link = _videoLink(file, defaultQuality ?? 0, player);
    if (link != null) links.add(link);
  }
  links.sort((left, right) => right.quality.compareTo(left.quality));
  final seen = <String>{};
  return [
    for (final link in links)
      if (seen.add(link.url)) link,
  ];
}

VideoLinkDto? _videoLink(String rawUrl, int? quality, Uri player) {
  final uri = _resolveHttpUri(rawUrl, player);
  if (uri == null) return null;
  final path = uri.path.toLowerCase().replaceFirst(RegExp(r'/+$'), '');
  final kind = switch (path) {
    final p when p.endsWith('.mp4') => VideoLinkKind.mp4,
    final p when p.endsWith('.m3u8') => VideoLinkKind.hls,
    final p when p.endsWith('.mpd') => VideoLinkKind.dash,
    _ => null,
  };
  if (kind == null) return null;
  return VideoLinkDto(url: uri.toString(), quality: quality ?? 0, kind: kind);
}

int? _quality(String? value) {
  final match = value == null
      ? null
      : RegExp(r'^(\d{3,4})p?$', caseSensitive: false).firstMatch(value.trim());
  return int.tryParse(match?.group(1) ?? '');
}

Map<String, String>? _playerFields(String html) {
  final starts = RegExp(r'new\s+Playerjs\s*\(\s*\{', caseSensitive: false);
  for (final match in starts.allMatches(html)) {
    final open = html.indexOf('{', match.start);
    final close = _matchingBrace(html, open);
    if (close == null) continue;
    final fields = <String, String>{};
    final properties = RegExp(
      r'''(?:^|[,\s])["']?(id|file|default_quality)["']?\s*:\s*(?:"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)')''',
      dotAll: true,
    );
    for (final property in properties.allMatches(
      html.substring(open + 1, close),
    )) {
      final name = property.group(1)!;
      if (_braceDepthAt(html, open + 1, open + 1 + property.start) != 0) {
        continue;
      }
      fields[name] = _decodeJsString(property.group(2) ?? property.group(3)!);
    }
    // AllVideo's content players are Video<id>. An unrelated ad player can
    // also have a top-level file, but must never become an anime episode.
    if (RegExp(r'^Video\d+$').hasMatch(fields['id'] ?? '') &&
        fields.containsKey('file')) {
      return fields;
    }
  }
  return null;
}

String _decodeJsString(String value) => value.replaceAllMapped(
  RegExp(r'\\(u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|[\s\S])'),
  (match) {
    final escaped = match.group(1)!;
    if (escaped.length > 1) {
      return String.fromCharCode(int.parse(escaped.substring(1), radix: 16));
    }
    return switch (escaped) {
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      _ => escaped,
    };
  },
);

int? _matchingBrace(String source, int open) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '{') {
      depth++;
    } else if (char == '}' && --depth == 0) {
      return i;
    }
  }
  return null;
}

int _braceDepthAt(String source, int start, int end) {
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var i = start; i < end; i++) {
    final char = source[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
    } else if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
    }
  }
  return quote == null ? depth : -1;
}
