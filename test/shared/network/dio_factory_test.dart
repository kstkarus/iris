import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/shikimori_api.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_secure_storage.dart';

void main() {
  test('names the app to Shikimori and keeps to its request limits', () {
    final dio = createShikimoriDio();

    expect(dio.options.headers['User-Agent'], ShikimoriApi.userAgent);
    expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<ShikimoriAuthInterceptor>(), isEmpty);
  });

  test('with a session, signs requests in before they are rate limited', () {
    final dio = createShikimoriDio(
      session: ShikimoriSessionStore(FakeSecureStorage()),
      oauth: ShikimoriOAuthClient(
        dio: createShikimoriOAuthDio(),
        config: const ShikimoriOAuthConfig(clientId: 'id', clientSecret: 's'),
      ),
    );

    final kinds = dio.interceptors.map(
      (interceptor) => interceptor.runtimeType,
    );
    expect(
      kinds.where(
        (kind) =>
            kind == ShikimoriAuthInterceptor || kind == RateLimitInterceptor,
      ),
      [ShikimoriAuthInterceptor, RateLimitInterceptor],
    );
  });

  test('the token client names the app and keeps to the same limits', () {
    final dio = createShikimoriOAuthDio();

    expect(dio.options.headers['User-Agent'], ShikimoriApi.userAgent);
    expect(dio.options.contentType, Headers.formUrlEncodedContentType);
    expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<ShikimoriAuthInterceptor>(), isEmpty);
  });

  test('a JSON API client asks for JSON at its base URL', () {
    final dio = createJsonApiDio(
      baseUrl: 'https://example.org/api',
      receiveTimeout: const Duration(seconds: 30),
    );

    expect(dio.options.baseUrl, 'https://example.org/api');
    expect(dio.options.headers['Accept'], 'application/json');
    expect(dio.options.responseType, ResponseType.json);
    expect(dio.options.receiveTimeout, const Duration(seconds: 30));
    expect(
      createJsonApiDio(baseUrl: 'https://example.org').options.receiveTimeout,
      const Duration(seconds: 20),
    );
  });
}
