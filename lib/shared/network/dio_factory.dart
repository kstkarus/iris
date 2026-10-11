import 'package:dio/dio.dart';

import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/shikimori_api.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

/// A plain JSON API client, such as AniLibria, Nyaa or YummyAnime.
Dio createJsonApiDio({
  required String baseUrl,
  Duration receiveTimeout = const Duration(seconds: 20),
}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: receiveTimeout,
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
}

/// The Shikimori API client; with a [session] and [oauth] it also signs
/// requests in as the account (anonymous requests go as before).
Dio createShikimoriDio({
  ShikimoriSessionStore? session,
  ShikimoriOAuthClient? oauth,
}) {
  final dio = _shikimoriBaseDio(contentType: Headers.jsonContentType);
  if (session != null && oauth != null) {
    dio.interceptors.add(
      ShikimoriAuthInterceptor(dio: dio, store: session, oauth: oauth),
    );
  }
  return dio
    ..interceptors.add(
      RateLimitInterceptor(dio: dio, limits: ShikimoriApi.rateLimits),
    );
}

/// For [ShikimoriOAuthClient]: the same limits, no auth interceptor.
Dio createShikimoriOAuthDio() {
  final dio = _shikimoriBaseDio(contentType: Headers.formUrlEncodedContentType);
  return dio
    ..interceptors.add(
      RateLimitInterceptor(dio: dio, limits: ShikimoriApi.rateLimits),
    );
}

Dio _shikimoriBaseDio({required String contentType}) => Dio(
  BaseOptions(
    baseUrl: ShikimoriApi.baseUrl,
    responseType: ResponseType.json,
    contentType: contentType,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: const {'User-Agent': ShikimoriApi.userAgent},
  ),
);
