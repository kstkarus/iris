import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// Reads an episode's links from Aksor's player API, as anicli-api
/// 0.12.0's `player/aksor.py` does: one GET by the video id at the end of
/// the player's URL, with yummy_anime as the referrer.
class AksorDataSource {
  const AksorDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _apiBase = 'https://player.aksor.tv/api/video/';
  static const _referer = 'https://old.yummyani.me/';

  Future<List<VideoLinkDto>> links(String playerUrl) async {
    final videoId = Uri.parse(playerUrl).pathSegments.lastOrNull ?? '';
    if (videoId.isEmpty) {
      throw const ResourceNotFoundException('Aksor link has no video id.');
    }
    final Response<String> response;
    try {
      response = await _dio.get<String>(
        '$_apiBase$videoId',
        options: Options(
          headers: const {'Accept': 'application/json', 'Referer': _referer},
        ),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
    final status = response.statusCode ?? 0;
    if (status == 404) {
      throw const ResourceNotFoundException('Aksor has no such video.');
    }
    if (status < 200 || status >= 300) {
      throw RemoteResponseException('Aksor answered $status.');
    }
    return parseAksorLinks(response.data ?? '');
  }
}

const _qualities = {
  'q4k': 2160,
  'q2k': 1440,
  'q1080': 1080,
  'q720': 720,
  'q480': 480,
  'q360': 360,
};

/// The links of an Aksor API answer, best first.
List<VideoLinkDto> parseAksorLinks(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const RemoteResponseException('Aksor answer is not JSON.');
  }
  final qualities = json is Map ? json['qualities'] : null;
  if (qualities is! Map) {
    throw const RemoteResponseException('Aksor answer has no qualities.');
  }
  return [
    for (final MapEntry(key: name, value: quality) in _qualities.entries)
      if (qualities[name] case final String url when url.isNotEmpty)
        if (_kind(url) case final kind?)
          VideoLinkDto(url: url, quality: quality, kind: kind),
  ];
}

VideoLinkKind? _kind(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.mpd')) return VideoLinkKind.dash;
  if (path.endsWith('.m3u8')) return VideoLinkKind.hls;
  if (path.endsWith('.mp4')) return VideoLinkKind.mp4;
  return null;
}
