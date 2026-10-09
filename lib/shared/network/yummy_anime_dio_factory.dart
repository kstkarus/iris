import 'package:dio/dio.dart';

import 'package:iris/shared/network/yummy_anime_api.dart';

Dio createYummyAnimeDio() {
  return Dio(
    BaseOptions(
      baseUrl: YummyAnimeApi.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      // A long-running anime lists thousands of videos.
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
}
