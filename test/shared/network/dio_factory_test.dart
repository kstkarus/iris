import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/shikimori_api.dart';

void main() {
  test('names the app to Shikimori and keeps to its request limits', () {
    final dio = createDio();

    expect(dio.options.headers['User-Agent'], ShikimoriApi.userAgent);
    expect(dio.interceptors.whereType<RateLimitInterceptor>(), hasLength(1));
  });
}
