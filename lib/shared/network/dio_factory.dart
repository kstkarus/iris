import 'package:dio/dio.dart';

import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/shikimori_api.dart';

Dio createDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ShikimoriApi.baseUrl,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'User-Agent': ShikimoriApi.userAgent},
    ),
  );
  return dio
    ..interceptors.add(
      RateLimitInterceptor(dio: dio, limits: ShikimoriApi.rateLimits),
    );
}
