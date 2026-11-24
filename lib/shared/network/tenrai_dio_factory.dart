import 'package:dio/dio.dart';

import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/tenrai_api.dart';

/// Short timeouts and Tenrai's own rate limits: episode metadata is optional
/// and must never hold up browsing or playback.
Dio createTenraiDio({
  DateTime Function()? now,
  Future<void> Function(Duration)? wait,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: TenraiApi.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
      // Tenrai answers 404 when an anime has no MAL entry or episode list.
      validateStatus: (status) =>
          status != null && (status < 300 || status == 404),
    ),
  );
  dio.interceptors.add(
    RateLimitInterceptor(
      dio: dio,
      limits: TenraiApi.rateLimits,
      now: now,
      wait: wait,
    ),
  );
  return dio;
}
