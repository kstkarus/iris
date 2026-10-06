import 'package:dio/dio.dart';

import 'package:iris/shared/network/aniskip_api.dart';

/// Short timeouts: skip times are a nicety and must never hold up playback.
Dio createAniSkipDio() {
  return Dio(
    BaseOptions(
      baseUrl: AniSkipApi.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      responseType: ResponseType.json,
      listFormat: ListFormat.multi,
      headers: const {'Accept': 'application/json'},
      // AniSkip answers 404 when it knows no times for an episode.
      validateStatus: (status) =>
          status != null && (status < 300 || status == 404),
    ),
  );
}
