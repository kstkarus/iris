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
    final dio = createDio();

    expect(dio.options.headers['User-Agent'], ShikimoriApi.userAgent);
    expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<ShikimoriAuthInterceptor>(), isEmpty);
  });

  test('with a session, signs requests in before they are rate limited', () {
    final dio = createDio(
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
    expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<ShikimoriAuthInterceptor>(), isEmpty);
  });
}
