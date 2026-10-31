import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import 'package:iris/features/online_sources/data/datasources/alloha_stream_proxy.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/utils/json_read.dart';

/// The subtitle translation selected by the site and its available episodes.
typedef AllohaEpisodes = ({
  String translationId,
  String translation,
  Map<int, int> videoIds,
});

class AllohaDataSource {
  AllohaDataSource({required Dio dio, AllohaSocketConnect? connect})
    : _dio = dio,
      _proxy = AllohaStreamProxy(dio: dio, connect: connect);

  final Dio _dio;
  final AllohaStreamProxy _proxy;

  Future<AllohaEpisodes?> episodes(String playerUrl) async {
    final uri = Uri.tryParse(playerUrl);
    if (uri == null || !isAllohaPlayer(uri)) {
      throw const ResourceNotFoundException('Unsupported Alloha player URL.');
    }
    final html = await _getText(uri, referer: 'https://animejoy.ru/');
    return _episodesFromHtml(html);
  }

  AllohaEpisodes? _episodesFromHtml(String html) {
    final match = RegExp(
      r"""const\s+fileList\s*=\s*JSON\.parse\('((?:\\.|[^'\\])*)'\s*\)""",
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(match.group(1)!.replaceAll(r"\'", "'"));
    } on FormatException {
      throw const RemoteResponseException('Alloha episode list is invalid.');
    }
    final fileList = jsonMap(decoded);
    final active = jsonMap(fileList['active']);
    final translation = jsonString(active['translation']).trim();
    final translationId = jsonIntOrNull(active['id_translation']);
    if (translationId == null ||
        translationId <= 0 ||
        !RegExp(
          r'субтитр|subtitle',
          caseSensitive: false,
        ).hasMatch(translation)) {
      return null;
    }
    final videoIds = <int, int>{};
    if (fileList['type'] == 'movie') {
      final id = jsonIntOrNull(active['id']);
      if (id != null && id > 0) videoIds[1] = id;
    } else if (fileList['type'] == 'serial') {
      final season = jsonIntOrNull(active['seasons']);
      if (season == null || season <= 0) return null;
      final all = jsonMap(fileList['all']);
      final selected = jsonMap(all['t$translationId']);
      final seasons = jsonMap(selected['file']);
      final episodes = jsonMap(seasons['$season']);
      for (final MapEntry(:key, :value) in episodes.entries) {
        final number = int.tryParse('$key');
        final episode = jsonMap(value);
        final id = jsonIntOrNull(episode['id']);
        final actualNumber = jsonIntOrNull(episode['episode']);
        final actualSeason = jsonIntOrNull(episode['seasons']);
        final actualTranslation = jsonIntOrNull(episode['id_translation']);
        if (number == null ||
            number <= 0 ||
            id == null ||
            id <= 0 ||
            actualNumber != number ||
            actualSeason != season ||
            actualTranslation != translationId) {
          continue;
        }
        videoIds[number] = id;
      }
    }
    if (videoIds.isEmpty) return null;
    return (
      translationId: '$translationId',
      translation: translation,
      videoIds: videoIds,
    );
  }

  Future<List<VideoLinkDto>> links(
    String playerUrl, {
    required int videoId,
  }) async {
    final player = Uri.tryParse(playerUrl);
    if (player == null || !isAllohaPlayer(player)) {
      throw const ResourceNotFoundException('Unsupported Alloha player URL.');
    }
    final html = await _getText(player, referer: 'https://animejoy.ru/');
    if (!(_episodesFromHtml(html)?.videoIds.values.contains(videoId) ??
        false)) {
      throw const ResourceNotFoundException('Alloha episode is unavailable.');
    }
    final document = parse(html);
    final viewport = document
        .querySelector('meta[name="viewporti"]')
        ?.attributes['content'];
    final app = document
        .querySelector('script[src*="/build/app."]')
        ?.attributes['src'];
    final token = player.queryParameters['token'];
    if (viewport == null ||
        viewport.isEmpty ||
        viewport.length > 4096 ||
        app == null ||
        token == null ||
        token.isEmpty) {
      throw const RemoteResponseException('Alloha player session is invalid.');
    }
    final appUri = player.resolve(app);
    if (appUri.origin != player.origin) {
      throw const RemoteResponseException('Alloha player script is invalid.');
    }
    final script = (await _getText(appUri, referer: player.toString()))
        .replaceAllMapped(
          RegExp(r'\\x([0-9a-fA-F]{2})'),
          (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
        );
    // shortcut: expects a single long guard literal, update if Alloha changes its player.
    final guards = RegExp(
      r'''['"]([A-Za-z0-9+/=_-]{200,})['"]''',
    ).allMatches(script).toList();
    if (guards.length != 1) {
      throw const RemoteResponseException(
        'Alloha player guard is unavailable.',
      );
    }
    final random = Random.secure();
    final nonce = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final Response<String> response;
    try {
      response = await _dio.postUri<String>(
        player.replace(path: '/bnsi/movies/$videoId', query: ''),
        data: {
          'token': token,
          'av1': 'true',
          'autoplay': '0',
          'audio': '',
          'subtitle': '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Origin': player.origin,
            'Referer': player.toString(),
            'User-Agent': allohaUserAgent,
            'X-Requested-With': 'XMLHttpRequest',
            'Borth': '$nonce|${_viewportSignature(viewport)}',
          },
        ),
      );
    } on DioException {
      throw const NetworkRequestException('Unable to reach Alloha.');
    }
    if (response.statusCode != 200) {
      throw const RemoteResponseException('Alloha video request was refused.');
    }
    final Map<Object?, Object?> data;
    try {
      data = jsonMap(jsonDecode(response.data ?? ''));
    } on FormatException {
      throw const RemoteResponseException('Alloha video response is invalid.');
    }
    final sources = data['hlsSource'];
    final tracks = data['tracks'];
    if (sources is! List || tracks is! List) {
      throw const RemoteResponseException('Alloha video has no tracks.');
    }
    final source = sources
        .map(jsonMap)
        .where(
          (source) =>
              jsonString(source['label']).toLowerCase().contains('japanese'),
        )
        .firstOrNull;
    final subtitles = tracks
        .map(jsonMap)
        .where(
          (track) =>
              track['kind'] == 'captions' &&
              {
                'ru',
                'rus',
              }.contains(jsonString(track['language']).toLowerCase()),
        )
        .toList();
    final fullSubtitles = subtitles.where((track) {
      final label = jsonString(track['label']).toLowerCase();
      return !label.contains('надписи') && !label.contains('forced');
    }).toList();
    final subtitle =
        fullSubtitles.where((track) => track['default'] == true).firstOrNull ??
        fullSubtitles.firstOrNull;
    final qualities = <int, List<Uri>>{};
    for (final entry in jsonMap(source?['quality']).entries) {
      final quality = int.tryParse('${entry.key}');
      final mirrors = jsonString(
        entry.value,
      ).split(' or ').map(Uri.tryParse).whereType<Uri>().toList();
      if (quality != null && quality > 0 && mirrors.isNotEmpty) {
        qualities[quality] = mirrors;
      }
    }
    final subtitleUri = Uri.tryParse(jsonString(subtitle?['src']));
    final socket = Uri.tryParse(jsonString(data['pnr']));
    final audioId = source?['audioId']?.toString() ?? '';
    if (qualities.isEmpty ||
        subtitleUri == null ||
        socket == null ||
        audioId.isEmpty) {
      throw const RemoteResponseException(
        'Alloha Japanese audio or Russian subtitles are unavailable.',
      );
    }
    final ({Map<int, String> qualities, String subtitle}) result;
    try {
      result = await _proxy.open(
        player: player,
        socket: socket,
        socketId: jsonString(data['pnk']),
        guard: guards.single.group(1)!,
        audioId: audioId,
        qualities: qualities,
        subtitle: subtitleUri,
      );
    } on DioException {
      throw const NetworkRequestException('Unable to reach Alloha.');
    } on Object {
      throw const RemoteResponseException(
        'Alloha video session is unavailable.',
      );
    }
    final links = [
      for (final entry in result.qualities.entries)
        VideoLinkDto(
          url: entry.value,
          quality: entry.key,
          kind: VideoLinkKind.hls,
          subtitleUrl: result.subtitle,
        ),
    ];
    links.sort((a, b) => b.quality.compareTo(a.quality));
    return links;
  }

  Future<void> close() => _proxy.close();

  Future<String> _getText(Uri uri, {required String referer}) async {
    final Response<String> response;
    try {
      response = await _dio.getUri<String>(
        uri,
        options: Options(
          headers: {'Referer': referer, 'User-Agent': allohaUserAgent},
        ),
      );
    } on DioException {
      throw const NetworkRequestException('Unable to reach Alloha.');
    }
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw RemoteResponseException('Alloha answered $status.');
    }
    return response.data ?? '';
  }
}

String _viewportSignature(String value) {
  String inverse(
    String value,
    int Function(int, int) group, {
    required bool descending,
  }) {
    final groups = List.generate(value.length, (i) => group(i, value.length));
    final counts = <int, int>{};
    for (final group in groups) {
      counts[group] = (counts[group] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
    final starts = <int, int>{};
    var offset = 0;
    for (final key in keys) {
      starts[key] = offset;
      offset += counts[key]!;
    }
    return groups.map((group) {
      final index = starts[group]!;
      starts[group] = index + 1;
      return value[index];
    }).join();
  }

  int trailing(int index, int length) {
    if (index == 0) return (length - 1).bitLength;
    var count = 0;
    while (index.isEven) {
      count++;
      index >>= 1;
    }
    return count;
  }

  final reversed = inverse(
    inverse(value, (i, _) => i.bitLength, descending: true),
    trailing,
    descending: false,
  );
  bool prime(int n) {
    if (n < 2) return false;
    for (var i = 2; i * i <= n; i++) {
      if (n % i == 0) return false;
    }
    return true;
  }

  var modulus = reversed.length + 1;
  while (!prime(modulus)) {
    modulus++;
  }
  final result = List<String>.filled(reversed.length, '');
  var cursor = 0;
  for (var i = 0; i < reversed.length;) {
    cursor = (cursor + 2) % modulus;
    if (cursor < reversed.length && result[cursor].isEmpty) {
      result[cursor] = reversed[i++];
    }
  }
  return result.join();
}

bool isAllohaPlayer(Uri uri) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      (host.endsWith('.stravers.live') ||
          host.endsWith('.stloadi.live') ||
          host.endsWith('.alloha.tv'));
}
